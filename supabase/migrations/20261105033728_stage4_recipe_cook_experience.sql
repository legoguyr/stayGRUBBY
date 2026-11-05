-- Explicit owner-private current association, separate from immutable Recipe-used snapshots
-- and preserved legacy Dish-family links. No backfill or cooking/content mutation.
begin;
create table staygrubby.recipe_cook_links (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 recipe_id uuid not null references staygrubby.recipes(id) on delete cascade,
 attempt_id uuid not null,
 created_at timestamptz not null default now(),
 primary key(account_id,recipe_id),unique(account_id,attempt_id),
 foreign key(account_id,attempt_id) references staygrubby.cooking_attempts(account_id,id) on delete cascade
);
alter table staygrubby.recipe_cook_links enable row level security;
revoke all on staygrubby.recipe_cook_links from public,anon,authenticated;

-- Preserve current card fields and only expose the viewer's own association IDs.
alter function staygrubby.recipe_card(uuid,uuid) rename to recipe_card_before_cook_links;
revoke all on function staygrubby.recipe_card_before_cook_links(uuid,uuid) from public,anon,authenticated;
create function staygrubby.recipe_card(viewer uuid,recipe uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb; chosen uuid; dish uuid;
begin
 result:=staygrubby.recipe_card_before_cook_links(viewer,recipe);
 if result is null then return null; end if;
 select attempt_id into chosen from staygrubby.recipe_cook_links where account_id=viewer and recipe_id=recipe;
 if found then
  select dish_id into dish from staygrubby.cooking_attempts where account_id=viewer and id=chosen and deleted_at is null;
  result:=result||jsonb_build_object('linkedAttemptID',chosen,'linkedDishID',dish);
 end if;
 return result;
end $$;
revoke all on function staygrubby.recipe_card(uuid,uuid) from public,anon,authenticated;

create function staygrubby.recipe_link_cook(action text,payload jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=staygrubby.social_actor(); rid uuid:=(payload->>'recipeID')::uuid;
 chosen uuid:=(payload->>'attemptID')::uuid; previous uuid; existing_recipe uuid;
begin
 if octet_length(payload::text)>60000 or rid is null then raise exception 'Invalid link' using errcode='22023'; end if;
 perform 1 from staygrubby.accounts where id=actor and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from actor then raise exception 'Account unavailable' using errcode='42501'; end if;
 if action='link_cook' and not staygrubby.recipe_visible(actor,rid) then raise exception 'Recipe unavailable' using errcode='42501'; end if;
 -- Serialize an account's association edits; cooking graph and Recipe content are never changed.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:recipe-cook-link:'||actor::text,0));
 select attempt_id into previous from staygrubby.recipe_cook_links where account_id=actor and recipe_id=rid;
 if previous is distinct from (payload->>'previousAttemptID')::uuid then raise exception 'Link changed; reload' using errcode='40001'; end if;
 if action='unlink_cook' then
  delete from staygrubby.recipe_cook_links where account_id=actor and recipe_id=rid;
 elsif action='link_cook' then
  if not exists(select 1 from staygrubby.cooking_attempts where account_id=actor and id=chosen and deleted_at is null) then raise exception 'Wait for cooking sync' using errcode='40001'; end if;
  select recipe_id into existing_recipe from staygrubby.recipe_cook_links where account_id=actor and attempt_id=chosen;
  if existing_recipe is not null and existing_recipe<>rid then raise exception 'Cook already linked; unlink first' using errcode='40001'; end if;
  insert into staygrubby.recipe_cook_links(account_id,recipe_id,attempt_id) values(actor,rid,chosen)
   on conflict(account_id,recipe_id) do update set attempt_id=excluded.attempt_id;
 else raise exception 'Unknown link action' using errcode='22023'; end if;
 return staygrubby.recipe_card(actor,rid);
end $$;
revoke all on function staygrubby.recipe_link_cook(text,jsonb) from public,anon,authenticated;

alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_stage4;
revoke all on function staygrubby.recipe_api_before_stage4(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=staygrubby.social_actor(); rid uuid; result jsonb; legacy boolean:=false; exact_link boolean:=false; used jsonb; used_id uuid; completed staygrubby.recipe_cooks%rowtype;
begin
 if octet_length(payload::text)>60000 then raise exception 'Invalid request' using errcode='22023'; end if;
 perform 1 from staygrubby.accounts where id=actor and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from actor then raise exception 'Account unavailable' using errcode='42501'; end if;
 if action in('link_cook','unlink_cook') then return staygrubby.recipe_link_cook(action,payload);
 elsif action='cook' then
  if not exists(select 1 from staygrubby.cooking_attempts where account_id=actor and id=(payload->>'attemptID')::uuid and deleted_at is null) then raise exception 'Cook unavailable' using errcode='42501'; end if;
  select recipe_id into rid from staygrubby.recipe_cook_links where account_id=actor and attempt_id=(payload->>'attemptID')::uuid;
  exact_link:=found;
  select c.recipe_id,jsonb_build_object('id',c.id,'recipeID',c.recipe_id,'snapshot',c.snapshot,'revision',c.recipe_revision)
   into used_id,used from staygrubby.recipe_cooks c where c.account_id=actor and c.attempt_id=(payload->>'attemptID')::uuid and c.completed_at is not null;
  if not exact_link and used is not null then rid:=used_id;
  elsif not exact_link then
   select l.recipe_id into rid from staygrubby.dish_recipes l join staygrubby.cooking_attempts a on a.account_id=actor and a.dish_id=l.dish_id
    where l.account_id=actor and a.id=(payload->>'attemptID')::uuid and a.deleted_at is null;
   legacy:=rid is not null;
  end if;
  return jsonb_build_object('recipe',staygrubby.recipe_card(actor,rid),'legacyFamilyLink',legacy,'linkedRecipeID',rid,'exactCookLink',exact_link,'usedRecipe',used);
 elsif action='library_index' then
  -- Keep Recipe UUID pagination/deduplication; metadata is Recipe-owned, never guessed.
  select coalesce(jsonb_agg(card order by id),'[]'::jsonb) into result from (
   select r.id,jsonb_build_object('recipeID',r.id,'dishID',coalesce(a.dish_id,d.id),'linkedAttemptID',l.attempt_id,
    'dishTitle',coalesce(ad.name,d.name,r.content->>'title'),'recipeTitle',r.content->>'title',
    'course',coalesce(r.content->>'course',a.course_code,d.default_course_code),
    'cuisine',coalesce(r.content->>'cuisine',ad.cuisine->>'label',d.cuisine->>'label'),
    'revision',r.revision,'createdAt',extract(epoch from r.created_at),'updatedAt',extract(epoch from r.updated_at),
    'yield',r.content->>'yield','prepMinutes',r.content->'prepMinutes','cookMinutes',r.content->'cookMinutes',
    'elapsedMinutes',r.content->'elapsedMinutes','creatorMetadata',r.content ? 'metadataOrigins','source',r.content->>'source',
    'allergens',r.content->'allergens','photoID',r.content->>'photoID',
    'searchText',concat_ws(' ',r.content->>'title',ad.name,d.name,r.content->>'description',r.content->>'cuisine',r.content->>'source',r.content->>'originalCreator',
     (select string_agg(x,' ') from jsonb_array_elements_text(coalesce(r.content->'ingredients','[]')) x))) card
   from staygrubby.recipes r
   left join staygrubby.recipe_cook_links l on l.recipe_id=r.id and l.account_id=actor
   left join staygrubby.cooking_attempts a on a.account_id=actor and a.id=l.attempt_id and a.deleted_at is null
   left join staygrubby.dishes ad on ad.account_id=actor and ad.id=a.dish_id and ad.deleted_at is null
   left join lateral (select dish.* from staygrubby.dish_recipes old join staygrubby.dishes dish on dish.account_id=actor and dish.id=old.dish_id and dish.deleted_at is null
    where old.account_id=actor and old.recipe_id=r.id and l.attempt_id is null order by old.created_at,dish.id limit 1) d on true
   where staygrubby.recipe_visible(actor,r.id) and (r.owner_id=actor or d.id is not null or a.id is not null)
    and (payload->>'beforeID' is null or r.id>(payload->>'beforeID')::uuid)
   order by r.id limit 50) page;
  return jsonb_build_object('entries',result);
 elsif action='complete' then
  result:=staygrubby.recipe_api_before_stage4(action,payload);
  select * into completed from staygrubby.recipe_cooks where account_id=actor and id=(payload->>'originID')::uuid and completed_at is not null;
  if completed.recipe_id is not null and staygrubby.recipe_visible(actor,completed.recipe_id)
   and exists(select 1 from staygrubby.cooking_attempts where account_id=actor and id=completed.attempt_id and deleted_at is null) then
   perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:recipe-cook-link:'||actor::text,0));
   -- A fresh explicit Recipe cook may establish its link, never move an already chosen cook.
   insert into staygrubby.recipe_cook_links(account_id,recipe_id,attempt_id) values(actor,completed.recipe_id,completed.attempt_id) on conflict do nothing;
  end if;
  return result;
 elsif action='save' and payload->>'attemptID' is not null then
  result:=staygrubby.recipe_api_before_stage4(action,payload-'dishID'-'attemptID');
  return staygrubby.recipe_link_cook('link_cook',payload);
 end if;
 return staygrubby.recipe_api_before_stage4(action,payload);
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
create or replace function api.recipes(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.recipe_api(action,payload) $$;
create or replace function staygrubby.owned_recipe_share_option(payload jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=staygrubby.social_actor(); attempt uuid:=(payload->>'attemptID')::uuid;
 rid uuid; version integer; content jsonb; historical boolean:=false;
begin
 if octet_length(payload::text)>60000 then raise exception 'Invalid request' using errcode='22023'; end if;
 perform 1 from staygrubby.accounts where id=actor and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from actor then raise exception 'Account unavailable' using errcode='42501'; end if;
 if payload->>'postID' is not null then
  select source_attempt_id into attempt from staygrubby.social_posts where id=(payload->>'postID')::uuid and author_id=actor and deleted_at is null;
 end if;
 if not exists(select 1 from staygrubby.cooking_attempts where account_id=actor and id=attempt and deleted_at is null)
 then raise exception 'Cook unavailable' using errcode='42501'; end if;
 select c.recipe_id,c.recipe_revision into rid,version from staygrubby.recipe_cooks c
 join staygrubby.recipes r on r.id=c.recipe_id and r.owner_id=actor
 where c.account_id=actor and c.attempt_id=attempt and c.completed_at is not null;
 historical:=found;
 if not historical then
  select r.id,r.revision into rid,version from staygrubby.recipe_cook_links l
  join staygrubby.recipes r on r.id=l.recipe_id and r.owner_id=actor
  where l.account_id=actor and l.attempt_id=attempt;
 end if;
 if not historical and rid is null then
  select r.id,r.revision into rid,version from staygrubby.dish_recipes l
  join staygrubby.cooking_attempts a on a.account_id=actor and a.dish_id=l.dish_id and a.id=attempt
  join staygrubby.recipes r on r.id=l.recipe_id and r.owner_id=actor
  where l.account_id=actor;
 end if;
 if rid is null then return jsonb_build_object('recipe',null); end if;
 select v.content into content from staygrubby.recipe_revisions v where v.recipe_id=rid and v.revision=version;
 return jsonb_build_object('recipe',staygrubby.recipe_card(actor,rid)||jsonb_build_object('content',content,'revision',version),'fromCookSnapshot',historical);
end $$;
revoke all on function staygrubby.owned_recipe_share_option(jsonb) from public,anon,authenticated;

notify pgrst,'reload schema';
commit;
