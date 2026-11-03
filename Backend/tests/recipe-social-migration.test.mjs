import {fixture} from './social-harness.mjs';
import {readFile,readdir} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
const dir=new URL('../../supabase/migrations/',import.meta.url);
const file=(await readdir(dir)).find(x=>x.endsWith('_recipe_social_integration.sql'));
const {db,users,actor,rpc,cooking,check,finish}=await fixture({before:file});
const lib=await cooking(0);
await actor(0);await rpc('social_identity','save',{displayName:'Migration cook',username:'migration_recipe',discoverable:true});
const id=randomUUID(),postID=randomUUID();await rpc('recipes','save',{recipeID:id,recipe:{title:'Existing Recipe',description:'Keep this exact description.',ingredients:['water'],steps:['Heat.']},visibility:'private'});
await rpc('social_content','prepare',{postID,attemptID:lib.attempts[0],expectedRevision:0,confirmed:true});
await db.exec('reset role');
const tables=(await db.query("select tablename from pg_tables where schemaname='staygrubby' order by tablename")).rows.map(r=>r.tablename);
async function fingerprint(){const out=[];for(const name of tables)out.push((await db.query(`select '${name}' name,count(*)::int n,md5(coalesce(string_agg(to_jsonb(t)::text,'|' order by to_jsonb(t)::text),'')) h from staygrubby.${name} t`)).rows[0]);return JSON.stringify(out);}
const before=await fingerprint();await db.exec(await readFile(new URL(file,dir),'utf8'));check(await fingerprint()===before,'additive migration leaves ALL existing private/social rows byte-identical');
check((await db.query('select count(*)::int n from staygrubby.post_recipes')).rows[0].n===0,'no implicit attachment backfill');
check((await db.query('select count(*)::int n from staygrubby.recipe_forks')).rows[0].n===0,'no inferred forks');
await actor(0);check((await rpc('recipes','get',{recipeID:id})).content.description==='Keep this exact description.','existing Recipe still opens');
check((await rpc('social_feed','post',{postID})).posts[0].title,'existing normal post still opens');
await finish();
