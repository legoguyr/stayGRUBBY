-- Explicitly authorized development identity, not an application login path.
-- No public issuer, passwords, email-provider changes, or arbitrary user targets.
begin;
create schema development;
revoke all on schema development from public,anon,authenticated,service_role;
create table development.recipe_test_identity (
 singleton boolean primary key default true check(singleton),
 auth_user_id uuid unique references auth.users(id) on delete set null
);
insert into development.recipe_test_identity(singleton) values(true);
create table development.recipe_test_login (
 id uuid primary key,
 proof_hash text not null check(proof_hash ~ '^[0-9a-f]{64}$'),
 expires_at timestamptz not null default (now()+interval '5 minutes'),
 consumed_at timestamptz
);
alter table development.recipe_test_identity enable row level security;
alter table development.recipe_test_login enable row level security;
revoke all on all tables in schema development from public,anon,authenticated,service_role;

-- Only a project administrator/owner connection can issue a capability.
-- The random 256-bit preimage remains on the developer's machine, never in SQL.
create function development.issue_recipe_test_login(p_id uuid,p_hash text) returns void
language sql security invoker set search_path='' as $$
 insert into development.recipe_test_login(id,proof_hash) values(p_id,p_hash);
$$;
revoke all on function development.issue_recipe_test_login(uuid,text) from public,anon,authenticated,service_role;

-- Definers are necessary to keep both tables unexposed and inaccessible to
-- ordinary clients. EXECUTE is service-role only; neither accepts a real target.
create function api.consume_recipe_test_login(p_id uuid,p_hash text) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 update development.recipe_test_login set consumed_at=clock_timestamp()
 where id=p_id and proof_hash=p_hash and consumed_at is null and expires_at>clock_timestamp();
 if not found then raise insufficient_privilege using message='Development authorization unavailable';end if;
 return (select jsonb_build_object('userID',auth_user_id) from development.recipe_test_identity where singleton);
end $$;
create function api.bind_recipe_test_identity(p_request uuid,p_user uuid) returns void
language plpgsql security definer set search_path='' as $$
declare existing uuid;
begin
 if not exists(select 1 from development.recipe_test_login where id=p_request and consumed_at is not null and expires_at>clock_timestamp())
 or not exists(select 1 from auth.users u where u.id=p_user and not u.is_anonymous and u.deleted_at is null
   and to_jsonb(u)->>'email'='recipe-validation@staygrubby.invalid'
   and to_jsonb(u)->'raw_app_meta_data'->>'staygrubby_development_identity'='recipe-validation')
 then raise insufficient_privilege using message='Development identity unavailable';end if;
 select auth_user_id into existing from development.recipe_test_identity where singleton for update;
 if existing is not null and existing<>p_user then raise insufficient_privilege using message='Development identity mismatch';end if;
 update development.recipe_test_identity set auth_user_id=p_user where singleton;
end $$;
revoke all on function api.consume_recipe_test_login(uuid,text),api.bind_recipe_test_identity(uuid,uuid) from public,anon,authenticated;
grant execute on function api.consume_recipe_test_login(uuid,text),api.bind_recipe_test_identity(uuid,uuid) to service_role;
commit;
