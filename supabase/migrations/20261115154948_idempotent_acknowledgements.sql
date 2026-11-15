-- Keep RPC signatures, validations, permissions and response shapes. Avoid writing
-- an identical read flag or manifest flag when an acknowledged request is replayed.
begin;
create or replace function staygrubby.social_notifications_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid:=staygrubby.social_actor(); result jsonb; unread integer;
begin
 if octet_length(payload::text)>4096 then raise exception 'Invalid notifications request' using errcode='22023'; end if;
 if action='read' then
  if not staygrubby.social_notice_visible(owner,(payload->>'targetID')::uuid) then raise exception 'Notification unavailable' using errcode='42501'; end if;
  update staygrubby.social_notifications set read_at=now() where id=(payload->>'targetID')::uuid and recipient_id=owner and read_at is null;
 elsif action='readAll' then
  update staygrubby.social_notifications n set read_at=now() where recipient_id=owner and read_at is null and staygrubby.social_notice_visible(owner,n.id);
 elsif action='delete' then
  -- Keep the dedupe tombstone: a delayed source retry must not recreate a dismissed notice.
  update staygrubby.social_notifications set read_at=now() where id=(payload->>'targetID')::uuid and recipient_id=owner and read_at is null;
 elsif action<>'page' then raise exception 'Unknown notification action' using errcode='22023'; end if;
 select count(*) into unread from staygrubby.social_notifications n where recipient_id=owner and read_at is null and staygrubby.social_notice_visible(owner,n.id);
 select coalesce(jsonb_agg(card order by created_at desc,id desc),'[]'::jsonb) into result from (
  select n.created_at,n.id,jsonb_build_object('id',n.id,'kind',n.kind,'actor',staygrubby.social_person(owner,n.actor_id),'targetID',n.target_id,
   'postID',case when n.kind in('like','recreated') then n.target_id when n.kind='comment' then (select post_id from staygrubby.social_comments where id=n.target_id) end,
   'createdAt',extract(epoch from n.created_at),'read',n.read_at is not null) card
  from staygrubby.social_notifications n where recipient_id=owner and staygrubby.social_notice_visible(owner,n.id)
  and (payload->>'beforeTime' is null or(n.created_at,n.id)<(to_timestamp((payload->>'beforeTime')::double precision),(payload->>'beforeID')::uuid))
  order by n.created_at desc,n.id desc limit 25) page;
 return jsonb_build_object('notifications',result,'unread',unread);
end $$;

create or replace function staygrubby.media_backup(action text,manifest jsonb default null) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid; mid uuid; stored_media staygrubby.media%rowtype; stored_backup staygrubby.media_backups%rowtype; result jsonb;
begin
 owner := staygrubby.media_owner();
 if owner is null then raise exception 'Authenticated account required' using errcode='42501'; end if;
 if action='list' then perform 1 from staygrubby.accounts where id=owner for share;
 else perform 1 from staygrubby.accounts where id=owner for update; end if;
 if staygrubby.media_owner() is distinct from owner then raise exception 'Session unavailable' using errcode='42501'; end if;
 if action is null or action not in ('list','register','complete','cleaned') then raise exception 'Invalid action' using errcode='22023'; end if;
 if action<>'list' then
  if (manifest->>'accountID')::uuid is distinct from owner then raise exception 'Account mismatch' using errcode='42501'; end if;
  mid := (manifest->>'mediaID')::uuid;
  select * into stored_media from staygrubby.media where account_id=owner and id=mid;
  if not found then raise exception 'Media not accepted' using errcode='PT409'; end if;
  if action in ('register','complete') and (stored_media.deleted_at is not null or not exists(
    select 1 from staygrubby.cooking_attempts a join staygrubby.dishes d on d.account_id=a.account_id and d.id=a.dish_id
    where a.account_id=owner and a.id=stored_media.attempt_id and a.deleted_at is null and d.deleted_at is null))
  then raise exception 'Media retired' using errcode='PT409'; end if;
  if action='register' then
   if manifest->>'displayHash' !~ '^[0-9a-f]{64}$' or manifest->>'thumbnailHash' !~ '^[0-9a-f]{64}$'
    or (manifest->>'displayBytes')::integer not between 1 and 2097152
    or (manifest->>'thumbnailBytes')::integer not between 1 and 2097152
   then raise exception 'Invalid integrity manifest' using errcode='22023'; end if;
   insert into staygrubby.media_backups(account_id,media_id,display_hash,thumbnail_hash,display_bytes,thumbnail_bytes,display_key,thumbnail_key)
   values(owner,mid,manifest->>'displayHash',manifest->>'thumbnailHash',(manifest->>'displayBytes')::integer,(manifest->>'thumbnailBytes')::integer,
    owner::text || '/' || mid::text || '/display-' || (manifest->>'displayHash') || '.jpg',
    owner::text || '/' || mid::text || '/thumbnail-' || (manifest->>'thumbnailHash') || '.jpg')
   on conflict(account_id,media_id) do nothing;
  end if;
  select * into stored_backup from staygrubby.media_backups where account_id=owner and media_id=mid;
  if not found then raise exception 'Manifest missing' using errcode='55000'; end if;
  if (stored_backup.display_hash,stored_backup.thumbnail_hash,stored_backup.display_bytes,stored_backup.thumbnail_bytes) is distinct from
   (manifest->>'displayHash',manifest->>'thumbnailHash',(manifest->>'displayBytes')::integer,(manifest->>'thumbnailBytes')::integer)
  then raise exception 'Immutable manifest mismatch' using errcode='23505'; end if;
  if action='complete' then
   if not exists(select 1 from storage.objects where bucket_id='cooking-photos' and name=stored_backup.display_key
     and (metadata->>'size')::bigint=stored_backup.display_bytes and metadata->>'mimetype'='image/jpeg')
    or not exists(select 1 from storage.objects where bucket_id='cooking-photos' and name=stored_backup.thumbnail_key
     and (metadata->>'size')::bigint=stored_backup.thumbnail_bytes and metadata->>'mimetype'='image/jpeg')
   then raise exception 'Bytes not backed up' using errcode='55000'; end if;
   update staygrubby.media_backups set ready=true where account_id=owner and media_id=mid and not ready;
  elsif action='cleaned' then
   if stored_media.deleted_at is null then raise exception 'Active media cannot be cleaned' using errcode='PT409'; end if;
   if exists(select 1 from storage.objects where bucket_id='cooking-photos' and name in (stored_backup.display_key,stored_backup.thumbnail_key))
   then raise exception 'Storage cleanup pending' using errcode='55000'; end if;
   update staygrubby.media_backups set cleaned=true where account_id=owner and media_id=mid and not cleaned;
  end if;
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('accountID',b.account_id,'mediaID',b.media_id,
  'displayHash',b.display_hash,'thumbnailHash',b.thumbnail_hash,'displayBytes',b.display_bytes,'thumbnailBytes',b.thumbnail_bytes,
  'displayKey',b.display_key,'thumbnailKey',b.thumbnail_key,'state',
  case when m.deleted_at is not null then 'deleted' when b.ready
   and exists(select 1 from storage.objects o where o.bucket_id='cooking-photos' and o.name=b.display_key and (o.metadata->>'size')::bigint=b.display_bytes and o.metadata->>'mimetype'='image/jpeg')
   and exists(select 1 from storage.objects o where o.bucket_id='cooking-photos' and o.name=b.thumbnail_key and (o.metadata->>'size')::bigint=b.thumbnail_bytes and o.metadata->>'mimetype'='image/jpeg')
   then 'ready' else 'pending' end) order by b.media_id),'[]'::jsonb)
 into result from staygrubby.media_backups b join staygrubby.media m on m.account_id=b.account_id and m.id=b.media_id
 where b.account_id=owner and not b.cleaned and (action='list' or b.media_id=mid);
 return jsonb_build_object('accountID',owner,'backups',result);
end $$;

commit;
