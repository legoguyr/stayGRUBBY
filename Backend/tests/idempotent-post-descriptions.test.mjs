import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { fixture } from './social-harness.mjs';

const migration = '20261121161457_idempotent_post_descriptions.sql';
const { db, users, actor, rpc, cooking, check, rejects, finish } = await fixture({ before: migration });
const postID = randomUUID();
const recipeID = randomUUID();

async function rowVersion() {
 await db.exec('reset role');
 return (await db.query('select xmin::text as version from staygrubby.social_posts where id=$1', [postID])).rows[0].version;
}

const edit = postDescription => rpc('social_content', 'editDescription', { postID, postDescription });
const prepare = (id, attemptID, extra = {}) => rpc('social_content', 'prepare', {
 postID: id, attemptID, expectedRevision: 0, confirmed: true, ...extra
});
const content = { title: 'Related clear soup', ingredients: ['Water'], steps: ['Heat.'] };

try {
 for (let n = 0; n < 3; n++) {
  await actor(n);
  await rpc('social_identity', 'save', { displayName: 'Safety fixture ' + n, username: 'desc_fixture_' + n, discoverable: true });
 }
 await actor(0);
 await rpc('social_people', 'request', { peerID: users[1].id });
 await actor(1);
 await rpc('social_people', 'accept', { peerID: users[0].id });
 const { attempts } = await cooking(0, 3);
 await actor(0);
 await rpc('recipes', 'save', { recipeID, recipe: content, visibility: 'friends' });
 const original = 'Made this for lunch';
 await prepare(postID, attempts[0], { postDescription: original, includeRecipe: true, recipeID, sourceRevision: 1 });
 const initial = await rowVersion();
 await actor(0);
 await edit(original);
 const before = await rowVersion();
 check(initial !== before, 'Predecessor repeats an unchanged description write');

 const related = async () => (await db.query(`
 select jsonb_build_object('post_recipes', (select jsonb_agg(to_jsonb(x)) from staygrubby.post_recipes x),
  'recipes', (select jsonb_agg(to_jsonb(x)) from staygrubby.recipe_revisions x),
  'cooks', (select jsonb_agg(to_jsonb(x) order by id) from staygrubby.cooking_attempts x),
  'ranks', (select jsonb_agg(to_jsonb(x) order by id) from staygrubby.ranked_items x))
 as snapshot`)).rows[0].snapshot;
 const preserved = JSON.stringify(await related());
 await db.exec(await readFile(new URL('../../supabase/migrations/' + migration, import.meta.url), 'utf8'));
 check(await rowVersion() === before, 'Migration does not rewrite existing content');
 await actor(0);
 const noChange = await edit(' ' + original + ' ');
 check(noChange.posts[0].postDescription === original, 'Normalized no-op returns the original response contract');
 check(await rowVersion() === before, 'Normalized resave does not update the row');
 await actor(0);
 const changed = 'Bright and simple';
 check((await edit(changed)).posts[0].postDescription === changed, 'Owner can change the description normally');
 const changedVersion = await rowVersion();
 check(changedVersion !== before, 'A genuine edit writes a new row version');
 await actor(1);
 await rejects(() => edit(changed));
 await rejects(() => edit('Try to replace it'));
 check((await rpc('recipes', 'shared_post', { postID })).revision === 1, 'Existing shared Recipe still resolves at the pinned revision');
 await actor(2);
 await rejects(() => rpc('recipes', 'shared_post', { postID }));
 await actor(0);
 check((await edit(null)).posts[0].postDescription == null, 'Owner can clear a description');
 const cleared = await rowVersion();
 await actor(0);
 check((await edit('   ')).posts[0].postDescription == null && await rowVersion() === cleared, 'Clearing an already-empty description does not write');
 await actor(0);
 const retry = await prepare(randomUUID(), attempts[0], { postDescription: 'Unexpected retry title' });
 check(retry.posts[0].id === postID && retry.posts[0].postDescription == null, 'Preparation replay returns the same post without replacing its text');
 check(await rowVersion() === cleared, 'Preparation replay leaves the published snapshot untouched');
 check(JSON.stringify(await related()) === preserved, 'Description mutations never rewrite the Dish, cook, rank or Recipe graph');
 await actor(0);
 const emptyPost = (await prepare(randomUUID(), attempts[1])).posts[0];
 check(emptyPost.postDescription == null, 'A new post can omit a description');
 const photoDraft = (await prepare(randomUUID(), attempts[2], { includePhoto: true })).posts[0];
 await rejects(() => rpc('social_content', 'editDescription', { postID: photoDraft.id, postDescription: null }));
 await db.exec("reset role; update staygrubby.social_posts set moderation_state='hidden' where id='" + postID + "'");
 await actor(0);
 await rejects(() => edit(null));
 await rejects(() => db.query("select staygrubby.social_content_before_calibration('editDescription', '{}'::jsonb)"));
} finally {
 await finish();
}
