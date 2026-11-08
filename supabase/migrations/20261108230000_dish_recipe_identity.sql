-- Dish identity for Recipes (FOOD_ARCHITECTURE §2–§3, November 8 owner decision).
-- Dish and Recipe are two views of one Dish. A Recipe's `dish_id` is the Dish
-- identity it belongs to; each Dish has at most one owned Recipe. The Dish row
-- itself is client-synced and may arrive after the Recipe (or not yet exist for
-- a Recipe that was never cooked), so `dish_id` is an owner-scoped identity, not
-- a foreign key. Exact cook provenance (`recipe_cooks`) is unchanged. Additive:
-- no ranking, evidence, Recipe content or relationship rows are rewritten.
begin;

alter table staygrubby.recipes add column dish_id uuid;
-- Recipe History archives content revisions. Assigning a Dish identity is not a
-- revision, so the archive fires only when revision or content change (every
-- existing write path changes the revision with its content).
drop trigger archive_recipe_revision on staygrubby.recipes;
create trigger archive_recipe_revision after insert or update of revision,content on staygrubby.recipes
 for each row execute function staygrubby.archive_recipe_revision();
create unique index recipes_owner_dish on staygrubby.recipes(owner_id,dish_id) where dish_id is not null;

-- Backfill from the D2 resolution (Main-Recipe Dish, exact-linked cook's Dish,
-- related Dish, legacy family link). If two Recipes resolve to one Dish, the
-- Dish's Main keeps it and the others stay unassigned (a later cook claims one).
with ranked as (
 select r.id,x.dish,row_number() over (partition by r.owner_id,x.dish
   order by (staygrubby.dish_main_recipe(r.owner_id,x.dish)=r.id) desc,r.created_at,r.id) n
 from staygrubby.recipes r
 cross join lateral (select staygrubby.recipe_primary_dish(r.owner_id,r.id) dish) x
 where x.dish is not null)
update staygrubby.recipes r set dish_id=ranked.dish from ranked where ranked.id=r.id and ranked.n=1;

-- True when the owner's Dish identity can hold this Recipe: no other owned
-- Recipe claims it, and it is not a Dish the owner already removed.
create function staygrubby.recipe_dish_available(owner uuid,dish uuid,recipe uuid) returns boolean
language sql stable set search_path='' as $$
 select dish is not null
  and not exists(select 1 from staygrubby.recipes r where r.owner_id=owner and r.dish_id=dish and r.id<>recipe)
  and not exists(select 1 from staygrubby.dishes d where d.account_id=owner and d.id=dish and d.deleted_at is not null)
$$;
-- The Recipe's Dish when that Dish is not removed (the row may not have synced yet).
create function staygrubby.recipe_live_dish(owner uuid,recipe uuid) returns uuid
language sql stable set search_path='' as $$
 select r.dish_id from staygrubby.recipes r
 where r.id=recipe and r.owner_id=owner and r.dish_id is not null
  and not exists(select 1 from staygrubby.dishes d where d.account_id=owner and d.id=r.dish_id and d.deleted_at is not null)
$$;
revoke all on function staygrubby.recipe_dish_available(uuid,uuid,uuid),staygrubby.recipe_live_dish(uuid,uuid) from public,anon,authenticated;

-- A completed cook of an owned Recipe gives a Recipe without a live Dish its Dish.
create function staygrubby.claim_recipe_dish_from_cook() returns trigger
language plpgsql set search_path='' as $$
declare dish uuid;
begin
 select a.dish_id into dish from staygrubby.cooking_attempts a
  where a.account_id=new.account_id and a.id=new.attempt_id and a.deleted_at is null;
 if dish is null then return new; end if;
 update staygrubby.recipes r set dish_id=dish
 where r.id=new.recipe_id and r.owner_id=new.account_id
  and staygrubby.recipe_live_dish(r.owner_id,r.id) is null
  and staygrubby.recipe_dish_available(r.owner_id,dish,r.id);
 return new;
end $$;
revoke all on function staygrubby.claim_recipe_dish_from_cook() from public,anon,authenticated;
create trigger claim_recipe_dish_from_cook after update of completed_at on staygrubby.recipe_cooks
 for each row when (old.completed_at is null and new.completed_at is not null and new.attempt_id is not null and new.recipe_id is not null)
 execute function staygrubby.claim_recipe_dish_from_cook();

-- Recipe cards carry the viewer's own Dish identity only (never another account's).
alter function staygrubby.recipe_card(uuid,uuid) rename to recipe_card_before_dish_identity;
revoke all on function staygrubby.recipe_card_before_dish_identity(uuid,uuid) from public,anon,authenticated;
create function staygrubby.recipe_card(viewer uuid,recipe uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb:=staygrubby.recipe_card_before_dish_identity(viewer,recipe);
begin
 if result is null then return null; end if;
 return result||jsonb_build_object('dishID',staygrubby.recipe_live_dish(viewer,recipe));
end $$;
revoke all on function staygrubby.recipe_card(uuid,uuid) from public,anon,authenticated;

alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_dish_identity;
revoke all on function staygrubby.recipe_api_before_dish_identity(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid; result jsonb; rid uuid:=(payload->>'recipeID')::uuid; claim uuid:=(payload->>'recipeDishID')::uuid; did uuid:=(payload->>'dishID')::uuid;
begin
 if action not in('save','set_dish','dish','library_index') then
  return staygrubby.recipe_api_before_dish_identity(action,payload);
 end if;
 if action in('save','set_dish','dish') then
  if octet_length(payload::text)>60000 then raise exception 'Invalid request' using errcode='22023'; end if;
  actor:=staygrubby.social_actor();
  perform 1 from staygrubby.accounts where id=actor and status='active' for share;
  if not found or staygrubby.social_actor() is distinct from actor then raise exception 'Account unavailable' using errcode='42501'; end if;
 end if;
 if action='dish' then
  -- The Dish's own Recipe first; older family links remain a fallback.
  select r.id into rid from staygrubby.recipes r where r.owner_id=actor and r.dish_id=did and did is not null;
  if found then return jsonb_build_object('recipe',staygrubby.recipe_card(actor,rid)); end if;
  return staygrubby.recipe_api_before_dish_identity(action,payload);
 end if;
 if action='set_dish' or (action='save' and claim is not null) then
  if claim is null or rid is null then raise exception 'Invalid request' using errcode='22023'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:dish-recipe:'||actor::text||claim::text,0));
  if action='set_dish' and not exists(select 1 from staygrubby.recipes where id=rid and owner_id=actor) then
   raise exception 'Recipe unavailable' using errcode='42501';
  end if;
  if not staygrubby.recipe_dish_available(actor,claim,rid) then raise exception 'This Dish already has a Recipe' using errcode='40001'; end if;
 end if;
 if action='set_dish' then
  update staygrubby.recipes set dish_id=claim where id=rid and owner_id=actor;
  return staygrubby.recipe_card(actor,rid);
 end if;
 result:=staygrubby.recipe_api_before_dish_identity(action,payload);
 if action='save' then
  -- A new Recipe takes its Dish identity at creation; an existing one only
  -- fills a missing or removed Dish, never moves away from a live one.
  if claim is not null then
   update staygrubby.recipes r set dish_id=claim
   where r.id=rid and r.owner_id=actor and staygrubby.recipe_live_dish(actor,r.id) is null;
  end if;
  if jsonb_typeof(result)='object' and result ? 'id' then
   result:=result||jsonb_build_object('dishID',staygrubby.recipe_live_dish(actor,(result->>'id')::uuid));
  end if;
  return result;
 end if;
 -- library_index: owned Recipes are their Dish; `cooked` follows that Dish.
 actor:=staygrubby.social_actor();
 if jsonb_typeof(result->'entries') is distinct from 'array' then return result; end if;
 select jsonb_set(result,'{entries}',coalesce(jsonb_agg(
   case when r.id is null then e
   else e||jsonb_build_object(
    'dishID',live.dish,
    'dishTitle',coalesce(d.name,e->>'recipeTitle'),
    'cooked',live.dish is not null and exists(
      select 1 from staygrubby.cooking_attempts a
      join staygrubby.ranked_items i on i.account_id=a.account_id and i.id=a.ranked_item_id and i.deleted_at is null
      where a.account_id=actor and a.dish_id=live.dish and a.deleted_at is null)) end
   order by t.ord),'[]'::jsonb))
 into result
 from jsonb_array_elements(result->'entries') with ordinality as t(e,ord)
 left join staygrubby.recipes r on r.id=(t.e->>'recipeID')::uuid and r.owner_id=actor
 left join lateral (select staygrubby.recipe_live_dish(actor,r.id) dish) live on true
 left join staygrubby.dishes d on d.account_id=actor and d.id=live.dish and d.deleted_at is null;
 return result;
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
create or replace function api.recipes(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.recipe_api(action,payload) $$;
notify pgrst,'reload schema';
commit;
