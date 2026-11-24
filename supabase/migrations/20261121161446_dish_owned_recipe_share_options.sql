-- Extend the existing owner-authorized attachment lookup to the cook's Dish identity.
-- Depends on public MVP moderation. Hidden Recipes remain readable by their owners
-- but cannot be attached through a suggestion or an explicit Recipe ID.
-- No backfill, new tables, new grants or changes to accepted attachments.
begin;

create or replace function staygrubby.owned_recipe_share_option(payload jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=staygrubby.social_actor(); attempt uuid:=(payload->>'attemptID')::uuid;
 attempt_dish uuid; rid uuid; version integer; content jsonb; shareable boolean; historical boolean:=false;
begin
 if octet_length(payload::text)>60000 then raise exception 'Invalid request' using errcode='22023'; end if;
 perform 1 from staygrubby.accounts where id=actor and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from actor then raise exception 'Account unavailable' using errcode='42501'; end if;
 if payload->>'postID' is not null then
  select source_attempt_id into attempt from staygrubby.social_posts where id=(payload->>'postID')::uuid and author_id=actor and deleted_at is null;
 end if;
 select dish_id into attempt_dish from staygrubby.cooking_attempts where account_id=actor and id=attempt and deleted_at is null;
 if not found then raise exception 'Cook unavailable' using errcode='42501'; end if;
 select c.recipe_id,c.recipe_revision into rid,version from staygrubby.recipe_cooks c
 join staygrubby.recipes r on r.id=c.recipe_id and r.owner_id=actor
 where c.account_id=actor and c.attempt_id=attempt and c.completed_at is not null;
 historical:=found;
 if not historical then
  select r.id,r.revision into rid,version from staygrubby.recipe_cook_links l
  join staygrubby.recipes r on r.id=l.recipe_id and r.owner_id=actor
  where l.account_id=actor and l.attempt_id=attempt;
 end if;
 if not historical and rid is null then
  select r.id,r.revision into rid,version from staygrubby.dish_recipes l
  join staygrubby.recipes r on r.id=l.recipe_id and r.owner_id=actor
  where l.account_id=actor and l.dish_id=attempt_dish;
 end if;
 if rid is null then
  select r.id,r.revision into rid,version from staygrubby.recipes r
  where r.owner_id=actor and r.dish_id=attempt_dish;
 end if;
 if rid is null then return jsonb_build_object('recipe',null); end if;
 select v.content,r.moderation_state='active' into content,shareable from staygrubby.recipe_revisions v
 join staygrubby.recipes r on r.id=v.recipe_id
 where v.recipe_id=rid and v.revision=version;
 if shareable is distinct from true then return jsonb_build_object('recipe',null,'unavailable',true); end if;
 return jsonb_build_object('recipe',staygrubby.recipe_card(actor,rid)||jsonb_build_object('content',content,'revision',version),'fromCookSnapshot',historical);
end $$;
revoke all on function staygrubby.owned_recipe_share_option(jsonb) from public,anon,authenticated;

create or replace function staygrubby.share_post_recipe(actor uuid,pid uuid,rid uuid,version integer) returns void
language plpgsql volatile security definer set search_path='' as $$
declare r staygrubby.recipes%rowtype;
begin
 perform 1 from staygrubby.social_posts where id=pid and author_id=actor and deleted_at is null and moderation_state='active' for update;
 if not found then raise exception 'Post unavailable' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:recipe:'||rid::text,0));
 select * into r from staygrubby.recipes where id=rid and owner_id=actor for update;
 if staygrubby.social_actor() is distinct from actor or r.id is null or r.moderation_state<>'active'
  or not exists(select 1 from staygrubby.recipe_revisions where recipe_id=rid and revision=version)
 then raise exception 'Recipe unavailable' using errcode='42501'; end if;
 if exists(select 1 from staygrubby.post_recipes where post_id=pid) then
  if not exists(select 1 from staygrubby.post_recipes where post_id=pid and recipe_id=rid and recipe_revision=version)
  then raise exception 'Remove the existing attachment first' using errcode='PT409'; end if;
  return;
 end if;
 -- Explicit share consent enables current-friends Recipe visibility. Content stays exact.
 if r.visibility<>'friends' then
  update staygrubby.recipes set visibility='friends',revision=revision+1,updated_at=now() where id=rid;
 end if;
 insert into staygrubby.post_recipes(post_id,recipe_id,recipe_revision) values(pid,rid,version);
end $$;
revoke all on function staygrubby.share_post_recipe(uuid,uuid,uuid,integer) from public,anon,authenticated;

notify pgrst,'reload schema';
commit;
