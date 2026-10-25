import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture();
try {
 const lib=await cooking(0,2); await actor(0);
 const dishes=(await db.query('select id from staygrubby.dishes order by id')).rows;
 const id=randomUUID();
 const content={title:'Cod & Pesto',ingredients:['1 cup roasted red peppers','2 cloves garlic'],steps:['Blend and cook.'],cuisine:'Italian',source:'The Home Cookbook',originalCreator:'Family Cook',yield:'4',prepMinutes:15,cookMinutes:25};
 await rpc('recipes','save',{recipeID:id,dishID:dishes[0].id,visibility:'private',recipe:content});
 const before=(await db.query("select md5(string_agg(row_to_json(d)::text,'' order by id)) hash from staygrubby.dishes d")).rows[0].hash;
 const page=await rpc('recipes','cookbook_index');check(page.entries.length===1,'Only linked cooked Dish appears');
 const entry=page.entries[0];check(entry.dishID===dishes[0].id && entry.recipeID===id,'Original stable identities');
 for(const term of ['peppers','garlic','Italian','Home Cookbook','Family Cook'])check(entry.searchText.includes(term),'Search index includes '+term);
 check(entry.yield==='4'&&entry.prepMinutes===15&&entry.cookMinutes===25&&entry.updatedAt>0,'Compact summary metadata');
 for(const field of ['content','components','steps','tips','notes','comparisons','score','photos'])check(!(field in entry),'No full/private payload '+field);
 check((await rpc('recipes','cookbook_index',{beforeID:entry.dishID})).entries.length===0,'Keyset next page');
 await rpc('recipes','ticket',{recipeID:id});check((await rpc('recipes','tickets')).tickets.length===1,'Dormant Ticket backend still works');
 await actor(1);check((await rpc('recipes','cookbook_index')).entries.length===0,'No cross-account cookbook index');
 await actor(0);check((await db.query("select md5(string_agg(row_to_json(d)::text,'' order by id)) hash from staygrubby.dishes d")).rows[0].hash===before,'Read index and Ticket leave Dishes untouched');
 await rejects(()=>rpc('recipes','cookbook_index',{query:'x'.repeat(5000)}),'22023');
 await db.exec('reset role;set role anon');await rejects(()=>rpc('recipes','cookbook_index'));
 await db.exec('reset role');
 check(!(await db.query("select has_function_privilege('authenticated','staygrubby.recipe_api_before_search_index(text,jsonb)','execute') yes")).rows[0].yes,'Legacy implementation remains private');
} finally {await finish();}
