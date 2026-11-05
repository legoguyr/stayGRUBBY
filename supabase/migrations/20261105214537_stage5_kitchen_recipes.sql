-- Bounded profile Recipe summaries. Existing Recipe visibility remains authoritative.
-- No data changes, new tables, grants to raw data or public Recipe catalog.
begin;
alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_stage5;
revoke all on function staygrubby.recipe_api_before_stage5(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=staygrubby.social_actor(); owner uuid:=coalesce((payload->>'peerID')::uuid,actor); result jsonb;
begin
 if action<>'profile_index' then return staygrubby.recipe_api_before_stage5(action,payload); end if;
 if octet_length(payload::text)>60000 then raise exception 'Invalid request' using errcode='22023'; end if;
 perform 1 from staygrubby.accounts where id=actor and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from actor then raise exception 'Account unavailable' using errcode='42501'; end if;
 select coalesce(jsonb_agg(card order by id),'[]'::jsonb) into result from (
  select r.id,jsonb_build_object('recipeID',r.id,'recipeTitle',r.content->>'title','dishTitle',r.content->>'title',
   'dishID',coalesce(a.dish_id,old.dish_id),'linkedAttemptID',l.attempt_id,
   'course',r.content->>'course','cuisine',r.content->>'cuisine','revision',r.revision,
   'createdAt',extract(epoch from r.created_at),'updatedAt',extract(epoch from r.updated_at),
   'yield',r.content->>'yield','prepMinutes',r.content->'prepMinutes','cookMinutes',r.content->'cookMinutes',
   'elapsedMinutes',r.content->'elapsedMinutes','creatorMetadata',r.content ? 'metadataOrigins',
   'photoID',r.content->>'photoID','source',r.content->>'source') card
  from staygrubby.recipes r
  left join staygrubby.recipe_cook_links l on actor=owner and l.account_id=actor and l.recipe_id=r.id
  left join staygrubby.cooking_attempts a on a.account_id=actor and a.id=l.attempt_id and a.deleted_at is null
  left join lateral (select x.dish_id from staygrubby.dish_recipes x join staygrubby.dishes d on d.account_id=actor and d.id=x.dish_id and d.deleted_at is null
   where actor=owner and x.account_id=actor and x.recipe_id=r.id and l.attempt_id is null order by x.created_at,x.dish_id limit 1) old on true
  where r.owner_id=owner and staygrubby.recipe_visible(actor,r.id)
   and (payload->>'beforeID' is null or r.id>(payload->>'beforeID')::uuid)
  order by r.id limit 25) page;
 return jsonb_build_object('entries',result);
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
create or replace function api.recipes(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.recipe_api(action,payload) $$;
notify pgrst,'reload schema';
commit;
