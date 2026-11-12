-- Cooking photo manifests survive ordinary media tombstones. Remove them only
-- during verified account erasure, after the Storage API has removed the bytes.
begin;

create or replace function staygrubby.erase_account_data(target_auth_user uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare job staygrubby.account_deletion_jobs%rowtype; account_status text;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('staygrubby:delete:' || target_auth_user::text,0));
 select * into job from staygrubby.account_deletion_jobs where auth_user_id=target_auth_user for update;
 if not found then raise exception 'Deletion job unavailable' using errcode='55000'; end if;
 if job.state='account_erased' then return jsonb_build_object('accountID',job.account_id,'state',job.state); end if;
 if job.state<>'storage_cleared' then raise exception 'Storage cleanup required' using errcode='55000'; end if;

 select status into account_status from staygrubby.accounts where id=job.account_id for update;
 if found and account_status<>'deleting' then
  raise exception 'Account deletion refused' using errcode='55000';
 end if;
 if exists(select 1 from storage.objects where bucket_id in ('cooking-photos','social-photos','profile-photos','recipe-photos')
           and (name=job.account_id::text or name like job.account_id::text || '/%'))
 then raise exception 'Storage cleanup incomplete' using errcode='55000'; end if;

 -- Keep the immediate composite FK. Clearing manifests and cascading the
 -- account graph must commit together with the Auth-cleanup checkpoint.
 delete from staygrubby.media_backups where account_id=job.account_id;
 delete from staygrubby.accounts where id=job.account_id;
 update staygrubby.account_deletion_jobs set state='account_erased',updated_at=clock_timestamp()
  where auth_user_id=target_auth_user returning * into job;
 return jsonb_build_object('accountID',job.account_id,'state',job.state);
end $$;

notify pgrst,'reload schema';
commit;
