import { fixture } from './social-harness.mjs';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

// Dish identity for Recipes: Dish and Recipe are two views of one Dish.
const directory = new URL('../../supabase/migrations/', import.meta.url);
const migration = (await readdir(directory)).find(name => name.endsWith('_dish_recipe_identity.sql'));
const { db, users, actor, rpc, cooking, check, rejects, finish } = await fixture({ before: migration });
const owner = users[0].id;
const content = title => ({ title, ingredients: ['salt'], steps: ['Cook'] });
const save = (id, title, extra = {}) => rpc('recipes', 'save', { recipeID: id, recipe: content(title), visibility: 'private', ...extra });
const index = async () => Object.fromEntries((await rpc('recipes', 'library_index', {})).entries.map(e => [e.recipeID, e]));

async function evidence() {
    await db.exec('reset role');
    const values = [];
    for (const table of ['dishes', 'cooking_attempts', 'ranked_items', 'comparisons', 'recipe_revisions', 'dish_recipes', 'dish_recipe_links', 'recipe_cook_links', 'recipe_cooks']) {
        values.push((await db.query(`select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) value from staygrubby.${table} t`)).rows[0].value);
    }
    values.push((await db.query(`select jsonb_agg(to_jsonb(t) order by id) value from staygrubby.recipes t`)).rows[0].value);
    return JSON.stringify(values);
}
async function dishOf(attempt) {
    await db.exec('reset role');
    return (await db.query('select dish_id from staygrubby.cooking_attempts where id=$1', [attempt])).rows[0].dish_id;
}

try {
    const graph = await cooking(0, 3);
    const [chili, stew, soup] = [await dishOf(graph.attempts[0]), await dishOf(graph.attempts[1]), await dishOf(graph.attempts[2])];
    const [main, extra, legacy, loose] = [randomUUID(), randomUUID(), randomUUID(), randomUUID()];
    await actor(0);
    for (const [id, title] of [[main, 'Chili main'], [extra, 'Chili extra'], [legacy, 'Stew family'], [loose, 'Never linked']]) await save(id, title);
    await rpc('recipes', 'link_dish_recipe', { dishID: chili, recipeID: main });
    await rpc('recipes', 'link_dish_recipe', { dishID: chili, recipeID: extra });
    await rpc('recipes', 'attach', { recipeID: legacy, dishID: stew });

    const before = await evidence();
    await db.exec(await readFile(new URL(migration, directory), 'utf8'));
    const after = JSON.parse(await evidence()), start = JSON.parse(before);
    check(JSON.stringify(after.slice(0, 9)) === JSON.stringify(start.slice(0, 9)), 'Migration rewrites no cooking, ranking, revision or relationship rows');
    const strip = rows => JSON.stringify(rows.map(({ dish_id, ...rest }) => rest));
    check(strip(after[9]) === strip(start[9]), 'Recipe content, revisions counters and ownership are unchanged');
    const assigned = Object.fromEntries(after[9].map(r => [r.id, r.dish_id]));
    check(assigned[main] === chili && assigned[legacy] === stew, 'Backfill gives each Recipe its existing Dish');
    check(assigned[extra] === null && assigned[loose] === null, 'A second Recipe of one Dish and an unlinked Recipe stay unassigned');

    await actor(0);
    let entries = await index();
    check(entries[main].dishID === chili && entries[main].cooked === true, 'Food Bible lists the Dish, cooked');
    check(entries[loose].dishID === null && entries[loose].cooked === false, 'An unassigned Recipe is not cooked yet');
    check((await rpc('recipes', 'get', { recipeID: main })).dishID === chili, 'The Recipe card carries its Dish identity');
    check((await rpc('recipes', 'dish', { dishID: chili })).recipe.id === main, 'The Dish opens its own Recipe');

    // Creating from Food Bible takes a new Dish identity before the Dish row syncs.
    const fresh = randomUUID(), freshDish = randomUUID();
    const created = await save(fresh, 'New granita', { recipeDishID: freshDish });
    check(created.dishID === freshDish, 'A new Recipe gets its Dish identity immediately');
    entries = await index();
    check(entries[fresh].dishID === freshDish && entries[fresh].cooked === false, 'Its Dish is not cooked yet');
    await rejects(() => save(randomUUID(), 'Duplicate', { recipeDishID: freshDish }), '40001');
    await rejects(() => rpc('recipes', 'set_dish', { recipeID: loose, recipeDishID: chili }), '40001');

    // Adding Recipe content from a Dish modifies that same Dish's Recipe side.
    const fromDish = randomUUID();
    check((await save(fromDish, 'Soup from the Dish', { recipeDishID: soup })).dishID === soup, 'Add Recipe from a Dish uses that Dish');
    check((await rpc('recipes', 'dish', { dishID: soup })).recipe.id === fromDish, 'The Dish now has that Recipe');

    // Editing never moves a Recipe off its live Dish.
    await save(fromDish, 'Soup from the Dish, edited', { recipeDishID: freshDish, expectedRevision: 1 }).catch(() => {});
    check((await rpc('recipes', 'get', { recipeID: fromDish })).dishID === soup, 'Edits keep the Dish identity');

    // A removed Dish frees its Recipe; the next cook of that Recipe gives it the new Dish.
    await db.exec('reset role');
    await db.query('update staygrubby.cooking_attempts set deleted_at=now() where id=$1', [graph.attempts[2]]);
    await db.query('update staygrubby.dishes set deleted_at=now() where id=$1', [soup]);
    await actor(0);
    check((await rpc('recipes', 'get', { recipeID: fromDish })).dishID === null, 'A removed Dish is not shown as the Recipe Dish');
    const origin = await rpc('recipes', 'begin', { originID: randomUUID(), recipeID: fromDish });
    await db.exec('reset role');
    const newDish = randomUUID(), attempt = randomUUID();
    await db.query("insert into staygrubby.dishes(account_id,id,name,default_course_code,created_at_ref) values($1,$2,'Soup again','soup',1000)", [owner, newDish]);
    await db.query(`insert into staygrubby.ranked_items(account_id,id,ranking_id,name,created_at_ref,strength,uncertainty) values($1,$2,$3,'Soup again',1000,0,1)`, [owner, origin.itemID, graph.ranking]);
    await db.query(`insert into staygrubby.cooking_attempts(account_id,id,dish_id,ranked_item_id,course_code,sequence_number,created_at_ref,updated_at_ref,is_legacy_import)
        values($1,$2,$3,$4,'soup',1,1000,1000,false)`, [owner, attempt, newDish, origin.itemID]);
    await actor(0);
    check((await rpc('recipes', 'get', { recipeID: fromDish })).dishID === newDish, 'Cooking the Recipe gives it the new Dish');
    const provenance = await rpc('recipes', 'cook', { attemptID: attempt });
    check(provenance.usedRecipe.revision >= 1 && provenance.usedRecipe.recipeID === fromDish, 'Exact Recipe revision provenance is preserved for the cook');

    // Privacy: another account sees no Dish identity and cannot claim or open it.
    await actor(0); await rpc('recipes', 'save', { recipeID: main, recipe: content('Chili main'), visibility: 'friends', expectedRevision: 1 }).catch(() => {});
    await actor(1);
    await rejects(() => rpc('recipes', 'set_dish', { recipeID: main, recipeDishID: randomUUID() }));
    check((await rpc('recipes', 'dish', { dishID: chili })).recipe == null, 'Another account cannot open my Dish Recipe by Dish ID');
    await rejects(() => db.query('select dish_id from staygrubby.recipes'));
} finally {
    await finish();
}
