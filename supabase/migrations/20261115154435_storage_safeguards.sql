-- Private, operational capacity telemetry. One rolling row (no user identifiers).
-- Cron's own completed run metadata expires after seven days in batches of 192.
-- Product tables, sync receipts, tombstones and Storage objects have no new retention.
begin;

create schema operations;
revoke all on schema operations from public, anon, authenticated, service_role;

create table operations.capacity_state (
 singleton boolean primary key default true check (singleton),
 sampled_at timestamptz not null,
 stats_epoch timestamptz not null,
 metrics jsonb not null,
 signals jsonb not null,
 last_alert_at timestamptz
);
alter table operations.capacity_state enable row level security;
revoke all on table operations.capacity_state from public, anon, authenticated, service_role;

create function operations.capacity_signals(sample jsonb) returns jsonb
language sql immutable set search_path='' as $$
 select coalesce(jsonb_object_agg(metric,
   case when actual >= critical then 'critical' when actual >= incident then 'incident' else 'warning' end), '{}'::jsonb)
 from (values
  ('database_bytes', 262144000::bigint, null::bigint, 419430400::bigint),
  ('wal_bytes', 314572800, null, 629145600),
  -- A conservative floor for a 2 GB disk. System overhead is not visible to PostgreSQL.
  ('visible_disk_bytes', 1200000000, 1400000000, 1600000000),
  ('storage_bytes', 700000000, null, 900000000),
  ('storage_unknown_sizes', 1, null, null),
  ('app_rows_per_minute', 1000, null, 5000),
  ('wal_generated_bytes_per_minute', 33554432, null, 134217728),
  ('excess_rollbacks_per_minute', 60, null, 300),
  ('long_or_idle_api_transactions', 1, null, 3)
 ) as thresholds(metric, warning, incident, critical)
 cross join lateral (select (sample->>metric)::numeric as actual) as measured
 where actual >= warning
$$;
revoke all on function operations.capacity_signals(jsonb) from public, anon, authenticated, service_role;

create function operations.sample_capacity() returns jsonb
language plpgsql volatile set search_path='' as $$
declare
 previous operations.capacity_state%rowtype;
 measured_at timestamptz := clock_timestamp();
 epoch timestamptz;
 metrics jsonb;
 signals jsonb;
 alert_at timestamptz;
 minutes numeric;
 commits bigint;
 rollbacks bigint;
 app_rows numeric;
 wal_generated numeric;
begin
 if not pg_try_advisory_xact_lock(hashtextextended('staygrubby-capacity-monitor', 0)) then
  return null;
 end if;

 select * into previous from operations.capacity_state;
 with db as (
  select (select sum(pg_database_size(oid)) from pg_database) bytes,
   greatest(stats_reset, pg_postmaster_start_time()) epoch, xact_commit, xact_rollback
  from pg_stat_database where datname = current_database()
 ), wal as (
  select coalesce(sum(size),0) bytes, (select wal_bytes from pg_stat_wal) generated from pg_ls_waldir()
 ), app as (
  select coalesce(sum(pg_total_relation_size(relid)),0) bytes,
   coalesce(sum(n_tup_ins::numeric + n_tup_upd + n_tup_del),0) row_changes
  from pg_stat_user_tables where schemaname = 'staygrubby'
 ), buckets as (
  select bucket_id, count(*) objects, coalesce(sum(size_bytes),0) bytes,
   count(*) filter (where size_bytes is null) unknown_sizes
  from (
   select bucket_id, case when metadata->>'size' ~ '^[0-9]{1,18}$' then (metadata->>'size')::bigint end size_bytes
   from storage.objects
  ) objects
  group by bucket_id
 ), storage_totals as (
  select coalesce(sum(objects),0) objects, coalesce(sum(bytes),0) bytes,
   coalesce(sum(unknown_sizes),0) unknown_sizes,
   coalesce(jsonb_object_agg(bucket_id,jsonb_build_object('objects',objects,'bytes',bytes,'unknown_sizes',unknown_sizes)),
    '{}'::jsonb) by_bucket
  from buckets
 ), logs as (
  select coalesce(sum(size),0) bytes from pg_ls_logdir()
 )
 select db.epoch, jsonb_build_object(
  'database_bytes', db.bytes, 'wal_bytes', wal.bytes, 'postgres_log_bytes', logs.bytes,
  'visible_disk_bytes', db.bytes + wal.bytes + logs.bytes,
  'app_relation_bytes', app.bytes, 'app_row_changes', app.row_changes,
  'storage_bytes', s.bytes, 'storage_objects', s.objects, 'storage_unknown_sizes', s.unknown_sizes,
  'storage_by_bucket', s.by_bucket, 'commits', db.xact_commit, 'rollbacks', db.xact_rollback,
  'wal_generated_bytes', wal.generated,
  'long_or_idle_api_transactions', (
   select count(*) from pg_stat_activity where usename = 'authenticator' and (
    (state = 'active' and measured_at - xact_start > interval '30 seconds')
    or (state like 'idle in transaction%' and measured_at - state_change > interval '30 seconds'))
  )
 ) into epoch, metrics
 from db cross join wal cross join app cross join storage_totals s cross join logs;

 minutes := extract(epoch from measured_at - previous.sampled_at) / 60;
 if epoch = previous.stats_epoch and minutes between 1 and 30 then
  commits := (metrics->>'commits')::bigint - (previous.metrics->>'commits')::bigint;
  rollbacks := (metrics->>'rollbacks')::bigint - (previous.metrics->>'rollbacks')::bigint;
  app_rows := (metrics->>'app_row_changes')::numeric - (previous.metrics->>'app_row_changes')::numeric;
  wal_generated := (metrics->>'wal_generated_bytes')::numeric - (previous.metrics->>'wal_generated_bytes')::numeric;
  metrics := metrics || jsonb_build_object(
   'app_rows_per_minute', case when app_rows >= 0 then round(app_rows / minutes, 2) end,
   'wal_generated_bytes_per_minute', case when wal_generated >= 0 then round(wal_generated / minutes, 2) end,
   'excess_rollbacks_per_minute', case when commits >= 0 and rollbacks >= 0 then round(greatest(0, rollbacks - commits) / minutes, 2) end,
   'app_relation_growth_bytes', (metrics->>'app_relation_bytes')::bigint - (previous.metrics->>'app_relation_bytes')::bigint,
   'storage_growth_bytes', (metrics->>'storage_bytes')::bigint - (previous.metrics->>'storage_bytes')::bigint
  );
 end if;

 signals := operations.capacity_signals(metrics);
 alert_at := previous.last_alert_at;
 if previous.sampled_at is null or signals <> previous.signals
   or (signals <> '{}'::jsonb and (alert_at is null or measured_at - alert_at >= interval '6 hours')) then
  raise log 'staygrubby_capacity signals=% previous=% database_bytes=% wal_bytes=% storage_bytes=%',
   signals, previous.signals, metrics->>'database_bytes', metrics->>'wal_bytes', metrics->>'storage_bytes';
  alert_at := measured_at;
 end if;
 insert into operations.capacity_state(singleton,sampled_at,stats_epoch,metrics,signals,last_alert_at)
 values(true, measured_at, epoch, metrics, signals, alert_at)
 on conflict (singleton) do update set sampled_at=excluded.sampled_at, stats_epoch=excluded.stats_epoch,
  metrics=excluded.metrics, signals=excluded.signals, last_alert_at=excluded.last_alert_at;

 -- pg_cron owns this table. Prune only this job's old, finished diagnostic rows.
 if to_regclass('cron.job_run_details') is not null then
  delete from cron.job_run_details where runid in (
   select run.runid from cron.job_run_details run join cron.job job using (jobid)
   where job.jobname = 'staygrubby-capacity' and job.username = current_user
    and run.end_time < measured_at - interval '7 days' order by run.runid limit 192
  );
 end if;
 return signals;
end $$;
revoke all on function operations.sample_capacity() from public, anon, authenticated, service_role;

-- Supabase supplies pg_cron. Disposable runtimes without the extension can replay the schema.
do $$
begin
 if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
  create extension if not exists pg_cron with schema pg_catalog;
  perform cron.schedule('staygrubby-capacity', '*/5 * * * *',
   'set statement_timeout = ''12s''; set lock_timeout = ''2s''; select operations.sample_capacity()');
 end if;
end $$;

commit;
