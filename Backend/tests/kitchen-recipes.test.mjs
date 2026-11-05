import {fixture} from './social-harness.mjs';
import {readFile,readdir} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
const migration=(await readdir(new URL('../../supabase/migrations/',import.meta.url))).find(x=>x.endsWith('_stage5_kitchen_recipes.sql'));
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture({before:migration});
try {
 for(let i=0;i<4;i++){await actor(i);await rpc('social_identity','save',{username:'kitchen_cook_'+i,displayName:'Kitchen Cook '+i,discoverable:true});}
 await actor(0);await rpc('social_people','request',{peerID:users[1].id});await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
 const graph=await cooking(0);await db.exec('reset role');const dish=(await db.query('select dish_id from staygrubby.cooking_attempts where account_id=$1',[users[0].id])).rows[0].dish_id;
 const privateID=randomUUID(),sharedID=randomUUID(),foreignID=randomUUID();
 await actor(0);await rpc('recipes','save',{recipeID:privateID,dishID:dish,visibility:'private',recipe:{title:'Private owner Recipe',ingredients:['stock'],steps:['Simmer']}});
 await rpc('recipes','save',{recipeID:sharedID,visibility:'friends',recipe:{title:'Shared owner Recipe',ingredients:['lemon'],steps:['Cook'],course:'soup',cuisine:'Italian'}});
 await actor(1);await rpc('recipes','save',{recipeID:foreignID,visibility:'friends',recipe:{title:'Other creator Recipe',ingredients:['water'],steps:['Heat']}});
 await actor(0);await rpc('recipes','link_cook',{recipeID:foreignID,attemptID:graph.attempts[0]});
 async function fingerprint(){await db.exec('reset role');const tables=(await db.query("select tablename from pg_tables where schemaname='staygrubby' order by tablename")).rows;const values={};for(const {tablename:t} of tables)values[t]=(await db.query(`select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]') v from staygrubby.${t} t`)).rows[0].v;return JSON.stringify(values);}
 const before=await fingerprint();await db.exec(await readFile(new URL('../../supabase/migrations/'+migration,import.meta.url),'utf8'));check(await fingerprint()===before,'Deployment changes no existing Recipe/cook/social/history row');
 await actor(0);let page=await rpc('recipes','profile_index');check(page.entries.length===2,'Own Kitchen contains both owned Recipes');check(page.entries.some(x=>x.recipeID===privateID),'Owner can see own private Recipe');check(!page.entries.some(x=>x.recipeID===foreignID),'A foreign linked Recipe is not presented as your own Recipe');
 const own=page.entries.find(x=>x.recipeID===privateID);check(own.dishID===dish,'Owner-only legacy fallback keeps own cook photography');
 check(page.entries.every(x=>!('content' in x)&&!('snapshot' in x)&&!('privateNotes' in x)),'Cards are minimal metadata, not private Recipe bodies or cook snapshots');
 await actor(1);page=await rpc('recipes','profile_index',{peerID:users[0].id});check(page.entries.length===1&&page.entries[0].recipeID===sharedID,'Sous Chef sees only authorized shared Recipe');check(page.entries[0].dishID===null&&page.entries[0].linkedAttemptID===null,'Other Kitchens expose no private cook/family IDs or fallback');check(page.entries[0].course==='soup'&&page.entries[0].cuisine==='Italian','Only Recipe-owned metadata projected');
 await rpc('recipes','ticket',{recipeID:sharedID});check((await rpc('recipes','profile_index')).entries.length===1,'Saved/ticket references do not become owned Kitchen Recipes');
 await actor(2);check((await rpc('recipes','profile_index',{peerID:users[0].id})).entries.length===0,'Stranger cannot enumerate friends or private Recipes');check((await rpc('recipes','profile_index',{peerID:randomUUID()})).entries.length===0,'Unknown Kitchen yields no existence/count disclosure');
 await actor(0);for(let i=0;i<28;i++)await rpc('recipes','save',{recipeID:randomUUID(),visibility:'private',recipe:{title:'Private paged Recipe '+i,ingredients:['stock'],steps:['Simmer']}});
 page=await rpc('recipes','profile_index');const next=await rpc('recipes','profile_index',{beforeID:page.entries.at(-1).recipeID});check(page.entries.length===25&&next.entries.length===5,'Bounded pagination covers owned collection');check(new Set([...page.entries,...next.entries].map(x=>x.recipeID)).size===30,'Pagination is stable and duplicate-free');
 await actor(1);check((await rpc('recipes','profile_index',{peerID:users[0].id})).entries.length===1,'Private collection size never leaks into friend results');
 await actor(0);await rpc('recipes','save',{recipeID:sharedID,expectedRevision:1,visibility:'private',recipe:{title:'Shared owner Recipe',ingredients:['lemon'],steps:['Cook']}});
 await actor(1);check((await rpc('recipes','profile_index',{peerID:users[0].id})).entries.length===0,'Revocation immediately removes summary');await rejects(()=>rpc('recipes','get',{recipeID:sharedID}));
 await actor(0);await rpc('recipes','save',{recipeID:sharedID,expectedRevision:2,visibility:'friends',recipe:{title:'Shared owner Recipe',ingredients:['lemon'],steps:['Cook']}});
 await actor(1);await rpc('social_people','block',{peerID:users[0].id});check((await rpc('recipes','profile_index',{peerID:users[0].id})).entries.length===0,'Blocking excludes previously visible Recipes');
 await actor(0);check((await rpc('recipes','profile_index',{peerID:users[1].id})).entries.length===0,'Blocking is symmetric for profile Recipe reads');
 await db.exec('reset role');check(!(await db.query("select has_function_privilege('anon','api.recipes(text,jsonb)','execute') v")).rows[0].v,'Anonymous wrapper remains closed');check(!(await db.query("select has_function_privilege('authenticated','staygrubby.recipe_api_before_stage5(text,jsonb)','execute') v")).rows[0].v,'Predecessor cannot be called to bypass new entry points');
 await db.exec('set role anon');await rejects(()=>rpc('recipes','profile_index',{peerID:users[0].id}));
 await db.exec('reset role');await db.query('delete from auth.sessions where id=$1',[users[1].session]);await actor(1);await rejects(()=>rpc('recipes','profile_index'));
} finally {await finish();}
