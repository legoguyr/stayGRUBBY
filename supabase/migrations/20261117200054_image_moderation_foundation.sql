-- Operational image moderation, one row per share-eligible Storage object.
-- Bounded metadata only, no image bytes, classifier text or extra event stream.
-- Kept while the original object exists; FK cleanup on object/account erasure.
-- Immutable generation + short lease prevents stale classification after replacement.
-- Deployment intentionally withholds peer image reads until screening completes.
begin;

create table staygrubby.image_reviews (
 object_id uuid primary key references storage.objects(id) on delete cascade,
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 generation uuid not null default gen_random_uuid(),
 state text not null default 'pending' check(state in ('pending','approved','review','rejected')),
 sha256 text check(sha256 ~ '^[0-9a-f]{64}$'),
 provider text check(provider in ('vision-v1','manual')),
 attempts integer not null default 0 check(attempts between 0 and 3),
 next_attempt_at timestamptz not null default now(),
 lease_id uuid,
 lease_until timestamptz,
 reviewed_by uuid references staygrubby.accounts(id) on delete set null,
 decided_at timestamptz,
 created_at timestamptz not null default now()
);
create index image_reviews_pending on staygrubby.image_reviews(next_attempt_at,object_id) where state='pending';
create index image_reviews_owner on staygrubby.image_reviews(account_id);
create index image_reviews_reviewer on staygrubby.image_reviews(reviewed_by) where reviewed_by is not null;
create index image_reviews_staff on staygrubby.image_reviews(created_at,object_id) where state in ('review','rejected');
alter table staygrubby.image_reviews enable row level security;
revoke all on staygrubby.image_reviews from public,anon,authenticated,service_role;

create function staygrubby.request_image_review(bucket text,path text) returns void
language plpgsql security definer set search_path='' as $$
begin
 insert into staygrubby.image_reviews(object_id,account_id)
 select o.id,a.id from storage.objects o
 join staygrubby.accounts a on split_part(o.name,'/',1)=a.id::text and a.status='active'
 where o.bucket_id=bucket and o.name=path and bucket in('social-photos','profile-photos','recipe-photos')
 on conflict(object_id) do nothing;
end $$;
revoke all on function staygrubby.request_image_review(text,text) from public,anon,authenticated,service_role;

create function staygrubby.queue_shared_image() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_table_schema='storage' then
  if tg_op='UPDATE' then
   delete from staygrubby.image_reviews where object_id=old.id;
  end if;
  if new.bucket_id in ('social-photos','profile-photos') then
   perform staygrubby.request_image_review(new.bucket_id,new.name);
  elsif new.bucket_id='recipe-photos' and (
   exists(select 1 from staygrubby.recipe_photos p join staygrubby.recipes r on r.content->>'photoID'=p.id::text
    where p.path=new.name and r.visibility='friends')
   or exists(select 1 from staygrubby.recipe_photos p join staygrubby.recipe_revisions v on v.content->>'photoID'=p.id::text
    join staygrubby.post_recipes s on s.recipe_id=v.recipe_id and s.recipe_revision=v.revision where p.path=new.name)
  ) then perform staygrubby.request_image_review(new.bucket_id,new.name); end if;
 elsif tg_table_name='recipes' then
  if new.visibility='friends' then
   perform staygrubby.request_image_review('recipe-photos',p.path)
    from staygrubby.recipe_photos p where p.id::text=new.content->>'photoID';
  end if;
 elsif tg_table_name='post_recipes' then
  perform staygrubby.request_image_review('recipe-photos',p.path)
   from staygrubby.recipe_revisions v join staygrubby.recipe_photos p on p.id::text=v.content->>'photoID'
   where v.recipe_id=new.recipe_id and v.revision=new.recipe_revision;
 end if;
 return new;
end $$;
revoke all on function staygrubby.queue_shared_image() from public,anon,authenticated,service_role;
-- Shared paths with a final approval/decision cannot be overwritten in place.
-- A replacement uses a new existing asset UUID/path and is screened independently.
create function staygrubby.protect_screened_image() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from staygrubby.image_reviews r where r.object_id=old.id
   and (r.state='approved' or r.provider='manual')) then
  raise exception 'Use a new photo path for a replacement' using errcode='PT409';
 end if;
 return new;
end $$;
revoke all on function staygrubby.protect_screened_image() from public,anon,authenticated,service_role;
create trigger protect_screened_image before update on storage.objects
 for each row execute function staygrubby.protect_screened_image();
create trigger review_uploaded_image after insert or update on storage.objects
 for each row execute function staygrubby.queue_shared_image();
create trigger review_shared_recipe_image after insert or update of visibility,content on staygrubby.recipes
 for each row execute function staygrubby.queue_shared_image();
create trigger review_pinned_recipe_image after insert or update on staygrubby.post_recipes
 for each row execute function staygrubby.queue_shared_image();

-- Queue only original shared/draft objects; private cooking and private-only Recipe bytes stay untouched.
select staygrubby.request_image_review(o.bucket_id,o.name) from storage.objects o
where o.bucket_id in ('social-photos','profile-photos') or (o.bucket_id='recipe-photos' and (
 exists(select 1 from staygrubby.recipe_photos p join staygrubby.recipes r on r.content->>'photoID'=p.id::text
  where p.path=o.name and r.visibility='friends')
 or exists(select 1 from staygrubby.recipe_photos p join staygrubby.recipe_revisions v on v.content->>'photoID'=p.id::text
  join staygrubby.post_recipes s on s.recipe_id=v.recipe_id and s.recipe_revision=v.revision where p.path=o.name)
));

create function staygrubby.image_approved(bucket text,path text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from storage.objects o join staygrubby.image_reviews r on r.object_id=o.id
 where o.bucket_id=bucket and o.name=path and r.state='approved')
$$;
revoke all on function staygrubby.image_approved(text,text) from public,anon,authenticated,service_role;

-- Keep the original Storage authorization checks. Screening is an additional
-- condition only for foreign reads. Owner reads, cleanup and immutable upload checks survive.
alter function staygrubby.social_object_allowed(text,text,text) rename to social_object_before_image_review;
revoke all on function staygrubby.social_object_before_image_review(text,text,text) from public,anon,authenticated,service_role;
create function staygrubby.social_object_allowed(bucket text,path text,mode text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
begin
 if not staygrubby.social_object_before_image_review(bucket,path,mode) then return false; end if;
 return mode<>'read' or split_part(path,'/',1)=staygrubby.media_owner()::text or staygrubby.image_approved(bucket,path);
end $$;
revoke all on function staygrubby.social_object_allowed(text,text,text) from public,anon;
grant execute on function staygrubby.social_object_allowed(text,text,text) to authenticated;
alter policy social_photo_read on storage.objects using(staygrubby.social_object_allowed(bucket_id,name,'read'));
alter policy social_photo_create on storage.objects with check(staygrubby.social_object_allowed(bucket_id,name,'write'));
alter policy social_photo_replace on storage.objects using(staygrubby.social_object_allowed(bucket_id,name,'write')) with check(staygrubby.social_object_allowed(bucket_id,name,'write'));
alter policy social_photo_remove on storage.objects using(staygrubby.social_object_allowed(bucket_id,name,'delete'));

alter function staygrubby.profile_object_allowed(text,text,text) rename to profile_object_before_image_review;
revoke all on function staygrubby.profile_object_before_image_review(text,text,text) from public,anon,authenticated,service_role;
create function staygrubby.profile_object_allowed(bucket text,path text,mode text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
begin
 if not staygrubby.profile_object_before_image_review(bucket,path,mode) then return false; end if;
 return mode<>'read' or split_part(path,'/',1)=staygrubby.media_owner()::text or staygrubby.image_approved(bucket,path);
end $$;
revoke all on function staygrubby.profile_object_allowed(text,text,text) from public,anon;
grant execute on function staygrubby.profile_object_allowed(text,text,text) to authenticated;
alter policy profile_photo_read on storage.objects using(staygrubby.profile_object_allowed(bucket_id,name,'read'));
alter policy profile_photo_create on storage.objects with check(staygrubby.profile_object_allowed(bucket_id,name,'write'));
alter policy profile_photo_replace on storage.objects using(staygrubby.profile_object_allowed(bucket_id,name,'write')) with check(staygrubby.profile_object_allowed(bucket_id,name,'write'));
alter policy profile_photo_remove on storage.objects using(staygrubby.profile_object_allowed(bucket_id,name,'delete'));

alter function staygrubby.recipe_object_allowed(text,text,text) rename to recipe_object_before_image_review;
revoke all on function staygrubby.recipe_object_before_image_review(text,text,text) from public,anon,authenticated,service_role;
do $rebind$
begin
 execute replace(pg_get_functiondef('staygrubby.recipe_object_before_image_review(text,text,text)'::regprocedure),
  'recipe_object_allowed.path','recipe_object_before_image_review.path');
end $rebind$;
create function staygrubby.recipe_object_allowed(bucket text,path text,mode text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
begin
 if not staygrubby.recipe_object_before_image_review(bucket,path,mode) then return false; end if;
 return mode<>'read' or split_part(path,'/',1)=staygrubby.media_owner()::text or staygrubby.image_approved(bucket,path);
end $$;
revoke all on function staygrubby.recipe_object_allowed(text,text,text) from public,anon;
grant execute on function staygrubby.recipe_object_allowed(text,text,text) to authenticated;
alter policy recipe_photo_read on storage.objects using(staygrubby.recipe_object_allowed(bucket_id,name,'read'));
alter policy recipe_photo_insert on storage.objects with check(staygrubby.recipe_object_allowed(bucket_id,name,'write'));
alter policy recipe_photo_delete on storage.objects using(staygrubby.recipe_object_allowed(bucket_id,name,'delete'));

-- Staff can inspect only a queued, uncertain/flagged original using an
-- authenticated GET. This grants no listing, signed-URL or private-library access.
create function staygrubby.review_image_allowed(bucket text,path text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
declare reviewer uuid;
begin
 if current_setting('storage.operation',true) is distinct from 'object.get_authenticated' then return false; end if;
 begin reviewer:=staygrubby.require_moderation_reviewer();
 exception when insufficient_privilege then return false; end;
 return exists(select 1 from storage.objects o join staygrubby.image_reviews r on r.object_id=o.id
  where o.bucket_id=bucket and o.name=path and r.state in ('review','rejected') and r.account_id<>reviewer);
end $$;
revoke all on function staygrubby.review_image_allowed(text,text) from public,anon,service_role;
grant execute on function staygrubby.review_image_allowed(text,text) to authenticated;
create policy moderation_image_inspect on storage.objects for select to authenticated
 using(staygrubby.review_image_allowed(bucket_id,name));

-- Service-only worker contract. No caller-supplied paths or account IDs.
create function api.claim_image_reviews() returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 update staygrubby.image_reviews set state='review',lease_id=null,lease_until=null
  where object_id in (select object_id from staygrubby.image_reviews
   where state='pending' and attempts=3 and (lease_until is null or lease_until<=now()) order by object_id limit 25);
 with selected as (
  select r.object_id from staygrubby.image_reviews r join staygrubby.accounts a on a.id=r.account_id and a.status='active'
  where r.state='pending' and r.attempts<3 and r.next_attempt_at<=now()
   and (r.lease_until is null or r.lease_until<=now())
  order by r.next_attempt_at,r.object_id limit 5 for update of r skip locked
 ), claimed as (
  update staygrubby.image_reviews r set attempts=attempts+1,lease_id=gen_random_uuid(),lease_until=now()+interval '5 minutes'
   from selected s where r.object_id=s.object_id returning r.*
 )
 select coalesce(jsonb_agg(jsonb_build_object('objectID',r.object_id,'generation',r.generation,'leaseID',r.lease_id,
  'bucket',o.bucket_id,'path',o.name,'bytes',o.metadata->'size')),'[]'::jsonb) into result
 from claimed r join storage.objects o on o.id=r.object_id;
 return result;
end $$;
revoke all on function api.claim_image_reviews() from public,anon,authenticated;
grant execute on function api.claim_image_reviews() to service_role;

create function api.finish_image_review(object_id uuid,generation uuid,lease_id uuid,outcome text,sha256 text default null) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if outcome is null or outcome not in ('approved','review','rejected','unavailable')
  or (outcome<>'unavailable' and (sha256 is null or sha256 !~ '^[0-9a-f]{64}$'))
 then raise exception 'Invalid image verdict' using errcode='22023'; end if;
 update staygrubby.image_reviews r set
  state=case when outcome='unavailable' then case when attempts>=3 then 'review' else 'pending' end else outcome end,
  sha256=finish_image_review.sha256,provider=case when outcome='unavailable' then null else 'vision-v1' end,
  next_attempt_at=now()+interval '10 minutes',lease_id=null,lease_until=null,
  decided_at=case when outcome='unavailable' then null else now() end
 where r.object_id=finish_image_review.object_id and r.generation=finish_image_review.generation
  and r.lease_id=finish_image_review.lease_id and r.lease_until>now() and r.state='pending'
  and exists(select 1 from staygrubby.accounts a where a.id=r.account_id and a.status='active');
 return found;
end $$;
revoke all on function api.finish_image_review(uuid,uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function api.finish_image_review(uuid,uuid,uuid,text,text) to service_role;

create function api.image_moderation(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare reviewer uuid:=staygrubby.require_moderation_reviewer(); item staygrubby.image_reviews%rowtype; result jsonb;
begin
 if payload is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>1024 then
  raise exception 'Invalid image review request' using errcode='22023'; end if;
 if action='queue' then
  select coalesce(jsonb_agg(card),'[]'::jsonb) into result from (
   select jsonb_build_object('objectID',r.object_id,'generation',r.generation,'state',r.state,'createdAt',r.created_at) card
   from staygrubby.image_reviews r where r.state in('review','rejected') and r.account_id<>reviewer
    and (payload->>'afterID' is null or r.object_id>(payload->>'afterID')::uuid)
   order by r.object_id limit 25
  ) page;
  return jsonb_build_object('images',result);
 end if;
 select * into item from staygrubby.image_reviews r
  where r.object_id=(payload->>'objectID')::uuid and r.account_id<>reviewer for update;
 if not found then raise exception 'Image unavailable' using errcode='42501'; end if;
 if action='inspect' then
  return (select jsonb_build_object('objectID',item.object_id,'generation',item.generation,'state',item.state,
   'accountID',item.account_id,'bucket',o.bucket_id,'path',o.name,'sha256',item.sha256)
   from storage.objects o where o.id=item.object_id);
 elsif action='resolve' then
  if item.generation is distinct from (payload->>'generation')::uuid
   then raise exception 'Image changed; reload' using errcode='PT409'; end if;
  if payload->>'decision' is null or payload->>'decision' not in ('approved','rejected')
   then raise exception 'Invalid image decision' using errcode='22023'; end if;
  if item.provider='manual' then
   if item.state=payload->>'decision' then return jsonb_build_object('state',item.state); end if;
   raise exception 'Image already resolved' using errcode='PT409';
  end if;
  if item.state not in ('review','rejected') or item.sha256 is null
   then raise exception 'Image needs a completed inspection' using errcode='PT409'; end if;
  update staygrubby.image_reviews set state=payload->>'decision',provider='manual',reviewed_by=reviewer,decided_at=now()
   where object_id=item.object_id;
  return jsonb_build_object('state',payload->>'decision');
 end if;
 raise exception 'Unknown image review action' using errcode='22023';
end $$;
revoke all on function api.image_moderation(text,jsonb) from public,anon,service_role;
grant execute on function api.image_moderation(text,jsonb) to authenticated;

notify pgrst,'reload schema';
commit;
