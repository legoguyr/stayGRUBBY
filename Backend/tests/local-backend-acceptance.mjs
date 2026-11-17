import { randomUUID, createHash, randomBytes, createHmac } from 'node:crypto';
import { readFile, lstat } from 'node:fs/promises';
import assert from 'node:assert/strict';
import pg from 'pg';

// Explicit disposable local stack only. Never accepts a hosted URL or existing accounts.
// The operator generates a private status JSON with their local CLI. No values are logged.
async function loadConfig() {
 try {
  const file=process.env.SG_LOCAL_STATUS;
  assert(file?.startsWith('/private/tmp/'));
  const stat=await lstat(file);
  assert(stat.isFile()&&stat.uid===process.getuid()&&(stat.mode&0o077)===0&&stat.size<65536);
  const config=JSON.parse(await readFile(file,'utf8'));
  for(const key of ['API_URL','DB_URL']){
   const url=new URL(config[key]);
   assert(['127.0.0.1','localhost','[::1]'].includes(url.hostname));
   assert(url.protocol===(key==='API_URL'?'http:':'postgresql:')||key==='DB_URL'&&url.protocol==='postgres:');
  }
  assert(config.ANON_KEY&&config.SERVICE_ROLE_KEY);
  return config;
 } catch {
  console.error('FAIL local configuration: use an owner-only status JSON for a fresh loopback Supabase stack');
  process.exit(1);
 }
}
const config=await loadConfig();
const api=new URL(config.API_URL);
const db = new pg.Client({ connectionString: config.DB_URL, connectionTimeoutMillis: 5000 });
let checks = 0;
const users = [];
const check = (value, message) => { assert.ok(value, message); checks++; };
async function call(path, token, method='POST', body, extra={}) {
 return await fetch(new URL(path,api), {
  method, headers: { apikey:token===config.SERVICE_ROLE_KEY?config.SERVICE_ROLE_KEY:config.ANON_KEY,Authorization:'Bearer '+token,...extra },
  body, redirect:'error', signal:AbortSignal.timeout(12000)
 });
}
async function rpc(name, token, payload) {
 const r=await call('/rest/v1/rpc/'+name,token,'POST',JSON.stringify(payload),{
  'Content-Type':'application/json','Content-Profile':'api'
 });
 assert(r.ok,'Local RPC failed: '+name+' HTTP '+r.status);
 return await r.json();
}
async function action(name,n,action,payload={}) {
 return rpc(name,users[n].token,{action,payload});
}

try {
 await db.connect();
 const blank = (await db.query("select (select count(*) from auth.users)+(select count(*) from staygrubby.accounts) n")).rows[0].n;
 check(Number(blank)===0,'A fresh disposable stack is required');
 check(Boolean((await db.query("select to_regclass('staygrubby.image_reviews') object")).rows[0].object),'Reviewed migrations must already be replayed');
 for(let i=0;i<3;i++){
  const email='fixture-'+randomUUID()+'@example.invalid', password=randomBytes(24).toString('hex');
  const created=await call('/auth/v1/admin/users',config.SERVICE_ROLE_KEY,'POST',JSON.stringify({
   email,password,email_confirm:true
  }),{'Content-Type':'application/json'});
  assert(created.ok,'Local Auth fixture creation failed');
  const user=await created.json();
  const sessionResponse=await call('/auth/v1/token?grant_type=password',config.ANON_KEY,'POST',
   JSON.stringify({email,password}),{'Content-Type':'application/json'});
  assert(sessionResponse.ok,'Local fixture sign-in failed');
  const session=await sessionResponse.json();
  const account=await rpc('provision_account',session.access_token,{});
  users.push({user:user.id,token:session.access_token,id:account.account_id});
  await action('social_identity',i,'save',{username:'local_fixture_'+i,displayName:'Fixture '+i,discoverable:true});
 }
 await action('social_people',0,'request',{peerID:users[1].id});
 await action('social_people',1,'accept',{peerID:users[0].id});
 const rid=randomUUID(),photo=randomUUID(),path=users[0].id+'/'+photo+'.jpg';
 const bytes=Buffer.from('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD3SiiiszQ//9k=','base64');
 await action('recipes',0,'prepare_photo',{assetID:photo,photoHash:createHash('sha256').update(bytes).digest('hex'),photoBytes:bytes.length});
 const upload=await call('/storage/v1/object/recipe-photos/'+path,users[0].token,'POST',bytes,{'Content-Type':'image/jpeg'});
 check(upload.ok,'Actual private Storage upload');
 await action('recipes',0,'complete_photo',{assetID:photo});
 await action('recipes',0,'save',{recipeID:rid,recipe:{title:'Local fixture',ingredients:['water'],steps:['Heat.'],photoID:photo},visibility:'friends'});
 const read=token=>call('/storage/v1/object/authenticated/recipe-photos/'+path,token,'GET');
 check((await read(users[0].token)).ok,'Owner reads pending bytes');
 check(!(await read(users[1].token)).ok,'Peer denied until screened');
 const claims=await rpc('claim_image_reviews',config.SERVICE_ROLE_KEY,{});
 const claim=claims.find(c=>c.path===path);
 assert(claim,'Local upload must have pending screening work');
 const approved=await rpc('finish_image_review',config.SERVICE_ROLE_KEY,{
  object_id:claim.objectID,generation:claim.generation,lease_id:claim.leaseID,outcome:'approved',
  sha256:createHash('sha256').update(bytes).digest('hex')
 });
 check(approved,'Synthetic provider verdict accepted on the exact lease');
 const approvedBytes=await read(users[1].token);
 check(approvedBytes.ok&&Buffer.from(await approvedBytes.arrayBuffer()).equals(bytes),'Actual authorized byte round trip');
 check(!(await read(users[2].token)).ok,'Outsider denied approved photo');
 const report=await action('social_report',1,'report',{targetType:'profile',targetID:users[0].id,reason:'other'});
 check(report.reported,'Signed report accepted');
 await db.query('insert into staygrubby.moderation_reviewers(account_id) values($1)',[users[2].id]);
 const queue=await action('moderation_review',2,'queue');
 await action('moderation_review',2,'resolve',{reportID:queue.reports[0].id,decision:'hide'});
 check((await action('recipes',0,'get',{recipeID:rid})).id===rid,'Hidden-profile owner retains signed personal Recipe read');
 check(!(await read(users[1].token)).ok,'Profile hide revokes actual shared bytes');
 const denied=await call('/rest/v1/rpc/moderation_review',users[1].token,'POST',JSON.stringify({action:'queue',payload:{}}),{
  'Content-Type':'application/json','Content-Profile':'api'
 });
 check(denied.status===403,'Unrelated signed user denied staff access');

 // These actual Edge routes must be served locally with JWT verification enabled.
 // Empty Recipe request and GET erasure stop before provider or account mutation.
 const format=await call('/functions/v1/recipe-import',users[0].token,'POST','{}',{'Content-Type':'application/json'});
 check(format.status===400&&(await format.json()).code==='invalid_request','Signed Recipe function reaches authenticated validation without Gemini');
 const deletion=await call('/functions/v1/delete-account',users[0].token,'GET');
 check(deletion.status===405,'Signed deletion probe stops before deletion');
 const encode=value=>Buffer.from(JSON.stringify(value)).toString('base64url');
 const foreignUnsigned=encode({alg:'HS256',typ:'JWT'})+'.'+encode({sub:users[0].user,role:'authenticated',aud:'authenticated',exp:Math.floor(Date.now()/1000)+300});
 const foreignToken=foreignUnsigned+'.'+createHmac('sha256',randomBytes(32)).update(foreignUnsigned).digest('base64url');
 for(const route of ['recipe-import','delete-account']){
  for(const token of ['invalid-fixture-token',config.ANON_KEY,foreignToken]){
   const denied=await call('/functions/v1/'+route,token,'GET');
   check(denied.status===401,'Edge Gateway rejects missing-user, malformed or foreign-signature token');
  }
 }
 // Test actual Storage cleanup followed by the staged database erasure; no Apple request.
 await rpc('begin_account_deletion',users[0].token,{});
 await db.query("select api.advance_account_deletion($1,'apple_revoked')",[users[0].user]);
 await db.query("select api.advance_account_deletion($1,'storage_cleared')",[users[0].user]);
 const removed=await call('/storage/v1/object/recipe-photos',config.SERVICE_ROLE_KEY,'DELETE',
  JSON.stringify({prefixes:[path]}),{'Content-Type':'application/json'});
 check(removed.ok,'Disposable Storage object removed through actual service');
 await db.query('select api.erase_account_data($1)',[users[0].user]);
 check(!(await read(users[0].token)).ok,'Erased owner token cannot recover object bytes');
 check(Number((await db.query('select count(*) n from staygrubby.image_reviews')).rows[0].n)===0,'No orphan image review');
 check((await action('social_identity',1,'get')).username==='local_fixture_1','Peer account remains intact');
 console.log('PASS '+checks+' local signed Auth, Edge, Storage and moderation checks; synthetic accounts only');
} catch (error) {
 console.error('FAIL local acceptance; '+(error instanceof assert.AssertionError?error.message:'operation failed; inspect local redacted service logs'));
 process.exitCode=1;
} finally {
 await db.end();
 // Deliberately leave the disposable stack for inspection. Delete it only through
 // the local CLI after recording results. No cleanup path can target a hosted service.
}
