-- Feature flag foundation (FOOD_ARCHITECTURE §10; STAYGRUBBY_ARCHITECTURE "Feature flags").
-- Global enable/disable now; `audience` reserves internal/beta cohorts for later
-- (a future membership table resolves them; today only 'everyone' can be on).
-- Flags are server-managed (SQL/dashboard by the owner), never client-writable,
-- and default to off. A flag never authorizes shipping an unfinished feature.
begin;

create table staygrubby.feature_flags (
 key text primary key check (key ~ '^[a-z][a-z0-9_]{1,62}$'),
 enabled boolean not null default false,
 audience text not null default 'everyone' check (audience in ('everyone','internal','beta')),
 description text not null default '' check (length(description)<=500),
 updated_at timestamptz not null default now()
);
alter table staygrubby.feature_flags enable row level security;
revoke all on staygrubby.feature_flags from public,anon,authenticated;

-- The flags on for this account. Cohort audiences resolve to off until a reviewed
-- membership model exists; adding one changes only this function.
create function staygrubby.feature_flag_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
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
  where f.enabled and f.audience='everyone'),'[]'::jsonb));
end $$;
revoke all on function staygrubby.feature_flag_api(text,jsonb) from public,anon;
grant execute on function staygrubby.feature_flag_api(text,jsonb) to authenticated;
create function api.feature_flags(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql stable security invoker set search_path='' as $$ select staygrubby.feature_flag_api(action,payload) $$;
revoke all on function api.feature_flags(text,jsonb) from public,anon;
grant execute on function api.feature_flags(text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
