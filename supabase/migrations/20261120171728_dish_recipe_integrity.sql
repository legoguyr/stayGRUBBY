-- Dish/Recipe integrity (November 18, 2026; FOOD_ARCHITECTURE §3.1).
-- A Recipe belongs to exactly one owner Dish through `recipes.dish_id`. Three
-- transitional paths could still present a Recipe on a Dish it does not belong to:
--  1. `recipes dish` fell back to the legacy `dish_recipes` family link when the
--     Dish had no own Recipe, even when that Recipe's identity is another Dish.
--  2. `share_options` consulted the legacy link before the Dish's own Recipe.
--  3. Completing any cook of a visible Recipe (`complete`) and older builds'
--     `attach` kept writing legacy links for whatever Dish the cook landed in,
--     including another creator's Recipe.
-- This migration makes Dish identity authoritative for 1 and 3 and repairs only
-- associations that are provable. Additive and reversible: no table, Recipe,
-- revision, cook, ranking or provenance row is deleted or rewritten; legacy rows
-- stay for older builds. No new tables (growth: none). Path 2 lives in
-- 20261118160050_recipe_share_option_integrity, which needs 20261117063020's
-- share option function; this file depends only on the deployed head (split
-- November 20, 2026, before either was applied, so it deploys alone).
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

-- 1. A Dish shows only a Recipe whose identity is that Dish: the `dish` action's
-- legacy family-link fallback (in the compatibility chain's `recipe_api_before_diet_index`)
-- now answers "no Recipe". Patched in place, as the rest of the chain is, so names,
-- grants and every other action stay exactly as they are (and later migrations that
-- verify this chain still find it). Equivalent to filtering the fallback's result:
-- the Dish's own Recipe is returned just above it, and the safe repair has already
-- given every provable legacy-only Recipe its Dish.
do $apply$
declare body text:=pg_get_functiondef('staygrubby.recipe_api_before_diet_index(text,jsonb)'::regprocedure);
 fallback constant text:=$f$  if found then return jsonb_build_object('recipe',staygrubby.recipe_card(actor,rid)); end if;
  return staygrubby.recipe_api_before_dish_identity(action,payload);
 end if;$f$;
begin
 if (length(body)-length(replace(body,fallback,'')))/length(fallback)<>1 then
  raise exception 'Unexpected Dish Recipe predecessor';
 end if;
 execute replace(body,fallback,$f$  if found then return jsonb_build_object('recipe',staygrubby.recipe_card(actor,rid)); end if;
  return jsonb_build_object('recipe',null);
 end if;$f$);
end $apply$;

notify pgrst,'reload schema';
commit;
