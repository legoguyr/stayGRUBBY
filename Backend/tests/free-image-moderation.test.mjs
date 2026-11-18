import { randomUUID } from 'node:crypto';
import { fixture } from './social-harness.mjs';
const { db,users,actor,rpc,cooking,check,rejects,finish } = await fixture();
const photo = randomUUID(), privatePhoto = randomUUID(), recipeID = randomUUID();
const path = id => users[0].id+'/'+id+'.jpg';
const read = async (name,operation='object.get_authenticated') => {
 await db.query("select set_config('storage.operation',$1,false)",[operation]);
 return (await db.query("select id from storage.objects where bucket_id='recipe-photos' and name=$1",[name])).rows.length;
};
const access = async name => (await db.query("select api.image_access('recipe-photos',$1) value",[name])).rows[0].value;
const inspect = async id => rpc('image_moderation','inspect',{objectID:id});
const decide = async (item,decision,hash='a'.repeat(64)) => rpc('image_moderation','resolve',{
 objectID:item.objectID,generation:item.generation,expectedState:item.state,decision,photoHash:hash
});
try {
 for (let n=0;n<4;n++) { await actor(n);await rpc('social_identity','save',{displayName:'Manual '+n,username:'manual_'+n,discoverable:true}); }
 await actor(0);await rpc('social_people','request',{peerID:users[1].id});
 await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
 for (const id of [photo,privatePhoto]) {
  await actor(0);await rpc('recipes','prepare_photo',{assetID:id,photoHash:'a'.repeat(64),photoBytes:100});
  await db.exec('reset role');await db.query("insert into storage.objects(bucket_id,name,metadata) values('recipe-photos',$1,'{\"mimetype\":\"image/jpeg\",\"size\":100}')",[path(id)]);
  await actor(0);await rpc('recipes','complete_photo',{assetID:id});
  await rpc('recipes','save',{recipeID:id===photo?recipeID:randomUUID(),recipe:{title:'Photo fixture',ingredients:['water'],steps:['Heat.'],photoID:id},visibility:id===photo?'friends':'private'});
 }
 await rejects(()=>rpc('image_moderation','capabilities'));
 await db.exec('reset role');await db.query('insert into staygrubby.moderation_reviewers(account_id) values($1)',[users[2].id]);
 const before = JSON.stringify((await db.query('select jsonb_agg(to_jsonb(o) order by id) data from storage.objects o')).rows[0].data);
 await actor(2);check((await rpc('image_moderation','capabilities')).reviewer,'Live enrolled staff capability');
 let queue = (await rpc('image_moderation','queue')).images;
 check(queue.length===1&&queue[0].state==='pending','Pending originals enter review without a worker/key/scheduler');
 await db.exec('reset role');
 const stamp = async () => (await db.query('select xmin::text,xmax::text from staygrubby.image_reviews where object_id=$1',[queue[0].objectID])).rows[0];
 const originalStamp = JSON.stringify(await stamp());
 await actor(2);
 let subject = await inspect(queue[0].objectID);
 await db.exec('reset role');check(JSON.stringify(await stamp())===originalStamp,'Inspect creates no row version or write lock on the review row');
 await actor(2);

 check(await read(subject.path)===1,'Staff can inspect pending shared original');
 await db.exec('reset role');const privateObject=(await db.query('select id from storage.objects where name=$1',[path(privatePhoto)])).rows[0].id;
 await actor(2);await rejects(()=>inspect(privateObject));
 check(await read(path(privatePhoto))===0,'Private-only original excluded from staff inspection');
 for (const op of ['object.sign','object.list','object.get_public','object.get_authenticated_transform']) {
  check(await read(subject.path,op)===0,'Staff has no alternate signed/public/list/transform access');
 }
 await actor(0);
 await db.query("select set_config('storage.operation','',false)");
 check((await rpc('recipes','photo',{assetID:photo})).id===photo,'Existing owner photo RPC works without a Storage route context');
 for (const op of ['object.sign','object.list','object.get_public','object.get_authenticated_transform']) {
  check(await read(subject.path,op)===0,'Owner cannot mint a bypass URL for a pending original');
 }
 check(await access(subject.path),'Owner retains private access');
 await actor(1);check(!await access(subject.path)&&await read(subject.path)===0,'Pending image denied to audience and cache permission RPC');
 await rejects(()=>decide(subject,'approved'));
 await rejects(()=>db.query('select * from staygrubby.image_review_actions'));
 await actor(2);await rejects(()=>decide(subject,'approved',null),'22023');
 const oldSubject = subject;
 await db.exec('reset role');await db.query('update storage.objects set metadata=metadata where id=$1',[subject.objectID]);
 await actor(2);await rejects(()=>decide(oldSubject,'approved'),'PT409');
 subject = await inspect(subject.objectID);
 check(subject.generation !== oldSubject.generation,'A pending replacement invalidates the prior human inspection');

 await rejects(()=>decide({...subject,generation:randomUUID()},'approved'),'PT409');
 check((await decide(subject,'approved')).state==='approved','A person approves a pending original directly');
 await decide(subject,'approved');
 await db.exec('reset role');
 check((await db.query('select count(*)::int n from staygrubby.image_review_actions')).rows[0].n===1,'Lost-response decision replay adds no audit/write');
 check(JSON.stringify((await db.query('select jsonb_agg(to_jsonb(o) order by id) data from storage.objects o')).rows[0].data)===before,'Approval preserves original object metadata and bytes');
 await actor(1);check(await access(subject.path)&&await read(subject.path)===1,'Eligible peer can read approved original');
 check(await read(subject.path,'object.sign')===0&&await read(subject.path,'object.get_public')===0,'Even approved content cannot mint a URL that outlives moderation');
 await actor(3);check(!await access(subject.path)&&await read(subject.path)===0,'Approval grants no new audience');
 await actor(2);subject=await inspect(subject.objectID);
 check((await decide(subject,'rejected')).state==='rejected','Staff can hide an already approved original');
 await actor(1);check(!await access(subject.path)&&await read(subject.path)===0,'Hide revokes cache reuse and new authenticated downloads');
 await actor(2);await rejects(()=>decide({...subject,state:'pending'},'approved'),'PT409');
 subject=await inspect(subject.objectID);await decide(subject,'approved');
 // Normal reporting/hide composes with image approval, with no new report system.
 await actor(1);await rpc('social_report','report',{targetType:'recipe',targetID:recipeID,sourceRevision:1,reason:'inappropriate'});
 await actor(2);const reports=(await rpc('moderation_review','queue')).reports;
 check(reports.length===1,'Existing report queue receives the image-bearing Recipe report');
 await rpc('moderation_review','resolve',{reportID:reports[0].id,decision:'hide'});
 await actor(1);check(!await access(subject.path),'Content moderation overrides a prior image approval');
 await rpc('social_people','block',{peerID:users[0].id});check(await read(subject.path)===0,'Blocking still overrides image approval');
 await actor(0);await rpc('recipes','save',{recipeID,expectedRevision:1,recipe:{title:'Photo fixture',ingredients:['water'],steps:['Heat.'],photoID:photo},visibility:'private'});
 await actor(2);await rejects(()=>inspect(subject.objectID));
 check((await rpc('image_moderation','queue',{reviewState:'approved'})).images.length===0,'Withdrawn shared Recipe original leaves the staff browser');
 await db.exec('reset role');await db.query('delete from staygrubby.moderation_reviewers where account_id=$1',[users[2].id]);
 await actor(2);await rejects(()=>rpc('image_moderation','queue'));
 // Test optional future worker cannot auto-approve under manual MVP policy.
 const graph=await cooking(3);await actor(3);
 const post=(await rpc('social_content','prepare',{postID:randomUUID(),attemptID:graph.attempts[0],expectedRevision:0,confirmed:true,includePhoto:true})).posts[0];
 await db.exec('reset role');await db.query("insert into storage.objects(bucket_id,name,metadata) values('social-photos',$1,'{\"mimetype\":\"image/jpeg\",\"size\":100}')",[post.photoPath]);
 await db.exec('set role service_role');const claims=(await db.query('select api.claim_image_reviews() rows')).rows[0].rows;
 const claim=claims.find(c=>c.path===post.photoPath);
 check((await db.query('select api.finish_image_review($1,$2,$3,$4,$5) done',[claim.objectID,claim.generation,claim.leaseID,'approved','b'.repeat(64)])).rows[0].done,'Optional validator receipt accepted');
 await db.exec('reset role');
 check((await db.query('select state from staygrubby.image_reviews where object_id=$1',[claim.objectID])).rows[0].state==='review','A worker allow verdict cannot substitute for a human');
 await db.query('insert into staygrubby.moderation_reviewers(account_id) values($1)',[users[3].id]);
 await actor(3);const own=await inspect(claim.objectID);
 check((await decide(own,'approved','b'.repeat(64))).state==='approved','A named operator may review their own shared image with the same audit');
 await db.exec('reset role');
 // Owner-controlled deletion cascades only that owner's image review evidence.
 await actor(0);await db.query('select api.begin_account_deletion()');
 await db.exec('reset role;set role service_role');
 await db.query("select api.advance_account_deletion($1,'apple_revoked')",[users[0].user]);await db.query("select api.advance_account_deletion($1,'storage_cleared')",[users[0].user]);
 await rejects(()=>db.query('select api.erase_account_data($1)',[users[0].user]),'55000');
 await db.exec('reset role');await db.query('delete from storage.objects where name like $1',[users[0].id+'/%']);
 await db.exec('set role service_role');await db.query('select api.erase_account_data($1)',[users[0].user]);
 await db.exec('reset role');
 check((await db.query('select count(*)::int n from staygrubby.image_review_actions where account_id=$1',[users[0].id])).rows[0].n===0,'Account erasure leaves no orphan image decision evidence');
 check((await db.query('select count(*)::int n from storage.objects where name=$1',[post.photoPath])).rows[0].n===1,'Another account original survives erasure unchanged');
 check((await db.query('select count(*)::int n from staygrubby.image_review_actions where account_id=$1',[users[3].id])).rows[0].n===1,'Other account decision evidence also survives');
 await db.exec('set role anon');check(await read(post.photoPath)===0,'Anonymous/public object access denied');
} finally { await finish(); }
