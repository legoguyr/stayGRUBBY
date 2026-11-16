import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';
// Food Bible "Saved Recipes" (Connected UI Phase 1, November 15 2026) reuses the private recipe_tickets
// bookmark. A save is a reference, never a copy or an ownership change, and every read rechecks access:
// unsharing, unfriending or deleting hides or removes the saved Recipe for the saver.
const {db,users,actor,rpc,check,rejects,finish}=await fixture();
for(let n=0;n<3;n++){await actor(n);await rpc('social_identity','save',{displayName:'Cook '+n,username:'saver_'+n,discoverable:true});}
const id=randomUUID(), content={title:'Charred leeks',ingredients:['4 leeks'],steps:['Char them']};
await actor(0);await rpc('recipes','save',{recipeID:id,recipe:content,visibility:'friends'});
await rpc('social_people','request',{peerID:users[1].id});await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
await rpc('recipes','ticket',{recipeID:id});
let saved=(await rpc('recipes','tickets')).tickets;
check(saved.length===1&&saved[0].recipe.content.title==='Charred leeks'&&saved[0].recipe.isOwner===false,'saved Recipe is the original, not owned by the saver');
check((await rpc('recipes','library_index')).entries.every(e=>e.recipeID!==id),'a save never enters My Recipes');
await db.exec('reset role');
check((await db.query('select count(*)::int n from staygrubby.recipes where owner_id=$1',[users[1].id])).rows[0].n===0,'no copy is created');
check((await db.query('select owner_id from staygrubby.recipes where id=$1',[id])).rows[0].owner_id===users[0].id,'ownership unchanged');
// Unshare: the bookmark stays but the Recipe is unavailable to the saver.
await actor(0);await rpc('recipes','save',{recipeID:id,recipe:content,visibility:'private',expectedRevision:1});
await actor(1);saved=(await rpc('recipes','tickets')).tickets;
check(saved.length===1&&saved[0].recipe===null,'unshared saved Recipe is hidden');await rejects(()=>rpc('recipes','get',{recipeID:id}));
// Re-share restores access through the same reference.
await actor(0);await rpc('recipes','save',{recipeID:id,recipe:content,visibility:'friends',expectedRevision:2});
await actor(1);check((await rpc('recipes','tickets')).tickets[0].recipe?.revision===3,'re-shared Recipe returns at its current revision');
// A non-friend cannot save it.
await actor(2);await rejects(()=>rpc('recipes','ticket',{recipeID:id}));
// Owner deletion removes the bookmark.
await actor(0);await rpc('recipes','delete',{recipeID:id});
await actor(1);check((await rpc('recipes','tickets')).tickets.length===0,'deleted Recipe leaves no saved reference');
finish();
