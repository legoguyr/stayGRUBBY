import {fixture} from './social-harness.mjs';
import {readFile,readdir} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
const migration=(await readdir(new URL('../../supabase/migrations/',import.meta.url))).find(x=>x.endsWith('_stage4_recipe_cook_experience.sql'));
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture({before:migration});
try {
 for(let i=0;i<4;i++){await actor(i);await rpc('social_identity','save',{username:'version_cook_'+i,displayName:'Version Cook '+i,discoverable:true});}
 await actor(0);await rpc('social_people','request',{peerID:users[1].id});await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
 const cook=await cooking(0,3), foreign=await cooking(1);
 await db.exec('reset role');
 const rows=(await db.query('select id,dish_id,ranked_item_id from staygrubby.cooking_attempts where account_id=$1 order by sequence_number,id',[users[0].id])).rows;
 await db.query('update staygrubby.cooking_attempts set dish_id=$1,sequence_number=2 where account_id=$2 and id=$3',[rows[0].dish_id,users[0].id,rows[1].id]);
 const r1=randomUUID(),r2=randomUUID(),origin=randomUUID();await actor(0);
 await rpc('recipes','save',{recipeID:r1,dishID:rows[0].dish_id,visibility:'friends',recipe:{title:'Original soup',ingredients:['1 cup milk'],steps:['Simmer'],allergens:{contains:['milk'],possible:[],reviewIngredients:[]}}});
 await rpc('recipes','save',{recipeID:r2,dishID:rows[2].dish_id,visibility:'private',recipe:{title:'New version soup',ingredients:['2 cups stock'],steps:['Simmer'],course:'soup',source:'My notes'}});
 await rpc('recipes','associate_cook',{recipeID:r1,attemptID:rows[0].id,targetID:rows[0].ranked_item_id,expectedRevision:1,originID:origin});
 async function snapshot(){await db.exec('reset role');const tables=(await db.query("select tablename from pg_tables where schemaname='staygrubby' and tablename<>'recipe_cook_links' order by tablename")).rows;const values={};for(const {tablename:t} of tables)values[t]=(await db.query(`select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]') value from staygrubby.${t} t`)).rows[0].value;return JSON.stringify(values);}
 const before=await snapshot();await db.exec(await readFile(new URL('../../supabase/migrations/'+migration,import.meta.url),'utf8'));
 check(await snapshot()===before,'Migration changes no existing row, identity, revision or legacy link');
 await actor(0);let card=await rpc('recipes','get',{recipeID:r1});check(card.linkedDishID===rows[0].dish_id&&!card.linkedAttemptID,'Legacy family stays a family, without a guessed version');
 await rpc('recipes','link_cook',{recipeID:r2,attemptID:rows[1].id});
 card=await rpc('recipes','get',{recipeID:r2});check(card.linkedAttemptID===rows[1].id&&card.linkedDishID===rows[0].dish_id,'Explicit second version wins over retained family link');
 check((await rpc('recipes','cook',{attemptID:rows[1].id})).recipe.id===r2,'Specific cook resolves own current link');
 const usedCook=await rpc('recipes','cook',{attemptID:rows[0].id});check(!usedCook.legacyFamilyLink&&usedCook.usedRecipe.snapshot.title==='Original soup'&&usedCook.usedRecipe.revision===1,'Historical Recipe used is shown as immutable evidence, not an inferred family link');
 let option=await rpc('recipes','share_options',{attemptID:rows[1].id});check(option.recipe.id===r2&&!option.fromCookSnapshot,'Sharing chooser honors owned explicit version link, not another family Recipe');
 let page=await rpc('recipes','library_index');check(page.entries.find(x=>x.recipeID===r2).linkedAttemptID===rows[1].id,'Index preserves explicit version');
 check(page.entries.find(x=>x.recipeID===r1).allergens.contains[0]==='milk','Recipe-owned allergen metadata available without cook inference');
 check(page.entries.find(x=>x.recipeID===r1).createdAt>0,'Real Recipe creation time exposed');
 await rpc('recipes','link_cook',{recipeID:r2,attemptID:rows[0].id,previousAttemptID:rows[1].id});
 option=await rpc('recipes','share_options',{attemptID:rows[0].id});check(option.recipe.id===r1&&option.fromCookSnapshot,'Manual link never replaces immutable Recipe-used evidence');
 const provenance=await rpc('recipes','provenance',{targetID:rows[0].ranked_item_id});check(provenance.cooks[0].snapshot.title==='Original soup'&&provenance.cooks[0].revision===1,'Cook snapshot remains original');
 await rejects(()=>rpc('recipes','link_cook',{recipeID:r2,attemptID:rows[2].id,previousAttemptID:rows[1].id}),'40001');
 await rpc('recipes','unlink_cook',{recipeID:r2,previousAttemptID:rows[0].id});
 card=await rpc('recipes','get',{recipeID:r2});check(!card.linkedAttemptID&&card.linkedDishID===rows[2].dish_id,'Unlink preserves legacy association, not silently deletes it');
 await rpc('recipes','link_cook',{recipeID:r2,attemptID:rows[1].id});
 const rejectedRecipe=randomUUID();await rejects(()=>rpc('recipes','save',{recipeID:rejectedRecipe,attemptID:rows[1].id,visibility:'private',recipe:{title:'Conflicting new Recipe',ingredients:['salt'],steps:['Mix']}}),'40001');
 await db.exec('reset role');check((await db.query('select count(*)::int n from staygrubby.recipes where id=$1',[rejectedRecipe])).rows[0].n===0,'Failed save/link is atomic, without orphan Recipe');
 check(await snapshot()===before,'Link/change/unlink does not rewrite any existing cooking/Recipe/revision/social record');
 const happyID=randomUUID();await actor(0);
 card=await rpc('recipes','save',{recipeID:happyID,attemptID:rows[2].id,visibility:'private',recipe:{title:'Created for exact cook',ingredients:['salt'],steps:['Mix']}});
 check(card.linkedAttemptID===rows[2].id&&card.revision===1,'New Recipe/save/link succeeds atomically for the chosen version');
 await rpc('recipes','delete',{recipeID:happyID});
 await db.exec('reset role');check((await db.query('select count(*)::int n from staygrubby.cooking_attempts where account_id=$1 and id=$2',[users[0].id,rows[2].id])).rows[0].n===1,'Deleting a linked Recipe preserves its actual cook');

 await actor(0);const legacyCook=await rpc('recipes','cook',{attemptID:rows[2].id});check(legacyCook.legacyFamilyLink&&!legacyCook.usedRecipe,'An actual legacy family link is not relabeled as a Recipe-used snapshot');
 async function completedCook(recipeID, editAfterBegin=false) {
  await actor(0);const originID=randomUUID(),claim=await rpc('recipes','begin',{recipeID,originID}),attemptID=randomUUID();
  if(editAfterBegin) { const current=await rpc('recipes','get',{recipeID});await rpc('recipes','save',{recipeID,expectedRevision:current.revision,visibility:current.visibility,recipe:{...current.content,title:'Edited after version began'}}); }
  await db.exec('reset role');
  await db.query("insert into staygrubby.ranked_items(account_id,id,ranking_id,name,created_at_ref,strength,uncertainty) values($1,$2,$3,'Exact Recipe cook',1000,0,1)",[users[0].id,claim.itemID,cook.ranking]);
  await db.query("insert into staygrubby.cooking_attempts(account_id,id,dish_id,ranked_item_id,course_code,sequence_number,created_at_ref,updated_at_ref,is_legacy_import) values($1,$2,$3,$4,'soup',(select coalesce(max(sequence_number),0)+1 from staygrubby.cooking_attempts where account_id=$1 and dish_id=$3),1000,1000,false)",[users[0].id,attemptID,rows[0].dish_id,claim.itemID]);
  await actor(0);await rpc('recipes','complete',{originID});await rpc('recipes','complete',{originID});return attemptID;
 }
 const repeated=await completedCook(r2,true);card=await rpc('recipes','get',{recipeID:r2});check(card.linkedAttemptID===rows[1].id,'Completing another cook never moves an explicitly selected current link');
 const actual=await rpc('recipes','cook',{attemptID:repeated});check(!actual.exactCookLink&&!actual.legacyFamilyLink&&actual.usedRecipe.recipeID===r2&&actual.usedRecipe.snapshot.title==='New version soup'&&actual.usedRecipe.revision===1&&actual.recipe.revision===2,'Rank My Version pins the exact Recipe revision/content at begin despite later editing or another current cook link');
 const fresh=randomUUID();await rpc('recipes','save',{recipeID:fresh,visibility:'private',recipe:{title:'Fresh Recipe',ingredients:['stock'],steps:['Simmer']}});
 const firstCook=await completedCook(fresh);card=await rpc('recipes','get',{recipeID:fresh});check(card.linkedAttemptID===firstCook,'Completing a fresh Recipe cook establishes one exact link idempotently');
 check((await rpc('recipes','cook',{attemptID:firstCook})).exactCookLink,'Fresh cook association is available through the canonical resolver');
 await db.exec('reset role');check((await db.query('select recipe_id from staygrubby.dish_recipes where account_id=$1 and dish_id=$2',[users[0].id,rows[0].dish_id])).rows[0].recipe_id===r1,'New versions preserve the existing Dish-family Recipe relationship without replacing legacy history');
 await actor(1);card=await rpc('recipes','get',{recipeID:r1});check(!card.linkedAttemptID&&!card.linkedDishID,'Other viewer never receives private cook/family IDs');
 await rejects(()=>rpc('recipes','link_cook',{recipeID:r1,attemptID:rows[0].id}),'40001');
 await rpc('recipes','link_cook',{recipeID:r1,attemptID:foreign.attempts[0]});
 await rejects(()=>db.query('select * from staygrubby.recipe_cook_links'));
 await actor(2);await rejects(()=>rpc('recipes','get',{recipeID:r1}));
 await actor(0);await rpc('recipes','save',{recipeID:r1,expectedRevision:1,visibility:'private',recipe:{title:'Original soup',ingredients:['1 cup milk'],steps:['Simmer']}});
 await actor(1);check((await rpc('recipes','cook',{attemptID:foreign.attempts[0]})).recipe===null,'Revoked source unavailable, with no private content fallback');
 await rpc('recipes','unlink_cook',{recipeID:r1,previousAttemptID:foreign.attempts[0]});check(true,'Can remove own pointer after source revocation');
 await db.exec('reset role');await db.query('update staygrubby.cooking_attempts set deleted_at=now() where account_id=$1 and id=$2',[users[0].id,rows[1].id]);
 await actor(0);card=await rpc('recipes','get',{recipeID:r2});check(card.linkedAttemptID===rows[1].id&&card.linkedDishID===null,'Deleted selected cook cannot choose arbitrary legacy photo');
 await db.exec('reset role;set role anon');await rejects(()=>rpc('recipes','link_cook',{recipeID:r2,attemptID:rows[1].id}));
} finally {await finish();}
