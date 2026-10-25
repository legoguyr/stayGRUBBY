import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';
const {db,actor,rpc,cooking,check,finish}=await fixture();
try {
 await cooking(0,1);await actor(0);
 const dish=(await db.query('select id from staygrubby.dishes')).rows[0].id;
 const before=(await db.query("select md5(string_agg(row_to_json(i)::text,'' order by id)) hash from staygrubby.ranked_items i")).rows[0].hash;
 const id=randomUUID(),rows=[
  {id:randomUUID(),quantity:'1/4',unit:'cup',name:'parsley',preparation:'finely chopped',note:'plus more for garnish'},
  {id:randomUUID(),quantity:'300',unit:'g',name:'parsley'},
  {id:randomUUID(),quantity:'2-3',unit:'clove',name:'garlic',preparation:'minced'},
  {id:randomUUID(),quantity:'1 1/2',unit:'lb',name:'chicken thighs'},
  {id:randomUUID(),quantity:'',unit:'',name:'a generous handful of parsley'},
  {id:randomUUID(),quantity:'',unit:'',name:'salt',note:'to taste'}
 ].map((row,order)=>({order,preparation:'',note:'',...row}));
 let saved=await rpc('recipes','save',{recipeID:id,dishID:dish,visibility:'private',recipe:{title:'Natural ingredients',components:[{id:randomUUID(),order:0,ingredients:rows,steps:[]}]}});
 let fetched=await rpc('recipes','get',{recipeID:id});
 for(let i=0;i<rows.length;i++)check(JSON.stringify(fetched.content.components[0].ingredients[i])===JSON.stringify(saved.content.components[0].ingredients[i]),'Structured row '+i+' survives save/read');
 check(fetched.content.components[0].ingredients[0].quantity==='1/4','ASCII exact fraction preserved');
 check(fetched.content.components[0].ingredients[2].quantity==='2-3','Range preserved');
 check((await rpc('recipes','dish',{dishID:dish})).recipe.id===id,'Dish association stable');
 let index=(await rpc('recipes','cookbook_index')).entries[0];
 for(const term of ['parsley','garlic','300 g','to taste'])check(index.searchText.includes(term),'Normalized search includes '+term);
 fetched.content.components[0].ingredients[1].quantity='350';
 saved=await rpc('recipes','save',{recipeID:id,dishID:dish,expectedRevision:fetched.revision,visibility:'private',recipe:fetched.content});
 fetched=await rpc('recipes','get',{recipeID:id});
 check(fetched.revision===2 && fetched.content.components[0].ingredients[1].quantity==='350','Read/edit/save again increments existing revision');
 check(fetched.content.components[0].ingredients[1].id===rows[1].id,'Ingredient identity stable');
 check((await rpc('recipes','cookbook_index')).entries[0].searchText.includes('350 g parsley'),'Search reflects canonical second save');
 check((await db.query("select md5(string_agg(row_to_json(i)::text,'' order by id)) hash from staygrubby.ranked_items i")).rows[0].hash===before,'Recipe writes preserve scores/evidence identities');
} finally {await finish();}
