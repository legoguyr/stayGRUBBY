-- Report-based image moderation: no publication hold, classifier or queue writes.
-- No new tables or content backfill. Remove disposable approval/lease state only;
-- preserve image_review_actions as closed historical audit (no new writes), and
-- all original Storage objects, photo manifests, content and audience permissions.
begin;

create or replace function staygrubby.social_object_allowed(bucket text,path text,mode text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
begin
 if mode='read' and nullif(current_setting('storage.operation',true),'') is not null and not storage.allow_any_operation(array['object.get_authenticated','object.get_authenticated_info','object.head_authenticated_info','object.info_authenticated','object.upload','object.upload_update','object.delete','object.delete_many']) then return false; end if;
 return staygrubby.social_object_before_image_review(bucket,path,mode);
end $$;
create or replace function staygrubby.profile_object_allowed(bucket text,path text,mode text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
begin
 if mode='read' and nullif(current_setting('storage.operation',true),'') is not null and not storage.allow_any_operation(array['object.get_authenticated','object.get_authenticated_info','object.head_authenticated_info','object.info_authenticated','object.upload','object.upload_update','object.delete','object.delete_many']) then return false; end if;
 return staygrubby.profile_object_before_image_review(bucket,path,mode);
end $$;
create or replace function staygrubby.recipe_object_allowed(bucket text,path text,mode text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
begin
 -- Preserve authenticated-only originals and internal Recipe descriptor calls.
 if mode='read' and nullif(current_setting('storage.operation',true),'') is not null and not storage.allow_any_operation(array['object.get_authenticated','object.get_authenticated_info','object.head_authenticated_info','object.info_authenticated','object.upload','object.upload_update','object.delete','object.delete_many']) then return false; end if;
 return staygrubby.recipe_object_before_image_review(bucket,path,mode);
end $$;

-- Staff may inspect the photo of an actual report, never browse private libraries.
-- Reporting did already authorize the exact subject/revision. Existing content
-- hide/dismiss decisions and their audit remain the only active review workflow.
create or replace function staygrubby.review_image_allowed(bucket text,path text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
declare reviewer uuid;
begin
 if current_setting('storage.operation',true) is distinct from 'object.get_authenticated' then return false; end if;
 begin reviewer:=staygrubby.require_moderation_reviewer();
 exception when insufficient_privilege then return false; end;
 return exists(select 1 from staygrubby.social_reports r
  where r.target_account_id<>reviewer and r.status in ('pending','reviewed')
   and split_part(path,'/',1)=r.target_account_id::text
   and ((bucket='social-photos' and r.target_type='post')
    or (bucket='profile-photos' and r.target_type='profile')
    or (bucket='recipe-photos' and r.target_type='recipe'))
   and staygrubby.moderation_subject(r)->>'photoPath'=path);
end $$;

drop trigger protect_screened_image on storage.objects;
drop trigger review_uploaded_image on storage.objects;
drop trigger review_shared_recipe_image on staygrubby.recipes;
drop trigger review_pinned_recipe_image on staygrubby.post_recipes;
drop function api.image_moderation(text,jsonb);
drop function api.claim_image_reviews();
drop function api.finish_image_review(uuid,uuid,uuid,text,text);
drop function staygrubby.finish_image_review_before_manual(uuid,uuid,uuid,text,text);
drop function staygrubby.protect_screened_image();
drop function staygrubby.queue_shared_image();
drop function staygrubby.request_image_review(text,text);
drop function staygrubby.image_approved(text,text);
drop function staygrubby.image_review_eligible(uuid);
drop function staygrubby.recipe_object_before_manual_review(text,text,text);
drop table staygrubby.image_reviews;
-- image_access remains the read-only ordinary-audience cache authorization seam.
notify pgrst,'reload schema';
commit;
