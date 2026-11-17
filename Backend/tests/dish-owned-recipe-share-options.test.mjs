import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { fixture } from './social-harness.mjs';

const migration = '20261117063020_dish_owned_recipe_share_options.sql';
const { db, users, actor, rpc, cooking, check, rejects, finish } = await fixture({ before: migration });
const content = title => ({ title, ingredients: ['water'], steps: ['Heat.'] });
const option = payload => rpc('recipes', 'share_options', payload);

try {
 for (let n = 0; n < users.length; n++) {
  await actor(n);
  await rpc('social_identity', 'save', { displayName: 'Share fixture ' + n, username: 'share_fixture_' + n, discoverable: true });
 }
 await actor(0);
 await rpc('social_people', 'request', { peerID: users[1].id });
 await actor(1);
 await rpc('social_people', 'accept', { peerID: users[0].id });

 const { attempts } = await cooking(0, 5);
 const [attempt, legacyCook, exactCook, usedCook, emptyCook] = attempts;
 const { dish_id: dish } = (await db.query('select dish_id from staygrubby.cooking_attempts where id=$1', [attempt])).rows[0];
 const { dish_id: legacyDish } = (await db.query('select dish_id from staygrubby.cooking_attempts where id=$1', [legacyCook])).rows[0];
 const { ranked_item_id: usedItem } = (await db.query('select ranked_item_id from staygrubby.cooking_attempts where id=$1', [usedCook])).rows[0];
 const owned = randomUUID(), legacy = randomUUID(), exact = randomUUID(), used = randomUUID();
 const post = randomUUID();

 await actor(0);
 await rpc('recipes', 'save', { recipeID: owned, recipeDishID: dish, recipe: content('Dish identity'), visibility: 'private' });
 await rpc('recipes', 'save', { recipeID: legacy, dishID: legacyDish, recipe: content('Legacy link'), visibility: 'private' });
 await rpc('recipes', 'save', { recipeID: exact, attemptID: exactCook, recipe: content('Exact link'), visibility: 'private' });
 await rpc('recipes', 'save', { recipeID: used, recipe: content('Pinned used Recipe'), visibility: 'private' });
 await rpc('recipes', 'associate_cook', { recipeID: used, attemptID: usedCook, targetID: usedItem, expectedRevision: 1, originID: randomUUID() });
 await rpc('recipes', 'link_cook', { recipeID: exact, attemptID: usedCook, previousAttemptID: exactCook });
 await rpc('recipes', 'save', { recipeID: used, recipe: content('Edited used Recipe'), visibility: 'private', expectedRevision: 1 });
 await rpc('social_content', 'prepare', { postID: post, attemptID: attempt, expectedRevision: 0, confirmed: true });

 check((await option({ attemptID: attempt })).recipe === null, 'Predecessor misses a Recipe linked only by Dish identity');
 check((await option({ postID: post })).recipe === null, 'Predecessor also misses it from the existing post');
 await db.exec('reset role');
 const tables = ['accounts', 'recipes', 'recipe_revisions', 'dishes', 'cooking_attempts', 'ranked_items', 'comparisons',
  'dish_recipes', 'recipe_cook_links', 'recipe_cooks', 'social_posts', 'post_recipes'];
 const snapshot = async () => Promise.all(tables.map(async table =>
  (await db.query(`select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) value from staygrubby.${table} t`)).rows[0].value));
 const before = await snapshot();
 await db.exec(await readFile(new URL('../../supabase/migrations/' + migration, import.meta.url), 'utf8'));

 await actor(0);
 for (const payload of [{ attemptID: attempt }, { postID: post, attemptID: emptyCook }]) {
  const result = await option(payload);
  check(result.recipe.id === owned && result.recipe.revision === 1 && !result.fromCookSnapshot
   && result.recipe.visibility === 'private', 'Lookup returns the existing private owned Recipe without claiming historical provenance');
 }
 check((await option({ attemptID: emptyCook })).recipe === null, 'A cook without an association remains empty');
 check((await option({ attemptID: legacyCook })).recipe.id === legacy, 'Legacy Dish lookup remains available');
 let result = await option({ attemptID: usedCook });
 check(result.recipe.id === used && result.recipe.revision === 1 && result.fromCookSnapshot
  && result.recipe.content.title === 'Pinned used Recipe', 'Exact historical Recipe still wins over a newer explicit cook link');
 await db.exec('reset role');
 check(JSON.stringify(await snapshot()) === JSON.stringify(before), 'Migration and repeated option reads preserve all existing rows and links');
 await actor(0);
 await rpc('recipes', 'link_cook', { recipeID: exact, attemptID: exactCook, previousAttemptID: usedCook });
 check((await option({ attemptID: exactCook })).recipe.id === exact, 'Explicit cook link remains available');
 await actor(1);
 await rejects(() => option({ attemptID: attempt }));
 await rejects(() => option({ postID: post }));
 await rejects(() => rpc('recipes', 'get', { recipeID: owned }));
 await rejects(() => rpc('recipes', 'shared_post', { postID: post }));

 await actor(0);
 await rejects(() => rpc('recipes', 'share_post', { postID: post, recipeID: owned, sourceRevision: 1 }), '22023');
 await rpc('recipes', 'share_post', { postID: post, recipeID: owned, sourceRevision: 1, confirmed: true });
 await rpc('recipes', 'share_post', { postID: post, recipeID: owned, sourceRevision: 1, confirmed: true });
 await actor(1);
 result = await rpc('recipes', 'shared_post', { postID: post });
 check(result.recipeID === owned && result.revision === 1 && !result.isAuthor, 'Explicitly adding the Recipe to an existing post shares the pinned revision');
 const report = { targetType: 'recipe', targetID: owned, postID: post, reason: 'spam', sourceRevision: 2 };
 await rejects(() => rpc('social_report', 'report', report), 'PT409');
 check((await rpc('social_report', 'report', { ...report, sourceRevision: 1 })).reported, 'Recipe shown from the same post is reportable at its pinned revision');

 await actor(2);
 await rejects(() => rpc('recipes', 'get', { recipeID: owned }));
 await rejects(() => rpc('moderation_review', 'queue'));
 await db.exec('reset role');
 await db.query('insert into staygrubby.moderation_reviewers(account_id) values($1)', [users[2].id]);
 await actor(2);
 const { reports } = await rpc('moderation_review', 'queue');
 await rpc('moderation_review', 'resolve', { reportID: reports[0].id, decision: 'hide' });
 await actor(0);
 check((await rpc('recipes', 'get', { recipeID: owned })).content.title === 'Dish identity', 'Owner retains the Recipe after moderation');
 result = await option({ postID: post });
 check(result.recipe === null && result.unavailable === true, 'Moderation marks an unavailable candidate without opening the legacy fallback');
 await rejects(() => rpc('recipes', 'share_post', { postID: post, recipeID: owned, sourceRevision: 1, confirmed: true }));
 const newPost = randomUUID();
 await rejects(() => rpc('social_content', 'prepare', {
  postID: newPost, attemptID: emptyCook, expectedRevision: 0, confirmed: true, includeRecipe: true, recipeID: owned, sourceRevision: 1
 }));
 await db.exec('reset role');
 check((await db.query('select id from staygrubby.social_posts where id=$1', [newPost])).rows.length === 0,
  'Rejected moderation bypass leaves no new post or attachment');
 await actor(1);
 await rejects(() => rpc('recipes', 'get', { recipeID: owned }));
 await rejects(() => rpc('recipes', 'shared_post', { postID: post }));
 check((await rpc('social_feed', 'post', { postID: post })).posts[0].recipeID == null, 'The existing cook post remains but hides its attachment');
 await db.exec('reset role; set role anon');
 await rejects(() => option({ postID: post }));
} finally {
 await finish();
}
