-- Additive, read-only cookbook summaries for local search. No table/data or Ticket changes.
begin;
alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_search_index;
revoke all on function staygrubby.recipe_api_before_search_index(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid; result jsonb;
begin
 if action is distinct from 'cookbook_index' then return staygrubby.recipe_api_before_search_index(action,payload); end if;
 owner:=staygrubby.social_actor();
 if octet_length(payload::text)>4096 then raise exception 'Invalid request' using errcode='22023'; end if;
 perform 1 from staygrubby.accounts where id=owner and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from owner then raise exception 'Account unavailable' using errcode='42501'; end if;
 select coalesce(jsonb_agg(card order by id),'[]'::jsonb) into result from (
  select d.id,jsonb_build_object('dishID',d.id,'recipeID',r.id,'dishTitle',d.name,'recipeTitle',r.content->>'title',
   'course',coalesce(r.content->>'course',d.default_course_code),'cuisine',coalesce(r.content->>'cuisine',d.cuisine->>'label'),
   'revision',r.revision,'updatedAt',extract(epoch from r.updated_at),'yield',r.content->>'yield',
   'prepMinutes',r.content->'prepMinutes','cookMinutes',r.content->'cookMinutes','source',r.content->>'source',
   'searchText',concat_ws(' ',d.name,r.content->>'title',r.content->>'cuisine',d.cuisine->>'label',r.content->>'source',r.content->>'originalCreator',
     (select string_agg(value,' ') from jsonb_array_elements_text(coalesce(r.content->'ingredients','[]'::jsonb))))) card
  from staygrubby.dish_recipes l join staygrubby.dishes d on d.account_id=owner and d.id=l.dish_id and d.deleted_at is null
  join staygrubby.recipes r on r.id=l.recipe_id
  where l.account_id=owner and staygrubby.recipe_visible(owner,r.id)
   and exists(select 1 from staygrubby.cooking_attempts a join staygrubby.ranked_items i on i.account_id=a.account_id and i.id=a.ranked_item_id and i.deleted_at is null where a.account_id=owner and a.dish_id=d.id and a.deleted_at is null)
   and (payload->>'beforeID' is null or d.id>(payload->>'beforeID')::uuid)
  order by d.id limit 50
 ) page;
 return jsonb_build_object('entries',result);
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
commit;
