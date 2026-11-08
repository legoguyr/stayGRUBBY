-- Finalize the existing reservation in the same transaction as the synced cook.
-- Retire current links when a cook is deleted, independently of its frozen snapshot.
begin;

create function staygrubby.reconcile_recipe_cook() returns trigger
language plpgsql set search_path='' as $$
declare source_recipe uuid;
begin
 if tg_op='UPDATE' then
  delete from staygrubby.recipe_cook_links where account_id=new.account_id and attempt_id=new.id;
  return new;
 end if;
 -- Take the Recipe lock before changing its reservation so source deletion
 -- can finish its FK updates without competing for locks in the reverse order.
 select r.id into source_recipe from staygrubby.recipe_cooks c
 join staygrubby.recipes r on r.id=c.recipe_id
 where c.account_id=new.account_id and c.item_id=new.ranked_item_id and c.completed_at is null
  and staygrubby.recipe_visible(new.account_id,r.id)
 for key share of r;
 update staygrubby.recipe_cooks
 set attempt_id=new.id,completed_at=statement_timestamp()
 where account_id=new.account_id and item_id=new.ranked_item_id and completed_at is null;
 -- A new explicit Recipe-origin cook can fill an empty current link.
 -- Revocation/deletion leaves the private snapshot intact without exposing the source.
 if found and source_recipe is not null then
  insert into staygrubby.recipe_cook_links(account_id,recipe_id,attempt_id)
  values(new.account_id,source_recipe,new.id) on conflict do nothing;
 end if;
 return new;
end $$;
revoke all on function staygrubby.reconcile_recipe_cook() from public,anon,authenticated;

create trigger reconcile_recipe_cook_insert after insert on staygrubby.cooking_attempts
 for each row when (new.deleted_at is null) execute function staygrubby.reconcile_recipe_cook();
create trigger retire_recipe_cook_link after update of deleted_at on staygrubby.cooking_attempts
 for each row when (old.deleted_at is null and new.deleted_at is not null) execute function staygrubby.reconcile_recipe_cook();

-- Repair only provable matches. The original completion time is unknown.
-- Existing complete snapshots, chosen live links, and family links are preserved.
update staygrubby.recipe_cooks c set attempt_id=a.id,completed_at=statement_timestamp()
from staygrubby.cooking_attempts a
where c.completed_at is null and a.account_id=c.account_id
 and a.ranked_item_id=c.item_id and a.deleted_at is null;
delete from staygrubby.recipe_cook_links l using staygrubby.cooking_attempts a
where a.account_id=l.account_id and a.id=l.attempt_id and a.deleted_at is not null;

-- Existing app builds still send the completion RPC. Keep its owner-scoped
-- acknowledgement, but retries may never recreate a removed association.
alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_cook_lifecycle;
revoke all on function staygrubby.recipe_api_before_cook_lifecycle(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid;
begin
 if action is distinct from 'complete' then
  return staygrubby.recipe_api_before_cook_lifecycle(action,payload);
 end if;
 if octet_length(payload::text)>60000 then raise exception 'Invalid request' using errcode='22023'; end if;
 actor:=staygrubby.social_actor();
 perform 1 from staygrubby.accounts where id=actor and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from actor then
  raise exception 'Account unavailable' using errcode='42501';
 end if;
 if not exists(select 1 from staygrubby.recipe_cooks where id=(payload->>'originID')::uuid and account_id=actor) then
  raise exception 'Recipe origin unavailable' using errcode='42501';
 end if;
 if not exists(select 1 from staygrubby.recipe_cooks c
  join staygrubby.cooking_attempts a on a.account_id=c.account_id and a.id=c.attempt_id
   and a.ranked_item_id=c.item_id and a.deleted_at is null
  where c.id=(payload->>'originID')::uuid and c.account_id=actor and c.completed_at is not null) then
  raise exception 'Wait for cooking sync' using errcode='40001';
 end if;
 return '{}'::jsonb;
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
create or replace function api.recipes(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.recipe_api(action,payload) $$;
notify pgrst,'reload schema';
commit;
