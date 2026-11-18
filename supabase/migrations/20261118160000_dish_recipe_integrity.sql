-- Dish/Recipe integrity (November 18, 2026; FOOD_ARCHITECTURE §3.1).
-- A Recipe belongs to exactly one owner Dish through `recipes.dish_id`. Three
-- transitional paths could still present a Recipe on a Dish it does not belong to:
--  1. `recipes dish` fell back to the legacy `dish_recipes` family link when the
--     Dish had no own Recipe, even when that Recipe's identity is another Dish.
--  2. `share_options` consulted the legacy link before the Dish's own Recipe.
--  3. Completing any cook of a visible Recipe (`complete`) and older builds'
--     `attach` kept writing legacy links for whatever Dish the cook landed in,
--     including another creator's Recipe.
-- This migration makes Dish identity authoritative in all three and repairs only
-- associations that are provable. Additive and reversible: no table, Recipe,
-- revision, cook, ranking or provenance row is deleted or rewritten; legacy rows
-- stay for older builds. No new tables (growth: none).
begin;

-- Safe repair: an owned Recipe with no Dish identity whose only legacy link is one
-- live Dish that has no own Recipe gets that Dish. Anything ambiguous (several
-- links, a Dish that already has a Recipe, several candidates for one Dish) is left
-- unassigned for the owner to link explicitly (Dish Detail → Add Recipe).
with candidates as (
 select r.id recipe,r.owner_id owner,min(l.dish_id::text)::uuid dish
 from staygrubby.recipes r
 join staygrubby.dish_recipes l on l.account_id=r.owner_id and l.recipe_id=r.id
 join staygrubby.dishes d on d.account_id=l.account_id and d.id=l.dish_id and d.deleted_at is null
 where r.dish_id is null
 group by r.id,r.owner_id
 having count(distinct l.dish_id)=1),
unique_claims as (
 select c.* from candidates c
 where not exists(select 1 from staygrubby.recipes o where o.owner_id=c.owner and o.dish_id=c.dish)
  and (select count(*) from candidates x where x.owner=c.owner and x.dish=c.dish)=1)
update staygrubby.recipes r set dish_id=u.dish from unique_claims u where r.id=u.recipe and r.dish_id is null;

-- 3. Legacy links are only kept when they agree with Dish identity: an owned Recipe
-- whose Dish is this Dish, or (older builds) an owned Recipe with no Dish yet.
create function staygrubby.legacy_dish_recipe_consistent() returns trigger
language plpgsql set search_path='' as $$
begin
 if exists(select 1 from staygrubby.recipes r where r.id=new.recipe_id
   and (r.owner_id<>new.account_id or (r.dish_id is not null and r.dish_id<>new.dish_id))) then
  return null; -- Skip silently: the write path stays compatible; identity decides.
 end if;
 return new;
end $$;
revoke all on function staygrubby.legacy_dish_recipe_consistent() from public,anon,authenticated;
create trigger legacy_dish_recipe_consistent before insert on staygrubby.dish_recipes
 for each row execute function staygrubby.legacy_dish_recipe_consistent();

-- 1. A Dish shows only a Recipe whose identity is that Dish.
alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_recipe_integrity;
revoke all on function staygrubby.recipe_api_before_recipe_integrity(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare result jsonb:=staygrubby.recipe_api_before_recipe_integrity(action,payload);
begin
 if action='dish' and jsonb_typeof(result->'recipe')='object'
  and (result->'recipe'->>'dishID') is distinct from (payload->>'dishID') then
  return jsonb_build_object('recipe',null);
 end if;
 return result;
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;

-- 2. Share options: the cook's exact snapshot, its exact link, then the Dish's own
-- Recipe. The legacy family link no longer decides.
do $apply$
declare body text:=pg_get_functiondef('staygrubby.owned_recipe_share_option(jsonb)'::regprocedure);
 legacy constant text:=$legacy$ if not historical and rid is null then
  select r.id,r.revision into rid,version from staygrubby.dish_recipes l
  join staygrubby.recipes r on r.id=l.recipe_id and r.owner_id=actor
  where l.account_id=actor and l.dish_id=attempt_dish;
 end if;
$legacy$;
begin
 if strpos(body,legacy)=0 then raise exception 'Unexpected share option predecessor'; end if;
 execute replace(body,legacy,'');
end $apply$;

notify pgrst,'reload schema';
commit;
