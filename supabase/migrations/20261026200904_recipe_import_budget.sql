-- Only counters: no recipe text, prompts, outputs, tokens or provider credentials.
begin;
create table staygrubby.recipe_import_usage (
 bucket text not null,
 window_start timestamptz not null,
 account_id uuid references staygrubby.accounts(id) on delete cascade,
 attempts integer not null default 0 check (attempts >= 0),
 primary key (bucket, window_start)
);
alter table staygrubby.recipe_import_usage enable row level security;
revoke all on staygrubby.recipe_import_usage from public, anon, authenticated;

-- Only the authenticated Edge Function's server credential may reserve budget.
-- It passes a user verified by Auth, never an actor supplied by the app request.
create function api.reserve_recipe_import(p_user uuid, p_session uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
 actor uuid; day_start timestamptz := date_trunc('day', now() at time zone 'UTC') at time zone 'UTC';
 month_start timestamptz := date_trunc('month', now() at time zone 'UTC') at time zone 'UTC';
 minute_start timestamptz := date_trunc('minute', now());
 b text; w timestamptz; lim integer; i integer;
 buckets text[]; windows timestamptz[]; limits integer[] := array[1000,100,20,3];
begin
 select l.account_id into actor from staygrubby.auth_account_links l
 join staygrubby.accounts a on a.id=l.account_id
 join auth.users u on u.id=l.auth_user_id
 join auth.sessions s on s.user_id=u.id and s.id=p_session
 where l.auth_user_id=p_user and a.status='active' and u.deleted_at is null
 and not coalesce(u.is_anonymous,false) and (s.not_after is null or s.not_after>now());
 if actor is null then raise insufficient_privilege using message='Account unavailable'; end if;
 buckets := array['global-month','global-day',actor::text||'-day',actor::text||'-minute'];
 windows := array[month_start,day_start,day_start,minute_start];
 -- Fixed global-month first lock serializes reservations across isolates/devices.
 for i in 1..4 loop
  b:=buckets[i]; w:=windows[i]; lim:=limits[i];
  insert into staygrubby.recipe_import_usage(bucket,window_start,account_id)
   values(b,w,case when i>2 then actor else null end) on conflict do nothing;
  perform 1 from staygrubby.recipe_import_usage where bucket=b and window_start=w for update;
  if (select attempts from staygrubby.recipe_import_usage where bucket=b and window_start=w)>=lim then return false; end if;
 end loop;
 for i in 1..4 loop
  update staygrubby.recipe_import_usage set attempts=attempts+1 where bucket=buckets[i] and window_start=windows[i];
 end loop;
 -- Bounded metadata retention; global current-month ceiling survives cleanup.
 delete from staygrubby.recipe_import_usage where window_start<month_start-interval '1 month';
 return true;
end $$;
revoke all on function api.reserve_recipe_import(uuid,uuid) from public,anon,authenticated;
grant usage on schema api to service_role;
grant execute on function api.reserve_recipe_import(uuid,uuid) to service_role;
commit;
