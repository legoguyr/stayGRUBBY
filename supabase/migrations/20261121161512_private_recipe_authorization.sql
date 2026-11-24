-- Personal Recipe access shares the verified owner resolver used by private media.
-- The same API keeps its legacy actions, payloads, locks, ownership checks and row grants.
-- Social actions and explicit audience expansion still require social eligibility.
begin;

create function staygrubby.recipe_operation_actor(action text) returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid;
begin
 if action in (
  'get','list','save','delete','history','revision','restore','library_index','cookbook','cookbook_index',
  'dish','dish_recipes','set_dish','attach','detach','link_dish_recipe','unlink_dish_recipe','set_main_recipe',
  'cook','link_cook','unlink_cook','begin','complete','associate_cook','provenance','fork_provenance',
  'ticket','tickets','unticket','prepare_photo','complete_photo','photo','cleanup_photos'
 ) then
  owner := staygrubby.media_owner();
  if owner is null then raise exception 'Account unavailable' using errcode='42501'; end if;
  return owner;
 end if;
 return staygrubby.social_actor();
end $$;
revoke all on function staygrubby.recipe_operation_actor(text) from public,anon,authenticated,service_role;

-- The functions below are the exact existing Recipe compatibility chain, not
-- alternate client endpoints. Change only actor resolution, plus the two
-- visibility cases below. Preserve all definitions, locks and ACLs in place.
do $apply$
declare signature record; body text; marker constant text := 'staygrubby.social_actor()';
 previous_default constant text := $target$coalesce((select r.visibility from staygrubby.recipes r where r.id=rid and r.owner_id=actor),'friends')$target$;
 safe_default constant text := $target$case when exists(
    select 1 from staygrubby.profiles where account_id=actor and deleted_at is null and social_state='active'
   ) then coalesce((select r.visibility from staygrubby.recipes r where r.id=rid and r.owner_id=actor),'friends')
   else 'private' end$target$;
 write_statement constant text := 'insert into staygrubby.recipes(id,owner_id,content,visibility) values';
begin
 for signature in select * from (values
  ('recipe_api',1), ('recipe_api_before_closeout',2), ('recipe_api_before_cook_lifecycle',1),
  ('recipe_api_before_creator_metadata',2), ('recipe_api_before_diet_index',3),
  ('recipe_api_before_dish_identity',1), ('recipe_api_before_dish_recipes',2),
  ('recipe_api_before_food_bible',2), ('recipe_api_before_food_bible_dishes',2),
  ('recipe_api_before_owned_copy_options',4), ('recipe_api_before_search_index',2),
  ('recipe_api_before_social',2), ('recipe_api_before_stage5',2), ('recipe_link_cook',2)
 ) as functions(name,actor_checks) loop
  body := pg_get_functiondef(to_regprocedure('staygrubby.'||signature.name||'(text,jsonb)'));
  if body is null or length(body)-length(replace(body,marker,'')) <> signature.actor_checks*length(marker) then
   raise exception 'Unexpected Recipe authorization predecessor: %', signature.name;
  end if;
  body := replace(body,marker,'staygrubby.recipe_operation_actor(action)');
  if signature.name='recipe_api_before_cook_lifecycle' then
   -- Omitted visibility from an older client still permits a restricted
   -- owner to save privately. Ordinary clients retain their existing default.
   if strpos(body,previous_default)=0 then raise exception 'Unexpected Recipe visibility default'; end if;
   body := replace(body,previous_default,safe_default);
  elsif signature.name='recipe_api_before_food_bible' then
   if strpos(body,write_statement)=0 then raise exception 'Unexpected Recipe save predecessor'; end if;
   body := replace(body,write_statement,
    $guard$if payload->>'visibility'='friends' then perform staygrubby.social_actor(); end if;
  $guard$||write_statement);
  end if;
  execute body;
 end loop;
end $apply$;

commit;
