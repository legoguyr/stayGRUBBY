-- Food Bible membership enriches existing cooked Dishes, never creates cooking/ranking.
begin;
create table staygrubby.dish_recipes (
 account_id uuid not null references staygrubby.accounts(id) on delete cascade,
 dish_id uuid not null, recipe_id uuid not null references staygrubby.recipes(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(account_id,dish_id),
 foreign key(account_id,dish_id) references staygrubby.dishes(account_id,id) on delete cascade
);
create index dish_recipes_recipe on staygrubby.dish_recipes(recipe_id);
create table staygrubby.recipe_revisions (
 recipe_id uuid not null references staygrubby.recipes(id) on delete cascade,
 revision integer not null, content jsonb not null, created_at timestamptz not null default now(),
 primary key(recipe_id,revision)
);
alter table staygrubby.dish_recipes enable row level security;
alter table staygrubby.recipe_revisions enable row level security;
revoke all on staygrubby.dish_recipes,staygrubby.recipe_revisions from public,anon,authenticated;
-- Preserve current legacy content byte-for-byte; no guessed associations by title.
insert into staygrubby.recipe_revisions(recipe_id,revision,content,created_at) select id,revision,content,updated_at from staygrubby.recipes;
insert into staygrubby.dish_recipes(account_id,dish_id,recipe_id)
 select distinct on(c.account_id,a.dish_id) c.account_id,a.dish_id,c.recipe_id
 from staygrubby.recipe_cooks c join staygrubby.cooking_attempts a on a.account_id=c.account_id and a.id=c.attempt_id and a.deleted_at is null
 join staygrubby.dishes d on d.account_id=a.account_id and d.id=a.dish_id and d.deleted_at is null
 where c.completed_at is not null and c.recipe_id is not null and staygrubby.recipe_visible(c.account_id,c.recipe_id)
 order by c.account_id,a.dish_id,c.completed_at desc,c.created_at desc,c.id;
create function staygrubby.archive_recipe_revision() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into staygrubby.recipe_revisions(recipe_id,revision,content) values(new.id,new.revision,new.content);
 return new;
end $$;
revoke all on function staygrubby.archive_recipe_revision() from public,anon,authenticated;
create trigger archive_recipe_revision after insert or update on staygrubby.recipes for each row execute function staygrubby.archive_recipe_revision();

-- A viewer only receives their own durable Dish association, never another cook's private IDs.
create or replace function staygrubby.recipe_card(viewer uuid,recipe uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',r.id,'isOwner',r.owner_id=viewer,'creator',staygrubby.social_person(viewer,r.owner_id),'content',r.content,
 'visibility',r.visibility,'revision',r.revision,'createdAt',extract(epoch from r.created_at),'updatedAt',extract(epoch from r.updated_at),
 'saved',exists(select 1 from staygrubby.recipe_tickets t where t.account_id=viewer and t.recipe_id=r.id),
 'linkedDishID',(select d.id from staygrubby.dish_recipes l join staygrubby.dishes d on d.account_id=viewer and d.id=l.dish_id and d.deleted_at is null
   where l.account_id=viewer and l.recipe_id=r.id order by l.created_at,d.id limit 1))
 from staygrubby.recipes r where r.id=recipe and staygrubby.recipe_visible(viewer,r.id)
$$;
revoke all on function staygrubby.recipe_card(uuid,uuid) from public,anon,authenticated;

alter function staygrubby.recipe_content(jsonb) rename to recipe_content_before_components;
revoke all on function staygrubby.recipe_content_before_components(jsonb) from public,anon,authenticated;
create function staygrubby.recipe_content(value jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare clean jsonb; component jsonb; row jsonb; components jsonb:='[]'; ingredients jsonb; steps jsonb;
 ingredient_rows jsonb; step_rows jsonb; ids text[]:='{}'; rid text; n integer:=0; i integer; j integer; field text;
begin
 foreach field in array array['title','description','course','cuisine','source','externalURL'] loop
  if value ? field and jsonb_typeof(value->field) not in('string','null') then raise exception 'Invalid recipe text' using errcode='22023'; end if;
 end loop;
 -- Retain the legacy wire arrays for old readers; structured components are authoritative.
 if value ? 'components' then
  if jsonb_typeof(value->'components') is distinct from 'array' or jsonb_array_length(value->'components') not between 1 and 20 then raise exception 'Invalid recipe components' using errcode='22023'; end if;
  ingredients:='[]'; steps:='[]';
  i:=0;
  for component in select x from jsonb_array_elements(value->'components') x loop
   rid:=lower(component->>'id');
   if jsonb_typeof(component) is distinct from 'object' or rid is null or rid !~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' or rid=any(ids)
    or (component ? 'title' and jsonb_typeof(component->'title') not in('string','null')) or length(coalesce(component->>'title',''))>120
    or jsonb_typeof(component->'ingredients') is distinct from 'array' or jsonb_typeof(component->'steps') is distinct from 'array'
    or jsonb_array_length(component->'ingredients')>100 or jsonb_array_length(component->'steps')>100 then raise exception 'Invalid component' using errcode='22023'; end if;
   ids:=array_append(ids,rid); ingredient_rows:='[]'; step_rows:='[]'; j:=0;
   for row in select x from jsonb_array_elements(component->'ingredients') x loop
    rid:=lower(row->>'id'); n:=n+1;
    if jsonb_typeof(row) is distinct from 'object' or rid is null or rid !~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' or rid=any(ids)
     or jsonb_typeof(row->'name') is distinct from 'string' or length(btrim(coalesce(row->>'name',''))) not between 1 and 500 then raise exception 'Invalid ingredient' using errcode='22023'; end if;
    foreach field in array array['quantity','unit','preparation','note'] loop
     if row ? field and (jsonb_typeof(row->field) not in('string','null') or length(coalesce(row->>field,''))>500) then raise exception 'Invalid ingredient field' using errcode='22023'; end if;
    end loop;
    ids:=array_append(ids,rid);
    ingredient_rows:=ingredient_rows||jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('id',rid,'order',j,'name',btrim(row->>'name'),'quantity',row->>'quantity','unit',row->>'unit','preparation',row->>'preparation','note',row->>'note')));
    ingredients:=ingredients||jsonb_build_array(concat_ws(' ',nullif(row->>'quantity',''),nullif(row->>'unit',''),row->>'name',nullif(row->>'preparation',''),nullif(row->>'note',''))); j:=j+1;
   end loop;
   j:=0;
   for row in select x from jsonb_array_elements(component->'steps') x loop
    rid:=lower(row->>'id'); n:=n+1;
    if jsonb_typeof(row) is distinct from 'object' or rid is null or rid !~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' or rid=any(ids)
     or jsonb_typeof(row->'instruction') is distinct from 'string' or length(btrim(coalesce(row->>'instruction',''))) not between 1 and 2000 then raise exception 'Invalid step' using errcode='22023'; end if;
    ids:=array_append(ids,rid); step_rows:=step_rows||jsonb_build_array(jsonb_build_object('id',rid,'order',j,'instruction',btrim(row->>'instruction')));
    steps:=steps||jsonb_build_array(btrim(row->>'instruction')); j:=j+1;
   end loop;
   components:=components||jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('id',lower(component->>'id'),'title',nullif(btrim(component->>'title'),''),'order',i,'ingredients',ingredient_rows,'steps',step_rows))); i:=i+1;
  end loop;
  if n>200 then raise exception 'Recipe has too many rows' using errcode='22023'; end if;
  -- Existing legacy arrays are capped at 100 each, keeping old clients safe to read.
  value:=jsonb_set(jsonb_set(value,'{ingredients}',ingredients),'{steps}',steps);
 end if;
 clean:=staygrubby.recipe_content_before_components(value);
 if value ? 'components' then clean:=clean||jsonb_build_object('components',components); end if;
 foreach field in array array['yield','tips','originalCreator'] loop
  if value ? field then
   if jsonb_typeof(value->field) not in('string','null') or length(coalesce(value->>field,''))>(case when field='tips' then 4000 else 500 end) then raise exception 'Invalid recipe metadata' using errcode='22023'; end if;
   clean:=clean||jsonb_strip_nulls(jsonb_build_object(field,value->>field));
  end if;
 end loop;
 foreach field in array array['prepMinutes','cookMinutes'] loop
  if value ? field and value->field<>'null'::jsonb then
   if jsonb_typeof(value->field)<>'number' or (value->>field)::numeric not between 0 and 10080 or trunc((value->>field)::numeric)<>(value->>field)::numeric then raise exception 'Invalid time' using errcode='22023'; end if;
   clean:=clean||jsonb_build_object(field,(value->>field)::integer);
  end if;
 end loop;
 return clean;
end $$;
revoke all on function staygrubby.recipe_content(jsonb) from public,anon,authenticated;

alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_food_bible;
revoke all on function staygrubby.recipe_api_before_food_bible(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare owner uuid:=staygrubby.social_actor(); rid uuid:=(payload->>'recipeID')::uuid; did uuid:=(payload->>'dishID')::uuid;
 result jsonb; prior uuid; recipe staygrubby.recipes%rowtype; claim staygrubby.recipe_cooks%rowtype;
begin
 if octet_length(payload::text)>60000 then raise exception 'Invalid request' using errcode='22023'; end if;
 perform 1 from staygrubby.accounts where id=owner and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from owner then raise exception 'Account unavailable' using errcode='42501'; end if;
 if action='cookbook' then
  -- Compact summaries only: no recipe bodies, revisions, notes or private remote photos.
  select coalesce(jsonb_agg(card order by id),'[]'::jsonb) into result from (
   select d.id,jsonb_build_object('dishID',d.id,'recipeID',r.id,'dishTitle',d.name,'recipeTitle',r.content->>'title',
    'course',coalesce(r.content->>'course',d.default_course_code),'cuisine',coalesce(r.content->>'cuisine',d.cuisine->>'label'),'revision',r.revision) card
   from staygrubby.dish_recipes l join staygrubby.dishes d on d.account_id=owner and d.id=l.dish_id and d.deleted_at is null
   join staygrubby.recipes r on r.id=l.recipe_id
   where l.account_id=owner and staygrubby.recipe_visible(owner,r.id)
    and exists(select 1 from staygrubby.cooking_attempts a join staygrubby.ranked_items i on i.account_id=a.account_id and i.id=a.ranked_item_id and i.deleted_at is null
      where a.account_id=owner and a.dish_id=d.id and a.deleted_at is null)
    and (payload->>'beforeID' is null or d.id>(payload->>'beforeID')::uuid)
    and (coalesce(payload->>'query','')='' or position(lower(payload->>'query') in lower(d.name||' '||(r.content->>'title')))>0)
    and (coalesce(payload->>'course','')='' or coalesce(r.content->>'course',d.default_course_code)=payload->>'course')
    and (coalesce(payload->>'cuisine','')='' or lower(coalesce(r.content->>'cuisine',d.cuisine->>'label',''))=lower(payload->>'cuisine'))
   order by d.id limit 50
  ) page;
  return jsonb_build_object('entries',result);
 elsif action='dish' then
  select l.recipe_id into rid from staygrubby.dish_recipes l join staygrubby.dishes d on d.account_id=l.account_id and d.id=l.dish_id and d.deleted_at is null where l.account_id=owner and l.dish_id=did;
  return jsonb_build_object('recipe',staygrubby.recipe_card(owner,rid));
 elsif action='revision' then
  if not exists(select 1 from staygrubby.recipes r where r.id=rid and r.owner_id=owner) then raise exception 'Recipe unavailable' using errcode='42501'; end if;
  select jsonb_build_object('content',v.content,'revision',v.revision) into result from staygrubby.recipe_revisions v where v.recipe_id=rid and v.revision=(payload->>'expectedRevision')::integer;
  return coalesce(result,'{}');
 elsif action in('attach','detach') or (action='save' and did is not null) then
  -- Only the actor's already-synced cooked Dish may be linked. This never writes that graph.
  perform 1 from staygrubby.dishes d where d.account_id=owner and d.id=did and d.deleted_at is null for share;
  if not found or not exists(select 1 from staygrubby.cooking_attempts a where a.account_id=owner and a.dish_id=did and a.deleted_at is null) then raise exception 'Wait for cooking sync' using errcode='40001'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:dish-recipe:'||owner::text||did::text,0));
  select recipe_id into prior from staygrubby.dish_recipes where account_id=owner and dish_id=did;
  if action='detach' then
   if prior is distinct from rid then raise exception 'Recipe link changed; reload' using errcode='40001'; end if;
   delete from staygrubby.dish_recipes where account_id=owner and dish_id=did; return '{}';
  end if;
  if prior is not null and prior is distinct from rid then raise exception 'Dish already has a recipe; remove its link first' using errcode='40001'; end if;
 end if;
 if action='save' then
  select * into recipe from staygrubby.recipes where id=rid;
  if recipe.content ? 'components' and not (payload->'recipe' ? 'components') then raise exception 'Update the app to edit this structured recipe' using errcode='40001'; end if;
 end if;
 if action='attach' then
  if not staygrubby.recipe_visible(owner,rid) then raise exception 'Recipe unavailable' using errcode='42501'; end if;
  result:=staygrubby.recipe_card(owner,rid);
 else
  result:=staygrubby.recipe_api_before_food_bible(action,payload);
 end if;
 if action='attach' or (action='save' and did is not null) then
  insert into staygrubby.dish_recipes(account_id,dish_id,recipe_id) values(owner,did,rid) on conflict do nothing;
 elsif action='complete' then
  select * into claim from staygrubby.recipe_cooks where id=(payload->>'originID')::uuid and account_id=owner and completed_at is not null;
  select a.dish_id into did from staygrubby.cooking_attempts a where a.account_id=owner and a.id=claim.attempt_id and a.deleted_at is null;
  if did is not null and staygrubby.recipe_visible(owner,claim.recipe_id) then
   perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:dish-recipe:'||owner::text||did::text,0));
   insert into staygrubby.dish_recipes(account_id,dish_id,recipe_id) values(owner,did,claim.recipe_id) on conflict do nothing;
  end if;
 end if;
 return result;
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
-- Rebind the exposed wrapper after renaming the predecessor.
create or replace function api.recipes(action text,payload jsonb default '{}'::jsonb) returns jsonb language sql volatile security invoker set search_path='' as $$ select staygrubby.recipe_api(action,payload) $$;
revoke all on function api.recipes(text,jsonb) from public,anon;
grant execute on function api.recipes(text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
