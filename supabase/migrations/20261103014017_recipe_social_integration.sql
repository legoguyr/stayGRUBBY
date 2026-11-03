-- Deliberate social Recipe attachment; no backfill or private cooking mutations.
begin;
create table staygrubby.post_recipes (
 post_id uuid primary key references staygrubby.social_posts(id) on delete cascade,
 recipe_id uuid not null, recipe_revision integer not null,
 created_at timestamptz not null default now(),
 foreign key(recipe_id,recipe_revision) references staygrubby.recipe_revisions(recipe_id,revision) on delete cascade
);
create index post_recipes_recipe on staygrubby.post_recipes(recipe_id,recipe_revision);
create table staygrubby.recipe_forks (
 recipe_id uuid primary key references staygrubby.recipes(id) on delete cascade,
 source_recipe_id uuid references staygrubby.recipes(id) on delete set null,
 source_revision integer not null, source_owner_id uuid references staygrubby.accounts(id) on delete set null,
 source_post_id uuid references staygrubby.social_posts(id) on delete set null,
 created_at timestamptz not null default now()
);
alter table staygrubby.post_recipes enable row level security;
alter table staygrubby.recipe_forks enable row level security;
revoke all on staygrubby.post_recipes,staygrubby.recipe_forks from public,anon,authenticated;

-- Social reads use ONLY an intentionally shared archived revision. No private history API.
create function staygrubby.shared_recipe_card(viewer uuid,post uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('postID',p.id,'recipeID',r.id,'revision',s.recipe_revision,'content',v.content,
 'creator',staygrubby.social_person(viewer,r.owner_id),'cook',staygrubby.social_person(viewer,p.author_id),
 'photoPath',case when p.photo_ready then p.photo_path end,'isAuthor',p.author_id=viewer)
 from staygrubby.post_recipes s join staygrubby.social_posts p on p.id=s.post_id
 join staygrubby.recipes r on r.id=s.recipe_id and r.owner_id=p.author_id
 join staygrubby.recipe_revisions v on v.recipe_id=s.recipe_id and v.revision=s.recipe_revision
 where s.post_id=post and r.visibility='friends' and staygrubby.recipe_visible(viewer,r.id)
 and staygrubby.social_can_view(viewer,p.id)
$$;
revoke all on function staygrubby.shared_recipe_card(uuid,uuid) from public,anon,authenticated;

alter function staygrubby.social_post_card(uuid,uuid) rename to social_post_card_before_recipe_sharing;
revoke all on function staygrubby.social_post_card_before_recipe_sharing(uuid,uuid) from public,anon,authenticated;
create function staygrubby.social_post_card(viewer uuid,post uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare card jsonb:=staygrubby.social_post_card_before_recipe_sharing(viewer,post); shared jsonb;
begin
 if card is null then return null; end if;
 shared:=staygrubby.shared_recipe_card(viewer,post);
 -- Overrides the legacy implicit cook association; absent explicit consent means no Recipe.
 return card||jsonb_build_object('recipeID',shared->'recipeID','recipeRevision',shared->'revision',
  'recipeAttachmentPresent',case when (card->>'isAuthor')::boolean then exists(select 1 from staygrubby.post_recipes where post_id=post) else shared is not null end);
end $$;
revoke all on function staygrubby.social_post_card(uuid,uuid) from public,anon,authenticated;

-- Only the author can choose a Recipe they own. A borrowed/shared cook cannot delegate ownership.
create function staygrubby.share_post_recipe(actor uuid,pid uuid,rid uuid,version integer) returns void
language plpgsql volatile security definer set search_path='' as $$
declare r staygrubby.recipes%rowtype;
begin
 perform 1 from staygrubby.social_posts where id=pid and author_id=actor and deleted_at is null and moderation_state='active' for update;
 if not found then raise exception 'Post unavailable' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:recipe:'||rid::text,0));
 select * into r from staygrubby.recipes where id=rid and owner_id=actor for update;
 if staygrubby.social_actor() is distinct from actor or r.id is null or not exists(select 1 from staygrubby.recipe_revisions where recipe_id=rid and revision=version)
 then raise exception 'Recipe unavailable' using errcode='42501'; end if;
 if exists(select 1 from staygrubby.post_recipes where post_id=pid) then
  if not exists(select 1 from staygrubby.post_recipes where post_id=pid and recipe_id=rid and recipe_revision=version)
  then raise exception 'Remove the existing attachment first' using errcode='40001'; end if;
  return;
 end if;
 -- Explicit share consent enables current-friends Recipe visibility. Content stays exact.
 if r.visibility<>'friends' then
  update staygrubby.recipes set visibility='friends',revision=revision+1,updated_at=now() where id=rid;
 end if;
 insert into staygrubby.post_recipes(post_id,recipe_id,recipe_revision) values(pid,rid,version);
end $$;
revoke all on function staygrubby.share_post_recipe(uuid,uuid,uuid,integer) from public,anon,authenticated;

alter function staygrubby.social_content(text,jsonb) rename to social_content_before_recipe_sharing;
revoke all on function staygrubby.social_content_before_recipe_sharing(text,jsonb) from public,anon,authenticated;
create function staygrubby.social_content(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=staygrubby.social_actor(); result jsonb; pid uuid; existed boolean;
begin
 if action<>'prepare' then return staygrubby.social_content_before_recipe_sharing(action,payload); end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:post-source:'||actor::text||':'||coalesce(payload->>'attemptID',''),0));
 select exists(select 1 from staygrubby.social_posts where author_id=actor and source_attempt_id=(payload->>'attemptID')::uuid and deleted_at is null) into existed;
 result:=staygrubby.social_content_before_recipe_sharing(action,payload-'recipeID'-'sourceRevision'-'includeRecipe');
 pid:=(result->'posts'->0->>'id')::uuid;
 -- Retries never change an already prepared/published attachment or its consent.
 if not existed and coalesce((payload->>'includeRecipe')::boolean,false) then
  if coalesce((payload->>'confirmed')::boolean,false) is not true then raise exception 'Recipe share confirmation required' using errcode='22023'; end if;
  perform staygrubby.share_post_recipe(actor,pid,(payload->>'recipeID')::uuid,(payload->>'sourceRevision')::integer);
 end if;
 return jsonb_build_object('posts',jsonb_build_array(staygrubby.social_post_card(actor,pid)));
end $$;
revoke all on function staygrubby.social_content(text,jsonb) from public,anon;
grant execute on function staygrubby.social_content(text,jsonb) to authenticated;
create or replace function api.social_content(action text,payload jsonb default '{}'::jsonb) returns jsonb language sql volatile security invoker set search_path='' as $$ select staygrubby.social_content(action,payload) $$;

-- Recipe history/photos remain private unless the exact archived image is intentionally shared.
create or replace function staygrubby.recipe_object_allowed(bucket text,path text,mode text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid; asset staygrubby.recipe_photos%rowtype;
begin
 if bucket is distinct from 'recipe-photos' or mode is null or mode not in('read','write','delete') then return false; end if;
 actor:=staygrubby.media_owner(); if actor is null then return false; end if;
 perform 1 from staygrubby.accounts where id=actor and status='active' for share;
 if not found or staygrubby.media_owner() is distinct from actor then return false; end if;
 select * into asset from staygrubby.recipe_photos p where p.path=recipe_object_allowed.path;
 if asset.id is null then return false; end if;
 if mode<>'read' then
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:recipe-photo:'||asset.id::text,0));
  select * into asset from staygrubby.recipe_photos p where p.path=recipe_object_allowed.path;
 end if;
 if mode='read' then
  return asset.owner_id=actor or (asset.ready and (exists(select 1 from staygrubby.recipes r
   where r.content->>'photoID'=asset.id::text and staygrubby.recipe_visible(actor,r.id))
   or exists(select 1 from staygrubby.post_recipes s join staygrubby.recipe_revisions v on v.recipe_id=s.recipe_id and v.revision=s.recipe_revision
    where v.content->>'photoID'=asset.id::text and staygrubby.shared_recipe_card(actor,s.post_id) is not null)));
 elsif mode='write' then return asset.owner_id=actor and not asset.ready;
 else return asset.owner_id=actor and not staygrubby.recipe_photo_referenced(asset.id);
 end if;
end $$;
revoke all on function staygrubby.recipe_object_allowed(text,text,text) from public,anon;
grant execute on function staygrubby.recipe_object_allowed(text,text,text) to authenticated;
-- Preserve the same policy entry point and immutable upload/deletion rules.
alter policy recipe_photo_read on storage.objects using(staygrubby.recipe_object_allowed(bucket_id,name,'read'));
alter policy recipe_photo_insert on storage.objects with check(staygrubby.recipe_object_allowed(bucket_id,name,'write'));
alter policy recipe_photo_delete on storage.objects using(staygrubby.recipe_object_allowed(bucket_id,name,'delete'));

alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_social;
revoke all on function staygrubby.recipe_api_before_social(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=staygrubby.social_actor(); pid uuid:=(payload->>'postID')::uuid; rid uuid:=(payload->>'recipeID')::uuid;
 result jsonb; shared jsonb; content jsonb; r staygrubby.recipes%rowtype; c staygrubby.recipe_cooks%rowtype; attempt uuid:=(payload->>'attemptID')::uuid;
 fork_id uuid:=(payload->>'targetID')::uuid; version integer; source_owner uuid;
begin
 if octet_length(payload::text)>60000 then raise exception 'Invalid request' using errcode='22023'; end if;
 perform 1 from staygrubby.accounts where id=actor and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from actor then raise exception 'Account unavailable' using errcode='42501'; end if;
 if action='share_options' then
  if pid is not null then
   select source_attempt_id into attempt from staygrubby.social_posts where id=pid and author_id=actor and deleted_at is null;
  end if;
  if not exists(select 1 from staygrubby.cooking_attempts where account_id=actor and id=attempt and deleted_at is null) then raise exception 'Cook unavailable' using errcode='42501'; end if;
  select * into c from staygrubby.recipe_cooks where account_id=actor and attempt_id=attempt and completed_at is not null;
  if c.id is not null then rid:=c.recipe_id; version:=c.recipe_revision;
  else
   select l.recipe_id into rid from staygrubby.dish_recipes l join staygrubby.cooking_attempts a on a.account_id=actor and a.dish_id=l.dish_id
   where l.account_id=actor and a.id=attempt;
   select revision into version from staygrubby.recipes where id=rid;
  end if;
  select * into r from staygrubby.recipes where id=rid and owner_id=actor;
  if r.id is null then return jsonb_build_object('recipe',null); end if;
  select v.content into content from staygrubby.recipe_revisions v where v.recipe_id=rid and v.revision=version;
  return jsonb_build_object('recipe',staygrubby.recipe_card(actor,rid)||jsonb_build_object('content',content,'revision',version),'fromCookSnapshot',c.id is not null);
 elsif action='shared_post' then
  shared:=staygrubby.shared_recipe_card(actor,pid);
  if shared is null then raise exception 'Recipe unavailable' using errcode='42501'; end if; return shared;
 elsif action in('share_post','unshare_post') then
  if coalesce((payload->>'confirmed')::boolean,false) is not true then raise exception 'Confirm sharing change' using errcode='22023'; end if;
  perform 1 from staygrubby.social_posts where id=pid and author_id=actor and deleted_at is null and moderation_state='active' for update;
  if not found or staygrubby.social_actor() is distinct from actor then raise exception 'Post unavailable' using errcode='42501'; end if;
  if action='unshare_post' then delete from staygrubby.post_recipes where post_id=pid;
  else perform staygrubby.share_post_recipe(actor,pid,rid,(payload->>'sourceRevision')::integer); end if;
  return '{}';
 elsif action in('fork_post','fork') then
  if fork_id is null or coalesce((payload->>'confirmed')::boolean,false) is not true then raise exception 'Confirm independent copy' using errcode='22023'; end if;
  if action='fork_post' then
   shared:=staygrubby.shared_recipe_card(actor,pid);
   if shared is null then raise exception 'Recipe unavailable' using errcode='42501'; end if;
   rid:=(shared->>'recipeID')::uuid;version:=(shared->>'revision')::integer;content:=shared->'content';
  else
   select * into r from staygrubby.recipes where id=rid and staygrubby.recipe_visible(actor,id);
   if r.id is null then raise exception 'Recipe unavailable' using errcode='42501'; end if;
   version:=r.revision;content:=r.content;
  end if;
  select owner_id into source_owner from staygrubby.recipes where id=rid;
  -- No foreign media ownership/reference transfer. The recipient may add their own photo.
  content:=content-'photoID';
  content:=jsonb_set(content,'{originalCreator}',to_jsonb(coalesce(content->>'originalCreator',staygrubby.social_person(actor,source_owner)->>'displayName','Original creator')));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:recipe:'||fork_id::text,0));
  if staygrubby.social_actor() is distinct from actor or not staygrubby.recipe_visible(actor,rid) or (action='fork_post' and staygrubby.shared_recipe_card(actor,pid) is null)
  then raise exception 'Recipe unavailable' using errcode='42501'; end if;
  if exists(select 1 from staygrubby.recipes where id=fork_id) then
   if not exists(select 1 from staygrubby.recipes x join staygrubby.recipe_forks f on f.recipe_id=x.id where x.id=fork_id and x.owner_id=actor and f.source_recipe_id=rid and f.source_revision=version and f.source_post_id is not distinct from pid)
   then raise exception 'Copy identity unavailable' using errcode='42501'; end if;
  else
   insert into staygrubby.recipes(id,owner_id,content,visibility) values(fork_id,actor,content,'private');
   insert into staygrubby.recipe_forks(recipe_id,source_recipe_id,source_revision,source_owner_id,source_post_id) values(fork_id,rid,version,source_owner,pid);
  end if;
  return staygrubby.recipe_card(actor,fork_id);
 elsif action='fork_provenance' then
  if not exists(select 1 from staygrubby.recipes where id=rid and owner_id=actor) then raise exception 'Recipe unavailable' using errcode='42501'; end if;
  select jsonb_build_object('sourceRecipeID',case when staygrubby.recipe_visible(actor,f.source_recipe_id) then f.source_recipe_id end,
   'sourceRevision',f.source_revision,'creator',case when f.source_owner_id=actor or staygrubby.shared_friends(actor,f.source_owner_id) then staygrubby.social_person(actor,f.source_owner_id) end,
   'postID',case when staygrubby.social_can_view(actor,f.source_post_id) then f.source_post_id end) into result from staygrubby.recipe_forks f where f.recipe_id=rid;
  return jsonb_build_object('provenance',result);
 end if;
 return staygrubby.recipe_api_before_social(action,payload);
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
create or replace function api.recipes(action text,payload jsonb default '{}'::jsonb) returns jsonb language sql volatile security invoker set search_path='' as $$ select staygrubby.recipe_api(action,payload) $$;

-- Bypass only the old implicit Recipe transfer; preserve the actual social-origin implementation.
alter function staygrubby.social_cooking(text,jsonb) rename to social_cooking_before_explicit_recipe;
revoke all on function staygrubby.social_cooking_before_explicit_recipe(text,jsonb) from public,anon,authenticated;
create function staygrubby.social_cooking(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=staygrubby.social_actor(); result jsonb; shared jsonb; pid uuid;
 c staygrubby.recipe_cooks%rowtype;
begin
 if action not in('recreate','claim') then return staygrubby.social_cooking_before_explicit_recipe(action,payload); end if;
 result:=staygrubby.social_cooking_before_recipes(action,payload);
 if action='recreate' then pid:=(payload->>'postID')::uuid;
 else
  select p.id into pid from staygrubby.shared_cooks e join staygrubby.social_posts p on p.author_id=e.owner_id and p.source_attempt_id=e.source_attempt_id
  where e.id=(payload->>'eventID')::uuid and staygrubby.shared_recipe_card(actor,p.id) is not null order by p.created_at desc limit 1;
 end if;
 shared:=staygrubby.shared_recipe_card(actor,pid);
 if shared is not null then
  insert into staygrubby.recipe_cooks(id,account_id,recipe_id,item_id,snapshot,recipe_revision)
   values((result->>'id')::uuid,actor,(shared->>'recipeID')::uuid,(result->>'itemID')::uuid,shared->'content',(shared->>'revision')::integer)
   on conflict(account_id,item_id) do nothing;
  select * into c from staygrubby.recipe_cooks where account_id=actor and item_id=(result->>'itemID')::uuid;
  result:=result||jsonb_build_object('recipeOriginID',c.id,'recipeSnapshot',c.snapshot);
 end if;
 return result;
end $$;
revoke all on function staygrubby.social_cooking(text,jsonb) from public,anon;
grant execute on function staygrubby.social_cooking(text,jsonb) to authenticated;
create or replace function api.social_cooking(action text,payload jsonb default '{}'::jsonb) returns jsonb language sql volatile security invoker set search_path='' as $$ select staygrubby.social_cooking(action,payload) $$;
notify pgrst,'reload schema';
commit;
