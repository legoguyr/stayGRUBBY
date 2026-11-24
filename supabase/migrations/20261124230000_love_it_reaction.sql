-- Love It: fourth first-impression reaction (owner, November 24, 2026). Same presentation transform as
-- ScoreCalibration.swift version 2. No table, column, grant, ranking, evidence or snapshot change;
-- growth: none. Replaces only the pure helper used for genuinely new social snapshots; existing
-- social snapshots keep their stored score text.
-- Reaction precedence (mirrors the client): `semanticReaction` while scoreCalibrationVersion >= 2,
-- else `latestSemanticReaction`, else `initialSemanticReaction`, else `initialReaction`, else the
-- legacy 1-10 mapping. Builds up to 1.0 (9) write Love It nowhere; new builds also write Liked it
-- into the original fields, so before this migration a Love It cook already scores in the Liked band.
begin;
create or replace function staygrubby.calibrated_cooking_score(strength double precision,diagnostics bytea) returns double precision
language plpgsql immutable security invoker set search_path='' as $$
declare record jsonb; reaction text; x double precision; lo double precision:=1; span double precision:=9; e double precision;
 known constant text[]:=array['Loved it','Liked it','It was fine','Didn''t like it'];
begin
 begin record:=convert_from(diagnostics,'UTF8')::jsonb;
 exception when others then record:=null; end;
 if jsonb_typeof(record)='object' then
  if jsonb_typeof(record->'scoreCalibrationVersion')='number' and (record->>'scoreCalibrationVersion') ~ '^[0-9]+$'
     and (record->>'scoreCalibrationVersion')::numeric>=2 and jsonb_typeof(record->'semanticReaction')='string'
     and record->>'semanticReaction'=any(known) then reaction:=record->>'semanticReaction';
  elsif jsonb_typeof(record->'latestSemanticReaction')='string' and record->>'latestSemanticReaction'=any(known) then reaction:=record->>'latestSemanticReaction';
  elsif jsonb_typeof(record->'initialSemanticReaction')='string' and record->>'initialSemanticReaction'=any(known) then reaction:=record->>'initialSemanticReaction';
  elsif jsonb_typeof(record->'initialReaction')='string' and record->>'initialReaction'=any(known) then reaction:=record->>'initialReaction';
  end if;
 end if;
 if strength is null or strength in ('Infinity'::float8,'-Infinity'::float8,'NaN'::float8) then strength:=0; end if;
 x:=strength/2;
 if reaction='Loved it' then lo:=7; span:=3; x:=strength/1.6+0.4;
 elsif reaction='Liked it' then lo:=7; span:=3; x:=strength/1.6-0.4;
 elsif reaction='It was fine' then lo:=4.8; span:=3; x:=strength/1.6;
 elsif reaction='Didn''t like it' then lo:=1; span:=4.8; x:=strength/1.6;
 end if;
 -- Stable sigmoid, matching the client without exponential overflow.
 e:=exp(-least(abs(x),700));
 return lo+span*(case when x>=0 then 1/(1+e) else e/(1+e) end);
end $$;
revoke all on function staygrubby.calibrated_cooking_score(double precision,bytea) from public,anon,authenticated;
commit;
