-- D1 Unified Dish foundation (FOOD_ARCHITECTURE §3, §5). Additive only.
-- A Dish may relate to several Recipes and may have one chosen Main Recipe.
-- Exact cook use (recipe_cooks) and current cook links stay separate claims;
-- no ranking, evidence, Recipe content or legacy row is rewritten.
begin;

create table staygrubby.dish_recipe_links (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 dish_id uuid not null,
 recipe_id uuid not null references staygrubby.recipes(id) on delete cascade,
 is_main boolean not null default false,
 created_at timestamptz not null default now(),
 primary key(account_id,dish_id,recipe_id),
 foreign key(account_id,dish_id) references staygrubby.dishes(account_id,id) on delete cascade
);
create unique index dish_recipe_links_one_main on staygrubby.dish_recipe_links(account_id,dish_id) where is_main;
create index dish_recipe_links_recipe on staygrubby.dish_recipe_links(recipe_id);
alter table staygrubby.dish_recipe_links enable row level security;
revoke all on staygrubby.dish_recipe_links from public,anon,authenticated;

-- Copy each legacy family link once. It is not marked Main: the default rule
-- already prefers the legacy link, so an explicit choice stays the user's.
insert into staygrubby.dish_recipe_links(account_id,dish_id,recipe_id,created_at)
 select account_id,dish_id,recipe_id,created_at from staygrubby.dish_recipes
 on conflict do nothing;

-- One serialized association path. Auto-main: the first Recipe related to a
-- Dish with no other related Recipe becomes its chosen Main.
create function staygrubby.associate_dish_recipe(owner uuid,dish uuid,recipe uuid) returns void
language plpgsql set search_path='' as $$
begin
 if owner is null or dish is null or recipe is null or not staygrubby.recipe_visible(owner,recipe) then return; end if;
 if not exists(select 1 from staygrubby.dishes d where d.account_id=owner and d.id=dish and d.deleted_at is null) then return; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:dish-recipe:'||owner::text||dish::text,0));
 insert into staygrubby.dish_recipe_links(account_id,dish_id,recipe_id,is_main)
 values(owner,dish,recipe,not exists(select 1 from staygrubby.dish_recipe_ids(owner,dish) x where x.recipe_id<>recipe))
 on conflict do nothing;
end $$;

-- Related Recipes of a Dish (§3.1): Dish Recipes and the legacy family link,
-- Recipes exact-linked to its active cooks, and Recipes its cooks used.
create function staygrubby.dish_recipe_ids(owner uuid,dish uuid) returns table(recipe_id uuid)
language sql stable set search_path='' as $$
 select l.recipe_id from staygrubby.dish_recipe_links l where l.account_id=owner and l.dish_id=dish
 union select l.recipe_id from staygrubby.dish_recipes l where l.account_id=owner and l.dish_id=dish
 union select l.recipe_id from staygrubby.recipe_cook_links l
  join staygrubby.cooking_attempts a on a.account_id=l.account_id and a.id=l.attempt_id and a.deleted_at is null
  where l.account_id=owner and a.dish_id=dish
 union select c.recipe_id from staygrubby.recipe_cooks c
  join staygrubby.cooking_attempts a on a.account_id=c.account_id and a.id=c.attempt_id and a.deleted_at is null
  where c.account_id=owner and a.dish_id=dish and c.completed_at is not null and c.recipe_id is not null
$$;

-- Effective Main (§3.2): the chosen Main, else the legacy family link, else the
-- oldest related Recipe by creation time with UUID tie-break. Never ranking.
create function staygrubby.dish_main_recipe(owner uuid,dish uuid) returns uuid
language sql stable set search_path='' as $$
 select coalesce(
  (select l.recipe_id from staygrubby.dish_recipe_links l where l.account_id=owner and l.dish_id=dish and l.is_main
    and staygrubby.recipe_visible(owner,l.recipe_id)),
  (select l.recipe_id from staygrubby.dish_recipes l where l.account_id=owner and l.dish_id=dish
    and staygrubby.recipe_visible(owner,l.recipe_id)),
  (select r.id from staygrubby.dish_recipe_ids(owner,dish) x join staygrubby.recipes r on r.id=x.recipe_id
    where staygrubby.recipe_visible(owner,r.id) order by r.created_at,r.id limit 1))
$$;
revoke all on function staygrubby.associate_dish_recipe(uuid,uuid,uuid),staygrubby.dish_recipe_ids(uuid,uuid),
 staygrubby.dish_main_recipe(uuid,uuid) from public,anon,authenticated;

-- Legacy writes from existing app builds stay mirrored, so the new relation is
-- the complete Dish-level association. An explicit legacy detach removes it.
create function staygrubby.mirror_legacy_dish_recipe() returns trigger
language plpgsql set search_path='' as $$
begin
 if tg_op='INSERT' then
  perform staygrubby.associate_dish_recipe(new.account_id,new.dish_id,new.recipe_id); return new;
 end if;
 delete from staygrubby.dish_recipe_links where account_id=old.account_id and dish_id=old.dish_id and recipe_id=old.recipe_id;
 return old;
end $$;
create trigger mirror_legacy_dish_recipe after insert or delete on staygrubby.dish_recipes
 for each row execute function staygrubby.mirror_legacy_dish_recipe();

-- Automatic association for explicit provenance (§3.3): an exact cook link
-- and a completed Recipe-origin cook both relate the Recipe to that cook's Dish.
create function staygrubby.associate_cook_recipe() returns trigger
language plpgsql set search_path='' as $$
declare dish uuid;
begin
 select a.dish_id into dish from staygrubby.cooking_attempts a
  where a.account_id=new.account_id and a.id=new.attempt_id and a.deleted_at is null;
 perform staygrubby.associate_dish_recipe(new.account_id,dish,new.recipe_id);
 return new;
end $$;
create trigger associate_linked_cook_recipe after insert on staygrubby.recipe_cook_links
 for each row execute function staygrubby.associate_cook_recipe();
create trigger associate_used_cook_recipe after update of completed_at on staygrubby.recipe_cooks
 for each row when (old.completed_at is null and new.completed_at is not null and new.attempt_id is not null and new.recipe_id is not null)
 execute function staygrubby.associate_cook_recipe();
revoke all on function staygrubby.mirror_legacy_dish_recipe(),staygrubby.associate_cook_recipe() from public,anon,authenticated;

-- Recipe Diet as written (§5): author-selected, optional, never Certification.
alter function staygrubby.recipe_content(jsonb) rename to recipe_content_before_dietary;
revoke all on function staygrubby.recipe_content_before_dietary(jsonb) from public,anon,authenticated;
create function staygrubby.recipe_content(value jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare clean jsonb:=staygrubby.recipe_content_before_dietary(value); v jsonb:=value->'dietary'; x jsonb; codes text[]:='{}';
begin
 if value ? 'dietary' and v<>'null'::jsonb then
  if jsonb_typeof(v)<>'array' or jsonb_array_length(v)>4 then raise exception 'Invalid diet' using errcode='22023'; end if;
  for x in select item from jsonb_array_elements(v) item loop
   if jsonb_typeof(x)<>'string' or (x#>>'{}') not in('dairyFree','glutenFree','vegan','vegetarian') or (x#>>'{}')=any(codes)
   then raise exception 'Invalid diet' using errcode='22023'; end if;
   codes:=array_append(codes,x#>>'{}');
  end loop;
  if cardinality(codes)>0 then
   clean:=clean||jsonb_build_object('dietary',(select to_jsonb(array_agg(c order by c)) from unnest(codes) c));
  end if;
 end if;
 return clean;
end $$;
revoke all on function staygrubby.recipe_content(jsonb) from public,anon,authenticated;

alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_dish_recipes;
revoke all on function staygrubby.recipe_api_before_dish_recipes(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid; did uuid; rid uuid; chosen uuid; result jsonb;
begin
 if action not in('dish_recipes','link_dish_recipe','unlink_dish_recipe','set_main_recipe') then
  return staygrubby.recipe_api_before_dish_recipes(action,payload);
 end if;
 if octet_length(payload::text)>60000 then raise exception 'Invalid request' using errcode='22023'; end if;
 actor:=staygrubby.social_actor();
 perform 1 from staygrubby.accounts where id=actor and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from actor then raise exception 'Account unavailable' using errcode='42501'; end if;
 did:=(payload->>'dishID')::uuid; rid:=(payload->>'recipeID')::uuid;
 -- Only the actor's own synced Dish; this never writes the cooking graph.
 perform 1 from staygrubby.dishes d where d.account_id=actor and d.id=did and d.deleted_at is null for share;
 if not found then raise exception 'Wait for cooking sync' using errcode='40001'; end if;
 if action<>'dish_recipes' then
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:dish-recipe:'||actor::text||did::text,0));
 end if;
 if action='link_dish_recipe' then
  if rid is null or not staygrubby.recipe_visible(actor,rid) then raise exception 'Recipe unavailable' using errcode='42501'; end if;
  perform staygrubby.associate_dish_recipe(actor,did,rid);
 elsif action='unlink_dish_recipe' then
  -- Removes the Dish-level association only. Cook links and used snapshots
  -- are separate claims and stay; the legacy row goes with an explicit unlink.
  delete from staygrubby.dish_recipe_links where account_id=actor and dish_id=did and recipe_id=rid;
  delete from staygrubby.dish_recipes where account_id=actor and dish_id=did and recipe_id=rid;
 elsif action='set_main_recipe' then
  select l.recipe_id into chosen from staygrubby.dish_recipe_links l where l.account_id=actor and l.dish_id=did and l.is_main;
  -- Compare-and-swap against the chosen Main the client last saw (null = none chosen).
  if chosen is distinct from (payload->>'expectedMainID')::uuid then raise exception 'Main Recipe changed; reload' using errcode='40001'; end if;
  if rid is not null then
   if not staygrubby.recipe_visible(actor,rid) or not exists(select 1 from staygrubby.dish_recipe_ids(actor,did) x where x.recipe_id=rid)
   then raise exception 'Recipe unavailable' using errcode='42501'; end if;
  end if;
  update staygrubby.dish_recipe_links set is_main=false where account_id=actor and dish_id=did and is_main;
  if rid is not null then
   insert into staygrubby.dish_recipe_links(account_id,dish_id,recipe_id,is_main) values(actor,did,rid,true)
   on conflict(account_id,dish_id,recipe_id) do update set is_main=true;
  end if;
 end if;
 select jsonb_build_object('dishID',did,'mainRecipeID',staygrubby.dish_main_recipe(actor,did),
  'chosenMainRecipeID',(select l.recipe_id from staygrubby.dish_recipe_links l where l.account_id=actor and l.dish_id=did and l.is_main),
  'recipes',coalesce(jsonb_agg(jsonb_build_object('recipe',staygrubby.recipe_card(actor,r.id),
   'dishLinked',exists(select 1 from staygrubby.dish_recipe_links l where l.account_id=actor and l.dish_id=did and l.recipe_id=r.id),
   'legacy',exists(select 1 from staygrubby.dish_recipes l where l.account_id=actor and l.dish_id=did and l.recipe_id=r.id),
   'linkedAttemptIDs',(select coalesce(jsonb_agg(l.attempt_id order by l.attempt_id),'[]'::jsonb) from staygrubby.recipe_cook_links l
     join staygrubby.cooking_attempts a on a.account_id=l.account_id and a.id=l.attempt_id and a.deleted_at is null
     where l.account_id=actor and l.recipe_id=r.id and a.dish_id=did),
   'usedByAttemptIDs',(select coalesce(jsonb_agg(distinct c.attempt_id),'[]'::jsonb) from staygrubby.recipe_cooks c
     join staygrubby.cooking_attempts a on a.account_id=c.account_id and a.id=c.attempt_id and a.deleted_at is null
     where c.account_id=actor and c.recipe_id=r.id and a.dish_id=did and c.completed_at is not null))
   order by r.created_at,r.id),'[]'::jsonb))
 into result
 from staygrubby.dish_recipe_ids(actor,did) x join staygrubby.recipes r on r.id=x.recipe_id
 where staygrubby.recipe_visible(actor,r.id);
 return result;
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
create or replace function api.recipes(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.recipe_api(action,payload) $$;
notify pgrst,'reload schema';
commit;
