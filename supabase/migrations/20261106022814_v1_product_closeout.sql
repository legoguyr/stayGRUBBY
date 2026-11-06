-- Explicit Recipe activity is not a cook, score or public discovery record.
begin;
create table staygrubby.recipe_activity (
 id uuid primary key default gen_random_uuid(),
 recipe_id uuid not null unique references staygrubby.recipes(id) on delete cascade,
 created_at timestamptz not null default now()
);
alter table staygrubby.recipe_activity enable row level security;
revoke all on staygrubby.recipe_activity from public,anon,authenticated;
create index recipe_activity_order on staygrubby.recipe_activity(created_at desc,id desc);
create function staygrubby.record_recipe_activity() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.visibility='friends' and (tg_op='INSERT' or old.visibility is distinct from new.visibility) then
  insert into staygrubby.recipe_activity(recipe_id) values(new.id) on conflict(recipe_id) do nothing;
 end if;
 return new;
end $$;
revoke all on function staygrubby.record_recipe_activity() from public,anon,authenticated;
create trigger record_recipe_activity after insert or update of visibility on staygrubby.recipes
 for each row execute function staygrubby.record_recipe_activity();

-- Creator credit is private historical attribution, separate from immutable Recipe content.
-- No backfill/rewriting of existing snapshots or self-credit.
alter table staygrubby.recipe_cooks add column creator_name text;
create function staygrubby.pin_recipe_creator() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 select case when r.owner_id<>new.account_id then staygrubby.social_person(new.account_id,r.owner_id)->>'displayName' end
 into new.creator_name from staygrubby.recipes r where r.id=new.recipe_id;
 return new;
end $$;
revoke all on function staygrubby.pin_recipe_creator() from public,anon,authenticated;
create trigger pin_recipe_creator before insert on staygrubby.recipe_cooks for each row execute function staygrubby.pin_recipe_creator();

alter function staygrubby.recipe_api(text,jsonb) rename to recipe_api_before_closeout;
revoke all on function staygrubby.recipe_api_before_closeout(text,jsonb) from public,anon,authenticated;
create function staygrubby.recipe_api(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=staygrubby.social_actor(); rid uuid:=(payload->>'recipeID')::uuid; result jsonb; credit text;
begin
 if action='save' and payload->>'visibility' is null then
  -- New owner-authored Recipes default to Sous Chefs, never globally Public.
  -- Existing private Recipes retain their current audience; fork remains explicitly private.
  payload:=payload||jsonb_build_object('visibility',coalesce((select r.visibility from staygrubby.recipes r where r.id=rid and r.owner_id=actor),'friends'));
 end if;
 result:=staygrubby.recipe_api_before_closeout(action,payload);
 if action='provenance' then
  select coalesce(jsonb_agg(e.value||jsonb_build_object('creatorName',c.creator_name) order by e.ordinality),'[]'::jsonb)
   into result from jsonb_array_elements(result->'cooks') with ordinality e(value,ordinality)
   left join staygrubby.recipe_cooks c on c.id=(e.value->>'id')::uuid and c.account_id=actor;
  return jsonb_build_object('cooks',result);
 elsif action='cook' and result->>'usedRecipe' is not null then
  select c.creator_name into credit from staygrubby.recipe_cooks c where c.id=(result->'usedRecipe'->>'id')::uuid and c.account_id=actor;
  result:=jsonb_set(result,'{usedRecipe,creatorName}',coalesce(to_jsonb(credit),'null'::jsonb));
 end if;
 return result;
end $$;
revoke all on function staygrubby.recipe_api(text,jsonb) from public,anon;
grant execute on function staygrubby.recipe_api(text,jsonb) to authenticated;
create or replace function api.recipes(action text,payload jsonb default '{}'::jsonb) returns jsonb
 language sql volatile security invoker set search_path='' as $$ select staygrubby.recipe_api(action,payload) $$;

-- New action preserves old clients' page/profile/post contracts without pretending Recipes are cooks.
alter function staygrubby.social_feed(text,jsonb) rename to social_feed_before_recipe_activity;
revoke all on function staygrubby.social_feed_before_recipe_activity(text,jsonb) from public,anon,authenticated;
create function staygrubby.social_feed(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare viewer uuid:=staygrubby.social_actor(); result jsonb;
begin
 if action<>'activity_page' then return staygrubby.social_feed_before_recipe_activity(action,payload); end if;
 if octet_length(payload::text)>1024 or ((payload->>'beforeTime' is null)<>(payload->>'beforeID' is null)) then raise exception 'Invalid cursor' using errcode='22023'; end if;
 perform 1 from staygrubby.accounts where id=viewer and status='active' for share;
 if not found or staygrubby.social_actor() is distinct from viewer then raise exception 'Account unavailable' using errcode='42501'; end if;
 select coalesce(jsonb_agg(card order by created_at desc,id desc),'[]'::jsonb) into result from (
  select * from (
   select p.id,p.created_at,jsonb_build_object('kind','cook','post',staygrubby.social_post_card(viewer,p.id)) card
   from staygrubby.social_posts p where p.published and p.deleted_at is null and p.moderation_state='active' and staygrubby.social_can_view(viewer,p.id)
   union all
   select a.id,a.created_at,jsonb_build_object('kind','recipe_created','recipe',jsonb_build_object(
    'id',a.id,'isAuthor',r.owner_id=viewer,'createdAt',extract(epoch from a.created_at),'author',staygrubby.social_person(viewer,r.owner_id),
    'entry',jsonb_build_object('recipeID',r.id,'recipeTitle',r.content->>'title','dishTitle',r.content->>'title','revision',r.revision,
      'updatedAt',extract(epoch from r.updated_at),'createdAt',extract(epoch from r.created_at),
      'course',r.content->>'course','cuisine',r.content->>'cuisine','yield',r.content->>'yield',
      'prepMinutes',r.content->'prepMinutes','cookMinutes',r.content->'cookMinutes','elapsedMinutes',r.content->'elapsedMinutes',
      'photoID',r.content->>'photoID'))) card
   from staygrubby.recipe_activity a join staygrubby.recipes r on r.id=a.recipe_id
   where r.visibility='friends' and staygrubby.recipe_visible(viewer,r.id) and staygrubby.social_person(viewer,r.owner_id) is not null
    and exists(select 1 from staygrubby.profiles p where p.account_id=r.owner_id and p.social_state='active' and p.deleted_at is null)
  ) visible where payload->>'beforeTime' is null or (created_at,id)<(to_timestamp((payload->>'beforeTime')::double precision),(payload->>'beforeID')::uuid)
  order by created_at desc,id desc limit 25
 ) page;
 return jsonb_build_object('activities',result);
end $$;
revoke all on function staygrubby.social_feed(text,jsonb) from public,anon;
grant execute on function staygrubby.social_feed(text,jsonb) to authenticated;
create or replace function api.social_feed(action text,payload jsonb default '{}'::jsonb) returns jsonb
 language sql volatile security invoker set search_path='' as $$ select staygrubby.social_feed(action,payload) $$;
notify pgrst,'reload schema';
commit;
