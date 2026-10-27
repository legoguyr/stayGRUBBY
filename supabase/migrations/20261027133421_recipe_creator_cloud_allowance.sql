-- Extend the existing attempt budget with five successful cloud formats per UTC day.
-- No recipe text, provider output, client tokens or credentials are stored here.
begin;
alter table staygrubby.recipe_import_usage add column successes integer not null default 0 check(successes>=0);
create table staygrubby.recipe_import_reservations (
 id uuid primary key,
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 day_start timestamptz not null,
 expires_at timestamptz not null,
 state text not null default 'pending' check(state in('pending','succeeded','failed','expired'))
);
create index recipe_import_pending on staygrubby.recipe_import_reservations(account_id,day_start,expires_at) where state='pending';
alter table staygrubby.recipe_import_reservations enable row level security;
revoke all on staygrubby.recipe_import_reservations from public,anon,authenticated;

create function staygrubby.recipe_import_actor(p_user uuid,p_session uuid) returns uuid
language sql volatile security definer set search_path='' as $$
 select a.id from staygrubby.auth_account_links l
 join staygrubby.accounts a on a.id=l.account_id
 join auth.users u on u.id=l.auth_user_id
 join auth.sessions s on s.user_id=u.id and s.id=p_session
 where l.auth_user_id=p_user and a.status='active' and u.deleted_at is null
 and not coalesce(u.is_anonymous,false) and (s.not_after is null or s.not_after>now())
$$;
revoke all on function staygrubby.recipe_import_actor(uuid,uuid) from public,anon,authenticated;
create function api.begin_recipe_import(p_user uuid,p_session uuid,p_request uuid) returns text
language plpgsql security definer set search_path='' as $$
declare actor uuid:=staygrubby.recipe_import_actor(p_user,p_session);
 d timestamptz:=date_trunc('day',now() at time zone 'UTC') at time zone 'UTC'; n integer; pending integer;
begin
 if actor is null or p_request is null then raise insufficient_privilege using message='Account unavailable'; end if;
 -- Reuse existing global/account attempt caps and their fixed lock order.
 if not api.reserve_recipe_import(p_user,p_session) then return 'attempt_limit'; end if;
 select successes into n from staygrubby.recipe_import_usage where bucket=actor::text||'-day' and window_start=d for update;
 if staygrubby.recipe_import_actor(p_user,p_session) is distinct from actor then raise insufficient_privilege using message='Account unavailable';end if;
 if n>=5 then return 'daily_limit'; end if;
 select count(*) into pending from staygrubby.recipe_import_reservations where account_id=actor and day_start=d and state='pending' and expires_at>now();
 if n+pending>=5 then return 'attempt_limit'; end if;
 insert into staygrubby.recipe_import_reservations(id,account_id,day_start,expires_at) values(p_request,actor,d,now()+interval '120 seconds');
 delete from staygrubby.recipe_import_reservations where day_start<d-interval '2 days';
 return 'allowed';
end $$;
create function api.finish_recipe_import(p_user uuid,p_session uuid,p_request uuid,p_success boolean) returns boolean
language plpgsql security definer set search_path='' as $$
declare actor uuid:=staygrubby.recipe_import_actor(p_user,p_session); receipt staygrubby.recipe_import_reservations%rowtype;
begin
 if actor is null then raise insufficient_privilege using message='Account unavailable'; end if;
 select * into receipt from staygrubby.recipe_import_reservations where id=p_request and account_id=actor;
 if not found then return false; end if;
 -- Account-day before receipt: the same order used by begin and all finish calls.
 perform 1 from staygrubby.recipe_import_usage where bucket=actor::text||'-day' and window_start=receipt.day_start for update;
 select * into receipt from staygrubby.recipe_import_reservations where id=p_request and account_id=actor for update;
 if staygrubby.recipe_import_actor(p_user,p_session) is distinct from actor then raise insufficient_privilege using message='Account unavailable';end if;
 if receipt.state='succeeded' then return p_success; end if;
 if receipt.state<>'pending' then return not p_success; end if;
 if receipt.expires_at<=now() then
  update staygrubby.recipe_import_reservations set state='expired' where id=p_request;return false;
 end if;
 update staygrubby.recipe_import_reservations set state=case when p_success then 'succeeded' else 'failed' end where id=p_request;
 if p_success then update staygrubby.recipe_import_usage set successes=successes+1 where bucket=actor::text||'-day' and window_start=receipt.day_start;end if;
 return true;
end $$;
revoke all on function api.begin_recipe_import(uuid,uuid,uuid),api.finish_recipe_import(uuid,uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function api.begin_recipe_import(uuid,uuid,uuid),api.finish_recipe_import(uuid,uuid,uuid,boolean) to service_role;
commit;
