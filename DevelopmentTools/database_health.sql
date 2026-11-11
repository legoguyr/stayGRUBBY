-- StayGrubby production database health check (read-only). Run in the Supabase SQL editor or
-- through the Supabase MCP `execute_sql` before every TestFlight/App Store candidate and whenever
-- the dashboard disk graph moves. See supabase/README.md "Database capacity and health".
-- It changes nothing and returns one JSON document with a verdict per signal.
--
-- Disk thresholds are against the provisioned disk shown in Project Settings -> Compute and Disk
-- (2 GB on November 11 2026). Postgres cannot see the platform "System" category, so the dashboard
-- total must be read there; this check covers everything Postgres itself can see.
with
 disk as (
  select (select sum(pg_database_size(oid)) from pg_database) database_bytes,
         (select coalesce(sum(size),0) from pg_ls_waldir()) wal_bytes,
         (select coalesce(sum(size),0) from pg_ls_logdir()) log_bytes),
 churn as (
  -- A retry storm (P0 Nov 11 2026) shows as rollbacks vastly exceeding commits and one
  -- PostgREST backend re-running the same statement. Since-start ratio plus live backends.
  select xact_commit, xact_rollback, round(xact_rollback::numeric / greatest(xact_commit,1), 2) rollback_ratio
  from pg_stat_database where datname = current_database()),
 busy as (
  select count(*) filter (where state = 'active' and now() - xact_start > interval '30 seconds') long_active,
         count(*) filter (where state like 'idle in transaction%' and now() - state_change > interval '30 seconds') idle_in_tx
  from pg_stat_activity where usename = 'authenticator'),
 retry_codes as (
  select count(*) n from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('staygrubby','api','development')
   and (p.prosrc ~* 'errcode\s*=\s*''40(001|P01)''' or p.prosrc ~* 'errcode\s*=\s*''(serialization_failure|deadlock_detected)''')),
 tables as (
  select n.nspname || '.' || c.relname rel, pg_total_relation_size(c.oid) bytes, s.n_live_tup live, s.n_dead_tup dead
  from pg_class c join pg_namespace n on n.oid = c.relnamespace left join pg_stat_all_tables s on s.relid = c.oid
  where c.relkind in ('r','m') and n.nspname in ('staygrubby','auth','storage','public','development')
  order by pg_total_relation_size(c.oid) desc limit 12),
 bloat as (
  select count(*) n from pg_stat_all_tables
  where schemaname in ('staygrubby','auth','storage') and n_dead_tup > 1000 and n_dead_tup > n_live_tup)
select jsonb_pretty(jsonb_build_object(
 'checked_at', now(),
 'read_only', current_setting('default_transaction_read_only'),
 'postgres_visible_bytes', jsonb_build_object('database', d.database_bytes, 'wal', d.wal_bytes, 'logs', d.log_bytes,
   'total_pretty', pg_size_pretty(d.database_bytes + d.wal_bytes + d.log_bytes)),
 'verdicts', jsonb_build_object(
   'read_only', case when current_setting('default_transaction_read_only') = 'on' then 'STOP: project is read-only' else 'ok' end,
   'database_size', case when d.database_bytes > 400*1024*1024 then 'STOP: database > 400 MB (Free plan limit 500 MB)'
                         when d.database_bytes > 250*1024*1024 then 'WARN: database > 250 MB' else 'ok' end,
   'wal', case when d.wal_bytes > 600*1024*1024 then 'STOP: WAL > 600 MB (archiving lagging or write storm)'
               when d.wal_bytes > 300*1024*1024 then 'WARN: WAL > 300 MB' else 'ok' end,
   'retry_codes', case when r.n > 0 then 'STOP: a function raises a PostgREST-retried SQLSTATE (40001/40P01)' else 'ok' end,
   'retry_storm', case when b.long_active + b.idle_in_tx > 0 then 'STOP: PostgREST backend busy > 30 s (possible retry loop)' else 'ok' end,
   'bloat', case when bl.n > 0 then 'WARN: table with more dead than live tuples' else 'ok' end),
 'transactions', jsonb_build_object('commits', c.xact_commit, 'rollbacks', c.xact_rollback, 'rollback_ratio_since_start', c.rollback_ratio),
 'backends', jsonb_build_object('long_active', b.long_active, 'idle_in_transaction', b.idle_in_tx),
 'largest_tables', (select jsonb_agg(jsonb_build_object('table', rel, 'size', pg_size_pretty(bytes), 'live', live, 'dead', dead)) from tables)
)) report
from disk d, churn c, busy b, retry_codes r, bloat bl;
