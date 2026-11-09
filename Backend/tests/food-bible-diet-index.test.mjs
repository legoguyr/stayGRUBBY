import { fixture } from './social-harness.mjs';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

// Food Bible Diet filter: library_index carries each Recipe's Diet as written.
const directory = new URL('../../supabase/migrations/', import.meta.url);
const migration = (await readdir(directory)).find(name => name.endsWith('_food_bible_diet_index.sql'));
const { db, actor, rpc, check, finish } = await fixture({ before: migration });
const save = (id, title, extra = {}) => rpc('recipes', 'save', { recipeID: id, recipe: { title, ingredients: ['beans'], steps: ['Cook'], ...extra }, visibility: 'private' });
try {
    const [vegan, plain] = [randomUUID(), randomUUID()];
    await actor(0);
    await save(vegan, 'Bean stew', { dietary: ['vegan', 'glutenFree'] }); await save(plain, 'Plain stew');
    await db.exec('reset role');
    const before = (await db.query('select jsonb_agg(to_jsonb(t) order by id) v from staygrubby.recipes t')).rows[0].v;
    await db.exec(await readFile(new URL(migration, directory), 'utf8'));
    check(JSON.stringify((await db.query('select jsonb_agg(to_jsonb(t) order by id) v from staygrubby.recipes t')).rows[0].v) === JSON.stringify(before), 'Migration changes no rows');
    await actor(0);
    const entries = Object.fromEntries((await rpc('recipes', 'library_index', {})).entries.map(e => [e.recipeID, e]));
    check(JSON.stringify(entries[vegan].dietary) === JSON.stringify(['glutenFree', 'vegan']), 'Index carries Diet as written');
    check(!('dietary' in entries[plain]), 'A Recipe without Diet has no Diet');
    check(entries[vegan].dishID === null && entries[vegan].cooked === false, 'Earlier index fields are preserved');
    await actor(1);
    check((await rpc('recipes', 'library_index', {})).entries.length === 0, 'Another account sees nothing private');
} finally { await finish(); }
