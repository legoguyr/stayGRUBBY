import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture();
for(let i=0;i<3;i++){await actor(i);await rpc('social_identity','save',{displayName:'Photo Recipe '+i,username:'photo_recipe_'+i,discoverable:true});}
await actor(0);await rpc('social_people','request',{peerID:users[1].id});await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
const lib=await cooking(0,3),rid=randomUUID(),photo=randomUUID(),path=users[0].id+'/'+photo+'.jpg';
await actor(0);await rpc('recipes','prepare_photo',{assetID:photo,photoHash:'a'.repeat(64),photoBytes:100});
await db.exec('reset role');await db.query("insert into storage.objects(bucket_id,name,metadata) values('recipe-photos',$1,$2)",[path,JSON.stringify({mimetype:'image/jpeg',size:100})]);
await actor(0);await rpc('recipes','complete_photo',{assetID:photo});
const content={title:'Recipe photo soup',description:'A useful optional introduction.',ingredients:['water'],steps:['Heat.'],photoID:photo};
await rpc('recipes','save',{recipeID:rid,recipe:content,visibility:'private'});
await actor(1);await rejects(()=>rpc('recipes','photo',{assetID:photo}));
const post=randomUUID();await actor(0);await rpc('social_content','prepare',{postID:post,attemptID:lib.attempts[0],expectedRevision:0,confirmed:true,includeRecipe:true,recipeID:rid,sourceRevision:1});
await actor(1);check((await rpc('recipes','photo',{assetID:photo})).id===photo,'explicit Recipe sharing permits its own image');
const copy=await rpc('recipes','fork_post',{postID:post,targetID:randomUUID(),confirmed:true});check(!copy.content.photoID&&copy.content.description===content.description,'private fork preserves description but not foreign media');
await db.exec('reset role');check((await db.query('select count(*)::int n from storage.objects')).rows[0].n===1,'fork never duplicates media uploads');
await actor(0);await rpc('recipes','save',{recipeID:rid,expectedRevision:2,recipe:{...content,photoID:null},removeRecipePhoto:true,visibility:'friends'});
await actor(1);check((await rpc('recipes','shared_post',{postID:post})).content.photoID===photo,'historical shared photo unchanged after replacement/removal');
check((await rpc('recipes','photo',{assetID:photo})).id===photo,'archived photo authorized only through active attachment');
// Exercise the actual Storage SELECT policy, not just its descriptor RPC.
await db.query("select set_config('storage.operation','object.get_authenticated',false)");
check((await db.query("select name from storage.objects where bucket_id='recipe-photos' and name=$1",[path])).rows.length===1,'Storage policy rebound to historical sharing helper');
await actor(2);await rejects(()=>rpc('recipes','photo',{assetID:photo}));check((await db.query("select name from storage.objects where name=$1",[path])).rows.length===0,'outsider cannot directly read object');
await actor(0);await rpc('recipes','unshare_post',{postID:post,confirmed:true});
await actor(1);await rejects(()=>rpc('recipes','photo',{assetID:photo}));check((await db.query("select name from storage.objects where name=$1",[path])).rows.length===0,'unshare revokes archived Storage access');
await actor(0);await rpc('recipes','share_post',{postID:post,recipeID:rid,sourceRevision:1,confirmed:true});
await actor(1);await rpc('social_people','block',{peerID:users[0].id});await rejects(()=>rpc('recipes','photo',{assetID:photo}));
check((await db.query("select name from storage.objects where name=$1",[path])).rows.length===0,'block denies historical Storage reads');
// No attachment from legacy auto-post or shared invitation alone.
await actor(0);const noRecipe=randomUUID();await rpc('social_content','prepare',{postID:noRecipe,attemptID:lib.attempts[1],expectedRevision:0,confirmed:true});
const event=randomUUID();await rpc('social_cooking','create',{eventID:event,attemptID:lib.attempts[1],participantIDs:[users[2].id],confirmed:true}).then(()=>{throw Error('outsider invite accepted')},e=>check(e.code==='42501','unrelated invite rejected'));
// Equivalent normal saved content has no AI/manual class or social distinction.
for(const title of ['Reviewed Creator draft','Manual draft']){const id=randomUUID();await rpc('recipes','save',{recipeID:id,recipe:{...content,title,photoID:null},visibility:'private'});const r=await rpc('recipes','get',{recipeID:id});check(r.content.description===content.description&&!r.content.creationMethod,'same saved Recipe contract regardless of creation path');}
// Verify no caller can transfer another owner's Recipe into their own post.
await actor(1);const own=await cooking(1);await actor(1);
await rejects(()=>rpc('social_content','prepare',{postID:randomUUID(),attemptID:own.attempts[0],expectedRevision:0,confirmed:true,includeRecipe:true,recipeID:rid,sourceRevision:1}));
await db.exec('reset role');const tables=(await db.query("select tablename from pg_tables where schemaname='staygrubby' and tablename in('post_recipes','recipe_forks')")).rows;
for(const t of tables){check(!(await db.query("select has_table_privilege('authenticated',$1,'INSERT,UPDATE,DELETE,TRUNCATE') allowed",['staygrubby.'+t.tablename])).rows[0].allowed,'no raw writes '+t.tablename);}
await finish();
