// Recipe Unlink and Recently Deleted (November 20, 2026). Full migration chain in PGlite,
// plus the hosted deployment order (deployed head + Dish Variations + integrity core, then
// this migration). Never touches a hosted project.
import { fixture } from './social-harness.mjs';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

const dir = new URL('../../supabase/migrations/', import.meta.url);
const files = (await readdir(dir)).filter(f => f.endsWith('.sql')).sort();
const trashFile = files.find(f => f.endsWith('_recipe_unlink_and_recently_deleted.sql'));
const hostedOrder = process.argv.includes('--hosted-order');
const { db, users, actor, rpc, cooking, check, rejects, finish } = await fixture({ before: hostedOrder ? '20261116' : '99999999' });
if (hostedOrder) {
 for (const f of [files.find(f => f.endsWith('_dish_collections.sql')), files.find(f => f.endsWith('_dish_recipe_integrity.sql')), trashFile])
  await db.exec(await readFile(new URL(f, dir), 'utf8'));
}
const owner = users[0].id;
const content = (title, extra = {}) => ({ title, ingredients: ['1 cup arborio rice', 'stock'], steps: ['Toast the rice.', 'Add stock.'], ...extra });
const count = async (table, where = 'true', args = []) => Number((await db.query(`select count(*) n from staygrubby.${table} where ${where}`, args)).rows[0].n);
const asOwner = () => actor(0);

try {
 // Butternut Squash Risotto and Mushroom Risotto are separate Dishes, each with cooks.
 const { attempts } = await cooking(0, 2);
 await cooking(1, 1);
 await db.exec('reset role');
 const dishOf = async a => (await db.query('select dish_id from staygrubby.cooking_attempts where id=$1', [a])).rows[0].dish_id;
 const butternut = await dishOf(attempts[0]), mushroom = await dishOf(attempts[1]);
 const recipe = randomUUID(), other = randomUUID(), photo = randomUUID();
 await db.query('insert into staygrubby.recipe_photos(id,owner_id,path,sha256,byte_count,ready) values($1,$2,$3,$4,1000,true)', [photo, owner, `${owner}/${photo}.jpg`, 'a'.repeat(64)]);
 await asOwner();
 await rpc('recipes', 'save', { recipeID: recipe, recipeDishID: butternut, recipe: content('Butternut Squash Risotto'), visibility: 'private' });
 for (let revision = 1; revision <= 3; revision++)
  await rpc('recipes', 'save', { recipeID: recipe, expectedRevision: revision, recipe: content('Butternut Squash Risotto', { description: `Edit ${revision}` }), visibility: 'private' });
 await db.exec('reset role');
 await db.query(`update staygrubby.recipes set content=content||jsonb_build_object('photoID',$2::text),revision=revision+1 where id=$1`, [recipe, photo]);
 const revisionsBefore = await count('recipe_revisions', 'recipe_id=$1', [recipe]);
 const rankingBefore = JSON.stringify((await db.query('select id,strength from staygrubby.ranked_items order by id')).rows);
 await asOwner();
 check((await rpc('recipes', 'dish', { dishID: butternut })).recipe?.id === recipe, 'Butternut Squash Risotto shows its Recipe');

 // Unlink: only the association goes.
 await rejects(() => rpc('recipe_library', 'unlink_dish', { recipeID: recipe, dishID: mushroom }), 'PT409');
 await actor(1);
 await rejects(() => rpc('recipe_library', 'unlink_dish', { recipeID: recipe, dishID: butternut }), '42501');
 await asOwner();
 const unlinked = await rpc('recipe_library', 'unlink_dish', { recipeID: recipe, dishID: butternut });
 check(unlinked.recipe.id === recipe && unlinked.recipe.dishID == null, 'Unlink returns the same Recipe with no Dish');
 check((await rpc('recipes', 'dish', { dishID: butternut })).recipe === null, 'The Dish no longer shows the Recipe');
 check((await rpc('recipes', 'get', { recipeID: recipe })).id === recipe, 'The Recipe is still in Food Bible');
 await db.exec('reset role');
 check(await count('recipe_revisions', 'recipe_id=$1', [recipe]) === revisionsBefore, 'Unlink keeps every revision');
 check(await count('cooking_attempts', 'dish_id=$1 and deleted_at is null', [butternut]) === 1, 'The Dish keeps its cook');
 check(JSON.stringify((await db.query('select id,strength from staygrubby.ranked_items order by id')).rows) === rankingBefore, 'Rankings unchanged');

 // Link it to a different Dish; a second Recipe cannot take a Dish that already has one.
 await asOwner();
 await rpc('recipes', 'set_dish', { recipeID: recipe, recipeDishID: mushroom });
 check((await rpc('recipes', 'dish', { dishID: mushroom })).recipe?.id === recipe, 'The Recipe links to another Dish explicitly');
 await rpc('recipes', 'save', { recipeID: other, recipe: content('Saffron Risotto'), visibility: 'private' });
 await rejects(() => rpc('recipes', 'set_dish', { recipeID: other, recipeDishID: mushroom }), 'PT409');
 await rpc('recipes', 'set_dish', { recipeID: other, recipeDishID: butternut });

 // Delete moves it to Recently Deleted with its history; its photo stays referenced.
 await rpc('recipes', 'delete', { recipeID: recipe });
 await rejects(() => rpc('recipes', 'get', { recipeID: recipe }), '42501').catch(async () => check((await rpc('recipes', 'get', { recipeID: recipe })) == null, 'Deleted Recipe is gone'));
 let listed = (await rpc('recipe_library', 'deleted')).recipes;
 check(listed.length === 1 && listed[0].id === recipe && listed[0].title === 'Butternut Squash Risotto' && listed[0].dishName != null, 'Recently Deleted lists it with its Dish');
 await db.exec('reset role');
 check((await db.query('select staygrubby.recipe_photo_referenced($1) r', [photo])).rows[0].r === true, 'Its photo is not cleaned up while it can be restored');
 await actor(1);
 check((await rpc('recipe_library', 'deleted')).recipes.length === 0, 'Another account never sees it');
 await rejects(() => rpc('recipe_library', 'restore', { recipeID: recipe }), '42501');

 // Restore: same ID, content, revision and history; its Dish now has a Recipe, so it is not reclaimed.
 await asOwner();
 await db.exec('reset role'); await db.query('update staygrubby.recipes set dish_id=null where id=$1', [other]);
 await db.query('update staygrubby.recipes set dish_id=$2 where id=$1', [other, mushroom]).catch(() => {});
 await asOwner();
 const restored = await rpc('recipe_library', 'restore', { recipeID: recipe });
 check(restored.recipe.id === recipe && restored.recipe.revision === 5 && restored.recipe.content.photoID === photo, 'Restore keeps ID, revision and photo');
 check(restored.dishReattached === false && restored.recipe.dishID == null, 'A Dish that now has another Recipe is not reclaimed');
 await db.exec('reset role');
 check(await count('recipe_revisions', 'recipe_id=$1', [recipe]) === revisionsBefore, 'Restore keeps the whole Recipe History');
 check(await count('recipe_trash') === 0, 'Restored Recipes leave Recently Deleted');

 // Restore reclaims a free Dish.
 await asOwner();
 await rpc('recipes', 'set_dish', { recipeID: recipe, recipeDishID: butternut }).catch(async () => {
  await rpc('recipe_library', 'unlink_dish', { recipeID: other }); await rpc('recipes', 'set_dish', { recipeID: recipe, recipeDishID: butternut });
 });
 await rpc('recipes', 'delete', { recipeID: recipe });
 const back = await rpc('recipe_library', 'restore', { recipeID: recipe });
 check(back.dishReattached === true && back.recipe.dishID === butternut, 'A still-free Dish is reclaimed on restore');
 await rejects(() => rpc('recipe_library', 'restore', { recipeID: recipe }), '42501');

 // Delete Permanently, and 30-day expiry.
 await rpc('recipes', 'delete', { recipeID: recipe });
 await rpc('recipe_library', 'purge', { recipeID: recipe });
 check((await rpc('recipe_library', 'deleted')).recipes.length === 0, 'Delete Permanently removes it');
 await db.exec('reset role');
 check((await db.query('select staygrubby.recipe_photo_referenced($1) r', [photo])).rows[0].r === false, 'After permanent deletion its photo can be cleaned up');
 await asOwner();
 await rpc('recipes', 'delete', { recipeID: other });
 await db.exec('reset role'); await db.query("update staygrubby.recipe_trash set expires_at=now()-interval '1 second'");
 await asOwner();
 check((await rpc('recipe_library', 'deleted')).recipes.length === 0, 'Expired Recipes are removed on the next visit');

 // Account erasure never keeps a copy.
 await rpc('recipes', 'save', { recipeID: randomUUID(), recipe: content('Leaving'), visibility: 'private' });
 await db.exec('reset role');
 await db.query("update staygrubby.accounts set status='deleting' where id=$1", [owner]);
 await db.query('delete from staygrubby.accounts where id=$1', [owner]);
 check(await count('recipe_trash') === 0 && await count('recipes', 'owner_id=$1', [owner]) === 0, 'Erased accounts leave nothing in Recently Deleted');
 check(await count('dishes', 'account_id=$1', [users[1].id]) >= 1, 'Other accounts are untouched');
} finally {
 await finish();
}
