import { fixture } from './social-harness.mjs';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

// D1 Unified Dish foundation: several Recipes per Dish, one Main, automatic
// association for explicit provenance, Recipe Diet as written. Evidence untouched.
const directory = new URL('../../supabase/migrations/', import.meta.url);
const migration = (await readdir(directory)).find(name => name.endsWith('_dish_recipe_links.sql'));
const { db, users, actor, rpc, cooking, check, rejects, finish } = await fixture({ before: migration });
const owner = users[0].id;
const recipe = title => ({ title, ingredients: ['1 onion'], steps: ['Cook it'] });

async function evidence() {
    await db.exec('reset role');
    const values = [];
    for (const table of ['dishes', 'cooking_attempts', 'ranked_items', 'comparisons', 'recipes', 'recipe_revisions', 'recipe_cook_links', 'recipe_cooks']) {
        values.push((await db.query(`select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) value from staygrubby.${table} t`)).rows[0].value);
    }
    return JSON.stringify(values);
}
async function save(id, title, extra = {}) {
    return rpc('recipes', 'save', { recipeID: id, recipe: { ...recipe(title), ...extra }, visibility: 'private' });
}
const ids = value => value.recipes.map(entry => entry.recipe.id);

try {
    const graph = await cooking(0, 4);
    const dishes = [];
    for (const attempt of graph.attempts) {
        dishes.push((await db.query('select dish_id from staygrubby.cooking_attempts where id=$1', [attempt])).rows[0].dish_id);
    }
    const [r1, r2, r3, r4] = [randomUUID(), randomUUID(), randomUUID(), randomUUID()];
    await actor(0);
    await save(r1, 'Old family soup');
    await rpc('recipes', 'attach', { recipeID: r1, dishID: dishes[0] });
    await db.exec('reset role');
    const legacyBefore = (await db.query('select jsonb_agg(to_jsonb(t) order by dish_id) value from staygrubby.dish_recipes t')).rows[0].value;
    const before = await evidence();
    await db.exec(await readFile(new URL(migration, directory), 'utf8'));
    check(await evidence() === before, 'Migration preserves IDs, evidence, Recipes, revisions, cook links and used snapshots');
    check(JSON.stringify((await db.query('select jsonb_agg(to_jsonb(t) order by dish_id) value from staygrubby.dish_recipes t')).rows[0].value) === JSON.stringify(legacyBefore), 'Legacy family links are kept unchanged');
    const copied = (await db.query('select * from staygrubby.dish_recipe_links')).rows;
    check(copied.length === 1 && copied[0].recipe_id === r1 && copied[0].is_main === false, 'Legacy link copied once and not marked as a chosen Main');

    await actor(0);
    let view = await rpc('recipes', 'dish_recipes', { dishID: dishes[0] });
    check(view.mainRecipeID === r1 && view.chosenMainRecipeID === null && view.recipes[0].legacy === true, 'Default Main is the legacy family link');

    await save(r2, 'Spicy soup'); await save(r3, 'Green soup'); await save(r4, 'Unrelated');
    view = await rpc('recipes', 'link_dish_recipe', { dishID: dishes[0], recipeID: r2 });
    check(ids(view).length === 2 && view.mainRecipeID === r1 && view.chosenMainRecipeID === null, 'Linking a second Recipe keeps the default Main; several Recipes per Dish');
    view = await rpc('recipes', 'set_main_recipe', { dishID: dishes[0], recipeID: r2, expectedMainID: null });
    check(view.mainRecipeID === r2 && view.chosenMainRecipeID === r2, 'User choice overrides the default');
    await rejects(() => rpc('recipes', 'set_main_recipe', { dishID: dishes[0], recipeID: r1, expectedMainID: null }), '40001');
    await rejects(() => rpc('recipes', 'set_main_recipe', { dishID: dishes[0], recipeID: r4, expectedMainID: r2 }), '42501');
    view = await rpc('recipes', 'set_main_recipe', { dishID: dishes[0], recipeID: r1, expectedMainID: r2 });
    check(view.chosenMainRecipeID === r1, 'Compare-and-swap Main change succeeds with the current value');

    // Explicit exact cook link associates automatically; first Recipe becomes Main.
    await rpc('recipes', 'link_cook', { recipeID: r3, attemptID: graph.attempts[1] });
    view = await rpc('recipes', 'dish_recipes', { dishID: dishes[1] });
    check(view.chosenMainRecipeID === r3 && view.recipes[0].dishLinked && view.recipes[0].linkedAttemptIDs[0] === graph.attempts[1], 'Exact cook link adds an auto-Main Dish Recipe');

    // Recipe-origin cook completes through the Codex lifecycle trigger.
    const origin = await rpc('recipes', 'begin', { originID: randomUUID(), recipeID: r2 });
    await db.exec('reset role');
    const used = randomUUID();
    await db.query(`insert into staygrubby.ranked_items(account_id,id,ranking_id,name,created_at_ref,strength,uncertainty)
        values($1,$2,$3,'Recipe cook',1000,0,1)`, [owner, origin.itemID, graph.ranking]);
    await db.query(`insert into staygrubby.cooking_attempts(account_id,id,dish_id,ranked_item_id,course_code,sequence_number,created_at_ref,updated_at_ref,is_legacy_import)
        values($1,$2,$3,$4,'soup',2,1000,1000,false)`, [owner, used, dishes[2], origin.itemID]);
    await actor(0);
    view = await rpc('recipes', 'dish_recipes', { dishID: dishes[2] });
    check(view.chosenMainRecipeID === r2 && view.recipes[0].usedByAttemptIDs.includes(used), 'Completed Recipe-origin cook associates its Dish automatically');

    // Main never establishes use: the Main of dish 0 has no used snapshot there.
    view = await rpc('recipes', 'dish_recipes', { dishID: dishes[0] });
    check(view.recipes.every(entry => entry.usedByAttemptIDs.length === 0), 'Main and Dish links never imply a cook used the Recipe');

    // Unlinking the chosen Main returns to the deterministic default.
    view = await rpc('recipes', 'unlink_dish_recipe', { dishID: dishes[0], recipeID: r1 });
    check(view.chosenMainRecipeID === null && view.mainRecipeID === r2 && ids(view).join() === r2, 'Unlinking the chosen Main removes the legacy row too and falls back to the oldest related Recipe');
    view = await rpc('recipes', 'unlink_dish_recipe', { dishID: dishes[0], recipeID: r2 });
    check(view.recipes.length === 0 && view.mainRecipeID === null, 'A Dish can return to having no Recipe');

    // Existing app builds still write the legacy relation; it stays mirrored.
    await rpc('recipes', 'attach', { recipeID: r4, dishID: dishes[3] });
    view = await rpc('recipes', 'dish_recipes', { dishID: dishes[3] });
    check(view.chosenMainRecipeID === r4 && view.recipes[0].legacy && view.recipes[0].dishLinked, 'Legacy attach mirrors into Dish Recipes');
    await rpc('recipes', 'detach', { recipeID: r4, dishID: dishes[3] });
    check((await rpc('recipes', 'dish_recipes', { dishID: dishes[3] })).recipes.length === 0, 'Legacy detach removes the mirrored association');

    // Owner privacy.
    await actor(1);
    await rejects(() => rpc('recipes', 'dish_recipes', { dishID: dishes[1] }), '40001');
    await rejects(() => rpc('recipes', 'link_dish_recipe', { dishID: dishes[1], recipeID: r3 }), '40001');
    await rejects(() => db.query('select * from staygrubby.dish_recipe_links'));
    await rejects(() => db.query('insert into staygrubby.dish_recipe_links(account_id,dish_id,recipe_id) values($1,$2,$3)', [owner, dishes[1], r4]));
    const foreign = await cooking(1, 1);
    const foreignDish = (await db.query('select dish_id from staygrubby.cooking_attempts where id=$1', [foreign.attempts[0]])).rows[0].dish_id;
    await actor(1);
    await rejects(() => rpc('recipes', 'link_dish_recipe', { dishID: foreignDish, recipeID: r3 }), '42501');

    // Recipe Diet as written: author-selected codes only, never Certification.
    await actor(0);
    const diet = await save(randomUUID(), 'Vegan stew', { dietary: ['vegan', 'dairyFree'] });
    check(JSON.stringify(diet.content.dietary) === JSON.stringify(['dairyFree', 'vegan']), 'Recipe Diet stored as sorted codes');
    check(!('dietary' in (await save(randomUUID(), 'No diet', { dietary: [] })).content), 'Empty Diet is omitted');
    await rejects(() => save(randomUUID(), 'Certified', { dietary: ['halal'] }), '22023');
    await rejects(() => save(randomUUID(), 'Twice', { dietary: ['vegan', 'vegan'] }), '22023');
    check((await save(randomUUID(), 'Old client', {})).content.dietary === undefined, 'Clients without Diet are unchanged');

    await db.exec('reset role');
    const [startDishes, startAttempts, startItems, startComparisons] = JSON.parse(before);
    const [, afterAttempts, afterItems, afterComparisons] = JSON.parse(await evidence());
    const kept = (rows, all) => rows.every(row => all.some(next => JSON.stringify(next) === JSON.stringify(row)));
    check(JSON.stringify(afterComparisons) === JSON.stringify(startComparisons), 'Comparisons are never written by Dish Recipe actions');
    check(kept(startItems, afterItems) && kept(startAttempts, afterAttempts), 'Existing ranked items (strength, uncertainty) and cooks are unchanged');
    check(startDishes.length === 4, 'Fixture Dishes were present before the migration');
} finally {
    await finish();
}
