-- Correct reported-original GET authorization for Supabase Storage operation prefixes.
-- No new records, tables, grants, roles, retention, backfill or Storage mutations.
-- Keep the existing report-only evidence scope and owner/peer privacy boundaries.
begin;
create or replace function staygrubby.review_image_allowed(bucket text,path text) returns boolean
language plpgsql volatile security definer set search_path='' as $$
declare reviewer uuid;
begin
 if not storage.allow_any_operation(array['object.get_authenticated']) then return false; end if;
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
commit;
