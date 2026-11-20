// Hosted deployment order rehearsal (November 20, 2026). Production runs migrations out of
// filename order: the deployed head 20261115154948, then Dish Variations
// (20261120150047), then the Dish/Recipe integrity core (20261118160000) ahead of the
// other pending files. This rebuilds that order in PGlite, checks a Dish never shows
// another Dish's Recipe, then applies every remaining pending migration in filename order
// and checks the behavior survives. Never touches a hosted project.
import { fixture } from './social-harness.mjs';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

const dir = new URL('../../supabase/migrations/', import.meta.url);
const files = (await readdir(dir)).filter(f => f.endsWith('.sql')).sort();
const early = [files.find(f => f.endsWith('_dish_collections.sql')), files.find(f => f.endsWith('_dish_recipe_integrity.sql'))];
const rest = files.filter(f => f > '20261115154948_~' && !early.includes(f));
const { db, users, actor, rpc, cooking, check, finish } = await fixture({ before: '20261116' });
const owner = users[0].id;
const content = title => ({ title, ingredients: ['rice'], steps: ['Stir.'] });

try {
 const { attempts } = await cooking(0, 2);
 await db.exec('reset role');
 const dishes = [];
 for (const [n, name] of ['Butternut Squash Risotto', 'Mushroom Risotto'].entries()) {
  const id = (await db.query('select dish_id from staygrubby.cooking_attempts where id=$1', [attempts[n]])).rows[0].dish_id;
  await db.query('update staygrubby.dishes set name=$2 where id=$1', [id, name]); dishes.push(id);
 }
 const [butternut, mushroom] = dishes;
 const recipe = randomUUID();
 await actor(0);
 await rpc('recipes', 'save', { recipeID: recipe, recipeDishID: butternut, recipe: content('Butternut Squash Risotto'), visibility: 'private' });
 // A stale family link of the kind that made the Recipe appear on a separated Dish.
 await db.exec('reset role');
 await db.query('insert into staygrubby.dish_recipes(account_id,dish_id,recipe_id) values($1,$2,$3)', [owner, mushroom, recipe]);
 await actor(0);
 check((await rpc('recipes', 'dish', { dishID: mushroom })).recipe?.id === recipe, 'Deployed head shows the Butternut Recipe on Mushroom Risotto (the reported defect)');

 await db.exec('reset role');
 for (const f of early) await db.exec(await readFile(new URL(f, dir), 'utf8'));
 await actor(0);
 check((await rpc('recipes', 'dish', { dishID: mushroom })).recipe === null, 'Integrity core alone: Mushroom Risotto shows no Recipe');
 check((await rpc('recipes', 'dish', { dishID: butternut })).recipe?.id === recipe, 'Butternut Squash Risotto keeps its own Recipe');

 await db.exec('reset role');
 for (const f of rest) await db.exec(await readFile(new URL(f, dir), 'utf8'));
 await actor(0);
 check((await rpc('recipes', 'dish', { dishID: mushroom })).recipe === null && (await rpc('recipes', 'dish', { dishID: butternut })).recipe?.id === recipe,
  `The other ${rest.length} pending migrations keep the behavior when applied afterwards`);
 check((await rpc('recipes', 'share_options', { attemptID: attempts[1] })).recipe === null, 'Share options never offer another Dish’s Recipe after the full chain');
} finally {
 await finish();
}
