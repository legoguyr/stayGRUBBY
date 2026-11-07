-- Reconcile an owner's exact cook and capture only the authorized ranking snapshot.
begin;
alter table staygrubby.social_posts
 add column rank_at_sharing integer,
 add column ranked_count_at_sharing integer,
 add constraint valid_rank_at_sharing check (
  (rank_at_sharing is null and ranked_count_at_sharing is null) or
  (rank_at_sharing is not null and ranked_count_at_sharing is not null and
   score_text is not null and rank_at_sharing between 1 and ranked_count_at_sharing)
 );

alter function staygrubby.social_post_card(uuid,uuid) rename to social_post_card_before_rank_snapshot;
revoke all on function staygrubby.social_post_card_before_rank_snapshot(uuid,uuid) from public,anon,authenticated;
create function staygrubby.social_post_card(viewer uuid,post uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare card jsonb:=staygrubby.social_post_card_before_rank_snapshot(viewer,post); p staygrubby.social_posts%rowtype;
begin
 if card is null then return null; end if;
 select * into p from staygrubby.social_posts where id=post;
 if p.rank_at_sharing is not null then
  card:=card||jsonb_build_object('rankAtSharing',p.rank_at_sharing,'rankedCountAtSharing',p.ranked_count_at_sharing);
 end if;
 return card;
end $$;
revoke all on function staygrubby.social_post_card(uuid,uuid) from public,anon,authenticated;

alter function staygrubby.social_content(text,jsonb) rename to social_content_before_rank_snapshot;
revoke all on function staygrubby.social_content_before_rank_snapshot(text,jsonb) from public,anon,authenticated;
create function staygrubby.social_content(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid; cook uuid; pid uuid; existing uuid; result jsonb; position integer; total integer;
begin
 if action not in ('source','cancelDraft','prepare') then return staygrubby.social_content_before_rank_snapshot(action,payload); end if;
 owner:=staygrubby.social_actor();
 if owner is null or octet_length(payload::text)>8192 then raise exception 'Invalid post' using errcode='42501'; end if;
 if action='cancelDraft' then
  pid:=(payload->>'postID')::uuid;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:post:'||pid::text,0));
  perform 1 from staygrubby.accounts where id=owner and status='active' for share;
  if not found or staygrubby.social_actor() is distinct from owner then raise exception 'Account unavailable' using errcode='42501'; end if;
  update staygrubby.social_posts set deleted_at=now()
   where author_id=owner and id=pid and not published and deleted_at is null;
  return jsonb_build_object('posts','[]'::jsonb);
 end if;
 cook:=(payload->>'attemptID')::uuid;
 if action='source' then
  select id into pid from staygrubby.social_posts
   where author_id=owner and source_attempt_id=cook and deleted_at is null and published;
  result:=staygrubby.social_post_card(owner,pid);
  return jsonb_build_object('posts',case when result is null then '[]'::jsonb else jsonb_build_array(result) end);
 end if;

 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:post-source:'||owner::text||':'||coalesce(cook::text,''),0));
 select id into existing from staygrubby.social_posts where author_id=owner and source_attempt_id=cook and deleted_at is null;
 result:=staygrubby.social_content_before_rank_snapshot(action,payload);
 pid:=(result->'posts'->0->>'id')::uuid;
 if existing is not null or pid is null then return result; end if;
 if payload->>'omitScore'='true' then
  update staygrubby.social_posts set score_text=null where id=pid and author_id=owner;
 end if;
 -- The delegated prepare holds the account lock and verified expectedRevision.
 -- Require the global list and eligible attempt order to agree before exposing a position.
 with ordered as (
  select i.id,a.id attempt_id,row_number() over(order by round(i.strength::numeric*10000000) desc,i.created_at_ref,i.id) as pos,
   count(*) over() as list_count,count(a.id) over() as eligible_count
  from staygrubby.ranked_items i
  join staygrubby.account_libraries l on l.account_id=i.account_id and l.global_ranking_id=i.ranking_id and l.deleted_at is null
  join staygrubby.rankings r on r.account_id=i.account_id and r.id=i.ranking_id and r.deleted_at is null
  left join (staygrubby.cooking_attempts a join staygrubby.dishes d
    on d.account_id=a.account_id and d.id=a.dish_id and d.deleted_at is null)
    on a.account_id=i.account_id and a.ranked_item_id=i.id and a.deleted_at is null
  where i.account_id=owner and i.deleted_at is null
 )
 select pos,eligible_count into position,total from ordered where attempt_id=cook and list_count=eligible_count;
 if position is not null and payload->'includeRankSnapshot'='true'::jsonb then
  update staygrubby.social_posts set rank_at_sharing=position,ranked_count_at_sharing=total
   where id=pid and author_id=owner and score_text is not null;
 end if;
 return jsonb_build_object('posts',jsonb_build_array(staygrubby.social_post_card(owner,pid)));
end $$;
revoke all on function staygrubby.social_content(text,jsonb) from public,anon;
grant execute on function staygrubby.social_content(text,jsonb) to authenticated;
create or replace function api.social_content(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.social_content(action,payload) $$;
notify pgrst,'reload schema';
commit;
