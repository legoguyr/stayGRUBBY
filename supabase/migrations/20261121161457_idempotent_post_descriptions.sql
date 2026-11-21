-- Reuse the existing social publication path. Avoid rewriting unchanged
-- descriptions and setting an already-null column on new cook posts.
-- Existing grants, auth, response shapes and durable content are preserved.
begin;

create or replace function staygrubby.social_content_before_calibration(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid:=staygrubby.social_actor(); description text; existed boolean; result jsonb; pid uuid;
begin
 if action not in ('prepare','editDescription') then return staygrubby.social_content_before_description(action,payload); end if;
 if octet_length(payload::text)>20480 or (payload ? 'postDescription' and jsonb_typeof(payload->'postDescription') not in ('string','null'))
 then raise exception 'Invalid post description' using errcode='22023'; end if;
 description:=nullif(btrim(payload->>'postDescription',E' \t\n\r'),'');
 if length(description)>2000 or regexp_replace(description,E'[\n\r\t]','','g') ~ '[[:cntrl:]]'
 then raise exception 'Invalid post description' using errcode='22023'; end if;
 if action='editDescription' then
  pid:=(payload->>'postID')::uuid;
  if pid is null or not payload ? 'postDescription' then raise exception 'Description required' using errcode='22023'; end if;
  perform 1 from staygrubby.accounts where id=owner and status='active' for share;
  perform staygrubby.social_actor();
  update staygrubby.social_posts set post_description=description
   where id=pid and author_id=owner and deleted_at is null and published and moderation_state='active'
    and post_description is distinct from description;
  -- An identical save still requires an active, published post owned by this caller.
  if not found and not exists(select 1 from staygrubby.social_posts
   where id=pid and author_id=owner and deleted_at is null and published and moderation_state='active')
  then raise exception 'Post unavailable' using errcode='42501'; end if;
 else
  -- Serialize new preparations for a cook; retries must not edit an existing snapshot.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:post-source:'||owner::text||':'||coalesce(payload->>'attemptID',''),0));
  select exists(select 1 from staygrubby.social_posts where author_id=owner and source_attempt_id=(payload->>'attemptID')::uuid and deleted_at is null) into existed;
  result:=staygrubby.social_content_before_description(action,payload-'postDescription');
  pid:=(result->'posts'->0->>'id')::uuid;
  if not existed and description is not null then
   update staygrubby.social_posts set post_description=description where id=pid and author_id=owner and deleted_at is null;
  end if;
 end if;
 return jsonb_build_object('posts',jsonb_build_array(staygrubby.social_post_card(owner,pid)));
end $$;
commit;
