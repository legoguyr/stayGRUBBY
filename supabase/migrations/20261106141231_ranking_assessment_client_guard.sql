-- Preserve the accepted writer; guard incompatible clients before any mutation.
-- No backfill, table/Storage changes, ranking fit, or evidence rewrite.
begin;
alter function staygrubby.apply_cooking_operation(jsonb) rename to apply_cooking_operation_model_legacy;
revoke all on function staygrubby.apply_cooking_operation_model_legacy(jsonb) from public,anon,authenticated;

create function staygrubby.apply_cooking_operation(envelope jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare
 owner uuid; payload_bytes bytea; changes jsonb; needs_model boolean;
 marker bytea := convert_to('"rankingAssessments"','UTF8');
begin
 owner := (staygrubby.provision_account()->>'account_id')::uuid;
 perform 1 from staygrubby.accounts where id=owner for update;
 perform staygrubby.provision_account(); -- Revalidate the live session after waiting.
 if (envelope->>'accountID')::uuid is distinct from owner then
  raise exception 'Account mismatch' using errcode='42501'; end if;
 -- Already accepted operations are read-only retries. The original writer checks
 -- their complete operation identity/hash and returns the original receipt.
 if exists(select 1 from staygrubby.sync_operations where account_id=owner and operation_id=(envelope->>'operationID')::uuid) then
  return staygrubby.apply_cooking_operation_model_legacy(envelope); end if;
 payload_bytes := decode(envelope->>'payload','base64');
 if payload_bytes is null or octet_length(payload_bytes)>8388608
  or encode(sha256(payload_bytes),'hex') is distinct from envelope->>'payloadHash' then
  raise exception 'Invalid payload hash or size' using errcode='22023'; end if;
 changes := convert_from(payload_bytes,'UTF8')::jsonb;
 if changes ? 'rankingAssessmentVersion' and changes->'rankingAssessmentVersion' not in ('null'::jsonb,'1'::jsonb) then
  raise exception 'Ranking client update required' using errcode='0A000'; end if;
 if changes->'rankingAssessmentVersion' is distinct from '1'::jsonb then
  -- Conservative byte marker avoids parsing arbitrary historical opaque JSON.
  -- Deleted rows are included so a late old-device write cannot bypass adoption.
  needs_model := exists(select 1 from staygrubby.ranked_items where account_id=owner
                        and position(marker in session_diagnostics)>0);
  if not needs_model then
   select exists(select 1 from jsonb_array_elements(changes->'upserts') r
    where r->'reference'->>'entity'='rankedItem'
      and position(marker in decode(convert_from(decode(r->>'data','base64'),'UTF8')::jsonb->>'sessionDiagnosticsData','base64'))>0)
    into needs_model;
  end if;
  if needs_model then raise exception 'Ranking client update required' using errcode='0A000'; end if;
 end if;
 return staygrubby.apply_cooking_operation_model_legacy(envelope);
end $$;
revoke all on function staygrubby.apply_cooking_operation(jsonb) from public,anon;
grant execute on function staygrubby.apply_cooking_operation(jsonb) to authenticated;
-- Rebind the public invoker wrapper to the guarded writer, not the renamed core.
create or replace function api.apply_cooking_operation(envelope jsonb) returns jsonb
language sql volatile security invoker set search_path='' as $$ select staygrubby.apply_cooking_operation(envelope) $$;
revoke all on function api.apply_cooking_operation(jsonb) from public,anon;
grant execute on function api.apply_cooking_operation(jsonb) to authenticated;
comment on function staygrubby.apply_cooking_operation(jsonb) is 'Requires rankingAssessmentVersion=1 for assessment-aware data; rejects old writers atomically. Original immutable operations remain retryable.';
commit;
