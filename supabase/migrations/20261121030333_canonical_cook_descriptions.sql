-- One canonical public description per Cook, separate from private notes and Dish text.
-- Bounded canonical content: one nullable <=2000-scalar field on each existing Cook;
-- retained/erased with that Cook. NULL is unresolved legacy; '' is explicit clear.
-- No content backfill, caption overwrite, new table, event stream or publication.
-- One history index entry per existing post supports exact-Cook legacy reconciliation
-- and FK cleanup; it copies no text and follows the existing post retention.
-- Prerequisites: current text moderation and the complete accepted sync/migration chain.
begin;
do $prerequisite$
begin
 if to_regprocedure('staygrubby.check_public_text(text)') is null
  or to_regprocedure('staygrubby.moderation_subject(staygrubby.social_reports)') is null then
  raise exception 'Apply the approved pending text/moderation chain before Cook descriptions';
 end if;
end $prerequisite$;
alter table staygrubby.cooking_attempts add column public_description text
 check(public_description is null or (char_length(public_description)<=2000
  and regexp_replace(public_description,E'[\n\r\t]','','g') !~ '[[:cntrl:]]'));

create index social_post_cook_history on staygrubby.social_posts(author_id,source_attempt_id,created_at desc,id desc);

-- Add to the existing atomic upsert/export; omitted/null old-client fields preserve
-- canonical text. Keep the ranking guard, graph integrity and receipt chain intact.
do $sync$
declare body text:=pg_get_functiondef('staygrubby.apply_cooking_operation_model_legacy(jsonb)'::regprocedure);
 opened text:=pg_get_functiondef('staygrubby.open_account_library()'::regprocedure);
 columns text:='created_at_ref,updated_at_ref,is_legacy_import)';
 vals text:=$v$(data->>'isLegacyImport')::boolean)$v$;
 updates text:='is_legacy_import=excluded.is_legacy_import';
 oldtuple text:='current.updated_at_ref,current.is_legacy_import) is distinct from';
 newtuple text:='excluded.updated_at_ref,excluded.is_legacy_import);';
 marker text:=$m$  when 'attempt' then
$m$;
 export text:=$e$'isLegacyImport',r.is_legacy_import,'dishID',r.dish_id$e$;
begin
 if strpos(body,columns)=0 or strpos(body,vals)=0 or strpos(body,updates)=0 or strpos(body,oldtuple)=0
  or strpos(body,newtuple)=0 or strpos(body,marker)=0 or strpos(opened,export)=0 then raise exception 'Unexpected Cook description sync predecessor'; end if;
 body:=replace(body,marker,marker||$guard$
   if data ? 'publicDescription' and jsonb_typeof(data->'publicDescription') not in ('string','null')
   then raise exception 'Invalid Cook description' using errcode='22023'; end if;$guard$);
 body:=replace(body,columns,'created_at_ref,updated_at_ref,is_legacy_import,public_description)');
 body:=replace(body,vals,$v$(data->>'isLegacyImport')::boolean,data->>'publicDescription')$v$);
 body:=replace(body,updates,updates||',public_description=coalesce(excluded.public_description,current.public_description)');
 body:=replace(body,oldtuple,'current.updated_at_ref,current.is_legacy_import,current.public_description) is distinct from');
 body:=replace(body,newtuple,'excluded.updated_at_ref,excluded.is_legacy_import,coalesce(excluded.public_description,current.public_description));');
 execute body;
 execute replace(opened,export,$e$'isLegacyImport',r.is_legacy_import,'publicDescription',r.public_description,'dishID',r.dish_id$e$);
end $sync$;

-- Read-only capability metadata piggybacks on the existing account/revision probe.
-- No authentication, identity creation or account state behavior changes.
do $capability$
declare body text:=pg_get_functiondef('staygrubby.provision_account()'::regprocedure);
 marker text:=$m$'sync_revision',revision,'library_state',$m$;
begin
 if strpos(body,marker)=0 then raise exception 'Unexpected account capability predecessor'; end if;
 execute replace(body,marker,$m$'sync_revision',revision,'cook_description_version',1,'library_state',$m$);
end $capability$;

-- Reuse the existing per-card post lookup with an indexed Cook join. No extra
-- client request per card and no post-caption update/fanout on Cook edits.
do $projection$
declare body text:=pg_get_functiondef('staygrubby.social_post_card_before_recipe_sharing(uuid,uuid)'::regprocedure);
 marker text:='select * into p from staygrubby.social_posts where id=post;';
begin
 if strpos(body,marker)=0 or strpos(body,'return card||jsonb_build_object(')=0 then raise exception 'Unexpected caption projection predecessor'; end if;
 body:=replace(body,marker,$join$
 select (jsonb_populate_record(s,jsonb_build_object('post_description',nullif(coalesce(c.public_description,s.post_description),'')))).*
 into p from staygrubby.social_posts s left join staygrubby.cooking_attempts c
  on c.account_id=s.author_id and c.id=s.source_attempt_id and c.deleted_at is null
 where s.id=post;$join$);
 execute replace(body,'return card||jsonb_build_object(',
  'return card||case when viewer=p.author_id then jsonb_build_object(''sourceAttemptID'',p.source_attempt_id) else ''{}''::jsonb end||jsonb_build_object(');
end $projection$;

-- Staff must see the same current public caption that a reporter can see.
do $staff$
declare body text:=pg_get_functiondef('staygrubby.moderation_subject(staygrubby.social_reports)'::regprocedure);
begin
 if strpos(body,'p.post_description')=0 or strpos(body,'from staygrubby.social_posts p where')=0 then raise exception 'Unexpected moderation caption predecessor'; end if;
 body:=replace(body,'p.post_description', 'nullif(coalesce(c.public_description,p.post_description),'''')');
 execute replace(body,'from staygrubby.social_posts p where',
 'from staygrubby.social_posts p left join staygrubby.cooking_attempts c on c.account_id=p.author_id and c.id=p.source_attempt_id and c.deleted_at is null where');
end $staff$;

-- Text protections apply both when a shared Cook changes and when a draft is
-- published/restored. Private notes are never consulted or projected.
create function staygrubby.screen_cook_description() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='cooking_attempts' then
  if new.deleted_at is null and exists(select 1 from staygrubby.social_posts p where p.author_id=new.account_id
   and p.source_attempt_id=new.id and p.deleted_at is null and p.published and p.moderation_state='active') then
   perform staygrubby.check_public_text(new.public_description);
  end if;
 elsif new.deleted_at is null and new.moderation_state='active' then
  perform staygrubby.check_public_text(c.public_description) from staygrubby.cooking_attempts c
   where c.account_id=new.author_id and c.id=new.source_attempt_id and c.deleted_at is null;
 end if;
 return new;
end $$;
revoke all on function staygrubby.screen_cook_description() from public,anon,authenticated,service_role;
create trigger screen_shared_cook_description before insert or update of public_description on staygrubby.cooking_attempts
 for each row execute function staygrubby.screen_cook_description();
create trigger screen_post_cook_description before insert or update of published,moderation_state on staygrubby.social_posts
 for each row execute function staygrubby.screen_cook_description();

-- Existing explicit post editors remain compatible, but now change only that
-- exact Cook. Original captions remain immutable legacy evidence. The account
-- lock/revision integrates edits into cross-device restore and rejects stale sync.
alter function staygrubby.social_content(text,jsonb) rename to social_content_before_cook_description;
revoke all on function staygrubby.social_content_before_cook_description(text,jsonb) from public,anon,authenticated,service_role;
create function staygrubby.social_content(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare owner uuid; cook uuid; pid uuid; description text; current_text text; legacy_text text; result jsonb; existed boolean; changed boolean:=false;
begin
 if action is null then raise exception 'Invalid social action' using errcode='22023'; end if;
 if action not in ('prepare','editDescription') then return staygrubby.social_content_before_cook_description(action,payload); end if;
 owner:=staygrubby.social_actor();
 if payload is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>20480
  or (payload ? 'postDescription' and jsonb_typeof(payload->'postDescription') not in ('string','null'))
  or (payload ? 'expectedDescription' and jsonb_typeof(payload->'expectedDescription') not in ('string','null'))
 then raise exception 'Invalid Cook description request' using errcode='22023'; end if;
 if action='prepare' then
  cook:=(payload->>'attemptID')::uuid;
  perform pg_advisory_xact_lock(hashtextextended('staygrubby:post-source:'||owner::text||':'||coalesce(cook::text,''),0));
 else
  pid:=(payload->>'postID')::uuid;
  select source_attempt_id,post_description into cook,legacy_text from staygrubby.social_posts where id=pid and author_id=owner
   and deleted_at is null and published and moderation_state='active';
  if not found or cook is null or not payload ? 'postDescription' then raise exception 'Post unavailable' using errcode='42501'; end if;
 end if;
 perform 1 from staygrubby.accounts where id=owner and status='active' for update;
 perform staygrubby.social_actor();
 select public_description into current_text from staygrubby.cooking_attempts where account_id=owner and id=cook and deleted_at is null;
 if not found then raise exception 'Cook unavailable' using errcode='42501'; end if;
 select exists(select 1 from staygrubby.social_posts where author_id=owner and source_attempt_id=cook and deleted_at is null) into existed;
 if payload ? 'postDescription' and (action='editDescription' or (not existed and current_text is null)) then
  description:=btrim(coalesce(payload->>'postDescription',''),E' \t\n\r');
  if char_length(description)>2000 or regexp_replace(description,E'[\n\r\t]','','g') ~ '[[:cntrl:]]' then raise exception 'Invalid Cook description' using errcode='22023'; end if;
  -- An old editor resaving an unchanged legacy caption is not an owner conflict
  -- decision. Leave it unresolved and avoid an otherwise unnecessary write.
  if action='editDescription' and current_text is null and not payload ? 'expectedDescription'
   and description=btrim(coalesce(legacy_text,''),E' \t\n\r') then
   return jsonb_build_object('posts',jsonb_build_array(staygrubby.social_post_card(owner,pid)));
  end if;
  if payload ? 'expectedDescription' and current_text is distinct from payload->>'expectedDescription' and current_text is distinct from description
   then raise exception 'Cook description changed; reload' using errcode='PT409'; end if;
  if action='prepare' then perform staygrubby.check_public_text(description); end if;
  update staygrubby.cooking_attempts set public_description=description,updated_at_ref=extract(epoch from clock_timestamp())-978307200
   where account_id=owner and id=cook and deleted_at is null and public_description is distinct from description;
  changed:=found;
 end if;
 if action='prepare' then result:=staygrubby.social_content_before_cook_description(action,payload-'postDescription');
 else result:=jsonb_build_object('posts',jsonb_build_array(staygrubby.social_post_card(owner,pid))); end if;
 if changed then update staygrubby.accounts set sync_revision=sync_revision+1 where id=owner; end if;
 return result;
end $$;
revoke all on function staygrubby.social_content(text,jsonb) from public,anon,service_role;
grant execute on function staygrubby.social_content(text,jsonb) to authenticated;

-- Owner-only, bounded reconciliation read. Never selects private notes or writes
-- a guessed canonical value. A legacy active caption (including blank) remains
-- the display fallback; otherwise the legacy Dish text is available to its owner.
create function api.cook_description(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare owner uuid:=staygrubby.media_owner(); cook staygrubby.cooking_attempts%rowtype; dish_text text; active_caption text; active_post uuid; legacy jsonb; more boolean; needs boolean;
begin
 if owner is null or action is distinct from 'get' or payload is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>1024
 then raise exception 'Cook description unavailable' using errcode='42501'; end if;
 select * into cook from staygrubby.cooking_attempts where account_id=owner and id=(payload->>'attemptID')::uuid and deleted_at is null;
 if not found then raise exception 'Cook unavailable' using errcode='42501'; end if;
 select public_description into dish_text from staygrubby.dishes where account_id=owner and id=cook.dish_id and deleted_at is null;
 select id,post_description into active_post,active_caption from staygrubby.social_posts
  where author_id=owner and source_attempt_id=cook.id and deleted_at is null order by created_at desc,id desc limit 1;
 select coalesce(jsonb_agg(row.card order by row.created_at desc,row.id desc),'[]'::jsonb) into legacy from
  (select p.id,p.created_at,jsonb_build_object('postID',p.id,'postDescription',p.post_description,'retired',p.deleted_at is not null) card
   from staygrubby.social_posts p where p.author_id=owner and p.source_attempt_id=cook.id order by p.created_at desc,p.id desc limit 25) row;
 select exists(select 1 from staygrubby.social_posts where author_id=owner and source_attempt_id=cook.id offset 25 limit 1) into more;
 select count(distinct value)>1 into needs from (
  select coalesce(nullif(btrim(dish_text),''),'') value
  union all select coalesce(nullif(btrim(p.post_description),''),'') from staygrubby.social_posts p where p.author_id=owner and p.source_attempt_id=cook.id
 ) variants;
 return jsonb_build_object('attemptID',cook.id,'publicDescription',cook.public_description,
  'effectiveDescription',case when cook.public_description is not null then nullif(cook.public_description,'') when active_post is not null then active_caption else dish_text end,
  'legacyDishDescription',dish_text,'legacyPosts',legacy,'hasMoreLegacyPosts',more,'needsReview',cook.public_description is null and needs);
end $$;
revoke all on function api.cook_description(text,jsonb) from public,anon,service_role;
grant execute on function api.cook_description(text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
