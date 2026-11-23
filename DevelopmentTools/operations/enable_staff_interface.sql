-- PREPARED ONLY: explicit activation approval and owner-accepted client containing
-- Claude 005a178 required. Run after all three security migrations and enrollment.
-- Pin the verified permanent owner UUID in staygrubby.approved_owner_id first.
begin;
do $$
declare owner_id uuid:=nullif(current_setting('staygrubby.approved_owner_id',true),'')::uuid;
begin
 if owner_id is null or (select count(*) from staygrubby.moderation_reviewers)<>1
  or not exists(select 1 from staygrubby.moderation_reviewers r join staygrubby.profiles p on p.account_id=r.account_id
    join staygrubby.accounts a on a.id=r.account_id where r.account_id=owner_id and r.role='admin' and p.username='grubwithguy' and a.status='active')
 then raise exception 'Approved sole owner enrollment required' using errcode='PT409'; end if;
 if to_regprocedure('api.staff_status(text,jsonb)') is null then raise exception 'Staff status migration required' using errcode='55000'; end if;
 insert into staygrubby.feature_flags(key,enabled,audience,description)
 values('staff_moderation',true,'everyone','Staff-only interface: flag reader filters current membership; server authorizes every action')
 on conflict(key) do update set enabled=true,audience='everyone',description=excluded.description,updated_at=now();
end $$;
commit;
-- The staff_status migration filters this key to current staff. The metadata
-- audience everyone is not a global client rollout; ordinary callers omit it.
-- UI rollback: set only this flag's enabled=false. Server role checks remain.
