-- Stage F (FOOD_ARCHITECTURE §5, §6.1): Food Bible filters Recipes by Diet as written.
-- Read path only: `library_index` entries gain the Recipe's own `dietary` codes (already
-- part of Recipe content visible to the viewer). No rows, ranking or content change.
begin;
alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_diet_index;
revoke all on function staygrubby.recipe_api_before_diet_index(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid; result jsonb;
begin
 result:=staygrubby.recipe_api_before_diet_index(action,payload);
 if action is distinct from 'library_index' or jsonb_typeof(result->'entries') is distinct from 'array' then return result; end if;
 actor:=staygrubby.social_actor();
 select jsonb_set(result,'{entries}',coalesce(jsonb_agg(
   case when r.id is not null and jsonb_typeof(r.content->'dietary')='array'
    then t.e||jsonb_build_object('dietary',r.content->'dietary') else t.e end order by t.ord),'[]'::jsonb))
 into result
 from jsonb_array_elements(result->'entries') with ordinality as t(e,ord)
 left join staygrubby.recipes r on r.id=(t.e->>'recipeID')::uuid and staygrubby.recipe_visible(actor,r.id);
 return result;
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
create or replace function api.recipes(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.recipe_api(action,payload) $$;
notify pgrst,'reload schema';
commit;
