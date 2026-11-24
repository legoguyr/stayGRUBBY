// Hosted deployment order rehearsal (November 20, 2026). Production runs migrations out of
// filename order: the deployed head 20261115154948, then Dish Variations
// (20261120150047), Dish/Recipe integrity (20261120171728) and Recipe recovery
// (20261121023911) ahead of the
// other pending files. This rebuilds that order in PGlite, checks a Dish never shows
// another Dish's Recipe, then applies every remaining pending migration in filename order
// and checks the behavior survives. Never touches a hosted project.
import { fixture, deployedAheadOfPending } from './social-harness.mjs';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

const dir = new URL('../../supabase/migrations/', import.meta.url);
const files = (await readdir(dir)).filter(f => f.endsWith('.sql')).sort();
const early = deployedAheadOfPending;
const rest = files.filter(f => f > '20261115154948_~' && !early.includes(f));
const { db, users, actor, rpc, cooking, check, rejects, finish } = await fixture({ before: '20261116' });
const owner = users[0].id;
const content = title => ({ title, ingredients: ['rice'], steps: ['Stir.'] });

try {
 for(let n=0;n<users.length;n++){await actor(n);await rpc('social_identity','save',{displayName:'Production fixture '+n,username:'production_'+n,discoverable:true});}
 const { attempts } = await cooking(0, 2);
 await db.exec('reset role');
 const dishes = [];
 for (const [n, name] of ['Butternut Squash Risotto', 'Mushroom Risotto'].entries()) {
  const id = (await db.query('select dish_id from staygrubby.cooking_attempts where id=$1', [attempts[n]])).rows[0].dish_id;
  await db.query('update staygrubby.dishes set name=$2 where id=$1', [id, name]); dishes.push(id);
 }
 const [butternut, mushroom] = dishes;
 const recipe = randomUUID();
 await actor(0);
 await rpc('recipes', 'save', { recipeID: recipe, recipeDishID: butternut, recipe: content('Butternut Squash Risotto'), visibility: 'private' });
 // A stale family link of the kind that made the Recipe appear on a separated Dish.
 await db.exec('reset role');
 await db.query('insert into staygrubby.dish_recipes(account_id,dish_id,recipe_id) values($1,$2,$3)', [owner, mushroom, recipe]);
 await actor(0);
 check((await rpc('recipes', 'dish', { dishID: mushroom })).recipe?.id === recipe, 'Deployed head shows the Butternut Recipe on Mushroom Risotto (the reported defect)');

 await db.exec('reset role');
 for (const f of early) await db.exec(await readFile(new URL(f, dir), 'utf8'));
 await actor(0);
 // Existing photo bytes are represented by the unchanged Storage catalog in PGlite;
 // real byte/JWT transport remains a separate signed-staging gate.
 const post=(await rpc('social_content','prepare',{postID:randomUUID(),attemptID:attempts[0],expectedRevision:0,confirmed:true,includePhoto:true,postDescription:'Legacy Cook caption'})).posts[0];
 await db.query("set storage.operation='object.upload'");
 await db.query("insert into storage.objects(bucket_id,name,metadata) values('social-photos',$1,$2)",[post.photoPath,JSON.stringify({mimetype:"image/jpeg",size:100})]);
 await rpc('social_content','publish',{postID:post.id});
 const recoverable=randomUUID();
 await rpc('recipes','save',{recipeID:recoverable,recipe:content('Recoverable fixture'),visibility:'private'});
 await rpc('recipes','delete',{recipeID:recoverable});
 await db.exec('reset role');
 check((await db.query('select count(*)::int n from staygrubby.recipe_trash')).rows[0].n===1,'Rehearsal includes already-deployed Recently Deleted history');
 await actor(0);
 check((await rpc('recipes', 'dish', { dishID: mushroom })).recipe === null, 'Integrity core alone: Mushroom Risotto shows no Recipe');
 check((await rpc('recipes', 'dish', { dishID: butternut })).recipe?.id === recipe, 'Butternut Squash Risotto keeps its own Recipe');

 await db.exec('reset role');
 // Preserve all original columns across the complete pending chain, including already
 // deployed recovery data. New schema columns must not obscure changes to old values.
 const tables=(await db.query(`select table_schema,table_name,array_agg(column_name order by ordinal_position) columns
  from information_schema.columns where table_schema in ('staygrubby','auth','storage')
  group by table_schema,table_name order by table_schema,table_name`)).rows;
 async function fingerprints(){
  const result=[];
  for(const t of tables){
   const name='"'+t.table_schema+'"."'+t.table_name+'"';
   result.push((await db.query(`select count(*)::int n,md5(coalesce(jsonb_agg(v order by v::text)::text,'[]')) hash
    from (select (select jsonb_object_agg(key,value) from jsonb_each(to_jsonb(r)) where key=any($1::text[])) v from ${name} r) x`,[t.columns])).rows[0]);
  }
  return JSON.stringify(result);
 }
 const before=await fingerprints();
 check(early.length===3&&rest.length===15&&rest.slice(-4).every((f,i)=>f.endsWith(['_staff_reported_photo_operation.sql','_moderation_staff_roles.sql','_staff_status.sql','_love_it_reaction.sql'][i])),'Rehearsal starts from all 54 deployed migrations and applies the 11 files deployed November 21, the 3 staff-security migrations and Love It');
 for (const f of rest) await db.exec(await readFile(new URL(f, dir), 'utf8'));
 check(await fingerprints()===before,'The full production-order upgrade preserves every original field in all existing Auth/app/Storage tables');
 check((await db.query("select to_regclass('staygrubby.image_reviews') value")).rows[0].value===null,'No mandatory image approval queue survives the complete rollout');
 check((await db.query("select count(*)::int n from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='api' and p.proname in ('image_moderation','claim_image_reviews','finish_image_review')")).rows[0].n===0,'No approval or image-classification API remains');
 check((await db.query("select bool_and(c.relrowsecurity) ok from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='staygrubby' and c.relkind='r'")).rows[0].ok,'All application tables retain RLS');
 check((await db.query("select not has_function_privilege('anon','api.cook_description(text,jsonb)','EXECUTE') and has_function_privilege('authenticated','api.cook_description(text,jsonb)','EXECUTE') ok")).rows[0].ok,'Cook description API remains authenticated only');
 check((await db.query("select count(*)::int n from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('staygrubby','api') and p.prosrc ~ '(40001|40P01)' and p.prosrc ~* 'raise'")).rows[0].n===0,'No unbounded PostgREST retry SQLSTATE is reintroduced');
 await actor(0);
 check((await db.query('select api.provision_account() value')).rows[0].value.cook_description_version===1,'Only the completed chain advertises canonical description support');
 check((await rpc('social_feed','post',{postID:post.id})).posts[0].postDescription==='Legacy Cook caption','Already-shared legacy caption remains unchanged after the entire chain');
 check((await db.query('select api.image_access($1,$2) ok',['social-photos',post.photoPath])).rows[0].ok,'Existing photo remains immediately authorized without approval');
 check((await rpc('recipe_library','deleted',{})).recipes.length===1,'Previously archived Recipe remains recoverable after older moderation wrappers land');
 check((await rpc('cook_description','get',{attemptID:attempts[0]})).publicDescription===null,'Existing Cook remains unresolved rather than silently backfilled');
 await actor(1);await rejects(()=>rpc('cook_description','get',{attemptID:attempts[0]}));
 await actor(0);
 check((await rpc('recipes', 'dish', { dishID: mushroom })).recipe === null && (await rpc('recipes', 'dish', { dishID: butternut })).recipe?.id === recipe,
  `The other ${rest.length} pending migrations keep the behavior when applied afterwards`);
 check((await rpc('recipes', 'share_options', { attemptID: attempts[1] })).recipe === null, 'Share options never offer another Dish’s Recipe after the full chain');
} finally {
 await finish();
}
