// Dish Variations deployment rehearsal (November 18, 2026). Rebuilds the hosted migration head
// (20261115154948) in PGlite, applies ONLY the dish_collections migration (deployed alone November 20 as 20261120150047), and checks that existing
// data is preserved, sync round-trips labels, older clients and other accounts cannot erase or write
// them, and the remaining pending migrations still apply afterwards. Never touches a hosted project.
import { fixture } from './social-harness.mjs';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID, createHash } from 'node:crypto';

const dir = new URL('../../supabase/migrations/', import.meta.url);
const files = (await readdir(dir)).filter(f => f.endsWith('.sql')).sort();
const collections = files.find(f => f.endsWith('_dish_collections.sql'));
const hostedHead = '20261115154948';
const pending = files.filter(f => f > `${hostedHead}_~` && f !== collections);
const { db, users, actor, cooking, check, rejects, finish } = await fixture({ before: '20261116' });
const owner = users[0].id, other = users[1].id;

const fingerprint = async () => {
 const rows = [];
 for (const [table, order] of [['dishes', 'id'], ['cooking_attempts', 'id'], ['ranked_items', 'id'], ['rankings', 'id'], ['account_libraries', 'account_id']])
  rows.push(createHash('sha256').update(JSON.stringify((await db.query(`select to_jsonb(t) - 'collections' j from staygrubby.${table} t order by ${order}`)).rows)).digest('hex'));
 return rows.join('/');
};
const record = (entity, data) => ({ reference: { entity, key: data.id }, data: Buffer.from(JSON.stringify(data)).toString('base64') });
const apply = async (account, upserts) => {
 const revision = (await db.query('select sync_revision n from staygrubby.accounts where id=$1', [account])).rows[0].n;
 const payload = Buffer.from(JSON.stringify({ upserts, deletions: [], photoCollectionVersion: 1 }));
 return (await db.query('select api.apply_cooking_operation($1::jsonb) result', [JSON.stringify({ operationID: randomUUID(), storeID: randomUUID(), accountID: account, kind: 'editDish', payload: payload.toString('base64'), payloadHash: createHash('sha256').update(payload).digest('hex'), expectedRevision: Number(revision) })])).rows[0].result;
};
const dishRow = (id, name, extra = {}) => ({ id, name, defaultCategoryCode: 'soup', createdAt: 1000, sourceID: null, ...extra });
const graph = async () => (await db.query('select api.open_account_library() result')).rows[0].result.graph;

try {
 check(pending.length > 0 && !pending.includes(collections), `The other migrations stay pending (${pending.length})`);
 // Three independent risotto Dishes with their own cooks, before deployment.
 const { attempts } = await cooking(0, 3);
 await cooking(1, 1);
 await db.exec('reset role');
 const dishes = [];
 for (const [n, name] of ['Butternut Squash Risotto', 'Mushroom Risotto', 'Pea and Mahi Mahi Risotto'].entries()) {
  const id = (await db.query('select dish_id from staygrubby.cooking_attempts where id=$1', [attempts[n]])).rows[0].dish_id;
  await db.query('update staygrubby.dishes set name=$2 where id=$1', [id, name]); dishes.push(id);
 }
 const [butternut, mushroom, pea] = dishes;
 const before = await fingerprint();
 // The function bodies the migration patches match hosted production byte-for-byte (read-only
 // md5 of pg_get_functiondef on ayjflxstqmnuoiphbyek, November 18, 2026).
 const bodies = (await db.query("select md5(pg_get_functiondef('staygrubby.apply_cooking_operation_model_legacy(jsonb)'::regprocedure)) a, md5(pg_get_functiondef('staygrubby.open_account_library()'::regprocedure)) o")).rows[0];
 check(bodies.a === 'f69a15c967c45e2e7315a8444249e8bc' && bodies.o === '2c33affcfe3081df9a16132669586bde', 'Rehearsal predecessor equals the hosted sync functions');

 // Deploy only the Dish Variations migration on the hosted head.
 await db.exec(await readFile(new URL(collections, dir), 'utf8'));
 check(await fingerprint() === before, 'Existing Dishes, cooks, ranked items and libraries are byte-identical after the migration');
 check((await db.query("select count(*) n from staygrubby.dishes where collections <> '{}'")).rows[0].n == 0, 'Every existing Dish starts in no variation');
 await actor(0);
 check((await graph()).dishes.every(d => d.collections === null), 'Restore sends an explicit empty value for existing Dishes');

 // Create Risotto with three Dishes; one Dish also in a second variation.
 await apply(owner, [record('dish', dishRow(butternut, 'Butternut Squash Risotto', { collections: ['Risotto', 'Comfort Food'] })),
  record('dish', dishRow(mushroom, 'Mushroom Risotto', { collections: ['Risotto'] })),
  record('dish', dishRow(pea, 'Pea and Mahi Mahi Risotto', { collections: ['Risotto'] }))]);
 let g = await graph();
 const labels = id => JSON.stringify(g.dishes.find(d => d.id === id).collections);
 check(labels(butternut) === '["Risotto","Comfort Food"]' && labels(mushroom) === '["Risotto"]' && labels(pea) === '["Risotto"]', 'One variation holds three Dishes; one Dish is in two variations');
 check(g.dishes.length === 3 && g.attempts.length === 3, 'Variations create no Dish or cook rows; each Dish keeps its own cook');

 // Rename (labels only) and remove one Dish from the variation.
 await apply(owner, [record('dish', dishRow(butternut, 'Butternut Squash Risotto', { collections: ['Risottos', 'Comfort Food'] })),
  record('dish', dishRow(mushroom, 'Mushroom Risotto', { collections: ['Risottos'] })),
  record('dish', dishRow(pea, 'Pea and Mahi Mahi Risotto', { collections: [] }))]);
 g = await graph();
 check(labels(butternut) === '["Risottos","Comfort Food"]' && labels(mushroom) === '["Risottos"]' && labels(pea) === 'null', 'Rename and removal change only labels');
 check(g.dishes.find(d => d.id === pea).name === 'Pea and Mahi Mahi Risotto', 'A Dish removed from a variation is not deleted');

 // An older app (no collections field) editing the Dish never erases its variations.
 await apply(owner, [record('dish', dishRow(butternut, 'Butternut Squash Risotto (edited)'))]);
 g = await graph();
 check(labels(butternut) === '["Risottos","Comfort Food"]', 'Older clients leave variation memberships unchanged');

 // Bounds and ownership.
 await rejects(() => apply(owner, [record('dish', dishRow(pea, 'Pea', { collections: [' padded'] }))]), '22023');
 await rejects(() => apply(owner, [record('dish', dishRow(pea, 'Pea', { collections: 'Risotto' }))]), '22023');
 await actor(1);
 let crossAccount = false;
 try { await apply(owner, [record('dish', dishRow(mushroom, 'Mushroom Risotto', { collections: ['Hijacked'] }))]); } catch { crossAccount = true; }
 check(crossAccount, 'Another account cannot write this account’s variations');
 check((await graph()).dishes.every(d => !dishes.includes(d.id)), 'Another account never restores this account’s Dishes');
 await db.exec('reset role');
 check(JSON.stringify((await db.query('select collections from staygrubby.dishes where id=$1', [mushroom])).rows[0].collections) === '["Risottos"]', 'Stored labels unchanged after the rejected write');
 check((await db.query("select has_column_privilege('authenticated','staygrubby.dishes','collections','UPDATE') u, has_column_privilege('anon','staygrubby.dishes','collections','SELECT') s")).rows.every(r => !r.u && !r.s), 'No direct client table access to collections');

 // Enabling the gate is one row; nothing else reads it.
 await db.query("insert into staygrubby.feature_flags(key,enabled,audience,description) values('dish_collections',true,'everyone','Dish Variations')");
 await actor(0);
 check(JSON.stringify((await db.query("select api.feature_flags('get') v")).rows[0].v.enabled) === '["dish_collections"]', 'Flag row turns Dish Variations on for clients that know it');

 // The other ten pending migrations still apply after it, and labels survive them.
 await db.exec('reset role');
 for (const f of pending) await db.exec(await readFile(new URL(f, dir), 'utf8'));
 await actor(0);
 g = await graph();
 check(labels(butternut) === '["Risottos","Comfort Food"]' && labels(mushroom) === '["Risottos"]', 'Later pending migrations preserve variations and the sync contract');
} finally {
 await finish();
}
