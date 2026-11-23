import { randomUUID, createHash, randomBytes, createHmac } from 'node:crypto';
import { readFile, lstat } from 'node:fs/promises';
import assert from 'node:assert/strict';
import pg from 'pg';
import { verifyCurrentLocalSchema } from './local-backend-schema.mjs';

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
 const blank = (await db.query("select (select count(*) from auth.users)+(select count(*) from staygrubby.accounts)+(select count(*) from storage.objects) n")).rows[0].n;
 check(Number(blank)===0,'A fresh disposable stack is required');
 await verifyCurrentLocalSchema(db); checks++;
 for(let i=0;i<4;i++){
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
 const library = await rpc('open_account_library', users[0].token, {});
 const ranking = library.graph.rankings[0].id;
 const dishes = [randomUUID(), randomUUID()];
 for (const dish of dishes) {
  await db.query("insert into staygrubby.dishes(account_id,id,name,default_course_code,created_at_ref) values($1,$2,'Same fixture title','soup',1000)", [users[0].id,dish]);
 }
 const posts = [];
 for (let n = 0; n < 3; n++) {
  const item = randomUUID(), attempt = randomUUID(), post = randomUUID();
  await db.query("insert into staygrubby.ranked_items(account_id,id,ranking_id,name,created_at_ref,strength,uncertainty) values($1,$2,$3,'Fixture cook',1000,0,1)", [users[0].id,item,ranking]);
  await db.query("insert into staygrubby.cooking_attempts(account_id,id,dish_id,ranked_item_id,course_code,sequence_number,created_at_ref,updated_at_ref,is_legacy_import) values($1,$2,$3,$4,'soup',$5,1000,1000,false)", [users[0].id,attempt,dishes[n < 2 ? 0 : 1],item,n < 2 ? n + 1 : 1]);
  const revision = Number((await db.query('select sync_revision from staygrubby.accounts where id=$1', [users[0].id])).rows[0].sync_revision);
  const result = await action('social_content',0,'prepare',{postID:post,attemptID:attempt,expectedRevision:revision,confirmed:true});
  posts.push(result.posts[0]);
 }
 check(posts[0].dishKey === posts[1].dishKey && posts[0].dishKey !== posts[2].dishKey, 'Signed cards preserve exact Dish identity across matching titles');
 const siblings = await action('social_feed',1,'dish',{postID:posts[0].id,order:'recent'});
 check(siblings.posts.length === 1 && siblings.posts[0].id === posts[1].id, 'Signed exact-Dish lookup excludes independent same-name Dish');
 const hidden = await call('/rest/v1/rpc/social_feed',users[2].token,'POST',JSON.stringify({action:'dish',payload:{postID:posts[0].id}}),{'Content-Type':'application/json','Content-Profile':'api'});
 check(hidden.status === 403, 'Unrelated signed account cannot enumerate Dish cooks');
 await db.query('insert into staygrubby.moderation_reviewers(account_id) values($1)',[users[2].id]);
 const rid=randomUUID(),photo=randomUUID(),path=users[0].id+'/'+photo+'.jpg';
 const bytes=Buffer.from('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD3SiiiszQ//9k=','base64');
 await action('recipes',0,'prepare_photo',{assetID:photo,photoHash:createHash('sha256').update(bytes).digest('hex'),photoBytes:bytes.length});
 const upload=await call('/storage/v1/object/recipe-photos/'+path,users[0].token,'POST',bytes,{'Content-Type':'image/jpeg'});
 check(upload.ok,'Actual private Storage upload');
 await action('recipes',0,'complete_photo',{assetID:photo});
 await action('recipes',0,'save',{recipeID:rid,recipe:{title:'Local fixture',ingredients:['water'],steps:['Heat.'],photoID:photo},visibility:'friends'});
 const read=token=>call('/storage/v1/object/authenticated/recipe-photos/'+path,token,'GET');
 check((await read(users[0].token)).ok,'Owner reads original bytes');
 const sharedBytes=await read(users[1].token);
 check(sharedBytes.ok&&Buffer.from(await sharedBytes.arrayBuffer()).equals(bytes),'Peer reads shared original immediately without approval');
 check(!(await read(users[2].token)).ok,'Staff cannot browse unreported shared originals');
 check(!(await read(users[3].token)).ok,'Outsider denied shared photo');
 await action('social_report',1,'report',{targetType:'recipe',targetID:rid,sourceRevision:1,reason:'inappropriate'});
 const imageReport=(await action('moderation_review',2,'queue')).reports.find(r=>r.kind==='recipe');
 check(Boolean(imageReport),'Reported image-bearing Recipe enters existing staff queue');
 const inspected=await read(users[2].token);
 check(inspected.ok&&Buffer.from(await inspected.arrayBuffer()).equals(bytes),'Staff can inspect only an actually reported original');
 await action('moderation_review',2,'resolve',{reportID:imageReport.id,decision:'hide'});
 check(!(await read(users[1].token)).ok,'Moderator hide revokes shared bytes');
 const peerPhoto = randomUUID(), peerPath = users[1].id+'/'+peerPhoto+'.jpg';
 await action('recipes',1,'prepare_photo',{assetID:peerPhoto,photoHash:createHash('sha256').update(bytes).digest('hex'),photoBytes:bytes.length});
 check((await call('/storage/v1/object/recipe-photos/'+peerPath,users[1].token,'POST',bytes,{'Content-Type':'image/jpeg'})).ok, 'Peer private fixture uploaded');
 await action('recipes',1,'complete_photo',{assetID:peerPhoto});
 await action('recipes',1,'save',{recipeID:randomUUID(),recipe:{title:'Peer private fixture',ingredients:['water'],steps:['Heat.'],photoID:peerPhoto},visibility:'private'});
 const report=await action('social_report',1,'report',{targetType:'profile',targetID:users[0].id,reason:'other'});
 check(report.reported,'Signed report accepted');
 const queue=await action('moderation_review',2,'queue');
 await action('moderation_review',2,'resolve',{reportID:queue.reports.find(r=>r.kind==='profile').id,decision:'hide'});
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
   const denied=route==='recipe-import'
    ? await call('/functions/v1/'+route,token,'POST','{}',{'Content-Type':'application/json'})
    : await call('/functions/v1/'+route,token,'GET');
   check(denied.status===401,'Edge Gateway rejects missing-user, malformed or foreign-signature token');
  }
 }
 // Test actual Storage cleanup followed by the staged database erasure; no Apple request.
 await rpc('begin_account_deletion',users[0].token,{});
 await db.query("select api.advance_account_deletion($1,'apple_revoked')",[users[0].user]);
 const removed=await call('/storage/v1/object/recipe-photos',config.SERVICE_ROLE_KEY,'DELETE',
  JSON.stringify({prefixes:[path]}),{'Content-Type':'application/json'});
 check(removed.ok,'Disposable Storage object removed through actual service');
 await db.query("select api.advance_account_deletion($1,'storage_cleared')",[users[0].user]);
 await db.query('select api.erase_account_data($1)',[users[0].user]);
 check(!(await read(users[0].token)).ok,'Erased owner token cannot recover object bytes');
 check(Number((await db.query(`select
  (select count(*) from staygrubby.media where account_id=$1)
  +(select count(*) from staygrubby.media_backups where account_id=$1)
  +(select count(*) from staygrubby.recipe_photos where owner_id=$1) n`,[users[0].id])).rows[0].n)===0,
  'Erased owner has no remaining media metadata or manifests');
 const removedAuth = await call('/auth/v1/admin/users/'+users[0].user,config.SERVICE_ROLE_KEY,'DELETE',JSON.stringify({should_soft_delete:false}),{'Content-Type':'application/json'});
 check(removedAuth.ok,'Synthetic Auth user removed through Auth Admin');
 check(Number((await db.query('select count(*) n from auth.users where id=$1',[users[0].user])).rows[0].n) === 0, 'Erased Auth identity is absent');
 check(Number((await db.query('select count(*) n from staygrubby.account_deletion_jobs where auth_user_id=$1',[users[0].user])).rows[0].n) === 0, 'Completed deletion job is retired by Auth FK cleanup');
 const peerBytes = await call('/storage/v1/object/authenticated/recipe-photos/'+peerPath,users[1].token,'GET');
 check(peerBytes.ok && Buffer.from(await peerBytes.arrayBuffer()).equals(bytes), 'Peer private original survives another account erasure byte-for-byte');
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
