set transaction read write;
-- P0 incident, November 11 2026. PostgREST runs every RPC inside a transaction that it
-- retries automatically, without limit, when PostgreSQL reports SQLSTATE 40001
-- (serialization_failure). StayGrubby functions used 40001 for deterministic business
-- conflicts ("Link changed; reload", "Media not accepted", "Wait for cooking sync", ...),
-- so one such request never returned: PostgREST re-ran it hundreds of times a second
-- forever, pinning a pooled connection, holding account locks, writing ~7 GB/day of WAL,
-- and eventually pushing the project's disk to 95% (read-only mode).
--
-- Deterministic conflicts now use PT409: PostgREST returns HTTP 409 with code PT409 once
-- and never retries it. Function bodies, owners, SECURITY DEFINER, search_path and grants
-- are otherwise unchanged (CREATE OR REPLACE of each function's own definition).
-- A guard fails the migration if any StayGrubby function still raises a retryable class-40 code.
do $$
declare f record;
begin
 for f in
  select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('staygrubby','api') and p.prokind='f' and p.prosrc like '%errcode=''40001''%'
 loop
  execute replace(pg_catalog.pg_get_functiondef(f.oid), 'errcode=''40001''', 'errcode=''PT409''');
 end loop;
 if exists(
  select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('staygrubby','api','development')
   and (p.prosrc ~* 'errcode\s*=\s*''40(001|P01)''' or p.prosrc ~* 'using\s+errcode\s*=\s*''(serialization_failure|deadlock_detected)'''))
 then raise exception 'A StayGrubby function still raises a PostgREST-retried SQLSTATE'; end if;
end $$;
