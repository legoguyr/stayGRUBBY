-- Stage 3 directed pointers through existing Order Up!; no chat, content copy or access grant.
alter table staygrubby.social_notifications drop constraint social_notifications_kind_check;
alter table staygrubby.social_notifications add constraint social_notifications_kind_check
 check(kind in('request','accepted','invited','joined','recreated','like','comment','recipe_shared','post_shared'));

create or replace function staygrubby.social_notice_visible(viewer uuid,notice uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from staygrubby.social_notifications n where n.id=notice and n.recipient_id=viewer and not staygrubby.social_blocked(viewer,n.actor_id)
 and exists(select 1 from staygrubby.profiles p join staygrubby.accounts a on a.id=p.account_id where p.account_id=n.actor_id and p.social_state='active' and p.deleted_at is null and a.status='active')
 and case n.kind
 when 'request' then exists(select 1 from staygrubby.friendships f where f.low_id=least(viewer,n.actor_id) and f.high_id=greatest(viewer,n.actor_id) and f.state='pending' and f.requester_id=n.actor_id)
 when 'accepted' then staygrubby.shared_friends(viewer,n.actor_id)
 when 'invited' then staygrubby.shared_access(viewer,n.target_id)
 when 'joined' then staygrubby.shared_access(viewer,n.target_id) and staygrubby.shared_friends(viewer,n.actor_id)
 when 'like' then staygrubby.social_can_view(viewer,n.target_id) and staygrubby.shared_friends(viewer,n.actor_id)
  and exists(select 1 from staygrubby.social_likes l where l.post_id=n.target_id and l.account_id=n.actor_id)
 when 'recreated' then staygrubby.social_can_view(viewer,n.target_id) and staygrubby.shared_friends(viewer,n.actor_id)
 when 'comment' then exists(select 1 from staygrubby.social_comments c where c.id=n.target_id and c.deleted_at is null and c.moderation_state='active' and staygrubby.social_can_view(viewer,c.post_id) and staygrubby.social_participant(viewer,c.author_id,c.post_id))
 when 'recipe_shared' then staygrubby.shared_friends(viewer,n.actor_id) and staygrubby.recipe_visible(viewer,n.target_id) and staygrubby.recipe_visible(n.actor_id,n.target_id)
 when 'post_shared' then staygrubby.shared_friends(viewer,n.actor_id) and staygrubby.social_can_view(viewer,n.target_id) and staygrubby.social_can_view(n.actor_id,n.target_id)
 else false end)
$$;
revoke all on function staygrubby.social_notice_visible(uuid,uuid) from public,anon,authenticated;

create function staygrubby.social_send_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid:=staygrubby.social_actor(); object_id uuid; peer uuid; source_owner uuid;
 content_kind text:=payload->>'targetType'; origin uuid; search text:=lower(btrim(coalesce(payload->>'query','')));
 result jsonb; cursor text; dedupe text; existing staygrubby.social_notifications; pair_key text;
begin
 if octet_length(payload::text)>4096 or content_kind is null or content_kind not in('recipe','post') or length(search)>50 then
  raise exception 'Invalid share request' using errcode='22023'; end if;
 object_id:=(payload->>'targetID')::uuid;
 if object_id is null or not (case content_kind when 'recipe' then staygrubby.recipe_visible(owner,object_id) else staygrubby.social_can_view(owner,object_id) end) then
  raise exception 'Shared content unavailable' using errcode='42501'; end if;
 if action='recipients' then
  select coalesce(jsonb_agg(person order by username),'[]'::jsonb) into result from (
   select p.username,staygrubby.social_person(owner,p.account_id) person from staygrubby.profiles p
   where staygrubby.shared_friends(owner,p.account_id)
   and (payload->>'afterUsername' is null or p.username>payload->>'afterUsername')
   and (search='' or position(search in lower(p.username))>0 or position(search in lower(p.display_name))>0)
   and case content_kind when 'recipe' then staygrubby.recipe_visible(p.account_id,object_id) else staygrubby.social_can_view(p.account_id,object_id) end
   order by p.username limit 51) people;
  if jsonb_array_length(result)>50 then cursor:=result->49->>'username'; result:=result-50; end if;
  return jsonb_build_object('people',result,'nextCursor',cursor);
 elsif action<>'send' then raise exception 'Unknown share action' using errcode='22023'; end if;
 peer:=(payload->>'peerID')::uuid; origin:=(payload->>'originID')::uuid;
 if peer is null or origin is null or peer=owner then raise exception 'Choose a Sous Chef' using errcode='22023'; end if;
 if content_kind='recipe' then select owner_id into source_owner from staygrubby.recipes where id=object_id;
 else select author_id into source_owner from staygrubby.social_posts where id=object_id; end if;
 -- Match existing friendship/block pair locks, in a deterministic order for multi-party authorization.
 for pair_key in select distinct 'staygrubby:pair:'||least(a,b)::text||':'||greatest(a,b)::text
  from unnest(array[owner,peer,source_owner]) a cross join unnest(array[owner,peer,source_owner]) b
  where a is not null and b is not null and a<>b order by 1
 loop perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(pair_key,0)); end loop;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:direct-share:'||owner::text,0));
 perform staygrubby.social_actor();
 if not staygrubby.shared_friends(owner,peer)
 or not (case content_kind when 'recipe' then staygrubby.recipe_visible(owner,object_id) and staygrubby.recipe_visible(peer,object_id)
 else staygrubby.social_can_view(owner,object_id) and staygrubby.social_can_view(peer,object_id) end) then
  raise exception 'Shared content or recipient unavailable' using errcode='42501'; end if;
 dedupe:='direct:'||owner::text||':'||origin::text;
 select * into existing from staygrubby.social_notifications where dedupe_key=dedupe;
 if found then
  if existing.recipient_id<>peer or existing.target_id<>object_id or existing.kind<>(content_kind||'_shared') then
   raise exception 'Share request changed' using errcode='40001'; end if;
  return jsonb_build_object('sent',true);
 end if;
 -- Security burst bound, not a product allowance. Retries do not spend another slot.
 if (select count(*) from staygrubby.social_notifications where actor_id=owner and kind in('recipe_shared','post_shared') and created_at>now()-interval '1 hour')>=100 then
  raise exception 'Sharing cooldown' using errcode='54000'; end if;
 perform staygrubby.social_notice(peer,owner,content_kind||'_shared',object_id,dedupe);
 return jsonb_build_object('sent',true);
end $$;
revoke all on function staygrubby.social_send_api(text,jsonb) from public,anon;
grant execute on function staygrubby.social_send_api(text,jsonb) to authenticated;
create function api.social_send(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_send_api(action,payload) $$;
revoke all on function api.social_send(text,jsonb) from public,anon;
grant execute on function api.social_send(text,jsonb) to authenticated;
