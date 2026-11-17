import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { fixture } from './social-harness.mjs';

const migration='20261117200054_image_moderation_foundation.sql';
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture({before:migration});
const rid=randomUUID(),privateRecipe=randomUUID(),recipePhoto=randomUUID(),privatePhoto=randomUUID();
const postID=randomUUID(),avatar=randomUUID(),peerPhoto=randomUUID(),peerRecipe=randomUUID();
const path=(n,id)=>users[n].id+'/'+id+'.jpg';
const object=async(bucket,name)=>db.query("insert into storage.objects(bucket_id,name,metadata) values($1,$2,$3) returning id",
 [bucket,name,JSON.stringify({mimetype:'image/jpeg',size:100})]);
const read=async(bucket,name)=>(await db.query('select name from storage.objects where bucket_id=$1 and name=$2',[bucket,name])).rows.length;
const worker=async()=>{await db.exec('reset role;set role service_role');return(await db.query('select api.claim_image_reviews() rows')).rows[0].rows;};
const settle=async(item,state='approved')=>(await db.query('select api.finish_image_review($1,$2,$3,$4,$5) value',
 [item.objectID,item.generation,item.leaseID,state,'a'.repeat(64)])).rows[0].value;
const recipe={title:'Image fixture',ingredients:['water'],steps:['Heat.']};

try{
 for(let n=0;n<4;n++){await actor(n);await rpc('social_identity','save',{displayName:'Image '+n,username:'image_fixture_'+n,discoverable:true});}
 await actor(0);await rpc('social_people','request',{peerID:users[1].id});
 await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
 await actor(1);
 await rpc('recipes','prepare_photo',{assetID:peerPhoto,photoHash:'b'.repeat(64),photoBytes:100});
 await db.exec('reset role');await object('recipe-photos',path(1,peerPhoto));
 await actor(1);await rpc('recipes','complete_photo',{assetID:peerPhoto});
 await rpc('recipes','save',{recipeID:peerRecipe,recipe:{...recipe,photoID:peerPhoto},visibility:'private'});
 const graph=await cooking(0);
 await actor(0);
 for(const id of [recipePhoto,privatePhoto]){
  await rpc('recipes','prepare_photo',{assetID:id,photoHash:'a'.repeat(64),photoBytes:100});
  await db.exec('reset role');await object('recipe-photos',path(0,id));
  await actor(0);await rpc('recipes','complete_photo',{assetID:id});
 }
 await rpc('recipes','save',{recipeID:rid,recipe:{...recipe,photoID:recipePhoto},visibility:'friends'});
 await rpc('recipes','save',{recipeID:privateRecipe,recipe:{...recipe,photoID:privatePhoto},visibility:'private'});
 const post=(await rpc('social_content','prepare',{postID,attemptID:graph.attempts[0],expectedRevision:0,confirmed:true,includePhoto:true})).posts[0];
 await db.query("set storage.operation='object.upload'");await object('social-photos',post.photoPath);
 await rpc('social_content','publish',{postID});
 const draft=await rpc('social_avatar','prepare',{assetID:avatar});
 await object('profile-photos',draft.path);
 await rpc('social_avatar','publish',{avatarPath:draft.path});
 await actor(1);
 await db.query("set storage.operation='object.get_authenticated'");
 check(await read('recipe-photos',path(0,recipePhoto))===1,'Peer had eligible access before image gate');
 await db.exec('reset role');
 const preserved=async()=>JSON.stringify((await db.query("select jsonb_build_object('recipes',(select jsonb_agg(to_jsonb(r) order by id) from staygrubby.recipes r),'posts',(select jsonb_agg(to_jsonb(p) order by id) from staygrubby.social_posts p),'storage',(select jsonb_agg(to_jsonb(o) order by id) from storage.objects o)) value")).rows[0].value);
 const before=await preserved();
 await db.exec(await readFile(new URL('../../supabase/migrations/'+migration,import.meta.url),'utf8'));
 check(await preserved()===before,'Migration queues metadata without mutating content or Storage');
 check((await db.query('select count(*)::int n from staygrubby.image_reviews')).rows[0].n===3,'Only the three share-eligible originals were queued');
 for(const [bucket,name] of [['recipe-photos',path(0,recipePhoto)],['social-photos',post.photoPath],['profile-photos',draft.path]]){
  await actor(0);check(await read(bucket,name)===1,'Owner reads pending original');
  await actor(1);check(await read(bucket,name)===0,'Peer cannot read unapproved bytes');
 }
 await rejects(()=>rpc('image_moderation','queue'));
 await rejects(()=>db.query('select api.claim_image_reviews()'));
 await rejects(()=>db.query('select * from staygrubby.image_reviews'));
 let claims=await worker();
 check(claims.length===3,'Worker claims a bounded batch');
 check((await db.query('select api.claim_image_reviews() rows')).rows[0].rows.length===0,'Lease prevents overlapping workers');
 const recipeWork=claims.find(c=>c.bucket==='recipe-photos');
 const avatarWork=claims.find(c=>c.bucket==='profile-photos');
 const postWork=claims.find(c=>c.bucket==='social-photos');
 check(await settle(recipeWork),'Automated allow commits exact current claim');
 await db.exec('reset role');
 await rejects(()=>db.query("update storage.objects set metadata=metadata where id=$1",[recipeWork.objectID]),'PT409');
 await db.exec('set role service_role');
 check(!await settle(recipeWork),'Duplicate result is a no-op');
 check(await settle(avatarWork,'review')&&await settle(postWork,'rejected'),'Uncertain and flagged originals enter human review');
 await actor(1);
 check(await read('recipe-photos',path(0,recipePhoto))===1,'Approved Recipe image is visible under prior audience rules');
 check(await read('social-photos',post.photoPath)===0&&await read('profile-photos',draft.path)===0,'Review and rejected images stay private');
 await actor(2);await rejects(()=>rpc('image_moderation','queue'));
 await db.exec('reset role');await db.query('insert into staygrubby.moderation_reviewers values($1)',[users[2].id]);
 await actor(2);
 const queue=(await rpc('image_moderation','queue')).images;
 check(queue.length===2,'Staff queue reuses moderator membership');
 const subject=await rpc('image_moderation','inspect',{objectID:avatarWork.objectID});
 check(subject.accountID===users[0].id&&subject.path===draft.path,'Staff gets scoped evidence pointer without a signed URL');
 check(await read('profile-photos',draft.path)===1&&await read('social-photos',post.photoPath)===1,'Authorized staff can inspect flagged originals');
 check(await read('recipe-photos',path(0,privatePhoto))===0&&await read('recipe-photos',path(0,recipePhoto))===0,'Staff queue access never opens private-only or approved unrelated images');
 await db.query("set storage.operation='object.sign'");
 check(await read('profile-photos',draft.path)===0,'Staff inspection cannot mint a persistent signed image URL');
 await db.query("set storage.operation='object.get_authenticated'");
 await rejects(()=>rpc('image_moderation','resolve',{objectID:avatarWork.objectID,generation:randomUUID(),decision:'approved'}),'PT409');
 check((await rpc('image_moderation','resolve',{objectID:avatarWork.objectID,generation:avatarWork.generation,decision:'approved'})).state==='approved','Human approves one inspected generation');
 check((await rpc('image_moderation','resolve',{objectID:avatarWork.objectID,generation:avatarWork.generation,decision:'approved'})).state==='approved','Human lost-response replay is idempotent');
 await rejects(()=>rpc('image_moderation','resolve',{objectID:avatarWork.objectID,generation:avatarWork.generation,decision:'rejected'}),'PT409');
 await actor(1);check(await read('profile-photos',draft.path)===1,'Human approved avatar is visible to eligible peer');
 await actor(3);check(await read('recipe-photos',path(0,recipePhoto))===0,'Approval never creates Recipe access for an outsider');
 await actor(1);await rpc('social_people','block',{peerID:users[0].id});
 check(await read('recipe-photos',path(0,recipePhoto))===0&&await read('profile-photos',draft.path)===0,'Block revokes approved bytes');

 // The original social image is immutable after publish for ordinary clients.
 // A privileged byte replacement must invalidate every previous worker generation.
 await db.exec('reset role');
 await db.query("update storage.objects set metadata=$1 where bucket_id='social-photos' and name=$2",[JSON.stringify({mimetype:'image/jpeg',size:101}),post.photoPath]);
 claims=await worker();
 const replacement=claims.find(c=>c.bucket==='social-photos');
 check(replacement.generation!==postWork.generation,'Object update invalidates prior verdict');
 check(!await settle(postWork),'Stale worker cannot approve replacement bytes');
 check(await settle(replacement,'unavailable'),'Provider failure records bounded cooldown');
 check((await db.query('select api.claim_image_reviews() rows')).rows[0].rows.length===0,'Cooldown avoids immediate reclaim');
 for(let n=0;n<2;n++){
  await db.exec('reset role');await db.query("update staygrubby.image_reviews set next_attempt_at=now()-interval '1 second' where object_id=$1",[replacement.objectID]);
  const next=(await worker()).find(c=>c.objectID===replacement.objectID);
  check(Boolean(next),'Retry is available within the bounded allowance');
  await settle(next,'unavailable');
 }
 await db.exec('reset role');
 check((await db.query('select state,attempts from staygrubby.image_reviews where object_id=$1',[replacement.objectID])).rows[0].state==='review','Third failure waits for human review');
 await db.query('delete from staygrubby.moderation_reviewers where account_id=$1',[users[2].id]);
 await actor(2);await rejects(()=>rpc('image_moderation','queue'));
 check(await read('social-photos',post.photoPath)===0,'Removing reviewer membership revokes image inspection');
 await db.exec('reset role');
 await db.query("delete from storage.objects where bucket_id='social-photos' and name=$1",[post.photoPath]);
 check((await db.query('select object_id from staygrubby.image_reviews where object_id=$1',[replacement.objectID])).rows.length===0,'Deleting original object removes technical review metadata');
 // Delete the fixture owner through the production erasure state machine.
 await actor(0);
 await db.query('select api.begin_account_deletion()');
 await db.exec('reset role;set role service_role');
 await db.query("select api.advance_account_deletion($1,'apple_revoked')",[users[0].user]);
 await db.query("select api.advance_account_deletion($1,'storage_cleared')",[users[0].user]);
 await rejects(()=>db.query('select api.erase_account_data($1)',[users[0].user]),'55000');
 await db.exec('reset role');await db.query('delete from storage.objects where name like $1',[users[0].id+'/%']);
 await db.exec('set role service_role');
 check((await db.query('select api.erase_account_data($1) value',[users[0].user])).rows[0].value.state==='account_erased','Erasure completes after Storage cleanup with review FKs intact');
 await db.exec('reset role');
 check((await db.query('select count(*)::int n from staygrubby.image_reviews')).rows[0].n===0,'Erasure leaves no orphan reviews');
 check((await db.query('select count(*)::int n from staygrubby.accounts where id=$1',[users[1].id])).rows[0].n===1,'Peer account remains intact');
 await actor(1);
 check((await rpc('recipes','get',{recipeID:peerRecipe})).content.photoID===peerPhoto
  && await read('recipe-photos',path(1,peerPhoto))===1,'Other account private Recipe and original photo survive unchanged');
}finally{await finish();}
