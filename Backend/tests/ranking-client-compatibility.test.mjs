import {fixture} from './social-harness.mjs';
import {readFile,readdir} from 'node:fs/promises';
import {randomUUID,createHash} from 'node:crypto';
const dir=new URL('../../supabase/migrations/',import.meta.url);
const migration=(await readdir(dir)).find(f=>f.endsWith('_ranking_assessment_client_guard.sql'));
const {db,users,actor,cooking,check,rejects,finish}=await fixture({before:migration});
await cooking(0,2);await cooking(1);const owner=users[0].id;
async function graph(){return(await db.query('select api.open_account_library() value')).rows[0].value.graph;}
async function fingerprint(){await db.exec('reset role');return JSON.stringify((await db.query(`select name,md5(rows::text) hash from (select 'items' name,jsonb_agg(to_jsonb(r) order by account_id,id) rows from staygrubby.ranked_items r union all select 'evidence',jsonb_agg(to_jsonb(c) order by account_id,id) from staygrubby.comparisons c union all select 'accounts',jsonb_agg(to_jsonb(a) order by id) from staygrubby.accounts a union all select 'receipts',jsonb_agg(to_jsonb(o) order by account_id,operation_id) from staygrubby.sync_operations o union all select 'storage',jsonb_agg(to_jsonb(s) order by id) from storage.objects s) x order by name`)).rows);}
function record(entity,data){return{reference:{entity,key:data.id},data:Buffer.from(JSON.stringify(data)).toString('base64')};}
async function envelope(upserts=[],version=null,account=owner){const revision=(await db.query('select sync_revision n from staygrubby.accounts where id=$1',[account])).rows[0].n;const payload=Buffer.from(JSON.stringify({photoCollectionVersion:1,...(version===null?{}:{rankingAssessmentVersion:version}),upserts,deletions:[]}));return{operationID:randomUUID(),storeID:randomUUID(),accountID:account,kind:'appendEvidence',payload:payload.toString('base64'),payloadHash:createHash('sha256').update(payload).digest('hex'),expectedRevision:Number(revision)};}
async function send(value){return(await db.query('select api.apply_cooking_operation($1::jsonb) value',[JSON.stringify(value)])).rows[0].value;}
await actor(0);let original=await graph();const item=original.items[0],opponent=original.items[1];
const pair={id:randomUUID(),rankingID:item.rankingID,firstItemID:item.id,secondItemID:opponent.id,preferredItemID:item.id,isTie:false,timestamp:1001};
const acceptedOld=await envelope([record('comparison',pair)]);const oldReceipt=await send(acceptedOld);
const before=await fingerprint();await db.exec(await readFile(new URL(migration,dir),'utf8'));
check(before===await fingerprint(),'migration preserves original data, evidence, account revisions, receipts and Storage');
await actor(0);const legacy=await envelope([record('rankedItem',{...item,name:'Legacy before assessment'})]);await send(legacy);
check((await graph()).items.find(r=>r.id===item.id).name==='Legacy before assessment','legacy stationary library remains writable before adoption');
const metadata=Buffer.from(JSON.stringify({initialReaction:'It was fine',rankingAssessments:[{parameterID:randomUUID(),comparisonIDs:[pair.id]}]})).toString('base64');
const assessed={...item,strength:-0.5,sessionDiagnosticsData:metadata};
const noCapability=await envelope([record('rankedItem',assessed)]);let snapshot=await fingerprint();await actor(0);
await rejects(()=>send(noCapability),'0A000');check(snapshot===await fingerprint(),'old client cannot introduce assessments without capability; no mutation/receipt');
await actor(0);const modern=await envelope([record('rankedItem',assessed)],1);await send(modern);
check((await graph()).items.find(r=>r.id===item.id).sessionDiagnosticsData===metadata,'modern client assessment metadata restores byte-identically');
const legacyOverwrite=await envelope([record('rankedItem',{...item,strength:2,sessionDiagnosticsData:null})]);snapshot=await fingerprint();await actor(0);
await rejects(()=>send(legacyOverwrite),'0A000');check(snapshot===await fingerprint(),'legacy cache overwrite or epoch removal is rejected atomically');
await actor(0);await rejects(async()=>send(await envelope([],2)),'0A000');
const receipt=await send(acceptedOld);check(JSON.stringify(receipt)===JSON.stringify(oldReceipt),'pre-adoption accepted operation still retries with its original receipt');
await rejects(()=>db.query('select staygrubby.apply_cooking_operation_model_legacy($1::jsonb)',[JSON.stringify(modern)]),'42501');
await actor(1);await rejects(()=>send(modern),'42501');
await db.exec('reset role;set role anon');await rejects(()=>send(modern),'42501');
await actor(1);const own=users[1].id,ownItem=(await graph()).items[0];await send(await envelope([record('rankedItem',ownItem)],null,own));check(true,'another stationary account is unaffected');
await db.exec('reset role');
check((await db.query("select not has_function_privilege('anon','api.apply_cooking_operation(jsonb)','execute') ok")).rows[0].ok,'anonymous API access remains denied');
check((await db.query("select not has_function_privilege('authenticated','staygrubby.apply_cooking_operation_model_legacy(jsonb)','execute') ok")).rows[0].ok,'authenticated direct legacy writer cannot bypass guard');
check((await db.query("select count(*)::int n from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='staygrubby' and c.relkind='r' and not c.relrowsecurity")).rows[0].n===0,'all application tables retain RLS');
check((await db.query('select count(*)::int n from storage.objects')).rows[0].n===0,'no photo bytes or Storage objects created');
await finish();
