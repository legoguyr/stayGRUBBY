import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture();
for(let n=0;n<3;n++){await actor(n);await rpc('social_identity','save',{displayName:'Activity '+n,username:'activity_'+n,discoverable:true});}
await actor(0);await rpc('social_people','request',{peerID:users[1].id});await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
const a=await cooking(0),b=await cooking(1);await actor(0);const event=randomUUID();
await rpc('social_cooking','create',{eventID:event,attemptID:a.attempts[0],participantIDs:[users[1].id],confirmed:true});
await rpc('social_cooking','create',{eventID:event,attemptID:a.attempts[0],participantIDs:[users[1].id],confirmed:true});
await actor(1);let p=await rpc('social_notifications','page');check(p.notifications.filter(n=>n.kind==='invited').length===1,'Tag a Sous Chef sends one eligible recipient notice');check(p.unread===1,'recipient has one invitation; acceptance goes to requester');
const invitation=p.notifications.find(n=>n.kind==='invited');check(invitation.targetID===event,'invitation routes to canonical shared event');
await rpc('social_notifications','read',{targetID:invitation.id});check((await rpc('social_notifications','page')).unread===0,'reading invite updates recipient count');
const claim=await rpc('social_cooking','claim',{eventID:event});
await db.exec('reset role');const item=b.attempts[0];
// Model the saved native claim with a new isolated item, never production data.
await db.query("insert into staygrubby.ranked_items(account_id,id,ranking_id,name,created_at_ref,strength,uncertainty) values($1,$2,$3,'Own shared result',1,0,1)",[users[1].id,claim.itemID,b.ranking]);
await db.query('update staygrubby.cooking_attempts set ranked_item_id=$1 where account_id=$2 and id=$3',[claim.itemID,users[1].id,item]);
await actor(1);await rpc('social_cooking','complete',{originID:claim.id});await rpc('social_cooking','complete',{originID:claim.id});
await actor(0);p=await rpc('social_notifications','page');check(p.notifications.filter(n=>n.kind==='joined').length===1,'completion retry creates one joined notice');
const postID=randomUUID();await rpc('social_content','prepare',{postID,attemptID:a.attempts[0],confirmed:true,expectedRevision:0});
await actor(1);const recreate=await rpc('social_cooking','recreate',{postID});
await db.exec('reset role');await db.query("insert into staygrubby.ranked_items(account_id,id,ranking_id,name,created_at_ref,strength,uncertainty) values($1,$2,$3,'My re-created result',1,0,1)",[users[1].id,recreate.itemID,b.ranking]);
await db.query('update staygrubby.cooking_attempts set ranked_item_id=$1 where account_id=$2 and id=$3',[recreate.itemID,users[1].id,item]);
await actor(1);await rpc('social_cooking','complete',{originID:recreate.id});await rpc('social_cooking','complete',{originID:recreate.id});
await actor(0);p=await rpc('social_notifications','page');check(p.notifications.filter(n=>n.kind==='recreated').length===1,'Run It Back completion deduplicates');check(p.notifications.find(n=>n.kind==='recreated').postID===postID,'Run It Back routes to source post');
await rpc('social_people','block',{peerID:users[1].id});check((await rpc('social_notifications','page')).unread===0,'block hides actor activity and unread count');
await actor(1);await rejects(()=>rpc('social_interactions','like',{postID}));await rejects(()=>rpc('social_cooking','recreate',{postID}));
await actor(2);check((await rpc('social_notifications','page')).notifications.length===0,'third account cannot see recipient activity');
await finish();
