-- Operational staff authorization: <= one membership per staff account.
-- Audit: one row per explicit role change; no read telemetry or copied content.
-- Retain audit outcomes; account erasure nulls personal account references.
-- No enrollment, content backfill, new accounts or automatic production activation.
begin;
alter table staygrubby.moderation_reviewers add column role text not null default 'moderator'
 check(role in ('admin','moderator'));
create table staygrubby.staff_role_audit (
 id bigint generated always as identity primary key,
 operation_id uuid unique,
 actor_id uuid references staygrubby.accounts(id) on delete set null,
 subject_id uuid references staygrubby.accounts(id) on delete set null,
 previous_role text, new_role text,
 reason text not null check(length(reason) between 1 and 300),
 operator_session text not null,
 created_at timestamptz not null default now()
);
alter table staygrubby.staff_role_audit enable row level security;
revoke all on staygrubby.staff_role_audit from public,anon,authenticated,service_role;

create function staygrubby.staff_role_guard() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended('staygrubby:staff-roles',0));
 if TG_OP in ('UPDATE','DELETE') and OLD.role='admin'
   and (TG_OP='DELETE' or NEW.role<>'admin')
   and not exists(select 1 from staygrubby.moderation_reviewers r join staygrubby.accounts a on a.id=r.account_id
     where r.role='admin' and r.account_id<>OLD.account_id and a.status='active') then
  -- Only the established deliberate erasure flow may remove a last admin.
  if TG_OP<>'DELETE' or exists(select 1 from staygrubby.accounts where id=OLD.account_id)
   or not exists(select 1 from staygrubby.account_deletion_jobs where account_id=OLD.account_id and state='storage_cleared')
  then raise exception 'Last admin must be retained' using errcode='PT409'; end if;
 end if;
 if TG_OP='DELETE' then return OLD; end if;
 if TG_OP='UPDATE' and NEW.account_id<>OLD.account_id then
  raise exception 'Staff identity is immutable' using errcode='22023'; end if;
 return NEW;
end $$;
create trigger staff_role_guard before insert or update or delete on staygrubby.moderation_reviewers
 for each row execute function staygrubby.staff_role_guard();

create function staygrubby.record_staff_role_change() returns trigger
language plpgsql security definer set search_path='' as $$
declare subject uuid; actor uuid; old_role text; next_role text;
begin
 if TG_OP<>'INSERT' then subject:=OLD.account_id; old_role:=OLD.role; end if;
 if TG_OP<>'DELETE' then subject:=NEW.account_id; next_role:=NEW.role; end if;
 if old_role is not distinct from next_role then return null; end if;
 select l.account_id into actor from staygrubby.auth_account_links l where l.auth_user_id=auth.uid();
 if not exists(select 1 from staygrubby.accounts where id=subject) then subject:=null; end if;
 insert into staygrubby.staff_role_audit(operation_id,actor_id,subject_id,previous_role,new_role,reason,operator_session)
 values(nullif(current_setting('staygrubby.staff_operation',true),'')::uuid,actor,subject,old_role,next_role,
  coalesce(nullif(current_setting('staygrubby.staff_reason',true),''),'Account erasure or authenticated operator change'),session_user);
 return null;
end $$;
create trigger record_staff_role_change after insert or update or delete on staygrubby.moderation_reviewers
 for each row execute function staygrubby.record_staff_role_change();
revoke all on function staygrubby.staff_role_guard(),staygrubby.record_staff_role_change() from public,anon,authenticated,service_role;

create function staygrubby.staff_roles(action text,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=staygrubby.social_actor(); target uuid; wanted text; previous text;
 op uuid; why text; receipt staygrubby.staff_role_audit%rowtype; result jsonb;
begin
 -- Match account-erasure lock order: target account before staff authorization.
 if action in ('assign','remove') then
  if payload is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>1024 then
   raise exception 'Invalid role request' using errcode='22023'; end if;
  target:=(payload->>'accountID')::uuid;
 end if;
 -- Lock both audit-FK parents before the global guard, in deterministic order.
 perform 1 from staygrubby.accounts where id in(actor,target) order by id for share;
 perform pg_advisory_xact_lock(hashtextextended('staygrubby:staff-roles',0));
 if not exists(select 1 from staygrubby.moderation_reviewers r join staygrubby.accounts a on a.id=r.account_id where r.account_id=actor and r.role='admin' and a.status='active')
 then raise exception 'Admin required' using errcode='42501'; end if;
 if payload is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>1024
 then raise exception 'Invalid role request' using errcode='22023'; end if;
 if action='list' then
  select coalesce(jsonb_agg(jsonb_build_object('accountID',r.account_id,'role',r.role) order by r.account_id),'[]') into result
   from (select account_id,role from staygrubby.moderation_reviewers order by account_id limit 100) r;
  return jsonb_build_object('staff',result);
 end if;
 if action is null or action not in ('assign','remove') or not(payload ? 'expectedRole')
 then raise exception 'Invalid role action' using errcode='22023'; end if;
 target:=(payload->>'accountID')::uuid; op:=(payload->>'operationID')::uuid;
 why:=btrim(payload->>'reason'); wanted:=case when action='remove' then null else payload->>'role' end;
 if target is null or op is null or why is null or length(why) not between 1 and 300
  or (action='assign' and (wanted is null or wanted not in ('admin','moderator')))
 then raise exception 'Invalid role change' using errcode='22023'; end if;
 select * into receipt from staygrubby.staff_role_audit where operation_id=op;
 if found then
  if receipt.actor_id is distinct from actor or receipt.subject_id is distinct from target
    or receipt.new_role is distinct from wanted or receipt.previous_role is distinct from payload->>'expectedRole' or receipt.reason<>why
  then raise exception 'Operation conflicts' using errcode='PT409'; end if;
  return jsonb_build_object('operationID',op,'role',wanted);
 end if;
 perform 1 from staygrubby.accounts where id=target and status='active' for share;
 if not found then raise exception 'Account unavailable' using errcode='42501'; end if;
 select role into previous from staygrubby.moderation_reviewers where account_id=target;
 if previous is distinct from payload->>'expectedRole' then raise exception 'Reload staff role' using errcode='PT409'; end if;
 perform set_config('staygrubby.staff_reason',why,true); perform set_config('staygrubby.staff_operation',op::text,true);
 if wanted is null then delete from staygrubby.moderation_reviewers where account_id=target;
 else insert into staygrubby.moderation_reviewers(account_id,role) values(target,wanted)
  on conflict(account_id) do update set role=excluded.role where moderation_reviewers.role<>excluded.role; end if;
 perform set_config('staygrubby.staff_reason','',true); perform set_config('staygrubby.staff_operation','',true);
 return jsonb_build_object('operationID',op,'role',wanted);
end $$;
revoke all on function staygrubby.staff_roles(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function staygrubby.staff_roles(text,jsonb) to authenticated;
create function api.staff_roles(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql security invoker set search_path='' as $$select staygrubby.staff_roles(action,payload)$$;
revoke all on function api.staff_roles(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function api.staff_roles(text,jsonb) to authenticated;
-- Existing moderation_review and reported-image access retain self-case exclusion.
-- First/recovery admin enrollment is an approved database-operator transaction,
-- never a public bootstrap endpoint. The same guard and audit triggers apply.
notify pgrst,'reload schema';
commit;
