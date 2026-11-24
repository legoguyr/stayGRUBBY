-- Prospective text screening on shared writes. No user text, matches or new events are stored.
-- Private recipes/notes, cooking data, existing rows and normal consent checks are preserved.
begin;

create function staygrubby.check_public_text(value text) returns void
language plpgsql immutable set search_path='' as $$
declare cleaned text;
begin
 if value is null or value='' then return; end if;
 -- Canonicalize spacing, common zero-width evasions and compatibility forms.
 -- Explicit phrases with targets avoid matching individual culinary words.
 cleaned := regexp_replace(lower(normalize(translate(value,U&'\200B\200C\200D\2060\FEFF',''),NFKC)), '[^[:alnum:]]+', ' ', 'g');
 -- An idiomatic promise to send a photo or recipe is common on The Pass.
 cleaned := regexp_replace(cleaned,'\mshoot you (a|an|the) (photo|picture|message|text|email|link|recipe)\M',' ', 'g');
 if cleaned ~ '\m(i will|we will|i am going to|we are going to|im going to) (kill|stab|shoot) (you|your family)\M'
  or cleaned ~ '\m(go|please) (kill|hang) yourself\M'
  or cleaned ~ '\m(kill all|death to) (jews|muslims|christians|hindus|sikhs|black people|gay people|trans people)\M'
  or cleaned ~ '\m(send me|sell me|trade) (child porn|child pornography)\M'
 then
  raise exception 'This text can’t be shared. Edit it and try again.' using errcode='PT422';
 end if;
end $$;
revoke all on function staygrubby.check_public_text(text) from public,anon,authenticated,service_role;

create function staygrubby.check_shared_recipe_text(content jsonb) returns void
language sql immutable set search_path='' as $$
 select staygrubby.check_public_text(t.value #>> '{}')
 from jsonb_path_query(content - array['photoID','externalURL','allergens','metadataOrigins','metadataEvidence'],
   'strict $.** ? (@.type() == "string")') t(value)
$$;
revoke all on function staygrubby.check_shared_recipe_text(jsonb) from public,anon,authenticated,service_role;

create function staygrubby.screen_outbound_text() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 case tg_table_name
 when 'social_posts' then
  if new.deleted_at is null and new.moderation_state='active' then
   if tg_op='INSERT' or (new.published and not old.published) or old.moderation_state is distinct from new.moderation_state
      or (new.title,new.version_title,new.post_description,new.safe_metadata)
         is distinct from (old.title,old.version_title,old.post_description,old.safe_metadata) then
    perform staygrubby.check_public_text(new.title);
    perform staygrubby.check_public_text(new.version_title);
    perform staygrubby.check_public_text(new.post_description);
    perform staygrubby.check_public_text(f.value #>> '{}')
     from jsonb_path_query(new.safe_metadata,'strict $.** ? (@.type() == "string")') f(value);
   end if;
   if tg_op='UPDATE' and new.published and (not old.published or old.moderation_state is distinct from new.moderation_state) then
    perform staygrubby.check_shared_recipe_text(v.content) from staygrubby.post_recipes p
     join staygrubby.recipe_revisions v on v.recipe_id=p.recipe_id and v.revision=p.recipe_revision
     where p.post_id=new.id;
   end if;
  end if;
 when 'social_comments' then
  if new.deleted_at is null and new.moderation_state='active'
     and (tg_op='INSERT' or new.body is distinct from old.body or new.moderation_state is distinct from old.moderation_state) then
   perform staygrubby.check_public_text(new.body);
  end if;
 when 'profiles' then
  -- A non-discoverable identity can still be seen by existing Sous Chefs.
  if new.username is not null and new.deleted_at is null and new.social_state='active'
     and (tg_op='INSERT' or (new.username,new.display_name,new.discoverable,new.social_state)
      is distinct from (old.username,old.display_name,old.discoverable,old.social_state)) then
   perform staygrubby.check_public_text(replace(new.username,'_',' '));
   perform staygrubby.check_public_text(new.display_name);
  end if;
 when 'recipes' then
  if new.visibility='friends' and new.moderation_state='active' then
   if tg_op='INSERT' or (new.visibility,new.content,new.moderation_state)
      is distinct from (old.visibility,old.content,old.moderation_state) then
    perform staygrubby.check_shared_recipe_text(new.content);
   end if;
   -- Widening the current audience can also re-expose an existing pinned revision.
   if tg_op='UPDATE' and (new.visibility,new.moderation_state) is distinct from (old.visibility,old.moderation_state) then
    perform staygrubby.check_shared_recipe_text(v.content) from staygrubby.recipe_revisions v
     where v.recipe_id=new.id and exists(
      select 1 from staygrubby.post_recipes s join staygrubby.social_posts p on p.id=s.post_id
      where s.recipe_id=v.recipe_id and s.recipe_revision=v.revision and p.published
       and p.deleted_at is null and p.moderation_state='active'
     );
   end if;
  end if;
 when 'post_recipes' then
  perform staygrubby.check_shared_recipe_text(v.content) from staygrubby.recipe_revisions v
   where v.recipe_id=new.recipe_id and v.revision=new.recipe_revision;
 else
  raise exception 'Unexpected social screening boundary';
 end case;
 return new;
end $$;
revoke all on function staygrubby.screen_outbound_text() from public,anon,authenticated,service_role;

create trigger screen_social_post_text
 before insert or update of published,title,version_title,post_description,safe_metadata,moderation_state
 on staygrubby.social_posts for each row execute function staygrubby.screen_outbound_text();
create trigger screen_social_comment_text
 before insert or update of body,moderation_state
 on staygrubby.social_comments for each row execute function staygrubby.screen_outbound_text();
create trigger screen_social_profile_text
 before insert or update of username,display_name,discoverable,social_state
 on staygrubby.profiles for each row execute function staygrubby.screen_outbound_text();
create trigger screen_shared_recipe_text
 before insert or update of content,visibility,moderation_state
 on staygrubby.recipes for each row execute function staygrubby.screen_outbound_text();
create trigger screen_pinned_recipe_text
 before insert or update of recipe_id,recipe_revision
 on staygrubby.post_recipes for each row execute function staygrubby.screen_outbound_text();

-- A reviewer can correlate case subjects across content types through the
-- existing approved case detail. Keep reporter identities and queue rows unchanged.
create or replace function staygrubby.moderation_subject(report staygrubby.social_reports) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('accountID',report.target_account_id) || case report.target_type
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

commit;
