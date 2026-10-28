-- Independent Food Bible objects; existing Recipe/Dish/cooking/evidence rows stay untouched.
begin;
create table staygrubby.recipe_photos (
 id uuid primary key, owner_id uuid not null references staygrubby.accounts(id) on delete cascade,
 path text not null unique, sha256 text not null check(sha256 ~ '^[0-9a-f]{64}$'),
 byte_count integer not null check(byte_count between 1 and 2097152), ready boolean not null default false,
 created_at timestamptz not null default now(), unique(owner_id,id),
 check(path=owner_id::text||'/'||id::text||'.jpg')
);
create index recipe_photos_owner on staygrubby.recipe_photos(owner_id,created_at);
alter table staygrubby.recipe_photos enable row level security;
revoke all on staygrubby.recipe_photos from public,anon,authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('recipe-photos','recipe-photos',false,2097152,array['image/jpeg']);

-- A removed current photo may still belong to immutable history/a completed cook.
create function staygrubby.recipe_photo_referenced(asset uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from staygrubby.recipes where content->>'photoID'=asset::text)
 or exists(select 1 from staygrubby.recipe_revisions where content->>'photoID'=asset::text)
 or exists(select 1 from staygrubby.recipe_cooks where snapshot->>'photoID'=asset::text)
$$;
revoke all on function staygrubby.recipe_photo_referenced(uuid) from public,anon,authenticated;
create index recipes_photo_reference on staygrubby.recipes((content->>'photoID')) where content ? 'photoID';
create index recipe_revisions_photo_reference on staygrubby.recipe_revisions((content->>'photoID')) where content ? 'photoID';
create index recipe_cooks_photo_reference on staygrubby.recipe_cooks((snapshot->>'photoID')) where snapshot ? 'photoID';

create function staygrubby.recipe_object_allowed(bucket text,path text,mode text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid; asset staygrubby.recipe_photos%rowtype;
begin
 if bucket is distinct from 'recipe-photos' or mode not in('read','write','delete') then return false; end if;
 actor:=staygrubby.media_owner(); if actor is null then return false; end if;
 perform 1 from staygrubby.accounts where id=actor and status='active' for share;
 if not found or staygrubby.media_owner() is distinct from actor then return false; end if;
 select * into asset from staygrubby.recipe_photos p where p.path=recipe_object_allowed.path;
 if asset.id is null then return false; end if;
 if mode<>'read' then perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:recipe-photo:'||asset.id::text,0));
  select * into asset from staygrubby.recipe_photos p where p.path=recipe_object_allowed.path;
 end if;
 if mode='read' then
  return asset.owner_id=actor or (asset.ready and exists(select 1 from staygrubby.recipes r
    where r.content->>'photoID'=asset.id::text and staygrubby.recipe_visible(actor,r.id)));
 elsif mode='write' then return asset.owner_id=actor and not asset.ready;
 else return asset.owner_id=actor and not staygrubby.recipe_photo_referenced(asset.id);
 end if;
end $$;
revoke all on function staygrubby.recipe_object_allowed(text,text,text) from public,anon;
grant execute on function staygrubby.recipe_object_allowed(text,text,text) to authenticated;
create policy recipe_photo_read on storage.objects for select to authenticated using(staygrubby.recipe_object_allowed(bucket_id,name,'read'));
create policy recipe_photo_insert on storage.objects for insert to authenticated with check(staygrubby.recipe_object_allowed(bucket_id,name,'write'));
-- No UPDATE policy: published immutable paths cannot be replaced, even by the owner.
create policy recipe_photo_delete on storage.objects for delete to authenticated using(staygrubby.recipe_object_allowed(bucket_id,name,'delete'));

alter function staygrubby.recipe_content(jsonb) rename to recipe_content_before_independent;
revoke all on function staygrubby.recipe_content_before_independent(jsonb) from public,anon,authenticated;
create function staygrubby.recipe_content(value jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare clean jsonb:=staygrubby.recipe_content_before_independent(value);
begin
 if value ? 'photoID' and value->'photoID'<>'null'::jsonb then
  if jsonb_typeof(value->'photoID')<>'string' then raise exception 'Invalid recipe photo' using errcode='22023'; end if;
  clean:=clean||jsonb_build_object('photoID',(value->>'photoID')::uuid::text);
 end if;
 return clean;
end $$;
revoke all on function staygrubby.recipe_content(jsonb) from public,anon,authenticated;

alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_independent;
revoke all on function staygrubby.recipe_api_before_independent(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=staygrubby.social_actor(); rid uuid:=(payload->>'recipeID')::uuid; asset uuid:=(payload->>'assetID')::uuid;
 result jsonb; value jsonb; photo staygrubby.recipe_photos%rowtype; recipe staygrubby.recipes%rowtype; source_revision integer;
begin
 if octet_length(payload::text)>60000 then raise exception 'Invalid request' using errcode='22023'; end if;
 perform 1 from staygrubby.accounts where id=actor and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from actor then raise exception 'Account unavailable' using errcode='42501'; end if;
 if action='library_index' then
  -- Recipe UUID is both identity and cursor. One card even with multiple Dish links.
  select coalesce(jsonb_agg(card order by id),'[]'::jsonb) into result from (
   select r.id,jsonb_build_object('recipeID',r.id,'dishID',d.id,'dishTitle',coalesce(d.name,r.content->>'title'),
    'recipeTitle',r.content->>'title','course',coalesce(r.content->>'course',d.default_course_code),
    'cuisine',coalesce(r.content->>'cuisine',d.cuisine->>'label'),'revision',r.revision,'updatedAt',extract(epoch from r.updated_at),
    'yield',r.content->>'yield','prepMinutes',r.content->'prepMinutes','cookMinutes',r.content->'cookMinutes',
    'elapsedMinutes',r.content->'elapsedMinutes','creatorMetadata',r.content ? 'metadataOrigins','source',r.content->>'source',
    'photoID',r.content->>'photoID','searchText',concat_ws(' ',r.content->>'title',d.name,r.content->>'description',
      r.content->>'cuisine',d.cuisine->>'label',r.content->>'source',r.content->>'originalCreator',
      (select string_agg(x,' ') from jsonb_array_elements_text(coalesce(r.content->'ingredients','[]')) x))) card
   from staygrubby.recipes r left join lateral (
    select dish.* from staygrubby.dish_recipes l join staygrubby.dishes dish on dish.account_id=actor and dish.id=l.dish_id and dish.deleted_at is null
     where l.account_id=actor and l.recipe_id=r.id order by l.created_at,dish.id limit 1
   ) d on true
   where staygrubby.recipe_visible(actor,r.id) and (r.owner_id=actor or d.id is not null)
    and (payload->>'beforeID' is null or r.id>(payload->>'beforeID')::uuid)
   order by r.id limit 50
  ) page;
  return jsonb_build_object('entries',result);
 elsif action='history' then
  if not exists(select 1 from staygrubby.recipes r where r.id=rid and r.owner_id=actor) then raise exception 'Recipe unavailable' using errcode='42501'; end if;
  select coalesce(jsonb_agg(card order by revision desc),'[]'::jsonb) into result from (
   select v.revision,jsonb_build_object('revision',v.revision,'createdAt',extract(epoch from v.created_at),'title',v.content->>'title') card
   from staygrubby.recipe_revisions v where v.recipe_id=rid and (payload->>'expectedRevision' is null or v.revision<(payload->>'expectedRevision')::integer)
   order by v.revision desc limit 50) page;
  return jsonb_build_object('versions',result);
 elsif action='restore' then
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:recipe:'||rid::text,0));
  select * into recipe from staygrubby.recipes r where r.id=rid and r.owner_id=actor for update;
  if recipe.id is null then raise exception 'Recipe unavailable' using errcode='42501'; end if;
  source_revision:=(payload->>'sourceRevision')::integer;
  select v.content into value from staygrubby.recipe_revisions v where v.recipe_id=rid and v.revision=source_revision;
  if value is null then raise exception 'Revision unavailable' using errcode='22023'; end if;
  if recipe.revision is distinct from (payload->>'expectedRevision')::integer then raise exception 'Recipe changed; reload' using errcode='40001'; end if;
  update staygrubby.recipes set content=value,revision=revision+1,updated_at=now() where id=rid;
  return staygrubby.recipe_card(actor,rid);
 elsif action='prepare_photo' then
  if asset is null or length(coalesce(payload->>'photoHash',''))<>64 or coalesce((payload->>'photoBytes')::integer,0) not between 1 and 2097152 then raise exception 'Invalid photo' using errcode='22023'; end if;
  insert into staygrubby.recipe_photos(id,owner_id,path,sha256,byte_count)
   values(asset,actor,actor::text||'/'||asset::text||'.jpg',payload->>'photoHash',(payload->>'photoBytes')::integer) on conflict(id) do nothing;
  select * into photo from staygrubby.recipe_photos p where p.id=asset and p.owner_id=actor;
  if photo.id is null or photo.sha256 is distinct from payload->>'photoHash' or photo.byte_count is distinct from (payload->>'photoBytes')::integer then raise exception 'Photo unavailable' using errcode='42501'; end if;
  return jsonb_build_object('id',photo.id,'path',photo.path,'sha256',photo.sha256,'ready',photo.ready);
 elsif action='complete_photo' then
  select * into photo from staygrubby.recipe_photos p where p.id=asset and p.owner_id=actor for update;
  if photo.id is null then raise exception 'Photo unavailable' using errcode='42501'; end if;
  if not exists(select 1 from storage.objects where bucket_id='recipe-photos' and name=photo.path and metadata->>'mimetype'='image/jpeg' and (metadata->>'size')::bigint=photo.byte_count) then raise exception 'Upload required' using errcode='55000'; end if;
  update staygrubby.recipe_photos set ready=true where id=asset;
  return jsonb_build_object('id',photo.id,'path',photo.path,'sha256',photo.sha256,'ready',true);
 elsif action='photo' then
  select * into photo from staygrubby.recipe_photos p where p.id=asset and staygrubby.recipe_object_allowed('recipe-photos',p.path,'read');
  if photo.id is null then raise exception 'Photo unavailable' using errcode='42501'; end if;
  return jsonb_build_object('id',photo.id,'path',photo.path,'sha256',photo.sha256,'ready',photo.ready);
 elsif action='cleanup_photos' then
  select coalesce(jsonb_agg(path),'[]'::jsonb) into result from (select p.path from staygrubby.recipe_photos p where p.owner_id=actor and p.created_at<now()-interval '1 day' and not staygrubby.recipe_photo_referenced(p.id) order by p.created_at limit 25) paths;
  return jsonb_build_object('paths',result);
 elsif action='save' then
  -- JSON photo ownership is checked in addition to Storage authorization; old clients cannot erase a photo silently.
  select * into recipe from staygrubby.recipes r where r.id=rid;
  if recipe.id is null and payload->>'expectedRevision' is not null then raise exception 'Recipe was deleted; save explicitly as a new Recipe' using errcode='40001'; end if;
  if recipe.content ? 'photoID' and not (payload->'recipe' ? 'photoID') and coalesce(payload->>'removeRecipePhoto','false')<>'true' then
   payload:=jsonb_set(payload,'{recipe,photoID}',recipe.content->'photoID');
  end if;
  asset:=nullif(payload->'recipe'->>'photoID','')::uuid;
  if asset is not null then
   perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:recipe-photo:'||asset::text,0));
   if not exists(select 1 from staygrubby.recipe_photos p join storage.objects o on o.bucket_id='recipe-photos' and o.name=p.path and o.metadata->>'mimetype'='image/jpeg' and (o.metadata->>'size')::bigint=p.byte_count where p.id=asset and p.owner_id=actor and p.ready) then raise exception 'Photo upload required' using errcode='42501'; end if;
  end if;
 elsif action='associate_cook' then
  -- Explicit association only: never guess/backfill what an old cook used from its current Dish link.
  select * into recipe from staygrubby.recipes r where r.id=rid and staygrubby.recipe_visible(actor,r.id) for share;
  if recipe.id is null or recipe.revision is distinct from (payload->>'expectedRevision')::integer then raise exception 'Recipe changed; review first' using errcode='40001'; end if;
  if not exists(select 1 from staygrubby.cooking_attempts a where a.account_id=actor and a.id=(payload->>'attemptID')::uuid and a.ranked_item_id=(payload->>'targetID')::uuid and a.deleted_at is null) then raise exception 'Cook unavailable' using errcode='42501'; end if;
  insert into staygrubby.recipe_cooks(id,account_id,recipe_id,item_id,attempt_id,snapshot,recipe_revision,completed_at)
   values((payload->>'originID')::uuid,actor,rid,(payload->>'targetID')::uuid,(payload->>'attemptID')::uuid,recipe.content,recipe.revision,now()) on conflict(account_id,item_id) do nothing;
  if not exists(select 1 from staygrubby.recipe_cooks c where c.account_id=actor and c.item_id=(payload->>'targetID')::uuid and c.recipe_id=rid and c.recipe_revision=recipe.revision) then raise exception 'Cook already has a different Recipe snapshot' using errcode='40001'; end if;
  return staygrubby.recipe_api_before_independent('provenance',payload);
 end if;
 return staygrubby.recipe_api_before_independent(action,payload);
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
create or replace function api.recipes(action text,payload jsonb default '{}'::jsonb) returns jsonb language sql volatile security invoker set search_path='' as $$ select staygrubby.recipe_api(action,payload) $$;
revoke all on function api.recipes(text,jsonb) from public,anon;
grant execute on function api.recipes(text,jsonb) to authenticated;

-- Extend the existing fail-closed account cleanup gate to Recipe bytes.
create or replace function staygrubby.erase_account_data(target_auth_user uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare job staygrubby.account_deletion_jobs%rowtype;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:delete:' || target_auth_user::text,0));
 select * into job from staygrubby.account_deletion_jobs where auth_user_id=target_auth_user for update;
 if not found then raise exception 'Deletion job unavailable' using errcode='55000'; end if;
 if job.state='account_erased' then return jsonb_build_object('accountID',job.account_id,'state',job.state); end if;
 if job.state<>'storage_cleared' then raise exception 'Storage cleanup required' using errcode='55000'; end if;
 if exists(select 1 from storage.objects where bucket_id in ('cooking-photos','social-photos','profile-photos','recipe-photos')
           and (name=job.account_id::text or name like job.account_id::text || '/%'))
 then raise exception 'Storage cleanup incomplete' using errcode='55000'; end if;
 delete from staygrubby.accounts where id=job.account_id and status='deleting';
 if found or not exists(select 1 from staygrubby.accounts where id=job.account_id) then
  update staygrubby.account_deletion_jobs set state='account_erased',updated_at=clock_timestamp()
   where auth_user_id=target_auth_user returning * into job;
 else raise exception 'Account deletion refused' using errcode='55000';
 end if;
 return jsonb_build_object('accountID',job.account_id,'state',job.state);
end $$;
notify pgrst,'reload schema';
commit;
