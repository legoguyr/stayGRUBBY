-- Zero-billing MVP: shared images require a named reviewer's explicit decision.
-- image_review_actions is canonical moderation evidence, normally 1-3 transitions
-- per shared original. Append only on an actual decision change, never on reads or
-- retries. Retain with the original; object/account erasure cascades the audit and
-- reviewer erasure detaches identity. No image bytes, private notes or event feed.
begin;
create table staygrubby.image_review_actions (
 id uuid primary key default gen_random_uuid(),
 object_id uuid not null references storage.objects(id) on delete cascade,
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 reviewer_id uuid references staygrubby.accounts(id) on delete set null,
 generation uuid not null,
 previous_state text not null,
 decision text not null check(decision in ('approved','rejected')),
 sha256 text check(sha256 ~ '^[0-9a-f]{64}$'),
 created_at timestamptz not null default now()
);
create index image_review_actions_object on staygrubby.image_review_actions(object_id,created_at);
create index image_review_actions_owner on staygrubby.image_review_actions(account_id);
create index image_review_actions_reviewer on staygrubby.image_review_actions(reviewer_id) where reviewer_id is not null;
alter table staygrubby.image_review_actions enable row level security;
revoke all on staygrubby.image_review_actions from public,anon,authenticated,service_role;
alter table staygrubby.image_reviews drop constraint image_reviews_provider_check;
alter table staygrubby.image_reviews add constraint image_reviews_provider_check check(provider in ('vision-v1','validation-v1','manual'));

-- Withdrawn Recipe photos and retired post/profile originals never enter the
-- staff browser merely because an old technical review row remains.
create function staygrubby.image_review_eligible(object uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from storage.objects o join staygrubby.accounts a on split_part(o.name,'/',1)=a.id::text and a.status='active'
 where o.id=object and (
  (o.bucket_id='social-photos' and exists(select 1 from staygrubby.social_posts p where p.author_id=a.id and p.photo_path=o.name and p.deleted_at is null))
  or (o.bucket_id='profile-photos' and exists(select 1 from staygrubby.profiles p where p.account_id=a.id and p.deleted_at is null and o.name in(p.avatar_path,p.avatar_draft_path)))
  or (o.bucket_id='recipe-photos' and exists(select 1 from staygrubby.recipe_photos f where f.owner_id=a.id and f.path=o.name and (
   exists(select 1 from staygrubby.recipes r where r.owner_id=a.id and r.visibility='friends' and r.content->>'photoID'=f.id::text)
   or exists(select 1 from staygrubby.recipe_revisions v join staygrubby.post_recipes pr on pr.recipe_id=v.recipe_id and pr.recipe_revision=v.revision
    join staygrubby.social_posts p on p.id=pr.post_id and p.deleted_at is null where v.content->>'photoID'=f.id::text)
  )))
 ))
$$;
revoke all on function staygrubby.image_review_eligible(uuid) from public,anon,authenticated,service_role;

create or replace function staygrubby.review_image_allowed(bucket text,path text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
begin
 if current_setting('storage.operation',true) is distinct from 'object.get_authenticated' then return false; end if;
 begin perform staygrubby.require_moderation_reviewer();
 exception when insufficient_privilege then return false; end;
 return exists(select 1 from storage.objects o join staygrubby.image_reviews r on r.object_id=o.id
  where o.bucket_id=bucket and o.name=path and staygrubby.image_review_eligible(o.id));
end $$;

-- Optional validation workers skip originals whose sharing intent was withdrawn.
do $eligibility$
declare body text:=pg_get_functiondef('api.claim_image_reviews()'::regprocedure);
 marker text:=$needle$where r.state='pending' and r.attempts<3$needle$;
begin
 if strpos(body,marker)=0 then raise exception 'Unexpected image worker predecessor'; end if;
 execute replace(body,marker,marker||' and staygrubby.image_review_eligible(r.object_id)');
end $eligibility$;

-- Recipe's historical owner-read helper allowed signing/listing. Require an
-- authenticated object operation even for owners; upload/delete SELECT remains.
alter function staygrubby.recipe_object_allowed(text,text,text) rename to recipe_object_before_manual_review;
revoke all on function staygrubby.recipe_object_before_manual_review(text,text,text) from public,anon,authenticated,service_role;
create function staygrubby.recipe_object_allowed(bucket text,path text,mode text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
begin
 if mode='read' and nullif(current_setting('storage.operation',true),'') is not null and not storage.allow_any_operation(array['object.get_authenticated','object.get_authenticated_info','object.head_authenticated_info','object.info_authenticated','object.upload','object.upload_update','object.delete','object.delete_many']) then return false; end if;
 return staygrubby.recipe_object_before_manual_review(bucket,path,mode);
end $$;
revoke all on function staygrubby.recipe_object_allowed(text,text,text) from public,anon;
grant execute on function staygrubby.recipe_object_allowed(text,text,text) to authenticated;
alter policy recipe_photo_read on storage.objects using(staygrubby.recipe_object_allowed(bucket_id,name,'read'));
alter policy recipe_photo_insert on storage.objects with check(staygrubby.recipe_object_allowed(bucket_id,name,'write'));
alter policy recipe_photo_delete on storage.objects using(staygrubby.recipe_object_allowed(bucket_id,name,'delete'));

-- The optional validator may only hold or reject bytes. A classifier result
-- cannot become approval under the manual MVP policy, including old workers.
alter function api.finish_image_review(uuid,uuid,uuid,text,text) rename to finish_image_review_before_manual;
revoke all on function api.finish_image_review_before_manual(uuid,uuid,uuid,text,text) from public,anon,authenticated,service_role;
alter function api.finish_image_review_before_manual(uuid,uuid,uuid,text,text) set schema staygrubby;
do $rebind$
begin
 execute replace(pg_get_functiondef('staygrubby.finish_image_review_before_manual(uuid,uuid,uuid,text,text)'::regprocedure),'finish_image_review.','finish_image_review_before_manual.');
end $rebind$;
create function api.finish_image_review(object_id uuid,generation uuid,lease_id uuid,outcome text,sha256 text default null) returns boolean
language plpgsql security definer set search_path='' as $$
declare changed boolean;
begin
 if not staygrubby.image_review_eligible(object_id) then return false; end if;
 changed:=staygrubby.finish_image_review_before_manual(object_id,generation,lease_id,case when outcome='approved' then 'review' else outcome end,sha256);
 if changed and outcome<>'unavailable' then
  update staygrubby.image_reviews r set provider='validation-v1' where r.object_id=finish_image_review.object_id;
 end if;
 return changed;
end $$;
revoke all on function api.finish_image_review(uuid,uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function api.finish_image_review(uuid,uuid,uuid,text,text) to service_role;

create or replace function api.image_moderation(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare reviewer uuid:=staygrubby.require_moderation_reviewer(); item staygrubby.image_reviews%rowtype;
 object storage.objects%rowtype; result jsonb; wanted text:=coalesce(payload->>'reviewState','pending'); decision text:=payload->>'decision'; digest text:=payload->>'photoHash';
begin
 if payload is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>1024 then raise exception 'Invalid image review request' using errcode='22023'; end if;
 if action='capabilities' then return jsonb_build_object('reviewer',true); end if;
 if action='queue' then
  if wanted not in ('pending','approved','rejected') then raise exception 'Invalid review filter' using errcode='22023'; end if;
  select coalesce(jsonb_agg(card),'[]'::jsonb) into result from (
   select jsonb_build_object('objectID',r.object_id,'generation',r.generation,'state',r.state,'createdAt',extract(epoch from r.created_at),'bucket',o.bucket_id) card
   from staygrubby.image_reviews r join storage.objects o on o.id=r.object_id
   where (r.state=wanted or (wanted='pending' and r.state='review')) and staygrubby.image_review_eligible(o.id)
    and (payload->>'afterID' is null or r.object_id>(payload->>'afterID')::uuid)
   order by r.object_id limit 25
  ) page;
  return jsonb_build_object('images',result);
 end if;
 if action='inspect' then
  select jsonb_build_object('objectID',r.object_id,'generation',r.generation,'state',r.state,'bucket',o.bucket_id,'path',o.name,'sha256',r.sha256)
   into result from storage.objects o join staygrubby.image_reviews r on r.object_id=o.id
   where o.id=(payload->>'objectID')::uuid and staygrubby.image_review_eligible(o.id);
  if result is null then raise exception 'Image unavailable' using errcode='42501'; end if;
  return result;
 end if;
 -- Match Storage's object -> review row lock order so replacement and a staff
 -- decision serialize. The generation is rechecked after the object lock.
 select * into object from storage.objects o where o.id=(payload->>'objectID')::uuid for share;
 if object.id is null or not staygrubby.image_review_eligible(object.id) then raise exception 'Image unavailable' using errcode='42501'; end if;
 select * into item from staygrubby.image_reviews r where r.object_id=object.id for update;
 if not found then raise exception 'Image unavailable' using errcode='42501'; end if;
 if action='resolve' then
  if item.generation is distinct from (payload->>'generation')::uuid then raise exception 'Image changed; reload' using errcode='PT409'; end if;
  if decision is null or decision not in ('approved','rejected') then raise exception 'Invalid image decision' using errcode='22023'; end if;
  if digest is not null and digest !~ '^[0-9a-f]{64}$' then raise exception 'Invalid image hash' using errcode='22023'; end if;
  if item.state=decision and item.provider='manual' and item.sha256 is not distinct from digest then return jsonb_build_object('state',decision); end if;
  if item.state is distinct from payload->>'expectedState' then raise exception 'Image decision changed; reload' using errcode='PT409'; end if;
  if decision='approved' and (digest is null or object.metadata->>'mimetype' is distinct from 'image/jpeg' or coalesce((object.metadata->>'size')::bigint,0) not between 1 and 2097152) then raise exception 'Valid inspected JPEG required' using errcode='22023'; end if;
  insert into staygrubby.image_review_actions(object_id,account_id,reviewer_id,generation,previous_state,decision,sha256)
   values(item.object_id,item.account_id,reviewer,item.generation,item.state,decision,digest);
  update staygrubby.image_reviews set state=decision,sha256=digest,provider='manual',reviewed_by=reviewer,decided_at=now(),lease_id=null,lease_until=null where object_id=item.object_id;
  return jsonb_build_object('state',decision);
 end if;
 raise exception 'Unknown image review action' using errcode='22023';
end $$;
-- A fresh authenticated POST gates cache reuse without re-downloading bytes.
-- It reveals only permission for the supplied path and makes no durable write.
create function api.image_access(bucket text,path text) returns boolean
language plpgsql security definer set search_path='' as $$
declare previous text:=current_setting('storage.operation',true); allowed boolean;
begin
 if bucket is null or bucket not in ('social-photos','profile-photos','recipe-photos') or path is null or length(path)>100 then return false; end if;
 perform set_config('storage.operation','object.get_authenticated_info',true);
 allowed:=case bucket
  when 'social-photos' then staygrubby.social_object_allowed(bucket,path,'read')
  when 'profile-photos' then staygrubby.profile_object_allowed(bucket,path,'read')
  else staygrubby.recipe_object_allowed(bucket,path,'read') end;
 perform set_config('storage.operation',coalesce(previous,''),true);
 return coalesce(allowed,false);
end $$;
revoke all on function api.image_access(text,text) from public,anon,service_role;
grant execute on function api.image_access(text,text) to authenticated;

notify pgrst,'reload schema';
commit;
