-- Recipe share option integrity (November 18, 2026; split from
-- 20261118160000_dish_recipe_integrity on November 20 so that file can deploy alone).
-- `share_options` consulted the legacy `dish_recipes` family link before the Dish's
-- own Recipe, so a cook could offer another Dish's Recipe. Depends on
-- 20261117063020_dish_owned_recipe_share_options. Function body only; no table,
-- row or grant changes (growth: none).
begin;

-- Share options: the cook's exact snapshot, its exact link, then the Dish's own
-- Recipe. The legacy family link no longer decides.
do $apply$
declare body text:=pg_get_functiondef('staygrubby.owned_recipe_share_option(jsonb)'::regprocedure);
 legacy constant text:=$legacy$ if not historical and rid is null then
  select r.id,r.revision into rid,version from staygrubby.dish_recipes l
  join staygrubby.recipes r on r.id=l.recipe_id and r.owner_id=actor
  where l.account_id=actor and l.dish_id=attempt_dish;
 end if;
$legacy$;
begin
 if strpos(body,legacy)=0 then raise exception 'Unexpected share option predecessor'; end if;
 execute replace(body,legacy,'');
end $apply$;

notify pgrst,'reload schema';
commit;
