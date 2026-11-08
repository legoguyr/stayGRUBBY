import { fixture } from './social-harness.mjs';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

// D2: Food Bible names one Dish per Recipe (Main Dish first) and says whether it is cooked.
const directory = new URL('../../supabase/migrations/', import.meta.url);
const migration = (await readdir(directory)).find(name => name.endsWith('_food_bible_dish_resolution.sql'));
const { db, users, actor, rpc, cooking, check, rejects, finish } = await fixture({ before: migration });

async function evidence() {
    await db.exec('reset role');
    const values = [];
    for (const table of ['dishes', 'cooking_attempts', 'ranked_items', 'comparisons', 'recipes', 'recipe_revisions', 'dish_recipes', 'dish_recipe_links', 'recipe_cook_links', 'recipe_cooks']) {
        values.push((await db.query(`select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) value from staygrubby.${table} t`)).rows[0].value);
    }
    return JSON.stringify(values);
}
const save = (id, title) => rpc('recipes', 'save', { recipeID: id, recipe: { title, ingredients: ['salt'], steps: ['Cook'] }, visibility: 'private' });
const index = async () => Object.fromEntries((await rpc('recipes', 'library_index', {})).entries.map(e => [e.recipeID, e]));

try {
    const graph = await cooking(0, 2);
    const dishOf = async attempt => (await db.query('select dish_id from staygrubby.cooking_attempts where id=$1', [attempt])).rows[0].dish_id;
    const [chili, stew] = [await dishOf(graph.attempts[0]), await dishOf(graph.attempts[1])];
    await db.query("update staygrubby.dishes set name='Chili' where id=$1", [chili]);
    await db.query("update staygrubby.dishes set name='Stew' where id=$1", [stew]);
    const [main, second, shared, alone] = [randomUUID(), randomUUID(), randomUUID(), randomUUID()];
    await actor(0);
    for (const [id, title] of [[main, 'Chili main'], [second, 'Chili spicy'], [shared, 'Shared base'], [alone, 'Not cooked yet']]) await save(id, title);
    await rpc('recipes', 'link_dish_recipe', { dishID: chili, recipeID: main });
    await rpc('recipes', 'link_dish_recipe', { dishID: chili, recipeID: second });
    await rpc('recipes', 'link_dish_recipe', { dishID: chili, recipeID: shared });
    await rpc('recipes', 'link_dish_recipe', { dishID: stew, recipeID: shared });
    const before = await evidence();
    let entries = await index();
    check(entries[second].dishID === null, 'Before D2 the index cannot see Recipes linked only through Dish Recipes');

    await db.exec(await readFile(new URL(migration, directory), 'utf8'));
    check(await evidence() === before, 'Migration changes no rows');
    await actor(0);
    entries = await index();
    check(entries[main].dishID === chili && entries[main].dishTitle === 'Chili' && entries[main].cooked === true, 'Main Recipe names its Dish, cooked');
    check(entries[second].dishID === chili && entries[second].cooked === true, 'A second Recipe of a cooked Dish is cooked');
    check(entries[shared].dishID === stew, 'A Recipe related to several Dishes names the Dish whose Main it is (Stew auto-main)');
    check(entries[alone].dishID === null && entries[alone].cooked === false, 'A Recipe-only Dish is not cooked yet');
    check(Object.keys(entries).length === 4, 'Every owned Recipe is listed once');

    // Choosing another Main moves the card to the Dish whose Main it is.
    await rpc('recipes', 'set_main_recipe', { dishID: chili, recipeID: shared, expectedMainID: main });
    entries = await index();
    check(entries[shared].dishID === chili, 'Main Dish takes precedence and wins the name tie-break');
    check(entries[main].dishID === chili, 'A non-Main Recipe still names its only related Dish');

    // Deleting the only cook makes the Dish not cooked; nothing is inferred.
    await db.exec('reset role');
    await db.query('update staygrubby.cooking_attempts set deleted_at=now() where id=$1', [graph.attempts[1]]);
    await db.query('update staygrubby.dishes set deleted_at=now() where id=$1', [stew]);
    await actor(0);
    entries = await index();
    check(entries[shared].dishID === chili, 'A deleted Dish is never named');

    // Other actions and other accounts are unchanged.
    await actor(1);
    check(Object.keys(await index()).length === 0, 'Another account sees none of these Recipes');
    await rejects(() => db.query('select staygrubby.recipe_primary_dish($1,$2)', [users[0].id, main]));
} finally {
    await finish();
}
