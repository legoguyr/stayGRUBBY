-- D2 Unified Dish Detail (FOOD_ARCHITECTURE §6). Read path only: no table,
-- row, ranking or Recipe content changes. Food Bible cards name one Dish per
-- Recipe: the Dish whose Main Recipe it is, else the Dish of its exact-linked
-- cook, else the first related Dish by name. `cooked` says whether that Dish
-- has an active cook, so Recipe-only Dishes read as not cooked yet.
begin;

create function staygrubby.recipe_primary_dish(owner uuid,recipe uuid) returns uuid
language sql stable set search_path='' as $$
 select coalesce(
  (select d.id from staygrubby.dish_recipe_links l
    join staygrubby.dishes d on d.account_id=owner and d.id=l.dish_id and d.deleted_at is null
    where l.account_id=owner and l.recipe_id=recipe and staygrubby.dish_main_recipe(owner,d.id)=recipe
    order by d.name,d.id limit 1),
  (select d.id from staygrubby.recipe_cook_links l
    join staygrubby.cooking_attempts a on a.account_id=l.account_id and a.id=l.attempt_id and a.deleted_at is null
    join staygrubby.dishes d on d.account_id=owner and d.id=a.dish_id and d.deleted_at is null
    where l.account_id=owner and l.recipe_id=recipe limit 1),
  (select d.id from staygrubby.dish_recipe_links l
    join staygrubby.dishes d on d.account_id=owner and d.id=l.dish_id and d.deleted_at is null
    where l.account_id=owner and l.recipe_id=recipe order by d.name,d.id limit 1),
  (select d.id from staygrubby.dish_recipes l
    join staygrubby.dishes d on d.account_id=owner and d.id=l.dish_id and d.deleted_at is null
    where l.account_id=owner and l.recipe_id=recipe order by d.name,d.id limit 1))
$$;
revoke all on function staygrubby.recipe_primary_dish(uuid,uuid) from public,anon,authenticated;

alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_food_bible_dishes;
revoke all on function staygrubby.recipe_api_before_food_bible_dishes(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid; result jsonb;
begin
 result:=staygrubby.recipe_api_before_food_bible_dishes(action,payload);
 if action is distinct from 'library_index' or jsonb_typeof(result->'entries') is distinct from 'array' then return result; end if;
 -- The predecessor already authenticated the active actor for this call.
 actor:=staygrubby.social_actor();
 select jsonb_set(result,'{entries}',coalesce(jsonb_agg(
   e||jsonb_build_object(
    'dishID',coalesce(p.dish_id::text,e->>'dishID'),
    'dishTitle',coalesce(d.name,e->>'dishTitle'),
    'cooked',(e->>'linkedAttemptID') is not null or exists(
      select 1 from staygrubby.cooking_attempts a
      join staygrubby.ranked_items i on i.account_id=a.account_id and i.id=a.ranked_item_id and i.deleted_at is null
      where a.account_id=actor and a.dish_id=coalesce(p.dish_id,(e->>'dishID')::uuid) and a.deleted_at is null))
   order by t.ord),'[]'::jsonb))
 into result
 from jsonb_array_elements(result->'entries') with ordinality as t(e,ord)
 left join lateral (select staygrubby.recipe_primary_dish(actor,(t.e->>'recipeID')::uuid) dish_id) p on true
 left join staygrubby.dishes d on d.account_id=actor and d.id=p.dish_id and d.deleted_at is null;
 return result;
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
create or replace function api.recipes(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.recipe_api(action,payload) $$;
notify pgrst,'reload schema';
commit;
