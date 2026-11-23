// Dish/Recipe integrity and Dish collections (November 18, 2026). Runs the full migration chain
// in PGlite; never touches a hosted project.
import { fixture } from './social-harness.mjs';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID, createHash } from 'node:crypto';

const dir = new URL('../../supabase/migrations/', import.meta.url);
const integrity = (await readdir(dir)).find(f => f.endsWith('_dish_recipe_integrity.sql'));
const collections = (await readdir(dir)).find(f => f.endsWith('_dish_collections.sql'));
const shareIntegrity = (await readdir(dir)).find(f => f.endsWith('_recipe_share_option_integrity.sql'));
// Since the November 21 hosted renaming, share-option integrity sorts after the integrity migration and the
// whole deployed chain between them. Start before the integrity migration and replay that span in filename
// (hosted) order, so the predecessor still shows the stale link the repair removes.
const span = (await readdir(dir)).filter(f => f.endsWith('.sql') && f >= integrity && f <= shareIntegrity).sort();
const { db, users, actor, rpc, cooking, check, rejects, finish } = await fixture({ before: integrity });
const owner = users[0].id;
const content = title => ({ title, ingredients: ['rice'], steps: ['Stir.'] });
const dishOf = async attempt => (await db.query('select dish_id from staygrubby.cooking_attempts where id=$1', [attempt])).rows[0].dish_id;
const fingerprint = async () => {
 const parts = [];
 for (const table of ['recipes', 'recipe_revisions', 'dishes', 'cooking_attempts', 'ranked_items', 'recipe_cooks', 'dish_recipes'])
  parts.push((await db.query(`select count(*) n from staygrubby.${table}`)).rows[0].n);
 return parts.join('/');
};

try {
 // Butternut Squash Risotto → Recipe A, Mushroom Risotto → Recipe B, Saffron Risotto → none.
 const { attempts } = await cooking(0, 4);
 const [butternutCook, mushroomCook, saffronCook, legacyCook] = attempts;
 const [butternut, mushroom, saffron, legacyDish] = await Promise.all(attempts.map(dishOf));
 await db.exec('reset role');
 const names = [[butternut, 'Butternut Squash Risotto'], [mushroom, 'Mushroom Risotto'], [saffron, 'Saffron Risotto'], [legacyDish, 'Legacy Risotto']];
 for (const [id, name] of names) await db.query('update staygrubby.dishes set name=$2 where id=$1', [id, name]);
 const recipeA = randomUUID(), recipeB = randomUUID(), legacyOnly = randomUUID();
 await actor(0);
 await rpc('recipes', 'save', { recipeID: recipeA, recipeDishID: butternut, recipe: content('Butternut Squash Risotto'), visibility: 'private' });
 await rpc('recipes', 'save', { recipeID: recipeB, recipeDishID: mushroom, recipe: content('Mushroom Risotto'), visibility: 'private' });
 await rpc('recipes', 'save', { recipeID: legacyOnly, recipe: content('Old family Recipe'), visibility: 'private' });
 // Stale legacy family links of the kind older paths wrote: Recipe A on Saffron, and a Recipe with no identity.
 await db.exec('reset role');
 await db.query('insert into staygrubby.dish_recipes(account_id,dish_id,recipe_id) values($1,$2,$3),($1,$4,$5)', [owner, saffron, recipeA, legacyDish, legacyOnly]);
 await actor(0);
 const dishRecipe = async dish => (await rpc('recipes', 'dish', { dishID: dish })).recipe;
 check((await dishRecipe(saffron))?.id === recipeA, 'Predecessor shows Recipe A on Saffron Risotto through the stale legacy link');

 await db.exec('reset role');
 const before = await fingerprint();
 for (const f of span) await db.exec(await readFile(new URL(f, dir), 'utf8'));
 check(await fingerprint() === before, 'Integrity migrations delete or add no rows');
 check((await db.query('select dish_id from staygrubby.recipes where id=$1', [legacyOnly])).rows[0].dish_id === legacyDish,
  'A Recipe whose only legacy link is one Dish without a Recipe takes that Dish (provable repair)');
 check((await db.query('select dish_id from staygrubby.recipes where id=$1', [recipeA])).rows[0].dish_id === butternut,
  'Recipe A keeps its own Dish');

 await actor(0);
 check((await dishRecipe(butternut))?.id === recipeA, 'Butternut Squash Risotto shows Recipe A');
 check((await dishRecipe(mushroom))?.id === recipeB, 'Mushroom Risotto shows Recipe B');
 check((await dishRecipe(saffron)) === null, 'Saffron Risotto shows no Recipe despite the stale legacy link');
 check((await dishRecipe(legacyDish))?.id === legacyOnly, 'The repaired legacy Dish shows its Recipe');

 // Share options follow the cook's Dish identity, never the stale legacy link.
 check((await rpc('recipes', 'share_options', { attemptID: saffronCook })).recipe === null, 'Sharing a Saffron cook offers no Recipe');
 check((await rpc('recipes', 'share_options', { attemptID: mushroomCook })).recipe?.id === recipeB, 'Sharing a Mushroom cook offers Recipe B');
 check((await rpc('recipes', 'share_options', { attemptID: butternutCook })).recipe?.id === recipeA, 'Sharing a Butternut cook offers Recipe A');

 // Editing Recipe A never touches another Dish's Recipe.
 await rpc('recipes', 'save', { recipeID: recipeA, recipe: content('Butternut Squash Risotto, brown butter'), visibility: 'private', expectedRevision: 1 });
 check((await dishRecipe(mushroom))?.content?.title !== 'Butternut Squash Risotto, brown butter' && (await dishRecipe(mushroom))?.id === recipeB, 'Editing Recipe A leaves Mushroom Risotto unchanged');
 // Explicit linking of a Recipe that already belongs to a Dish is refused, not silently moved.
 await rejects(() => rpc('recipes', 'set_dish', { recipeID: recipeB, recipeDishID: butternut }), 'PT409');

 // New legacy writes that disagree with identity are skipped; agreeing ones remain possible.
 await db.exec('reset role');
 const legacyBefore = (await db.query('select count(*) n from staygrubby.dish_recipes')).rows[0].n;
 await db.query('insert into staygrubby.dish_recipes(account_id,dish_id,recipe_id) values($1,$2,$3) on conflict do nothing', [owner, mushroom, recipeA]);
 check((await db.query('select count(*) n from staygrubby.dish_recipes')).rows[0].n === legacyBefore, 'A legacy link to another Dish’s Recipe is not written');
 await db.query('insert into staygrubby.dish_recipes(account_id,dish_id,recipe_id) values($1,$2,$3) on conflict do nothing', [owner, mushroom, recipeB]);
 check(Number((await db.query('select count(*) n from staygrubby.dish_recipes')).rows[0].n) === Number(legacyBefore) + 1, 'A legacy link that agrees with identity is still accepted');

 // Dish collections: one column, synced only when sent; old clients leave it unchanged.
 // Hosted order deploys Dish collections (20261120150047) before the integrity migration, so the fixture already has it.
 if (collections > integrity) await db.exec(await readFile(new URL(collections, dir), 'utf8'));
 await actor(0);
 const record = (entity, data) => ({ reference: { entity, key: data.id }, data: Buffer.from(JSON.stringify(data)).toString('base64') });
 const apply = async upserts => {
  const revision = (await db.query('select sync_revision n from staygrubby.accounts where id=$1', [owner])).rows[0].n;
  const payload = Buffer.from(JSON.stringify({ upserts, deletions: [], photoCollectionVersion: 1 }));
  return (await db.query('select api.apply_cooking_operation($1::jsonb) result', [JSON.stringify({ operationID: randomUUID(), storeID: randomUUID(), accountID: owner, kind: 'editDish', payload: payload.toString('base64'), payloadHash: createHash('sha256').update(payload).digest('hex'), expectedRevision: Number(revision) })])).rows[0].result;
 };
 const dishRow = (id, name, extra = {}) => ({ id, name, defaultCategoryCode: 'soup', createdAt: 1000, sourceID: null, ...extra });
 await apply([record('dish', dishRow(butternut, 'Butternut Squash Risotto', { collections: ['Risotto', 'Comfort Food'] })),
  record('dish', dishRow(mushroom, 'Mushroom Risotto', { collections: ['Risotto'] }))]);
 let graph = (await db.query('select api.open_account_library() result')).rows[0].result.graph;
 const restored = id => graph.dishes.find(d => d.id === id).collections;
 check(JSON.stringify(restored(butternut)) === '["Risotto","Comfort Food"]' && JSON.stringify(restored(mushroom)) === '["Risotto"]', 'Collections restore per Dish; one Dish in two collections');
 check(graph.dishes.find(d => d.id === saffron).hasOwnProperty('collections') && restored(saffron) === null, 'Dishes without collections restore an explicit empty value');
 await apply([record('dish', dishRow(butternut, 'Butternut Squash Risotto'))]);
 graph = (await db.query('select api.open_account_library() result')).rows[0].result.graph;
 check(restored(butternut).length === 2, 'An older client that omits collections leaves them unchanged');
 await rejects(() => apply([record('dish', dishRow(saffron, 'Saffron Risotto', { collections: ['x'.repeat(41)] }))]), '22023');
 await rejects(() => apply([record('dish', dishRow(saffron, 'Saffron Risotto', { collections: [42] }))]), '22023');
 await rejects(() => apply([record('dish', dishRow(saffron, 'Saffron Risotto', { collections: Array.from({ length: 21 }, (_, n) => 'C' + n) }))]), '22023');
 await db.exec('reset role');
 check((await db.query('select count(*) n from staygrubby.dishes where account_id=$1', [owner])).rows[0].n == 4, 'Collections create no Dish rows');
 check((await db.query('select count(*) n from staygrubby.recipes where owner_id=$1', [owner])).rows[0].n == 3, 'Collections create no Recipe rows');
} finally {
 await finish();
}
