import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { fixture } from './social-harness.mjs';

const migration = '20261117142843_public_text_screening.sql';
const { db, users, actor, rpc, cooking, check, rejects, finish } = await fixture({ before: migration });
const threat = 'I will kill you';
const normal = 'Beat the egg whites for chicken breasts. Kill the heat. I will shoot you a photo.';
const privateID = randomUUID(), sharedID = randomUUID(), legacyID = randomUUID(), postID = randomUUID(), legacyPost = randomUUID();
const content = { title: 'Cock-a-leekie soup', description: normal, ingredients: ['2 chicken breasts'], steps: ['Bring to a boil.'] };
const save = (recipeID, recipe, visibility, expectedRevision) =>
 rpc('recipes','save',{recipeID,recipe,visibility,expectedRevision});

try {
 for (let n = 0; n < 3; n++) {
  await actor(n);
  await rpc('social_identity','save',{displayName:'Chef '+n,username:'filter_fixture_'+n,discoverable:true});
 }
 await actor(0);
 await rpc('social_people','request',{peerID:users[1].id});
 await actor(1);
 await rpc('social_people','accept',{peerID:users[0].id});
 const { attempts } = await cooking(0, 5);
 const draftID = randomUUID();
 const prepare = (postID, attemptID, extra={}) =>
  rpc('social_content','prepare',{postID,attemptID,expectedRevision:0,confirmed:true,...extra});
 await actor(0);
 await save(legacyID,{...content,description:threat},'friends');
 await prepare(legacyPost,attempts[0],{includeRecipe:true,recipeID:legacyID,sourceRevision:1});
 await save(legacyID,{...content},'private',1);
 await prepare(postID,attempts[1],{postDescription:normal});
 const draft = (await prepare(draftID,attempts[3],{includePhoto:true,postDescription:threat})).posts[0];
 await db.exec('reset role');
 const tables = ['social_posts','post_recipes','social_comments','recipes','recipe_revisions','recipe_activity','dishes','cooking_attempts','ranked_items','profiles'];
 const snapshot = async () => JSON.stringify(await Promise.all(tables.map(async table =>
  (await db.query(`select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text) rows from staygrubby.${table} r`)).rows[0].rows)));
 const before = await snapshot();
 await db.exec(await readFile(new URL('../../supabase/migrations/'+migration,import.meta.url),'utf8'));
 check(await snapshot() === before,'The migration changes no existing data or revisions');

 await actor(0);
 await rejects(() => prepare(randomUUID(),attempts[2],{postDescription:threat}),'PT422');
 await rejects(() => rpc('social_content','editDescription',{postID,postDescription:'I  ＷＩＬＬ  k\u200bill—YOU!'}),'PT422');
 check((await rpc('social_feed','post',{postID})).posts[0].postDescription === normal,'Rejected edit leaves benign text intact');
 await rpc('social_content','editDescription',{postID,postDescription:'Sauté until golden and deglaze.'});
 await rejects(() => rpc('social_identity','save',{displayName:'Death to Muslims',username:'filter_fixture_0',discoverable:false}),'PT422');
 await rpc('social_identity','save',{displayName:'Álvaro’s Kitchen',username:'filter_fixture_0',discoverable:false});
 await save(privateID,{...content,description:threat},'private');
 check((await rpc('recipes','get',{recipeID:privateID})).content.description === threat,'Private drafts are excluded from screening');
 await rejects(() => rpc('recipes','share_post',{postID,recipeID:privateID,sourceRevision:1,confirmed:true}),'PT422');
 check((await rpc('recipes','get',{recipeID:privateID})).visibility === 'private','Rejected publication leaves the audience private');
 await save(privateID,content,'private',1);
 await save(privateID,content,'friends',2);
 await rejects(() => rpc('recipes','share_post',{postID,recipeID:privateID,sourceRevision:1,confirmed:true}),'PT422');
 await rejects(() => rpc('recipes','restore',{recipeID:privateID,expectedRevision:3,sourceRevision:1}),'PT422');
 check((await rpc('recipes','get',{recipeID:privateID})).revision === 3,'Rejected restore cannot create a new version');
 await rejects(() => save(legacyID,content,'friends',2),'PT422');
 await rpc('recipes','unshare_post',{postID:legacyPost,confirmed:true});
 check((await save(legacyID,content,'friends',2)).visibility === 'friends','Removing the old pinned attachment allows safe reopening');

 await rejects(() => save(sharedID,{...content,steps:['Heat.','Go hang yourself']},'friends'),'PT422');
 await rejects(() => save(sharedID,{...content,components:[{id:randomUUID(),title:'Sauce',order:0,ingredients:[{id:randomUUID(),order:0,name:'water'}],steps:[{id:randomUUID(),order:0,instruction:threat}]}]},'friends'),'PT422');
 check((await save(sharedID,content,'friends')).content.description === normal,'Normal cooking terms and photo-sharing idiom pass');
 await actor(1);
 const rejectedComment = randomUUID();
 await rejects(() => rpc('social_interactions','comment',{postID,commentID:rejectedComment,body:'Send me child pornography'}),'PT422');
 const commentID = randomUUID();
 await rpc('social_interactions','comment',{postID,commentID,body:'美味しい！Scrape the pan and reduce.'});
 await db.exec('reset role');
 check((await db.query('select id from staygrubby.social_comments where id=$1',[commentID])).rows.length === 1,'Cooking comment in multiple scripts passes');
 check((await db.query('select id from staygrubby.social_comments where id=$1',[rejectedComment])).rows.length === 0,'Rejection writes neither a comment nor a copied review payload');

 await actor(0);
 const rejectedDraft = randomUUID();
 await rejects(() => prepare(rejectedDraft,attempts[4],{includePhoto:true,postDescription:threat}),'PT422');
 await db.exec('reset role');
 check((await db.query('select id from staygrubby.social_posts where id=$1',[rejectedDraft])).rows.length===0,
  'New rejected photo draft rolls back before any asset is staged');
 await actor(0);
 check(!draft.published,'Legacy photo draft remains private until final publish');
 await db.query("set storage.operation = 'object.upload'");
 await db.query("insert into storage.objects(bucket_id,name,metadata) values('social-photos',$1,$2)",[
  draft.photoPath, JSON.stringify({mimetype:'image/jpeg',size:100})
 ]);
 await rejects(() => rpc('social_content','publish',{postID:draftID}),'PT422');
 await actor(1);
 await rejects(() => rpc('social_feed','post',{postID:draftID}));
 await db.query("set storage.operation = 'object.get_authenticated'");
 check((await db.query("select name from storage.objects where bucket_id='social-photos' and name=$1",[draft.photoPath])).rows.length===0,'Peer cannot read photo bytes after text rejection');
 await rejects(()=>db.query("select staygrubby.check_public_text('hi')"));
 await rpc('social_report','report',{targetType:'post',targetID:postID,reason:'other'});
 await rpc('social_report','report',{targetType:'profile',targetID:users[0].id,reason:'other'});
 await rejects(()=>rpc('moderation_review','queue'));
 await db.exec('reset role');
 await db.query('insert into staygrubby.moderation_reviewers(account_id) values($1)',[users[2].id]);
 await actor(2);
 const {reports} = await rpc('moderation_review','queue');
 check(reports.length === 2 && !reports.some(report => report.accountID), 'Queue does not expose a subject or a reporter identity');
 for (const report of reports) {
  const details = await rpc('moderation_review','review',{reportID:report.id});
  check(details.subject.accountID === users[0].id && !details.reporterID,
   'Staff case detail correlates the subject across reports without revealing the reporter');
  await rpc('moderation_review','resolve',{reportID:report.id,decision:'dismiss'});
 }
} finally { await finish(); }
