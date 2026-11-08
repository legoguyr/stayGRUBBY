import { fixture } from './social-harness.mjs';
import { readFile, readdir } from 'node:fs/promises';
import { createHash, randomUUID } from 'node:crypto';

const directory = new URL('../../supabase/migrations/', import.meta.url);
const migration = (await readdir(directory)).find(name => name.endsWith('_recipe_cook_lifecycle.sql'));
const { db, users, actor, rpc, cooking, check, rejects, finish } = await fixture({ before: migration });
const owner = users[0].id;
const recipeID = randomUUID();
const original = { title: 'Lemon broth', ingredients: ['1 lemon'], steps: ['Simmer the peel'] };
const latest = { ...original, title: 'Ginger lemon broth', ingredients: ['1 lemon', '1 tsp ginger'] };
const storeID = randomUUID();

function upsert(entity, data) {
    return { reference: { entity, key: data.id }, data: Buffer.from(JSON.stringify(data)).toString('base64') };
}
function operation(revision, upserts, deletions = []) {
    const payload = Buffer.from(JSON.stringify({ upserts, deletions, rankingAssessmentVersion: 1 }));
    return { operationID: randomUUID(), storeID, accountID: owner, kind: 'cookLifecycleFixture',
        payload: payload.toString('base64'), payloadHash: createHash('sha256').update(payload).digest('hex'),
        expectedRevision: revision };
}
async function apply(envelope) {
    return (await db.query('select api.apply_cooking_operation($1::jsonb) value', [JSON.stringify(envelope)])).rows[0].value;
}
async function restore() {
    return (await db.query('select api.open_account_library() value')).rows[0].value;
}
async function begin() {
    const originID = randomUUID();
    return rpc('recipes', 'begin', { originID, recipeID });
}
async function fingerprint() {
    await db.exec('reset role');
    const values = [];
    for (const table of ['dishes', 'cooking_attempts', 'ranked_items', 'comparisons', 'recipes', 'recipe_revisions', 'dish_recipes', 'sync_operations', 'social_posts']) {
        values.push((await db.query(`select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) value from staygrubby.${table} t`)).rows[0].value);
    }
    values.push((await db.query(`select jsonb_agg(to_jsonb(c)-'attempt_id'-'completed_at' order by id) value from staygrubby.recipe_cooks c`)).rows[0].value);
    return JSON.stringify(values);
}

try {
    const graph = await cooking(0, 3);
    const initial = (await db.query('select id,dish_id from staygrubby.cooking_attempts where account_id=$1 and id=$2',
        [owner, graph.attempts[0]])).rows[0];
    await actor(0);
    await rpc('recipes', 'save', { recipeID, recipe: original, visibility: 'private' });
    const lostJournal = await begin();
    const abandoned = await begin();
    await rpc('recipes', 'link_cook', { recipeID, attemptID: graph.attempts[1] });
    await rpc('recipes', 'save', { recipeID, recipe: latest, expectedRevision: 1 });
    await db.exec('reset role');
    const recoveredAttempt = randomUUID();
    await db.query(`insert into staygrubby.ranked_items(account_id,id,ranking_id,name,created_at_ref,strength,uncertainty)
        values($1,$2,$3,'Interrupted Recipe cook',1000,0,1)`, [owner, lostJournal.itemID, graph.ranking]);
    await db.query(`insert into staygrubby.cooking_attempts(account_id,id,dish_id,ranked_item_id,course_code,sequence_number,created_at_ref,updated_at_ref,is_legacy_import)
        values($1,$2,$3,$4,'soup',2,1000,1000,false)`, [owner, recoveredAttempt, initial.dish_id, lostJournal.itemID]);
    await db.query('update staygrubby.cooking_attempts set deleted_at=now() where account_id=$1 and id=$2', [owner, graph.attempts[1]]);
    const before = await fingerprint();
    await db.exec(await readFile(new URL(migration, directory), 'utf8'));
    check(await fingerprint() === before, 'Migration preserves IDs, evidence, content, revisions, legacy links and existing receipts');

    await actor(0);
    const recovered = await rpc('recipes', 'cook', { attemptID: recoveredAttempt });
    check(recovered.usedRecipe.revision === 1 && recovered.usedRecipe.snapshot.title === original.title && recovered.recipe.revision === 2,
        'Recover the exact historical reservation without a client journal or current-content substitution');
    check(!recovered.exactCookLink && !recovered.recipe.linkedAttemptID, 'Recovery retires stale links without choosing a replacement');
    await rejects(() => rpc('recipes', 'complete', { originID: abandoned.id }), '40001');
    check((await rpc('recipes', 'provenance', { targetID: abandoned.itemID })).cooks.length === 0, 'An abandoned reservation is not a cook');
    const claim = await begin();
    await rejects(() => rpc('recipes', 'complete', { originID: claim.id }), '40001');
    await actor(1);
    await rejects(() => rpc('recipes', 'complete', { originID: claim.id }));
    await rejects(() => rpc('recipes', 'cook', { attemptID: recoveredAttempt }));
    await rejects(() => db.query('select * from staygrubby.recipe_cooks'));
    await actor(0);

    // Remove the old fixture cook's paired item too, as a normal delete would.
    await db.exec('reset role');
    await db.query(`update staygrubby.ranked_items set deleted_at=now() where account_id=$1 and id=(
        select ranked_item_id from staygrubby.cooking_attempts where account_id=$1 and id=$2)`, [owner, graph.attempts[1]]);
    await actor(0);
    const attemptID = randomUUID();
    const completedReactions = [{ id: claim.itemID, kind: 'initial', reaction: 'Liked it', completedAt: 42 }];
    const diagnostics = Buffer.from(JSON.stringify({ initialReaction: 'Liked it', completedReactions })).toString('base64');
    const insert = operation(0, [
        upsert('rankedItem', { id: claim.itemID, rankingID: graph.ranking, name: latest.title, createdAt: 2000,
            strength: 0, uncertainty: 1, sessionDiagnosticsData: diagnostics }),
        upsert('attempt', { id: attemptID, dishID: initial.dish_id, rankedItemID: claim.itemID, cookedAt: 1990,
            categoryCode: 'soup', sequenceNumber: 3, createdAt: 2000, updatedAt: 2000, isLegacyImport: false, tagKeys: [] })
    ]);
    const receipt = await apply(insert);
    const fromSync = await rpc('recipes', 'cook', { attemptID });
    check(fromSync.usedRecipe.revision === 2 && fromSync.recipe.linkedAttemptID === attemptID, 'Sync completes the Recipe and fills a vacant current link');
    const restored = await restore();
    check(restored.graph.attempts.some(a => a.id === attemptID), 'New device can restore the cook without its original journal');
    const restoredItem = restored.graph.items.find(item => item.id === claim.itemID);
    check(restoredItem.sessionDiagnosticsData === diagnostics, 'The wire stores dated private reaction evidence without re-encoding it');
    check(JSON.stringify(await apply(insert)) === JSON.stringify(receipt), 'Accepted sync retry returns the same receipt');

    await rpc('recipes', 'unlink_cook', { recipeID, previousAttemptID: attemptID });
    await rpc('recipes', 'complete', { originID: claim.id });
    check(!(await rpc('recipes', 'get', { recipeID })).linkedAttemptID, 'A late journal retry does not recreate an unlinked association');
    await rpc('recipes', 'link_cook', { recipeID, attemptID });
    const deletion = await apply(operation(receipt.revision, [], [{ entity: 'attempt', key: attemptID }, { entity: 'rankedItem', key: claim.itemID }]));
    const afterDelete = await restore();
    check(!afterDelete.graph.attempts.some(a => a.id === attemptID) &&
        afterDelete.graph.deletions.some(row => row.entity === 'attempt' && row.key === attemptID),
        'Restore after deletion returns the tombstone instead of the old cook');
    check(!(await rpc('recipes', 'get', { recipeID })).linkedAttemptID, 'Deleting the cook retires its current link');
    check((await rpc('recipes', 'provenance', { targetID: claim.itemID })).cooks.length === 0, 'Deleted cook is absent from active history');
    await rejects(() => rpc('recipes', 'link_cook', { recipeID, attemptID }), '40001');
    await rpc('recipes', 'link_cook', { recipeID, attemptID: graph.attempts[2] });
    check((await rpc('recipes', 'get', { recipeID })).linkedAttemptID === graph.attempts[2], 'A surviving cook can be deliberately linked after restore/delete');
    await rpc('recipes', 'delete', { recipeID });
    const retained = await rpc('recipes', 'cook', { attemptID: recoveredAttempt });
    check(retained.usedRecipe.revision === 1 && retained.usedRecipe.recipeID === null && retained.recipe === null,
        'Deleting the Recipe removes the live source but preserves the surviving cook snapshot');

    const foreignRecipeID = randomUUID();
    await rpc('social_identity', 'save', { username: 'lifecycle_owner', displayName: 'Lifecycle Owner', discoverable: true });
    await actor(1);
    await rpc('social_identity', 'save', { username: 'lifecycle_creator', displayName: 'Lifecycle Creator', discoverable: true });
    await rpc('social_people', 'request', { peerID: owner });
    await rpc('recipes', 'save', { recipeID: foreignRecipeID, recipe: original, visibility: 'friends' });
    await actor(0);
    await rpc('social_people', 'accept', { peerID: users[1].id });
    const beforeRevocation = await rpc('recipes', 'begin', { originID: randomUUID(), recipeID: foreignRecipeID });
    await actor(1);
    await rpc('recipes', 'save', { recipeID: foreignRecipeID, recipe: latest, expectedRevision: 1, visibility: 'private' });
    await actor(0);
    const foreignAttempt = randomUUID();
    await apply(operation(deletion.revision, [
        upsert('rankedItem', { id: beforeRevocation.itemID, rankingID: graph.ranking, name: original.title,
            createdAt: 2100, strength: 0, uncertainty: 1 }),
        upsert('attempt', { id: foreignAttempt, dishID: initial.dish_id, rankedItemID: beforeRevocation.itemID,
            categoryCode: 'soup', sequenceNumber: 4, createdAt: 2100, updatedAt: 2100, isLegacyImport: false, tagKeys: [] })
    ]));
    const revoked = await rpc('recipes', 'cook', { attemptID: foreignAttempt });
    check(revoked.usedRecipe.revision === 1 && revoked.usedRecipe.creatorName === 'Lifecycle Creator' &&
        revoked.usedRecipe.snapshot.title === original.title && revoked.recipe === null && !revoked.exactCookLink,
        'Revocation before sync leaves the authorized reservation snapshot private and creates no current link');
    await rejects(() => rpc('recipes', 'get', { recipeID: foreignRecipeID }));
} finally {
    await finish();
}
