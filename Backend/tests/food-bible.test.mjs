import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture();
for(let n=0;n<2;n++){await actor(n);await rpc('social_identity','save',{displayName:'Cook '+n,username:'bible_'+n,discoverable:true});}
const graph=await cooking(0,2),other=await cooking(1);
await db.exec('reset role');
const dishes=(await db.query('select dish_id from staygrubby.cooking_attempts where account_id=$1 order by id',[users[0].id])).rows.map(x=>x.dish_id);
async function fingerprint(){await db.exec('reset role');return (await db.query(`select md5(string_agg(row::text,'|' order by row::text)) hash from (
 select to_jsonb(t) row from staygrubby.dishes t union all select to_jsonb(t) from staygrubby.cooking_attempts t union all select to_jsonb(t) from staygrubby.ranked_items t union all select to_jsonb(t) from staygrubby.comparisons t union all select to_jsonb(t) from staygrubby.media t) x`)).rows[0].hash;}
const before=await fingerprint(),id=randomUUID();
const content={title:'Short ribs & polenta',ingredients:[],steps:[],yield:'4 servings',prepMinutes:20,cookMinutes:180,originalCreator:'Family cookbook',tips:'Recipe tip explicitly shared, not private cook notes',course:'main',cuisine:'Italian',components:[
 {id:randomUUID(),title:'Short ribs',order:0,ingredients:[{id:randomUUID(),order:0,quantity:'1 1/2',unit:'lb',name:'short ribs',preparation:'trimmed',note:'bone-in'}],steps:[{id:randomUUID(),order:0,instruction:'Braise at 300°F.'}]},
 {id:randomUUID(),title:'Polenta',order:1,ingredients:[{id:randomUUID(),order:0,quantity:'1',unit:'cup',name:'cornmeal'}],steps:[{id:randomUUID(),order:0,instruction:'Simmer.'}]}
]};
await actor(0);check((await rpc('recipes','cookbook')).entries.length===0,'ranked dishes without recipes excluded');
const r=await rpc('recipes','save',{recipeID:id,dishID:dishes[0],recipe:content,visibility:'private'});
check(r.revision===1&&r.content.components[0].ingredients[0].quantity==='1 1/2','structured quantity preserved');
check(r.content.ingredients[0]==='1 1/2 lb short ribs trimmed bone-in','legacy reader projection');
check((await rpc('recipes','cookbook')).entries[0].dishID===dishes[0],'same dish appears automatically');
check(!(await rpc('recipes','cookbook')).entries[0].content,'summary excludes full bodies');
check((await rpc('recipes','dish',{dishID:dishes[0]})).recipe.id===id,'dish route same recipe');
check((await rpc('recipes','cookbook',{query:'POLENTA',course:'main',cuisine:'italian'})).entries.length===1,'search and course/cuisine');
check((await rpc('recipes','cookbook',{query:'unknown'})).entries.length===0,'search restricts');
check((await rpc('recipes','cookbook',{course:'soup'})).entries.length===0,'course restricts');
const edited=structuredClone(content);edited.components.reverse();edited.components[0].ingredients[0].note='whisk slowly';
await rpc('recipes','save',{recipeID:id,dishID:dishes[0],expectedRevision:1,recipe:edited,visibility:'friends'});
check((await rpc('recipes','dish',{dishID:dishes[0]})).recipe.content.components[0].title==='Polenta','ordered components reload');
check((await rpc('recipes','revision',{recipeID:id,expectedRevision:1})).content.components[0].title==='Short ribs','immutable old revision');
await rejects(()=>rpc('recipes','save',{recipeID:id,expectedRevision:1,recipe:edited,visibility:'private'}),'40001');
await rejects(()=>rpc('recipes','save',{recipeID:id,expectedRevision:2,recipe:{title:'Old client',ingredients:[],steps:[]},visibility:'private'}),'40001');
await rpc('recipes','attach',{dishID:dishes[0],recipeID:id});
const standalone=randomUUID();await rpc('recipes','save',{recipeID:standalone,recipe:{title:'Uncooked cake',ingredients:[],steps:[]},visibility:'private'});
check((await rpc('recipes','cookbook')).entries.length===1,'standalone preserved not cookbook');
await rpc('recipes','ticket',{recipeID:standalone});await rpc('recipes','ticket',{recipeID:standalone});
check((await rpc('recipes','tickets')).tickets.length===1,'ticket idempotent');
check((await rpc('recipes','cookbook')).entries.length===1,'ticket creates no cookbook entry');
await rejects(()=>rpc('recipes','attach',{dishID:dishes[0],recipeID:standalone}),'40001');
await actor(1);await rejects(()=>rpc('recipes','get',{recipeID:id}));await rejects(()=>rpc('recipes','attach',{dishID:dishes[0],recipeID:id}),'40001');
check((await rpc('recipes','dish',{dishID:dishes[0]})).recipe===null,'foreign dish hidden');
await rejects(()=>rpc('recipes','revision',{recipeID:id,expectedRevision:1}));
await actor(0);await rpc('social_people','request',{peerID:users[1].id});await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
check((await rpc('recipes','get',{recipeID:id})).content.tips===content.tips,'explicit recipe tips shared');
await rejects(()=>rpc('recipes','revision',{recipeID:id,expectedRevision:1}));
const claim=await rpc('recipes','begin',{recipeID:id,originID:randomUUID()});
await db.exec('reset role');const target=(await db.query('select dish_id,ranked_item_id from staygrubby.cooking_attempts where account_id=$1 and id=$2',[users[1].id,other.attempts[0]])).rows[0];
await db.query('update staygrubby.recipe_cooks set item_id=$1 where id=$2',[target.ranked_item_id,claim.id]);
await actor(1);await rpc('recipes','complete',{originID:claim.id});await rpc('recipes','complete',{originID:claim.id});
check((await rpc('recipes','cookbook')).entries.length===1,'completed ticket cook derives membership');
const snapshot=(await rpc('recipes','provenance',{targetID:target.ranked_item_id})).cooks[0];check(snapshot.snapshot.components[0].title==='Polenta','version-specific snapshot');
await actor(0);await rpc('recipes','save',{recipeID:id,expectedRevision:2,recipe:{...edited,title:'Current recipe'},visibility:'private'});
await actor(1);check((await rpc('recipes','cookbook')).entries.length===0,'revoked recipe not exposed in cookbook');check((await rpc('recipes','provenance',{targetID:target.ranked_item_id})).cooks[0].snapshot.title===content.title,'own old snapshot remains');
await actor(0);await rpc('recipes','detach',{dishID:dishes[0],recipeID:id});check((await rpc('recipes','cookbook')).entries.length===0,'remove recipe link removes membership only');check((await rpc('recipes','get',{recipeID:id})).content.title==='Current recipe','detach retains recipe');
await rpc('recipes','attach',{dishID:dishes[0],recipeID:id});await rpc('recipes','delete',{recipeID:id});check((await rpc('recipes','cookbook')).entries.length===0,'recipe deletion removes membership');
for(const table of ['dish_recipes','recipe_revisions'])await rejects(()=>db.query('select * from staygrubby.'+table));
const invalid=structuredClone(content);invalid.components[1].id=invalid.components[0].id;
await rejects(()=>rpc('recipes','save',{recipeID:randomUUID(),recipe:invalid,visibility:'private'}),'22023');
check(await fingerprint()===before,'all recipe operations leave cooking/ranking/media/evidence byte identical');
await finish();
