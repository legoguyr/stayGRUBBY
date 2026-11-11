import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';

const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture();
try {
 for (let n=0;n<4;n++) {
  await actor(n);
  await rpc('social_identity','save',{displayName:'Test cook '+n,username:'next_cook_'+n,discoverable:true});
 }
 for (const n of [1,2]) {
  await actor(0); await rpc('social_people','request',{peerID:users[n].id});
  await actor(n); await rpc('social_people','accept',{peerID:users[0].id});
 }
 const a=await cooking(0,12), b=await cooking(1);
 const cook=a.attempts[0], old=a.attempts[1], photoCook=a.attempts[2], postID=randomUUID();
 // Stable tie break by timestamp, then identity. One older version of the same dish.
 await db.query('update staygrubby.cooking_attempts set dish_id=(select dish_id from staygrubby.cooking_attempts where account_id=$1 and id=$2),sequence_number=2 where account_id=$1 and id=$3',[users[0].id,cook,old]);
 await db.query('update staygrubby.ranked_items set strength=0,created_at_ref=1001 where account_id=$1 and id=(select ranked_item_id from staygrubby.cooking_attempts where account_id=$1 and id=$2)',[users[0].id,old]);
 const prepare={attemptID:cook,postID,expectedRevision:0,confirmed:true,includeRankSnapshot:true,postDescription:'Shared explicitly'};
 await actor(0);
 check((await rpc('social_content','source',{attemptID:cook})).posts.length===0,'Unsynced/unpublished cook has no visible post');
 await rejects(()=>rpc('social_content','prepare',{...prepare,expectedRevision:99}),'PT409');
 const published=(await rpc('social_content','prepare',prepare)).posts[0];
 check(published.published && published.scoreText && published.rankAtSharing===11 && published.rankedCountAtSharing===12 && !published.recipeID,'Server-derived tie order and eligible total on a post with no Recipe');
 const replay=(await rpc('social_content','prepare',{...prepare,postID:randomUUID()})).posts[0];
 check(replay.id===postID&&replay.rankAtSharing===11,'Manual and automatic publication reconcile to one post');
 check((await rpc('social_content','source',{attemptID:cook})).posts[0].id===postID,'Exact cook owner lookup returns already published post');
 await rpc('social_content','cancelDraft',{postID});
 check((await rpc('social_content','source',{attemptID:cook})).posts[0].id===postID,'Lost publish reply followed by cancel cannot delete published post');
 const legacy=(await rpc('social_content','prepare',{...prepare,postID:randomUUID(),attemptID:old,includeRankSnapshot:undefined})).posts[0];
 check(legacy.scoreText && legacy.rankAtSharing===undefined,'Older clients retain the score-only disclosure contract');
 const suppressed=(await rpc('social_content','prepare',{...prepare,postID:randomUUID(),attemptID:a.attempts[3],omitScore:true})).posts[0];
 check(!suppressed.scoreText && suppressed.rankAtSharing===undefined,'Local lock prevents an unlocked server snapshot from leaking score or position');
 const photo=(await rpc('social_content','prepare',{...prepare,postID:randomUUID(),attemptID:photoCook,includePhoto:true})).posts[0];
 check(!photo.published && (await rpc('social_content','source',{attemptID:photoCook})).posts.length===0,'Unpublished photo draft stays out of reconciliation');
 await rejects(()=>rpc('social_content','publish',{postID:photo.id}),'55000');
 await db.query("select set_config('storage.operation','object.upload',false)");
 await db.query("insert into storage.objects(bucket_id,name,metadata) values('social-photos',$1,'{\"mimetype\":\"image/jpeg\",\"size\":512}')",[photo.photoPath]);
 const photoPost=(await rpc('social_content','publish',{postID:photo.id})).posts[0];
 check(photoPost.published && photoPost.rankAtSharing!==undefined,'Real social photo object gates only that selected photo post');
 await actor(1);
 check((await rpc('social_content','source',{attemptID:cook})).posts.length===0,'Sous Chef cannot resolve an owner-only cook identifier');
 const locked=(await rpc('social_content','prepare',{...prepare,postID:randomUUID(),attemptID:b.attempts[0]})).posts[0];
 check(!locked.scoreText && locked.rankedCountAtSharing===undefined,'Server lock omits the entire snapshot');
 const before=(await rpc('social_feed','post',{postID})).posts[0];
 check(before.rankAtSharing===11,'Authorized recipient sees creator rank, not viewer rank');
 await actor(3);
 await rejects(()=>rpc('social_feed','post',{postID}));

 await actor(0);
 const read=()=>rpc('social_cooking','edit_selection',{attemptID:cook});
 const update=(token,ids)=>rpc('social_cooking','update_selection',{attemptID:cook,selectionToken:token,participantIDs:ids,confirmed:true});
 const empty=await read();
 check(empty.selectedIDs.length===0 && empty.event===null,'Existing cook starts with exact empty selection');
 check((await rpc('social_cooking','eligible_selection',{query:'Test cook 2'})).people.map(p=>p.id).join()===users[2].id,'Search returns eligible Sous Chefs by display name');
 await rejects(()=>update(empty.selectionToken,[users[3].id]));
 await rejects(()=>update(empty.selectionToken,[users[1].id,users[1].id]),'22023');
 const first=await update(empty.selectionToken,[users[1].id]);
 check(first.event.participants[0].state==='pending' && first.selectedIDs[0]===users[1].id,'Adds invitation to previously shared cook');
 check((await update(empty.selectionToken,[users[1].id])).event.id===first.event.id,'Lost response retries stable event');
 await rejects(()=>update(empty.selectionToken,[users[2].id]),'PT409');
 await actor(1);
 await rejects(()=>rpc('social_cooking','edit_selection',{attemptID:cook}));
 check((await rpc('social_notifications','page')).notifications.filter(n=>n.targetID===first.event.id).length===1,'One Ticket for genuine addition');
 const claim=await rpc('social_cooking','claim',{eventID:first.event.id});
 await db.exec('reset role');
 const independent=randomUUID(),dish=randomUUID();
 await db.query("insert into staygrubby.dishes(account_id,id,name,default_course_code,created_at_ref) values($1,$2,'Independent cook','main',2000)",[users[1].id,dish]);
 await db.query("insert into staygrubby.ranked_items(account_id,id,ranking_id,name,created_at_ref,strength,uncertainty) values($1,$2,$3,'Own cook',2000,0,1)",[users[1].id,claim.itemID,b.ranking]);
 await db.query("insert into staygrubby.cooking_attempts(account_id,id,dish_id,ranked_item_id,course_code,sequence_number,created_at_ref,updated_at_ref,is_legacy_import) values($1,$2,$3,$4,'main',1,2000,2000,false)",[users[1].id,independent,dish,claim.itemID]);
 await actor(1); await rpc('social_cooking','complete',{originID:claim.id});
 await actor(0);
 const joined=await read();
 check(joined.event.participants[0].state==='joined','Existing accepted selection is populated');
 const replaced=await update(joined.selectionToken,[users[2].id]);
 check(replaced.event.id===first.event.id && replaced.selectedIDs[0]===users[2].id,'Replacement retains event identity');
 check((await rpc('social_content','source',{attemptID:cook})).posts[0].id===postID,'Tag edit does not republish');
 await actor(1);
 await rejects(()=>rpc('social_cooking','event',{eventID:first.event.id}));
 await db.exec('reset role');
 check((await db.query('select count(*)::int n from staygrubby.cooking_origins where id=$1 and attempt_id=$2 and completed_at is not null',[claim.id,independent])).rows[0].n===1,'Removing attribution preserves independent completed cook origin');
 await actor(0);
 const removed=await update(replaced.selectionToken,[]);
 check(removed.selectedIDs.length===0 && (await read()).selectedIDs.length===0,'Removing final tag persists');
 await rpc('social_people','block',{peerID:users[2].id});
 await rejects(()=>update(removed.selectionToken,[users[2].id]));

 await db.exec('reset role');
 await db.query('update staygrubby.ranked_items set strength=5 where account_id=$1',[users[0].id]);
 await actor(0);
 check((await rpc('social_content','source',{attemptID:cook})).posts[0].rankAtSharing===11,'Snapshot stays historical after ranking changes');
 await db.exec('reset role');
 await db.query('update staygrubby.cooking_attempts set deleted_at=now() where account_id=$1 and id=$2',[users[0].id,cook]);
 await actor(0);
 check((await rpc('social_content','source',{attemptID:cook})).posts.length===0,'Retired cook retires its post');
 await rejects(()=>rpc('social_cooking','edit_selection',{attemptID:cook}));
 await db.exec('reset role; set role anon');
 await rejects(()=>rpc('social_content','source',{attemptID:old}));
 await rejects(()=>rpc('social_cooking','edit_selection',{attemptID:old}));
} finally { await finish(); }
