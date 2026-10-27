-- Owner policy: no StayGrubby daily/monthly allowance; provider quota is authoritative.
-- Retain only a short per-account burst guard. Never disables cloud by date.
begin;
create or replace function api.reserve_recipe_import(p_user uuid,p_session uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare actor uuid:=staygrubby.recipe_import_actor(p_user,p_session); w timestamptz:=date_trunc('minute',now()); n integer;
begin
 if actor is null then raise insufficient_privilege using message='Account unavailable';end if;
 insert into staygrubby.recipe_import_usage(bucket,window_start,account_id) values(actor::text||'-minute',w,actor) on conflict do nothing;
 select attempts into n from staygrubby.recipe_import_usage where bucket=actor::text||'-minute' and window_start=w for update;
 if staygrubby.recipe_import_actor(p_user,p_session) is distinct from actor then raise insufficient_privilege using message='Account unavailable';end if;
 if n>=3 then return false;end if;
 update staygrubby.recipe_import_usage set attempts=attempts+1 where bucket=actor::text||'-minute' and window_start=w;
 delete from staygrubby.recipe_import_usage where window_start<now()-interval '2 days';
 return true;
end $$;
-- Compatibility for the briefly deployed allowance function: no seats, success
-- counting or daily checks. Kept server-only while clients/functions roll forward.
create or replace function api.begin_recipe_import(p_user uuid,p_session uuid,p_request uuid) returns text
language plpgsql security definer set search_path='' as $$
begin
 if api.reserve_recipe_import(p_user,p_session) then return 'allowed';end if;return 'attempt_limit';
end $$;
create or replace function api.finish_recipe_import(p_user uuid,p_session uuid,p_request uuid,p_success boolean) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if staygrubby.recipe_import_actor(p_user,p_session) is null then raise insufficient_privilege using message='Account unavailable';end if;
 return true;
end $$;
-- Historical ledger/column are inert, private, and cascade on account erasure.
-- Do not destroy any valid in-flight bookkeeping during the policy transition.
commit;
