import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';
const {db,users,actor,rpc,cooking,check,finish}=await fixture();
for(let n=0;n<2;n++){await actor(n);await rpc('social_identity','save',{displayName:'Fork Cook '+n,username:'fork_cook_'+n,discoverable:true});}
await actor(0);await rpc('social_people','request',{peerID:users[1].id});await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
const own=await cooking(1);await db.exec('reset role');const cook=(await db.query('select id,dish_id,ranked_item_id from staygrubby.cooking_attempts where account_id=$1',[users[1].id])).rows[0];
await actor(0);const rid=randomUUID();await rpc('recipes','save',{recipeID:rid,visibility:'friends',recipe:{title:'Source soup',ingredients:['water'],steps:['Heat.']}});
await actor(1);await rpc('recipes','associate_cook',{recipeID:rid,expectedRevision:1,originID:randomUUID(),attemptID:cook.id,targetID:cook.ranked_item_id});
check((await rpc('recipes','share_options',{attemptID:cook.id})).recipe===null,'foreign snapshot cannot be delegated');
const copy=await rpc('recipes','fork',{recipeID:rid,targetID:randomUUID(),confirmed:true});await rpc('recipes','attach',{recipeID:copy.id,dishID:cook.dish_id});
const option=await rpc('recipes','share_options',{attemptID:cook.id});
check(option.recipe?.id===copy.id&&option.fromCookSnapshot===false,'owned linked copy is offered without rewriting the foreign historical snapshot');
const post=randomUUID();await rpc('social_content','prepare',{postID:post,attemptID:cook.id,expectedRevision:0,confirmed:true,includeRecipe:true,recipeID:option.recipe.id,sourceRevision:option.recipe.revision});
check((await rpc('recipes','shared_post',{postID:post})).recipeID===copy.id,'own independent copy can be intentionally shared');
check((await rpc('recipes','provenance',{targetID:cook.ranked_item_id})).cooks[0].recipeID===rid,'original historical cook attribution remains intact');
await finish();
