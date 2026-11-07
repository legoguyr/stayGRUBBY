-- Edit only the owner's invitations/attribution. The private cooking graph is untouched.
begin;
alter function staygrubby.social_cooking(text,jsonb) rename to social_cooking_before_participant_edit;
revoke all on function staygrubby.social_cooking_before_participant_edit(text,jsonb) from public,anon,authenticated;
create function staygrubby.social_cooking(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid; cook uuid; item uuid; eid uuid; peer uuid; metadata jsonb;
 selected uuid[]; desired uuid[]; version_token text; response jsonb;
 search_text text; people jsonb;
begin
 if action not in ('edit_selection','update_selection','eligible_selection') then
  return staygrubby.social_cooking_before_participant_edit(action,payload);
 end if;
 owner:=staygrubby.social_actor();
 if owner is null or octet_length(payload::text)>8192 then raise exception 'Invalid cook selection' using errcode='42501'; end if;
 if action='update_selection' then
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:shared:'||owner::text,0));
 end if;
 perform 1 from staygrubby.accounts where id=owner and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from owner then raise exception 'Account unavailable' using errcode='42501'; end if;
 if action='eligible_selection' then
  search_text:=lower(btrim(coalesce(payload->>'query','')));
  if length(search_text)>50 then raise exception 'Search is too long' using errcode='22023'; end if;
  select coalesce(jsonb_agg(card order by username),'[]'::jsonb) into people from (
   select p.username,staygrubby.social_person(owner,p.account_id) card
   from staygrubby.friendships f join staygrubby.profiles p
    on p.account_id=case when f.low_id=owner then f.high_id else f.low_id end
   where owner in (f.low_id,f.high_id) and f.state='friends'
    and p.username>coalesce(payload->>'afterUsername','')
    and staygrubby.shared_friends(owner,p.account_id)
    and (position(ltrim(search_text,'@') in p.username)>0 or position(search_text in lower(p.display_name))>0)
   order by p.username limit 50
  ) matches where card is not null;
  return jsonb_build_object('people',people,'nextCursor',case when jsonb_array_length(people)=50 then people->49->>'username' end);
 end if;
 cook:=(payload->>'attemptID')::uuid;
 select a.ranked_item_id into item from staygrubby.cooking_attempts a
 where a.account_id=owner and a.id=cook and a.deleted_at is null;
 metadata:=staygrubby.shared_cook_metadata(owner,cook);
 if item is null or metadata is null then raise exception 'Cook unavailable' using errcode='42501'; end if;
 select id into eid from staygrubby.shared_cooks where owner_id=owner and source_attempt_id=cook for update;
 select coalesce(array_agg(s.account_id order by s.account_id) filter (
   where s.state in ('pending','joining','joined') and staygrubby.shared_friends(owner,s.account_id)),array[]::uuid[]),
  encode(sha256(convert_to(coalesce(jsonb_agg(jsonb_build_array(s.account_id,s.state,s.updated_at) order by s.account_id)::text,'[]'),'UTF8')),'hex')
 into selected,version_token from staygrubby.shared_participants s where s.event_id=eid;
 if action='update_selection' then
  if payload->'confirmed' is distinct from 'true'::jsonb
   or jsonb_typeof(payload->'participantIDs') is distinct from 'array'
   or jsonb_array_length(payload->'participantIDs')>8
  then raise exception 'Invalid cook selection' using errcode='22023'; end if;
  select coalesce(array_agg(distinct x::uuid order by x::uuid),array[]::uuid[]) into desired
   from jsonb_array_elements_text(payload->'participantIDs') x;
  if cardinality(desired)<>jsonb_array_length(payload->'participantIDs') or array_position(desired,null) is not null
  then raise exception 'Duplicate or missing Sous Chef' using errcode='22023'; end if;
  -- Identical retries (including lost replies) do not create another invitation or Ticket.
  if desired is distinct from selected then
   if payload->>'selectionToken' is distinct from version_token
   then raise exception 'Sous Chef selection changed' using errcode='40001'; end if;
   for peer in select unnest(desired) loop
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:pair:'||least(owner,peer)::text||':'||greatest(owner,peer)::text,0));
    if not staygrubby.shared_friends(owner,peer) then raise exception 'Choose current Sous Chefs' using errcode='42501'; end if;
   end loop;
   if eid is null then
    response:=staygrubby.social_cooking_before_participant_edit('create',payload||jsonb_build_object('eventID',item));
    eid:=(response->>'id')::uuid;
   else
    update staygrubby.shared_participants set state='removed',updated_at=clock_timestamp()
     where event_id=eid and account_id=any(selected) and not(account_id=any(desired));
    for peer in select unnest(desired) except select unnest(selected) loop
     insert into staygrubby.shared_participants(event_id,account_id) values(eid,peer)
      on conflict(event_id,account_id) do update set state='pending',updated_at=clock_timestamp();
     perform staygrubby.social_notice(peer,owner,'invited',eid,'invite:'||eid::text||':'||peer::text);
    end loop;
   end if;
   return staygrubby.social_cooking('edit_selection',jsonb_build_object('attemptID',cook));
  end if;
 end if;
 return jsonb_build_object('selectionToken',version_token,'selectedIDs',to_jsonb(selected),'event',staygrubby.shared_event_card(owner,eid));
end $$;
revoke all on function staygrubby.social_cooking(text,jsonb) from public,anon;
grant execute on function staygrubby.social_cooking(text,jsonb) to authenticated;
create or replace function api.social_cooking(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_cooking(action,payload) $$;
notify pgrst,'reload schema';
commit;
