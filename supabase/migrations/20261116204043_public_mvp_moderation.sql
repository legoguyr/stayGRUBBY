-- Additive public MVP moderation, with no content backfill.
-- moderation_reviewers: operational authorization, one row per enrolled account,
-- revoked explicitly or erased with the account.
-- moderation_actions: operational audit, at most one outcome per report, erased
-- with the report. No copied content or reporter identity. Author removal clears
-- the moderator's account reference while preserving surviving case outcomes.
begin;

alter table staygrubby.recipes add column moderation_state text not null default 'active'
 check (moderation_state in ('active','hidden'));
alter table staygrubby.social_reports drop constraint social_reports_target_type_check;
alter table staygrubby.social_reports add constraint social_reports_target_type_check
 check (target_type in ('profile','post','comment','recipe'));
alter table staygrubby.social_reports drop constraint social_reports_reporter_id_target_type_target_id_key;
alter table staygrubby.social_reports add column target_recipe_id uuid,
 add column target_recipe_revision integer,
 add constraint social_reports_recipe_revision_fk foreign key (target_recipe_id,target_recipe_revision)
 references staygrubby.recipe_revisions(recipe_id,revision) match full on delete cascade,
 add constraint social_reports_recipe_target check (
  (target_type='recipe' and target_recipe_id is not null and target_recipe_id=target_id)
  or (target_type<>'recipe' and target_recipe_id is null));
create unique index social_reports_non_recipe_dedupe on staygrubby.social_reports(reporter_id,target_type,target_id)
 where target_type<>'recipe';
create unique index social_reports_recipe_dedupe on staygrubby.social_reports(reporter_id,target_recipe_id,target_recipe_revision)
 where target_type='recipe';
create index social_reports_recipe_revision on staygrubby.social_reports(target_recipe_id,target_recipe_revision)
 where target_recipe_id is not null;
create index social_reports_reporter_recent on staygrubby.social_reports(reporter_id,created_at desc);
create index social_reports_pending_page on staygrubby.social_reports(created_at,id) where status='pending';

create table staygrubby.moderation_reviewers (
 account_id uuid primary key references staygrubby.accounts(id) on delete cascade
);
create table staygrubby.moderation_actions (
 report_id uuid primary key references staygrubby.social_reports(id) on delete cascade,
 reviewer_id uuid references staygrubby.accounts(id) on delete set null,
 decision text not null check (decision in ('hide','dismiss')),
 created_at timestamptz not null default now()
);
create index moderation_actions_reviewer on staygrubby.moderation_actions(reviewer_id);
alter table staygrubby.moderation_reviewers enable row level security;
alter table staygrubby.moderation_actions enable row level security;
revoke all on staygrubby.moderation_reviewers,staygrubby.moderation_actions from public,anon,authenticated,service_role;

-- Keep the owner's private reader and all prior snapshots. Foreign readers,
-- attachments, share routes and photo policies use this same visibility rule.
create or replace function staygrubby.recipe_visible(viewer uuid,recipe uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from staygrubby.recipes r join staygrubby.accounts a on a.id=r.owner_id and a.status='active'
 where r.id=recipe and (r.owner_id=viewer or (r.moderation_state='active' and r.visibility='friends'
  and staygrubby.shared_friends(viewer,r.owner_id))))
$$;

create or replace function staygrubby.social_report(action text,payload jsonb default '{}'::jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare
 owner uuid := staygrubby.social_actor(); kind text := payload->>'targetType'; target uuid := (payload->>'targetID')::uuid;
 author uuid; post uuid; comment uuid; recipe_id uuid; recipe_revision integer; shared jsonb;
 note text; why text := payload->>'reason';
begin
 if action is distinct from 'report' or target is null or octet_length(payload::text)>4096 or why is null
  or why not in ('harassment','hate','spam','inappropriate','impersonation','other')
 then raise exception 'Invalid report' using errcode='22023'; end if;
 note:=nullif(btrim(regexp_replace(coalesce(payload->>'context',''),'[[:space:]]+',' ','g')),'');
 if length(note)>500 then raise exception 'Report context too long' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended('staygrubby:reports:'||owner::text,0));
 if staygrubby.social_actor() is distinct from owner then
  raise exception 'Social account unavailable' using errcode='42501';
 end if;
 if kind='profile' then
  if staygrubby.social_person(owner,target) is null then raise exception 'Person unavailable' using errcode='42501'; end if;
  author:=target;
 elsif kind='post' then
  if not staygrubby.social_can_view(owner,target) then raise exception 'Post unavailable' using errcode='42501'; end if;
  select author_id,id into author,post from staygrubby.social_posts where id=target;
 elsif kind='comment' then
  select c.author_id,c.post_id,c.id into author,post,comment from staygrubby.social_comments c
  where c.id=target and c.deleted_at is null and c.moderation_state='active'
   and staygrubby.social_participant(owner,c.author_id,c.post_id) and staygrubby.social_can_view(owner,c.post_id)
   and not staygrubby.social_blocked(owner,c.author_id);
 elsif kind='recipe' then
  select r.owner_id,r.id,r.revision into author,recipe_id,recipe_revision from staygrubby.recipes r
   where r.id=target and staygrubby.recipe_visible(owner,r.id);
  if payload->>'postID' is not null then
   shared:=staygrubby.shared_recipe_card(owner,(payload->>'postID')::uuid);
   if (shared->>'recipeID')::uuid is distinct from recipe_id or shared is null then
    raise exception 'Recipe unavailable' using errcode='42501';
   end if;
   recipe_revision:=(shared->>'revision')::integer;
  end if;
 else raise exception 'Invalid report target' using errcode='22023'; end if;
 if author is null then raise exception 'Report target unavailable' using errcode='42501'; end if;
 if author=owner then raise exception 'Cannot report yourself' using errcode='22023'; end if;
 if exists(select 1 from staygrubby.social_reports where reporter_id=owner and target_type=kind and target_id=target
  and target_recipe_revision is not distinct from recipe_revision)
 then return jsonb_build_object('reported',true); end if;
 if (select count(*) from staygrubby.social_reports where reporter_id=owner and created_at>now()-interval '1 day')>=50
 then raise exception 'Report limit reached' using errcode='54000'; end if;
 insert into staygrubby.social_reports(reporter_id,target_type,target_id,target_account_id,target_post_id,target_comment_id,
  target_recipe_id,target_recipe_revision,reason,context)
 values(owner,kind,target,author,post,comment,recipe_id,recipe_revision,why,note)
 on conflict do nothing;
 return jsonb_build_object('reported',true);
end $$;

create function staygrubby.require_moderation_reviewer() returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare reviewer uuid := staygrubby.social_actor();
begin
 if not exists(select 1 from staygrubby.moderation_reviewers where account_id=reviewer)
 then raise exception 'Moderator access required' using errcode='42501'; end if;
 return reviewer;
end $$;
revoke all on function staygrubby.require_moderation_reviewer() from public,anon,authenticated,service_role;

-- Projection is limited to the reported item. No profile email, private
-- cooking graph, reporter IDs, ranking evidence or signed object URLs.
create function staygrubby.moderation_subject(report staygrubby.social_reports) returns jsonb
language sql stable security definer set search_path='' as $$
 select case report.target_type
 when 'profile' then (select jsonb_build_object('displayName',p.display_name,'username',p.username,
   'state',p.social_state,'photoPath',p.avatar_path) from staygrubby.profiles p where p.account_id=report.target_id)
 when 'post' then (select jsonb_build_object('title',p.title,'description',p.post_description,'state',p.moderation_state,
   'photoPath',case when p.photo_ready then p.photo_path end) from staygrubby.social_posts p where p.id=report.target_id)
 when 'comment' then (select jsonb_build_object('body',c.body,'state',c.moderation_state)
   from staygrubby.social_comments c where c.id=report.target_id and c.deleted_at is null)
 when 'recipe' then (select jsonb_build_object('content',v.content,'revision',v.revision,'state',r.moderation_state,
   'photoPath',p.path)
   from staygrubby.recipe_revisions v join staygrubby.recipes r on r.id=v.recipe_id
   left join staygrubby.recipe_photos p on p.owner_id=r.owner_id and p.id::text=v.content->>'photoID'
   where v.recipe_id=report.target_recipe_id and v.revision=report.target_recipe_revision)
 end
$$;
revoke all on function staygrubby.moderation_subject(staygrubby.social_reports) from public,anon,authenticated,service_role;

create function staygrubby.moderation_review(action text,payload jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare
 reviewer uuid := staygrubby.require_moderation_reviewer();
 report staygrubby.social_reports%rowtype;
 outcome staygrubby.moderation_actions%rowtype;
 report_id uuid; after_id uuid; after_time timestamptz; decision text;
 result jsonb;
begin
 if payload is null or jsonb_typeof(payload)<>'object' or octet_length(payload::text)>1024
 then raise exception 'Invalid moderation request' using errcode='22023'; end if;
 if action='queue' then
  after_id:=(payload->>'afterID')::uuid;
  after_time:=(payload->>'afterTime')::timestamptz;
  if (after_id is null)<>(after_time is null) then
   raise exception 'Invalid report cursor' using errcode='22023';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'kind',r.target_type,'reason',r.reason,
   'createdAt',r.created_at,'status',r.status) order by r.created_at,r.id),'[]'::jsonb) into result
  from (select id,target_type,reason,created_at,status from staygrubby.social_reports
   where status='pending' and target_account_id<>reviewer
    and (after_time is null or (created_at,id)>(after_time,after_id))
   order by created_at,id limit 25) r;
  return jsonb_build_object('reports',result);
 end if;
 if action is null or action not in ('review','resolve') then
  raise exception 'Invalid moderation action' using errcode='22023';
 end if;
 report_id:=(payload->>'reportID')::uuid;
 if action='resolve' then
  decision:=payload->>'decision';
  if report_id is null or decision is null or decision not in ('dismiss','hide') then
   raise exception 'Invalid moderation decision' using errcode='22023';
  end if;
  -- Serialize staff handling without taking a report row lock before the
  -- target lock. Target deletion cascades take those locks in the other order.
  perform pg_advisory_xact_lock(hashtextextended('staygrubby:moderation:'||report_id::text,0));
  if staygrubby.require_moderation_reviewer() is distinct from reviewer then
   raise exception 'Moderator access required' using errcode='42501';
  end if;
 end if;
 select * into report from staygrubby.social_reports r where r.id=report_id and r.target_account_id<>reviewer;
 if not found then raise exception 'Report unavailable' using errcode='42501'; end if;
 select * into outcome from staygrubby.moderation_actions a where a.report_id=report.id;
 if action='review' then
  return jsonb_build_object('id',report.id,'kind',report.target_type,'reason',report.reason,
   'context',report.context,'status',report.status,'createdAt',report.created_at,
   'decision',outcome.decision,'resolvedAt',outcome.created_at,'subject',staygrubby.moderation_subject(report));
 end if;
 if outcome.decision is not null and outcome.decision=decision then
  return jsonb_build_object('status',report.status,'decision',outcome.decision,'resolvedAt',outcome.created_at);
 end if;
 if report.status<>'pending' then raise exception 'Report already resolved' using errcode='PT409'; end if;
 if decision='hide' then
  if report.target_type='recipe' then
   update staygrubby.recipes set moderation_state='hidden' where id=report.target_id and moderation_state='active';
  else
   perform api.moderate_social_content(report.target_type,report.target_id,'hidden');
  end if;
 end if;
 update staygrubby.social_reports set status=case when decision='hide' then 'reviewed' else 'dismissed' end
  where id=report.id and status='pending' returning status into report.status;
 if not found then raise exception 'Report no longer pending' using errcode='PT409'; end if;
 insert into staygrubby.moderation_actions(report_id,reviewer_id,decision)
  values(report.id,reviewer,decision) returning * into outcome;
 return jsonb_build_object('status',report.status,'decision',outcome.decision,'resolvedAt',outcome.created_at);
end $$;
revoke all on function staygrubby.moderation_review(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function staygrubby.moderation_review(text,jsonb) to authenticated;
create function api.moderation_review(action text,payload jsonb default '{}'::jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$
 select staygrubby.moderation_review(action,payload)
$$;
revoke all on function api.moderation_review(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function api.moderation_review(text,jsonb) to authenticated;

-- Normal staff operations go through the audit. Preserve the existing helper
-- for database operators and the internal moderation transaction.
revoke execute on function api.moderate_social_content(text,uuid,text) from service_role;
notify pgrst,'reload schema';
commit;
