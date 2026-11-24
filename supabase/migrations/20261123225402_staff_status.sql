-- Read-only own-role projection for the gated native moderation interface.
-- No tables, enrollment, audit writes, content mutation or additional visibility.
begin;
create function staygrubby.staff_status(action text,payload jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid := staygrubby.social_actor(); staff_role text;
begin
 if action is distinct from 'me' or payload is distinct from '{}'::jsonb then
  raise exception 'Invalid staff status request' using errcode='22023'; end if;
 select role into staff_role from staygrubby.moderation_reviewers where account_id=actor;
 return jsonb_build_object('role',staff_role);
end $$;
revoke all on function staygrubby.staff_status(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function staygrubby.staff_status(text,jsonb) to authenticated;
create function api.staff_status(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql stable security invoker set search_path='' as $$select staygrubby.staff_status(action,payload)$$;
revoke all on function api.staff_status(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function api.staff_status(text,jsonb) to authenticated;
-- Deliver only this existing gate to current staff; other flags are unchanged.
-- This migration does not insert/enable flags or enroll anyone.
create or replace function staygrubby.feature_flag_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=staygrubby.social_actor();
begin
 if action is distinct from 'get' or octet_length(coalesce(payload,'{}'::jsonb)::text)>1024 then
  raise exception 'Invalid request' using errcode='22023';
 end if;
 if actor is null or not exists(select 1 from staygrubby.accounts where id=actor and status='active') then
  raise exception 'Account unavailable' using errcode='42501';
 end if;
 return jsonb_build_object('enabled',coalesce((select jsonb_agg(f.key order by f.key) from staygrubby.feature_flags f
  where f.enabled and f.audience='everyone'
   and (f.key<>'staff_moderation' or exists(select 1 from staygrubby.moderation_reviewers r where r.account_id=actor))),'[]'::jsonb));
end $$;
notify pgrst,'reload schema';
commit;
