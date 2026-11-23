-- PREPARED ONLY. Requires final owner activation approval and an authenticated
-- database operator session. Run after both approved security migrations.
-- Operator first sets staygrubby.approved_owner_id in this transaction to the
-- separately verified permanent account UUID; never infer recovery from a reused username.
-- Creates no user/account. Aborts if the initial state or username is different.
begin;
set local statement_timeout='10s';
select pg_advisory_xact_lock(hashtextextended('staygrubby:staff-roles',0));
do $$
declare owner_id uuid; matches integer;
begin
 if session_user not in ('postgres','supabase_admin') then
  raise exception 'Authenticated database operator required' using errcode='42501'; end if;
 if exists(select 1 from staygrubby.moderation_reviewers) then
  raise exception 'Staff state changed; obtain fresh approval' using errcode='PT409'; end if;
 select count(*),(array_agg(a.id))[1] into matches,owner_id
  from staygrubby.accounts a join staygrubby.profiles p on p.account_id=a.id
  where p.username='grubwithguy' and a.status='active';
 if matches<>1 or owner_id is distinct from nullif(current_setting('staygrubby.approved_owner_id',true),'')::uuid then raise exception 'Pinned approved owner identity required' using errcode='55000'; end if;
 perform set_config('staygrubby.staff_reason','Initial sole-owner enrollment after explicit activation approval',true);
 insert into staygrubby.moderation_reviewers(account_id,role) values(owner_id,'admin');
 perform set_config('staygrubby.staff_reason','',true);
end $$;
commit;
