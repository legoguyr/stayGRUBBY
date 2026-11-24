import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { fixture } from './social-harness.mjs';

const migration = '20261121161512_private_recipe_authorization.sql';
const { db, users, actor, rpc, cooking, check, rejects, finish } = await fixture({ before: migration });
const privateID = randomUUID(), sharedID = randomUUID(), postID = randomUUID(), photoID = randomUUID();
const photoPath = users[0].id + '/' + photoID + '.jpg';
const recipe = { title: 'Lemon Soup', ingredients: ['Water'], steps: ['Simmer.'], photoID };
const graph = async () => (await db.query('select api.open_account_library() value')).rows[0].value.graph;
const photoRead = async () => (await db.query("select name from storage.objects where bucket_id='recipe-photos' and name=$1", [photoPath])).rows.length;

try {
 for (let n = 0; n < users.length; n++) {
  await actor(n);
  await rpc('social_identity', 'save', { displayName: 'Chef ' + n, username: 'private_fixture_' + n, discoverable: true });
 }
 await actor(0);
 await rpc('social_people','request',{ peerID: users[1].id });
 await actor(1);
 await rpc('social_people','accept',{ peerID: users[0].id });
 const { attempts } = await cooking(0, 2);
 const [{ dish_id: dish }] = (await db.query('select dish_id from staygrubby.cooking_attempts where id=$1', [attempts[0]])).rows;
 await db.query('update staygrubby.dishes set private_notes=$1 where id=$2', ['Private fixture note', dish]);
 await actor(0);
 await rpc('recipes','prepare_photo',{ assetID: photoID, photoHash: 'a'.repeat(64), photoBytes: 100 });
 await db.query("set storage.operation = 'object.upload'");
 await db.query("insert into storage.objects(bucket_id,name,metadata) values('recipe-photos',$1,$2)", [
  photoPath, JSON.stringify({ mimetype: 'image/jpeg', size: 100 })
 ]);
 await rpc('recipes','complete_photo',{ assetID: photoID });
 await rpc('recipes','save',{ recipeID: privateID, recipeDishID: dish, recipe, visibility: 'private' });
 await rpc('recipes','save',{ recipeID: sharedID, recipe, visibility: 'friends' });
 await rpc('social_content','prepare',{ postID, attemptID: attempts[0], expectedRevision: 0, confirmed: true,
  includeRecipe: true, recipeID: sharedID, sourceRevision: 1 });
 const expectedGraph = await graph();
 await actor(1);
 check((await rpc('recipes','shared_post',{postID})).revision === 1, 'Peer initially sees authorized pinned Recipe');
 await db.query("set storage.operation = 'object.get_authenticated'");
 check(await photoRead() === 1, 'Peer initially sees an authorized Recipe photo');
 await rejects(() => rpc('recipes','get',{ recipeID: privateID }));
 await rpc('social_report','report',{ targetType: 'profile', targetID: users[0].id, reason: 'other' });
 await db.exec('reset role');
 await db.query('insert into staygrubby.moderation_reviewers(account_id) values($1)', [users[2].id]);
 await actor(2);
 const { reports } = await rpc('moderation_review','queue');
 await rpc('moderation_review','resolve',{ reportID: reports[0].id, decision: 'hide' });
 await actor(0);
 await rejects(() => rpc('recipes','get',{ recipeID: privateID }));

 await db.exec('reset role');
 await db.exec(await readFile(new URL('../../supabase/migrations/' + migration, import.meta.url),'utf8'));
 await actor(0);
 check((await rpc('recipes','get',{ recipeID: privateID })).content.title === recipe.title, 'Hidden owner can read own private Recipe');
 check((await rpc('recipes','get',{ recipeID: sharedID })).revision === 1, 'Hidden owner can read previously shared Recipe privately');
 check((await rpc('recipes','library_index')).entries.length === 2, 'Private index remains available');
 check((await rpc('recipes','dish',{ dishID: dish })).recipe.id === privateID, 'Dish Recipe lookup works for the owner');
 check((await rpc('recipes','history',{ recipeID: privateID })).versions.length === 1, 'Owner can read exact revision history');
 const archived = await rpc('recipes','revision',{ recipeID: privateID, expectedRevision: 1 });
 check(archived.revision === 1, 'Owner can fetch the immutable revision');
 check((await rpc('recipes','photo',{ assetID: photoID })).id === photoID && await photoRead() === 1, 'Owner can read personal Recipe media');
 check(JSON.stringify(await graph()) === JSON.stringify(expectedGraph) && expectedGraph.dishes[0] !== undefined
  && JSON.stringify(expectedGraph).includes('Private fixture note'), 'Cooking restore, ranking and notes remain unchanged');

 await rejects(() => rpc('recipes','save',{ recipeID: privateID, expectedRevision: 1, recipe, visibility: 'friends' }));
 const saved = await rpc('recipes','save',{ recipeID: privateID, expectedRevision: 1, recipe:{...recipe,title:'Private edit'} });
 check(saved.visibility === 'private' && saved.revision === 2, 'Omitted visibility remains usable on older clients');
 const restored = await rpc('recipes','restore',{ recipeID: privateID, sourceRevision: 1, expectedRevision: 2 });
 check(restored.revision === 3 && restored.content.title === recipe.title, 'Private restore creates a new revision');
 const claim = await rpc('recipes','begin',{ recipeID: privateID, originID: randomUUID() });
 check(claim.recipeSnapshot.title === recipe.title, 'Owner can start a private cook with exact Recipe provenance');
 await rejects(() => rpc('recipes','share_options',{ postID }));
 await rejects(() => rpc('recipes','share_post',{ postID, recipeID: privateID, sourceRevision: 1, confirmed: true }));
 await rejects(() => rpc('social_content','prepare',{ postID: randomUUID(), attemptID: attempts[1], expectedRevision: 0, confirmed: true }));
 await rejects(() => rpc('social_people','search',{ query: 'chef' }));
 await actor(1);
 await rejects(() => rpc('recipes','get',{ recipeID: sharedID }));
 await rejects(() => rpc('recipes','shared_post',{postID}));
 await rejects(() => rpc('recipes','history',{ recipeID: privateID }));
 await rejects(() => rpc('recipes','photo',{ assetID: photoID }));
 check(await photoRead() === 0, 'Peer loses Storage access after profile hide');
 await rejects(() => db.query("select staygrubby.recipe_operation_actor('get')"));
 await rejects(() => db.query("select staygrubby.recipe_api_before_food_bible('list','{}')"));
 await actor(3);
 await rejects(() => rpc('recipes','get',{ recipeID: privateID }));

 await db.exec('reset role');
 await db.query("update staygrubby.profiles set social_state='active' where account_id=$1", [users[0].id]);
 await actor(1);
 await rpc('social_people','block',{ peerID: users[0].id });
 await rejects(() => rpc('recipes','get',{ recipeID: sharedID }));
 check(await photoRead() === 0, 'Block still revokes Recipe and photo access');
 await actor(0);
 check((await db.query('select api.begin_account_deletion() result')).rows[0].result.state === 'requested', 'Restricted account still has erasure eligibility');
 await rejects(() => rpc('recipes','get',{ recipeID: privateID }));
 check(await photoRead() === 0, 'Deletion prevents personal media access during erasure');
 await db.exec('reset role');
 await db.query('delete from auth.sessions where id=$1',[users[1].session]);
 await actor(1);
 await rejects(() => rpc('recipes','list'));
 await db.exec('reset role; set role anon');
 await rejects(() => rpc('recipes','list'));
} finally {
 await finish();
}
