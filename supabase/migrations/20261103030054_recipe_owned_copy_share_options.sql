-- A foreign historical cook snapshot must not hide a separately owned linked copy.
-- Preserve both the deployed integration migration and every existing snapshot.
begin;
create function staygrubby.owned_recipe_share_option(payload jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=staygrubby.social_actor(); attempt uuid:=(payload->>'attemptID')::uuid;
 rid uuid; version integer; content jsonb; historical boolean:=false;
begin
 if octet_length(payload::text)>60000 then raise exception 'Invalid request' using errcode='22023'; end if;
 perform 1 from staygrubby.accounts where id=actor and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from actor then raise exception 'Account unavailable' using errcode='42501'; end if;
 if payload->>'postID' is not null then
  select source_attempt_id into attempt from staygrubby.social_posts where id=(payload->>'postID')::uuid and author_id=actor and deleted_at is null;
 end if;
 if not exists(select 1 from staygrubby.cooking_attempts where account_id=actor and id=attempt and deleted_at is null)
 then raise exception 'Cook unavailable' using errcode='42501'; end if;
 select c.recipe_id,c.recipe_revision into rid,version from staygrubby.recipe_cooks c
 join staygrubby.recipes r on r.id=c.recipe_id and r.owner_id=actor
 where c.account_id=actor and c.attempt_id=attempt and c.completed_at is not null;
 historical:=found;
 if not historical then
  select r.id,r.revision into rid,version from staygrubby.dish_recipes l
  join staygrubby.cooking_attempts a on a.account_id=actor and a.dish_id=l.dish_id and a.id=attempt
  join staygrubby.recipes r on r.id=l.recipe_id and r.owner_id=actor
  where l.account_id=actor;
 end if;
 if rid is null then return jsonb_build_object('recipe',null); end if;
 select v.content into content from staygrubby.recipe_revisions v where v.recipe_id=rid and v.revision=version;
 return jsonb_build_object('recipe',staygrubby.recipe_card(actor,rid)||jsonb_build_object('content',content,'revision',version),'fromCookSnapshot',historical);
end $$;
revoke all on function staygrubby.owned_recipe_share_option(jsonb) from public,anon,authenticated;
alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_owned_copy_options;
revoke all on function staygrubby.recipe_api_before_owned_copy_options(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
begin
 if action='share_options' then return staygrubby.owned_recipe_share_option(payload); end if;
 return staygrubby.recipe_api_before_owned_copy_options(action,payload);
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
create or replace function api.recipes(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.recipe_api(action,payload) $$;
notify pgrst,'reload schema';
commit;
