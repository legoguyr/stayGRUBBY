-- Exact per-creator Dish identity for authorized shared cook cards.
-- Derived opaque key from random existing account/Dish UUIDs; no private UUID projection,
-- no table, content backfill, inference across creators, or routine write.
begin;
create function staygrubby.social_dish_key(post uuid) returns text
language sql stable security definer set search_path='' as $$
 select md5('staygrubby-social-dish-v1:'||p.author_id::text||':'||a.dish_id::text)
 from staygrubby.social_posts p join staygrubby.cooking_attempts a
 on a.account_id=p.author_id and a.id=p.source_attempt_id and a.deleted_at is null
 join staygrubby.dishes d on d.account_id=a.account_id and d.id=a.dish_id and d.deleted_at is null
 where p.id=post and p.deleted_at is null
$$;
revoke all on function staygrubby.social_dish_key(uuid) from public,anon,authenticated,service_role;
alter function staygrubby.social_post_card(uuid,uuid) rename to social_post_card_before_dish_key;
revoke all on function staygrubby.social_post_card_before_dish_key(uuid,uuid) from public,anon,authenticated,service_role;
create function staygrubby.social_post_card(viewer uuid,post uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare card jsonb:=staygrubby.social_post_card_before_dish_key(viewer,post);
begin
 if card is null then return null; end if;
 return card||jsonb_build_object('dishKey',staygrubby.social_dish_key(post));
end $$;
revoke all on function staygrubby.social_post_card(uuid,uuid) from public,anon,authenticated,service_role;

alter function staygrubby.social_feed(text,jsonb) rename to social_feed_before_dish_cooks;
revoke all on function staygrubby.social_feed_before_dish_cooks(text,jsonb) from public,anon,authenticated,service_role;
create function staygrubby.social_feed(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare viewer uuid:=staygrubby.social_actor(); source staygrubby.social_posts%rowtype;
 dish uuid; rows jsonb; ranked boolean:=payload->>'order'='highestRated';
begin
 if action is distinct from 'dish' then return staygrubby.social_feed_before_dish_cooks(action,payload); end if;
 if payload is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>2048
  or coalesce(payload->>'order','recent') not in ('recent','highestRated')
  or ((payload->>'beforeTime' is null)<>(payload->>'beforeID' is null))
  or (ranked and payload->>'beforeID' is not null and payload->>'beforeScore' is null)
 then raise exception 'Invalid Dish page' using errcode='22023'; end if;
 select * into source from staygrubby.social_posts p
  where p.id=(payload->>'postID')::uuid and staygrubby.social_can_view(viewer,p.id);
 if source.id is null then raise exception 'Dish unavailable' using errcode='42501'; end if;
 select a.dish_id into dish from staygrubby.cooking_attempts a join staygrubby.dishes d
  on d.account_id=a.account_id and d.id=a.dish_id and d.deleted_at is null
  where a.account_id=source.author_id and a.id=source.source_attempt_id and a.deleted_at is null;
 select coalesce(jsonb_agg(page.card order by page.score desc,page.created_at desc,page.id desc),'[]'::jsonb) into rows from (
  select p.id,p.created_at,case when ranked then coalesce(p.score_text::numeric,-1) else 0 end score,
   staygrubby.social_post_card(viewer,p.id) card
  from staygrubby.cooking_attempts a join staygrubby.social_posts p
   on p.author_id=a.account_id and p.source_attempt_id=a.id
  where a.account_id=source.author_id and a.dish_id=dish and a.deleted_at is null
   and p.id<>source.id and p.deleted_at is null and p.published and p.moderation_state='active'
   and staygrubby.social_can_view(viewer,p.id)
   and (payload->>'beforeID' is null or
    (case when ranked then coalesce(p.score_text::numeric,-1) else 0 end,p.created_at,p.id) <
    (case when ranked then (payload->>'beforeScore')::numeric else 0 end,
     to_timestamp((payload->>'beforeTime')::double precision),(payload->>'beforeID')::uuid))
  order by score desc,p.created_at desc,p.id desc limit 25
 ) page;
 return jsonb_build_object('posts',rows);
end $$;
revoke all on function staygrubby.social_feed(text,jsonb) from public,anon;
grant execute on function staygrubby.social_feed(text,jsonb) to authenticated;
create or replace function api.social_feed(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_feed(action,payload) $$;
notify pgrst,'reload schema';
commit;
