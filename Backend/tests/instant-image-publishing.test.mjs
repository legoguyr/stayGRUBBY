import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { fixture } from './social-harness.mjs';
const migration='20261118050952_report_based_image_publishing.sql';
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture({before:migration});
const photo=randomUUID(),privatePhoto=randomUUID(),recipeID=randomUUID(),avatar=randomUUID();
const path=id=>users[0].id+'/'+id+'.jpg';
const object=async(bucket,name)=>db.query("insert into storage.objects(bucket_id,name,metadata) values($1,$2,'{\"mimetype\":\"image/jpeg\",\"size\":100}') returning id",[bucket,name]);
const read=async(bucket,name,operation='object.get_authenticated')=>{
 await db.query("select set_config('storage.operation',$1,false)",[operation]);
 return(await db.query('select id from storage.objects where bucket_id=$1 and name=$2',[bucket,name])).rows.length;
};
const access=async(bucket,name)=>(await db.query('select api.image_access($1,$2) ok',[bucket,name])).rows[0].ok;
try{
 for(let n=0;n<4;n++){await actor(n);await rpc('social_identity','save',{displayName:'Instant '+n,username:'instant_'+n,discoverable:n!==0});}
 await actor(0);await rpc('social_people','request',{peerID:users[1].id});
 await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
 for(const id of [photo,privatePhoto]){
  await actor(0);await rpc('recipes','prepare_photo',{assetID:id,photoHash:'a'.repeat(64),photoBytes:100});
  await db.exec('reset role');await object('recipe-photos',path(id));
  await actor(0);await rpc('recipes','complete_photo',{assetID:id});
  await rpc('recipes','save',{recipeID:id===photo?recipeID:randomUUID(),recipe:{title:'Instant soup',ingredients:['water'],steps:['Heat.'],photoID:id},visibility:id===photo?'friends':'private'});
 }
 const graph=await cooking(0,2);await actor(0);
 const post=(await rpc('social_content','prepare',{postID:randomUUID(),attemptID:graph.attempts[0],expectedRevision:0,confirmed:true,includePhoto:true})).posts[0];
 await db.query("set storage.operation='object.upload'");await object('social-photos',post.photoPath);await rpc('social_content','publish',{postID:post.id});
 const draft=await rpc('social_avatar','prepare',{assetID:avatar});await object('profile-photos',draft.path);await rpc('social_avatar','publish',{avatarPath:draft.path});
 await db.exec('reset role');await db.query('insert into staygrubby.moderation_reviewers(account_id) values($1)',[users[2].id]);
 await db.query("update staygrubby.image_reviews set state=case when object_id=(select id from storage.objects where name=$1) then 'rejected' else 'pending' end",[post.photoPath]);
 await db.query("insert into staygrubby.image_review_actions(object_id,account_id,reviewer_id,generation,previous_state,decision,sha256) select object_id,account_id,$1,generation,'pending','rejected',$2 from staygrubby.image_reviews where state='rejected'",[users[2].id,'a'.repeat(64)]);
 const fingerprint=async()=>JSON.stringify((await db.query("select jsonb_build_object('accounts',(select jsonb_agg(to_jsonb(a) order by id) from staygrubby.accounts a),'identities',(select jsonb_agg(to_jsonb(u) order by id) from auth.users u),'profiles',(select jsonb_agg(to_jsonb(p) order by account_id) from staygrubby.profiles p),'revisions',(select jsonb_agg(to_jsonb(v) order by recipe_id,revision) from staygrubby.recipe_revisions v),'evidence',(select jsonb_agg(to_jsonb(c) order by account_id,id) from staygrubby.comparisons c),'objects',(select jsonb_agg(to_jsonb(o) order by id) from storage.objects o),'recipes',(select jsonb_agg(to_jsonb(r) order by id) from staygrubby.recipes r),'cooks',(select jsonb_agg(to_jsonb(c) order by account_id,id) from staygrubby.cooking_attempts c),'ranks',(select jsonb_agg(to_jsonb(i) order by account_id,id) from staygrubby.ranked_items i),'posts',(select jsonb_agg(to_jsonb(p) order by id) from staygrubby.social_posts p),'audit',(select jsonb_agg(to_jsonb(a) order by id) from staygrubby.image_review_actions a)) value")).rows[0].value);
 const before=await fingerprint();await db.exec(await readFile(new URL('../../supabase/migrations/'+migration,import.meta.url),'utf8'));
 check(await fingerprint()===before,'Forward correction preserves all objects/content/cooks/ranks and historical decisions');
 check((await db.query("select to_regclass('staygrubby.image_reviews') value")).rows[0].value===null,'Obsolete queue and approval states are removed');
 check((await db.query("select count(*)::int n from pg_trigger where tgname in('review_uploaded_image','review_shared_recipe_image','review_pinned_recipe_image','protect_screened_image')")).rows[0].n===0,'Photo uploads/sharing no longer create review writes or replacement locks');
 check((await db.query("select count(*)::int n from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='api' and p.proname in('image_moderation','claim_image_reviews','finish_image_review')")).rows[0].n===0,'Approval and classifier APIs removed');
 for(const [bucket,name] of [['recipe-photos',path(photo)],['social-photos',post.photoPath],['profile-photos',draft.path]]){
  await actor(1);check(await read(bucket,name)===1&&await access(bucket,name),'Existing pending/rejected originals immediately use their original audience');
  for(const op of ['object.sign','object.list','object.get_public','object.get_authenticated_transform'])check(await read(bucket,name,op)===0,'No alternate byte bypass: '+bucket+' '+op);
  await actor(3);check(await read(bucket,name)===0&&!await access(bucket,name),'Immediate publishing does not widen the audience');
  await actor(2);check(await read(bucket,name)===0,'Staff cannot browse unreported originals');
 }
 await actor(0);await rpc('social_identity','save',{displayName:'Instant 0',username:'instant_0',discoverable:true});
 await actor(3);check(await read('profile-photos',draft.path)===1&&await access('profile-photos',draft.path),'Public discovery keeps its original immediate avatar audience');
 await actor(0);await rpc('social_identity','save',{displayName:'Instant 0',username:'instant_0',discoverable:false});
 await actor(3);check(await read('profile-photos',draft.path)===0&&!await access('profile-photos',draft.path),'Disabling discovery restores private profile access immediately');
 await actor(1);check(await read('recipe-photos',path(privatePhoto))===0,'Private-only Recipe original stays private');
 await actor(2);check(await read('recipe-photos',path(privatePhoto))===0,'Staff role never opens private libraries');
 await actor(0);await db.query("set storage.operation=''");check((await rpc('recipes','photo',{assetID:photo})).id===photo,'Internal Recipe descriptor continues to work');
 // A new upload/post needs only the existing structural upload + explicit publish.
 const fresh=(await rpc('social_content','prepare',{postID:randomUUID(),attemptID:graph.attempts[1],expectedRevision:0,confirmed:true,includePhoto:true})).posts[0];
 await db.query("set storage.operation='object.upload'");await object('social-photos',fresh.photoPath);await rpc('social_content','publish',{postID:fresh.id});
 await actor(1);check(await read('social-photos',fresh.photoPath)===1,'New food photo is visible immediately after publish');
 await db.exec('reset role');check((await db.query('update storage.objects set metadata=metadata where name=$1 returning id',[fresh.photoPath])).rows.length===1,'Retired approval trigger no longer blocks Storage metadata handling');
 await actor(1);
 for(const [kind,id] of [['recipe',recipeID],['post',post.id],['profile',users[0].id]]){
  const payload={targetType:kind,targetID:id,reason:'inappropriate',...(kind==='recipe'?{sourceRevision:1}:{})};
  check((await rpc('social_report','report',payload)).reported,'Existing report action accepts image-bearing '+kind);
  await rpc('social_report','report',payload);
 }
 await rejects(()=>rpc('moderation_review','queue'));
 await actor(2);const reports=(await rpc('moderation_review','queue')).reports;check(reports.length===3,'Report retries are idempotent; only actual reports enter staff queue');
 for(const [bucket,name] of [['recipe-photos',path(photo)],['social-photos',post.photoPath],['profile-photos',draft.path]])check(await read(bucket,name)===1,'Staff can inspect the reported original only');
 check(await read('social-photos',fresh.photoPath)===0,'Reporting one post does not open its other cooks/photos');
 await actor(1);await rpc('social_report','report',{targetType:'post',targetID:fresh.id,reason:'other'});
 await actor(2);const dismissed=(await rpc('moderation_review','queue')).reports.find(r=>r.kind==='post'&&r.id!==reports.find(r=>r.kind==='post').id);
 check(await read('social-photos',fresh.photoPath)===1,'An actual second report grants scoped evidence access');
 await rpc('moderation_review','resolve',{reportID:dismissed.id,decision:'dismiss'});
 check(await read('social-photos',fresh.photoPath)===0,'Dismiss ends special evidence access without hiding legitimate content');

 await rpc('moderation_review','resolve',{reportID:reports.find(r=>r.kind==='recipe').id,decision:'hide'});
 await rpc('moderation_review','resolve',{reportID:reports.find(r=>r.kind==='post').id,decision:'hide'});
 await actor(1);check(await read('recipe-photos',path(photo))===0&&!await access('recipe-photos',path(photo)),'Recipe hide revokes downloads and cached access');
 check(await read('social-photos',post.photoPath)===0&&!await access('social-photos',post.photoPath),'Post hide revokes downloads and cached access');
 check(await read('social-photos',fresh.photoPath)===1,'Removing reported post preserves another legitimate shared cook');
 await rpc('social_people','block',{peerID:users[0].id});check(await read('social-photos',fresh.photoPath)===0&&!await access('social-photos',fresh.photoPath),'Block overrides immediate publication');
 check(await read('profile-photos',draft.path)===0,'Block denies profile photo');
 await actor(2);await rpc('moderation_review','resolve',{reportID:reports.find(r=>r.kind==='profile').id,decision:'hide'});
 await db.exec('reset role');check((await db.query('select social_state from staygrubby.profiles where account_id=$1',[users[0].id])).rows[0].social_state==='hidden','Moderator profile removal uses existing lifecycle');
 check((await db.query('select count(*)::int n from staygrubby.image_review_actions')).rows[0].n===1,'Publishing/reading/reporting adds no approval/audit rows');
 await db.query('delete from staygrubby.moderation_reviewers where account_id=$1',[users[2].id]);await actor(2);
 await rejects(()=>rpc('moderation_review','queue'));check(await read('recipe-photos',path(photo))===0,'Staff revocation removes report evidence access');
 await db.exec('reset role');const otherPath=users[3].id+'/'+randomUUID()+'.jpg';await object('profile-photos',otherPath);
 const otherBefore=JSON.stringify((await db.query('select to_jsonb(o) value from storage.objects o where name=$1',[otherPath])).rows[0].value);
 await actor(0);await db.query('select api.begin_account_deletion()');await db.exec('reset role;set role service_role');
 await db.query("select api.advance_account_deletion($1,'apple_revoked')",[users[0].user]);await db.query("select api.advance_account_deletion($1,'storage_cleared')",[users[0].user]);
 await rejects(()=>db.query('select api.erase_account_data($1)',[users[0].user]),'55000');
 await db.exec('reset role');await db.query('delete from storage.objects where name like $1',[users[0].id+'/%']);
 await db.exec('set role service_role');await db.query('select api.erase_account_data($1)',[users[0].user]);await db.query('select api.erase_account_data($1)',[users[0].user]);await db.exec('reset role');
 check((await db.query('select count(*)::int n from staygrubby.image_review_actions')).rows[0].n===0,'Erasure cleans historical image evidence without FK failure');
 check((await db.query('select count(*)::int n from staygrubby.social_reports where target_account_id=$1',[users[0].id])).rows[0].n===0,'Erasure cleans report references');
 check((await db.query('select count(*)::int n from staygrubby.accounts where id=$1',[users[0].id])).rows[0].n===0,'Account graph erasure completes and retries safely');
 check(JSON.stringify((await db.query('select to_jsonb(o) value from storage.objects o where name=$1',[otherPath])).rows[0].value)===otherBefore,'Another account photo remains unchanged');
 await db.exec('set role anon');check(await read('profile-photos',otherPath)===0,'Anonymous object access denied');
}finally{await finish();}
