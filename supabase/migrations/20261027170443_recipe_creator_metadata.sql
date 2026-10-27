-- Optional Recipe-revision metadata only. No Dish/attempt/tag/ranking migration.
begin;
alter function staygrubby.recipe_content(jsonb) rename to recipe_content_before_creator;
revoke all on function staygrubby.recipe_content_before_creator(jsonb) from public,anon,authenticated;
create function staygrubby.recipe_content(value jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare clean jsonb:=staygrubby.recipe_content_before_creator(value); a jsonb; x jsonb; k text; v jsonb;
 codes text[]:=array['peanuts','treeNuts','sesame','milk','egg','wheat','soy','fish','shellfish'];
begin
 if value ? 'elapsedMinutes' and value->'elapsedMinutes'<>'null'::jsonb then
  v:=value->'elapsedMinutes';
  if jsonb_typeof(v)<>'number' or (v::text)::numeric not between 0 and 10080 or trunc((v::text)::numeric)<>(v::text)::numeric then raise exception 'Invalid elapsed time' using errcode='22023';end if;
  if (v::text)::integer<greatest(coalesce((clean->>'prepMinutes')::integer,0),coalesce((clean->>'cookMinutes')::integer,0)) then raise exception 'Invalid elapsed workflow' using errcode='22023';end if;
  clean:=clean||jsonb_build_object('elapsedMinutes',(v::text)::integer);
 end if;
 if value ? 'metadataOrigins' and value->'metadataOrigins'<>'null'::jsonb then
  v:=value->'metadataOrigins';
  if jsonb_typeof(v)<>'object' then raise exception 'Invalid origins' using errcode='22023';end if;
  for k,x in select key,val from jsonb_each(v) as e(key,val) loop
   if k not in('yield','prepMinutes','cookMinutes','totalMinutes','cuisine') or jsonb_typeof(x)<>'string' or (x#>>'{}') not in('provided','derived','estimated','unknown') then raise exception 'Invalid origin' using errcode='22023';end if;
  end loop;
  clean:=clean||jsonb_build_object('metadataOrigins',v);
 end if;
 if value ? 'allergens' and value->'allergens'<>'null'::jsonb then
  a:=value->'allergens';
  if jsonb_typeof(a)<>'object' or exists(select 1 from jsonb_object_keys(a) as fields(key) where fields.key not in('contains','possible','reviewIngredients')) then raise exception 'Invalid allergen information' using errcode='22023';end if;
  foreach k in array array['contains','possible','reviewIngredients'] loop
   v:=a->k;
   if jsonb_typeof(v) is distinct from 'array' or jsonb_array_length(v)>(case when k='reviewIngredients' then 100 else 9 end) then raise exception 'Invalid allergen list' using errcode='22023';end if;
   for x in select item from jsonb_array_elements(v) item loop
    if jsonb_typeof(x)<>'string' or length(x#>>'{}')>500 or (k<>'reviewIngredients' and not ((x#>>'{}')=any(codes))) then raise exception 'Invalid allergen code' using errcode='22023';end if;
   end loop;
  end loop;
  clean:=clean||jsonb_build_object('allergens',a);
 end if;
 if octet_length(clean::text)>40000 then raise exception 'Recipe too large' using errcode='22023';end if;
 return clean;
end $$;
revoke all on function staygrubby.recipe_content(jsonb) from public,anon,authenticated;
-- Add elapsed time to the already-authorized compact cookbook cards. No new
-- discovery, Recipe/Dish relationship or filtering behavior.
alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_creator_metadata;
revoke all on function staygrubby.recipe_api_before_creator_metadata(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare result jsonb; cards jsonb;
begin
 result:=staygrubby.recipe_api_before_creator_metadata(action,payload);
 if action='cookbook_index' then
  select coalesce(jsonb_agg(e.value||jsonb_strip_nulls(jsonb_build_object('elapsedMinutes',r.content->'elapsedMinutes','creatorMetadata',r.content ? 'metadataOrigins')) order by e.ordinality),'[]'::jsonb)
   into cards from jsonb_array_elements(result->'entries') with ordinality e(value,ordinality)
   join staygrubby.recipes r on r.id=(e.value->>'recipeID')::uuid;
  result:=jsonb_set(result,'{entries}',cards);
 end if;
 return result;
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
commit;
