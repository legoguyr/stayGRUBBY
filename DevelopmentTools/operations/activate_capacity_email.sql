-- OPERATOR TEMPLATE ONLY: not a migration; run only after explicit activation approval.
-- First create a free Healthchecks check and securely store its HTTPS URL in Vault
-- under staygrubby_capacity_ping. Never put the URL in Git, SQL history or chat.
-- Requires separately approved pg_net extension. No content/identity transmission.
begin;
create extension if not exists pg_net;
create or replace function operations.deliver_capacity_heartbeat() returns void
language plpgsql security definer set search_path='' as $$
declare destination text; sample operations.capacity_state%rowtype; suffix text;
begin
 select decrypted_secret into destination from vault.decrypted_secrets where name='staygrubby_capacity_ping';
 if destination is null or destination !~ '^https://hc-ping[.]com/[0-9a-f-]{36}$' then
  raise exception 'Capacity heartbeat not configured' using errcode='55000'; end if;
 select * into sample from operations.capacity_state where singleton;
 suffix:=case when sample.sampled_at between now()-interval '15 minutes' and clock_timestamp() and sample.signals='{}'::jsonb then '' else '/fail' end;
 -- One queued request per destination prevents backlog on a stalled worker.
 if exists(select 1 from net.http_request_queue where url in(destination,destination||'/fail')) then return; end if;
 perform net.http_post(url:=destination||suffix,body:='{}'::jsonb,timeout_milliseconds:=3000);
end $$;
revoke all on function operations.deliver_capacity_heartbeat() from public,anon,authenticated,service_role;
select cron.schedule('staygrubby-capacity-email','2-57/5 * * * *','select operations.deliver_capacity_heartbeat()');
commit;
-- Receipt test: use a separate synthetic Healthchecks check for healthy/fail,
-- missing heartbeat and recovery. Never alter live capacity signals to test email.
-- Rollback delivery only: cron.unschedule('staygrubby-capacity-email'); leave
-- existing capacity sampling, Vault, application data and policies intact.
