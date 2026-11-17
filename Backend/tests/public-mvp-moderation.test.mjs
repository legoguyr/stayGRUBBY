import { randomUUID } from 'node:crypto';
import { fixture } from './social-harness.mjs';

const { db, users, actor, rpc, cooking, check, rejects, finish } = await fixture();
const report = (kind, id, extra = {}) => rpc('social_report', 'report', {
 targetType: kind, targetID: id, reason: 'spam', context: ' Review this reference. ', ...extra
});
const moderation = (action, payload) => rpc('moderation_review', action, payload);
const photo = randomUUID(), recipe = randomUUID(), post = randomUUID(), comment = randomUUID();
const privateRecipe = randomUUID();
const photoPath = users[1].id + '/' + photo + '.jpg';
const content = { title: 'Archived soup', ingredients: ['water'], steps: ['Heat.'], photoID: photo };

try {
 for (let n = 0; n < users.length; n++) {
  await actor(n);
  await rpc('social_identity', 'save', { displayName: 'Moderator fixture ' + n, username: 'mod_fixture_' + n, discoverable: true });
 }
 await actor(0);
 await rpc('social_people', 'request', { peerID: users[1].id });
 await actor(1);
 await rpc('social_people', 'accept', { peerID: users[0].id });
 const source = await cooking(1);
 await actor(1);
 await rpc('recipes', 'prepare_photo', { assetID: photo, photoHash: 'a'.repeat(64), photoBytes: 100 });
 await db.exec('reset role');
 await db.query("insert into storage.objects(bucket_id,name,metadata) values('recipe-photos',$1,$2)", [
  photoPath, JSON.stringify({ mimetype: 'image/jpeg', size: 100 })
 ]);
 await actor(1);
 await rpc('recipes', 'complete_photo', { assetID: photo });
 await rpc('recipes', 'save', { recipeID: privateRecipe, recipe: { ...content, photoID: null }, visibility: 'private' });
 await rpc('recipes', 'save', { recipeID: recipe, recipe: content, visibility: 'friends' });
 await rpc('social_content', 'prepare', {
  postID: post, attemptID: source.attempts[0], expectedRevision: 0, confirmed: true, includeRecipe: true, recipeID: recipe, sourceRevision: 1
 });
 await rpc('social_interactions', 'comment', { postID: post, commentID: comment, body: 'A reported comment' });
 await rpc('recipes', 'save', { recipeID: recipe, recipe: { ...content, title: 'Current soup' }, expectedRevision: 1, visibility: 'friends' });
 await rejects(() => report('recipe', recipe), '22023');

 await actor(0);
 await rejects(() => report('recipe', privateRecipe));
 await rejects(() => report('recipe', recipe, { postID: randomUUID() }));
 check((await report('recipe', recipe, { postID: post })).reported, 'Pinned Recipe is reportable');
 check((await report('recipe', recipe)).reported, 'Current Recipe is independently reportable');
 await report('recipe', recipe);
 for (const [type, id] of [['post', post], ['comment', comment], ['profile', users[1].id]]) {
  check((await report(type, id)).reported, 'Legacy report works for ' + type);
 }
 await rejects(() => moderation('queue'));
 await rejects(() => db.query('select * from staygrubby.moderation_actions'));
 await db.query("select set_config('request.jwt.claims',$1,false)", [
  JSON.stringify({ sub: users[0].user, session_id: users[0].session, user_metadata: { moderator: true }, app_metadata: { moderator: true } })
 ]);
 await rejects(() => moderation('queue'));

 await db.exec('reset role; set role anon');
 await rejects(() => moderation('queue'));
 await db.exec('reset role; set role service_role');
 await rejects(() => moderation('queue'));
 await rejects(() => db.query("select api.moderate_social_content('post',$1,'hidden')", [post]));
 await db.exec('reset role');
 await db.query('insert into staygrubby.moderation_reviewers values($1),($2)', [users[2].id, users[3].id]);
 check((await db.query("select count(*)::int n from staygrubby.social_reports where target_type='recipe'")).rows[0].n === 2,
  'Same revision deduplicates while a new revision remains reportable');
 await actor(2);
 const queue = (await moderation('queue')).reports;
 check(queue.length === 5 && !queue.some(r => 'context' in r || 'reporterID' in r), 'Queue exposes only triage metadata');
 const reviews = await Promise.all(queue.map(r => moderation('review', { reportID: r.id })));
 const pinned = reviews.find(r => r.subject?.revision === 1);
 const current = reviews.find(r => r.subject?.revision === 2);
 const caseFor = kind => reviews.find(r => r.kind === kind);
 check(pinned?.subject.content.title === 'Archived soup' && current?.subject.content.title === 'Current soup',
  'Review shows the exact reported Recipe revision');
 check(pinned.subject.photoPath === photoPath && pinned.context === 'Review this reference.' && !pinned.reporterID,
  'Only report context and the reported photo reference are returned');
 await rejects(() => moderation('review', { reportID: randomUUID() }));
 await rejects(() => moderation('resolve', { reportID: pinned.id, decision: 'purge' }), '22023');
 const resolved = await moderation('resolve', { reportID: pinned.id, decision: 'hide' });
 check(resolved.status === 'reviewed' && resolved.decision === 'hide', 'Hide and report status commit together');
 const replay = await moderation('resolve', { reportID: pinned.id, decision: 'hide' });
 check(resolved.resolvedAt === replay.resolvedAt, 'Replay returns the first audit receipt');
 await rejects(() => moderation('resolve', { reportID: pinned.id, decision: 'dismiss' }), 'PT409');
 check((await moderation('resolve', { reportID: current.id, decision: 'dismiss' })).status === 'dismissed', 'Dismiss records an outcome');
 check((await moderation('queue')).reports.length === 3, 'Resolved reports leave the pending queue');

 await actor(0);
 await rejects(() => rpc('recipes', 'get', { recipeID: recipe }));
 await rejects(() => rpc('recipes', 'shared_post', { postID: post }));
 await rejects(() => rpc('recipes', 'photo', { assetID: photo }));
 await db.query("select set_config('storage.operation','object.get_authenticated',false)");
 check((await db.query("select name from storage.objects where bucket_id='recipe-photos' and name=$1", [photoPath])).rows.length === 0,
  'Moderation withdraws peer Storage authorization');
 check((await rpc('social_feed', 'post', { postID: post })).posts[0].recipeID == null, 'Cook remains visible without hidden Recipe');
 await actor(1);
 check((await rpc('recipes', 'get', { recipeID: recipe })).content.title === 'Current soup', 'Owner retains Recipe and revision');
 check((await rpc('recipes', 'photo', { assetID: photo })).id === photo, 'Owner photo remains available');
 await actor(0);
 await rpc('social_people', 'block', { peerID: users[1].id });
 await rejects(() => report('post', post));
 await rejects(() => report('profile', users[1].id));

 await actor(2);
 for (const kind of ['comment', 'post', 'profile']) {
  check((await moderation('resolve', { reportID: caseFor(kind).id, decision: 'hide' })).status === 'reviewed',
   'Audited hide applies to ' + kind);
 }
 await db.exec('reset role');
 const { n: actionCount } = (await db.query('select count(*)::int n from staygrubby.moderation_actions')).rows[0];
 check(actionCount === 5, 'One append-only audit record per outcome');
 check((await db.query('select count(*)::int n from staygrubby.recipe_revisions where recipe_id=$1', [recipe])).rows[0].n === 2,
  'Moderation neither edits nor inserts Recipe revisions');

 await db.query('insert into staygrubby.moderation_reviewers values($1)', [users[1].id]);
 await db.query("update staygrubby.profiles set social_state='active' where account_id=$1", [users[1].id]);
 await actor(1);
 await rejects(() => moderation('review', { reportID: pinned.id }));
 await db.exec('reset role');
 await db.query("insert into staygrubby.social_reports(reporter_id,target_type,target_id,target_account_id,reason) select $1,'profile',gen_random_uuid(),$2,'spam' from generate_series(1,27)", [users[0].id, users[1].id]);
 await actor(3);
 const first = (await moderation('queue')).reports;
 const last = first.at(-1);
 const second = (await moderation('queue', { afterID: last.id, afterTime: last.createdAt })).reports;
 check(first.length === 25 && second.length === 2 && !first.some(r => second.some(x => x.id === r.id)), 'Queue uses stable keyset pages');
 await rejects(() => moderation('queue', { afterID: last.id }), '22023');
 await db.exec('reset role');
 await db.query('delete from staygrubby.moderation_reviewers where account_id=$1', [users[3].id]);
 await actor(3);
 await rejects(() => moderation('queue'));
 await db.exec('reset role');
 await db.query('delete from auth.sessions where id=$1', [users[2].session]);
 await actor(2);
 await rejects(() => moderation('queue'));

 await db.exec('reset role');
 await db.query('delete from staygrubby.accounts where id=$1', [users[2].id]);
 check((await db.query('select count(*)::int n from staygrubby.moderation_actions where reviewer_id is null')).rows[0].n === 5,
  'Reviewer erasure detaches reviewer identity from surviving cases');
 await actor(1);
 await rpc('recipes', 'delete', { recipeID: recipe });
 await db.exec('reset role');
 check((await db.query("select count(*)::int n from staygrubby.social_reports where target_type='recipe'")).rows[0].n === 0,
  'Recipe deletion cascades to exact-revision reports');
 check((await db.query('select count(*)::int n from staygrubby.moderation_actions')).rows[0].n === 3,
  'Only audits belonging to deleted reports are removed');
 await db.query('delete from staygrubby.accounts where id=$1', [users[1].id]);
 check((await db.query('select count(*)::int n from staygrubby.moderation_actions')).rows[0].n === 0,
  'Subject account deletion cascades through reports and audit');
} finally {
 await finish();
}
