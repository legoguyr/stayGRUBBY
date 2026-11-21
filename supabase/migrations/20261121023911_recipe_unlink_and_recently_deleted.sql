-- Recipe Unlink and Recently Deleted (November 20, 2026; FOOD_ARCHITECTURE §3.6).
-- After an owner deleted a Recipe they only meant to unlink, deletion becomes recoverable
-- and unlinking becomes its own action.
--
-- Recently Deleted: a BEFORE DELETE trigger on `recipes` copies the Recipe and every row
-- that would cascade with it (revisions, saves, activity, cook links, Dish links, post
-- attachments, forks) plus the rows that only lose their reference (Recipe-used
-- snapshots, forks of it) into `recipe_trash`, then the existing delete proceeds
-- unchanged. Every delete path (the current `recipes delete` and older builds) is
-- covered without touching the Recipe API chain. Account erasure is excluded: the
-- trigger archives only for an `active` account, and erasure deletes Recipes through
-- the account row after marking it `deleting`.
-- Restore reinserts the same Recipe ID, content, revision number and history, and
-- only the related rows whose targets still exist. It reclaims its Dish only when that
-- Dish still exists and has no other Recipe. Recipes stay server-authoritative (never
-- in the device outbox), so no device can resurrect or erase one through sync.
--
-- recipe_trash — growth: at most one row per deleted Recipe, ~10–60 KB each (content
-- plus revision history); class: operational recoverable copy of canonical content;
-- retention: 30 days, then removed lazily by the owner's next delete or Recently
-- Deleted call (no scheduled job). Deleting permanently removes it at once. Photos stay
-- referenced (and so are not cleaned up) only while their Recipe is in the trash.
--
-- Unlink: `api.recipe_library('unlink_dish')` clears only the Recipe's Dish identity and
-- that Dish's legacy links to it. The Recipe, its revisions, photos, cook history,
-- Recipe-used snapshots and the Dish with its cooks and rankings are untouched.
-- Errors use PT409/42501/22023; never 40001/40P01.
begin;

create table staygrubby.recipe_trash (
 recipe_id uuid primary key,
 owner_id uuid not null references staygrubby.accounts(id) on delete cascade,
 title text not null,
 dish_id uuid,
 photo_id text,
 deleted_at timestamptz not null default now(),
 expires_at timestamptz not null,
 payload jsonb not null check (jsonb_typeof(payload)='object')
);
create index recipe_trash_owner on staygrubby.recipe_trash(owner_id, deleted_at desc);
create index recipe_trash_photo on staygrubby.recipe_trash(photo_id) where photo_id is not null;
alter table staygrubby.recipe_trash enable row level security;
revoke all on staygrubby.recipe_trash from public, anon, authenticated;

create function staygrubby.archive_deleted_recipe() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from staygrubby.accounts where id=old.owner_id and status='active') then return old; end if;
 delete from staygrubby.recipe_trash where owner_id=old.owner_id and expires_at<=now();
 insert into staygrubby.recipe_trash(recipe_id,owner_id,title,dish_id,photo_id,expires_at,payload)
 values(old.id, old.owner_id, left(coalesce(nullif(btrim(old.content->>'title'),''),'Untitled Recipe'),200), old.dish_id,
  nullif(old.content->>'photoID',''), now()+interval '30 days',
  jsonb_build_object(
   'recipe', to_jsonb(old),
   'revisions', coalesce((select jsonb_agg(to_jsonb(t)) from staygrubby.recipe_revisions t where t.recipe_id=old.id),'[]'),
   'tickets', coalesce((select jsonb_agg(to_jsonb(t)) from staygrubby.recipe_tickets t where t.recipe_id=old.id),'[]'),
   'activity', coalesce((select jsonb_agg(to_jsonb(t)) from staygrubby.recipe_activity t where t.recipe_id=old.id),'[]'),
   'cookLinks', coalesce((select jsonb_agg(to_jsonb(t)) from staygrubby.recipe_cook_links t where t.recipe_id=old.id),'[]'),
   'legacyLinks', coalesce((select jsonb_agg(to_jsonb(t)) from staygrubby.dish_recipes t where t.recipe_id=old.id),'[]'),
   'dishLinks', coalesce((select jsonb_agg(to_jsonb(t)) from staygrubby.dish_recipe_links t where t.recipe_id=old.id),'[]'),
   'postRecipes', coalesce((select jsonb_agg(to_jsonb(t)) from staygrubby.post_recipes t where t.recipe_id=old.id),'[]'),
   'fork', (select to_jsonb(t) from staygrubby.recipe_forks t where t.recipe_id=old.id),
   'forkedFrom', coalesce((select jsonb_agg(t.recipe_id) from staygrubby.recipe_forks t where t.source_recipe_id=old.id),'[]'),
   'usedSnapshots', coalesce((select jsonb_agg(t.id) from staygrubby.recipe_cooks t where t.recipe_id=old.id),'[]')))
 on conflict(recipe_id) do update set owner_id=excluded.owner_id,title=excluded.title,dish_id=excluded.dish_id,
  photo_id=excluded.photo_id,deleted_at=excluded.deleted_at,expires_at=excluded.expires_at,payload=excluded.payload;
 return old;
end $$;
revoke all on function staygrubby.archive_deleted_recipe() from public,anon,authenticated;
create trigger archive_deleted_recipe before delete on staygrubby.recipes
 for each row execute function staygrubby.archive_deleted_recipe();

-- A photo of a Recipe in Recently Deleted is still referenced, so `cleanup_photos` keeps it.
create or replace function staygrubby.recipe_photo_referenced(asset uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from staygrubby.recipes where content->>'photoID'=asset::text)
 or exists(select 1 from staygrubby.recipe_revisions where content->>'photoID'=asset::text)
 or exists(select 1 from staygrubby.recipe_cooks where snapshot->>'photoID'=asset::text)
 or exists(select 1 from staygrubby.recipe_trash where photo_id=asset::text and expires_at>now())
$$;
revoke all on function staygrubby.recipe_photo_referenced(uuid) from public,anon,authenticated;

-- Reinserts stored rows of one table, skipping any whose references no longer exist.
create function staygrubby.restore_trash_rows(target regclass, rows jsonb) returns integer
language plpgsql security definer set search_path='' as $$
declare item jsonb; restored integer:=0;
begin
 for item in select * from jsonb_array_elements(coalesce(rows,'[]'::jsonb)) loop
  begin
   execute format('insert into %s select * from jsonb_populate_record(null::%s,$1) on conflict do nothing', target, target) using item;
   restored:=restored+1;
  exception when foreign_key_violation or check_violation or not_null_violation then null;
  end;
 end loop;
 return restored;
end $$;
revoke all on function staygrubby.restore_trash_rows(regclass,jsonb) from public,anon,authenticated;

create function staygrubby.recipe_library_api(action text, payload jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=staygrubby.media_owner(); rid uuid; item staygrubby.recipe_trash%rowtype; owned staygrubby.recipes%rowtype;
 stored jsonb; dish uuid; reattached boolean:=false; result jsonb;
begin
 if actor is null then raise exception 'Account unavailable' using errcode='42501'; end if;
 if action is null or action not in ('unlink_dish','deleted','restore','purge') or octet_length(coalesce(payload,'{}'::jsonb)::text)>1024 then
  raise exception 'Invalid request' using errcode='22023';
 end if;
 begin rid:=nullif(payload->>'recipeID','')::uuid;
 exception when invalid_text_representation then raise exception 'Invalid request' using errcode='22023'; end;
 perform 1 from staygrubby.accounts where id=actor and status='active' for share;
 delete from staygrubby.recipe_trash where owner_id=actor and expires_at<=now();

 if action='deleted' then
  select coalesce(jsonb_agg(jsonb_build_object('id',t.recipe_id,'title',t.title,'photoID',t.photo_id,
    'deletedAt',extract(epoch from t.deleted_at),'expiresAt',extract(epoch from t.expires_at),
    'dishID',t.dish_id,'dishName',(select d.name from staygrubby.dishes d where d.account_id=actor and d.id=t.dish_id and d.deleted_at is null))
   order by t.deleted_at desc, t.recipe_id),'[]'::jsonb) into result
  from (select * from staygrubby.recipe_trash where owner_id=actor order by deleted_at desc limit 100) t;
  return jsonb_build_object('recipes',result);
 end if;
 if rid is null then raise exception 'Invalid request' using errcode='22023'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:recipe:'||rid::text,0));

 if action='unlink_dish' then
  select * into owned from staygrubby.recipes where id=rid for update;
  if owned.id is null or owned.owner_id<>actor then raise exception 'Recipe unavailable' using errcode='42501'; end if;
  if payload ? 'dishID' and owned.dish_id is distinct from nullif(payload->>'dishID','')::uuid then
   raise exception 'Recipe is no longer on this Dish' using errcode='PT409';
  end if;
  if owned.dish_id is not null then
   delete from staygrubby.dish_recipes where account_id=actor and recipe_id=rid and dish_id=owned.dish_id;
   delete from staygrubby.dish_recipe_links where account_id=actor and recipe_id=rid and dish_id=owned.dish_id;
   update staygrubby.recipes set dish_id=null where id=rid;
  end if;
  return jsonb_build_object('recipe',staygrubby.recipe_card(actor,rid));
 end if;

 select * into item from staygrubby.recipe_trash where recipe_id=rid and owner_id=actor for update;
 if item.recipe_id is null then raise exception 'Recipe unavailable' using errcode='42501'; end if;
 if action='purge' then
  delete from staygrubby.recipe_trash where recipe_id=rid;
  return '{}'::jsonb;
 end if;

 -- restore
 if exists(select 1 from staygrubby.recipes where id=rid) then raise exception 'Recipe already restored' using errcode='PT409'; end if;
 stored:=item.payload->'recipe';
 dish:=item.dish_id;
 if dish is not null and exists(select 1 from staygrubby.dishes d where d.account_id=actor and d.id=dish and d.deleted_at is null)
   and not exists(select 1 from staygrubby.recipes r where r.owner_id=actor and r.dish_id=dish) then reattached:=true; else dish:=null; end if;
 insert into staygrubby.recipes(id,owner_id,content,visibility,revision,created_at,updated_at,dish_id)
 values(rid,actor,stored->'content',stored->>'visibility',(stored->>'revision')::integer,
  (stored->>'created_at')::timestamptz,(stored->>'updated_at')::timestamptz,dish);
 perform staygrubby.restore_trash_rows('staygrubby.recipe_revisions',item.payload->'revisions');
 -- The insert trigger may announce the Recipe again; keep its original activity instead.
 delete from staygrubby.recipe_activity where recipe_id=rid;
 perform staygrubby.restore_trash_rows('staygrubby.recipe_activity',item.payload->'activity');
 perform staygrubby.restore_trash_rows('staygrubby.recipe_tickets',item.payload->'tickets');
 perform staygrubby.restore_trash_rows('staygrubby.recipe_cook_links',item.payload->'cookLinks');
 perform staygrubby.restore_trash_rows('staygrubby.post_recipes',item.payload->'postRecipes');
 if reattached then
  perform staygrubby.restore_trash_rows('staygrubby.dish_recipes',(select jsonb_agg(e) from jsonb_array_elements(item.payload->'legacyLinks') e where (e->>'dish_id')::uuid=dish));
  perform staygrubby.restore_trash_rows('staygrubby.dish_recipe_links',(select jsonb_agg(e) from jsonb_array_elements(item.payload->'dishLinks') e where (e->>'dish_id')::uuid=dish));
 end if;
 if jsonb_typeof(item.payload->'fork')='object' then
  perform staygrubby.restore_trash_rows('staygrubby.recipe_forks',jsonb_build_array(item.payload->'fork'));
 end if;
 update staygrubby.recipe_forks set source_recipe_id=rid
  where source_recipe_id is null and recipe_id in (select (jsonb_array_elements_text(item.payload->'forkedFrom'))::uuid);
 update staygrubby.recipe_cooks set recipe_id=rid
  where recipe_id is null and id in (select (jsonb_array_elements_text(item.payload->'usedSnapshots'))::uuid);
 delete from staygrubby.recipe_trash where recipe_id=rid;
 return jsonb_build_object('recipe',staygrubby.recipe_card(actor,rid),'dishReattached',reattached);
end $$;
revoke all on function staygrubby.recipe_library_api(text,jsonb) from public,anon,authenticated;

create function api.recipe_library(action text, payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security definer set search_path='' as $$ select staygrubby.recipe_library_api(action,payload) $$;
revoke all on function api.recipe_library(text,jsonb) from public,anon;
grant execute on function api.recipe_library(text,jsonb) to authenticated;

notify pgrst,'reload schema';
commit;
