import {fixture} from './social-harness.mjs';
const {db,actor,rpc,cooking,check,rejects,finish}=await fixture();
import {randomUUID} from 'node:crypto';
const graph=await cooking(0),dish=(await db.query('select dish_id from staygrubby.cooking_attempts where id=$1',[graph.attempts[0]])).rows[0].dish_id;
await actor(0);const id=randomUUID();
const base={title:'Fixture pasta',ingredients:['pasta','Parmesan'],steps:['Boil pasta.'],yield:'4',prepMinutes:10,cookMinutes:20,elapsedMinutes:25,cuisine:'Italian',metadataOrigins:{yield:'estimated',prepMinutes:'estimated',cookMinutes:'estimated',totalMinutes:'estimated',cuisine:'estimated'},allergens:{contains:['milk'],possible:['wheat'],reviewIngredients:['pasta']}};
let recipe=await rpc('recipes','save',{recipeID:id,dishID:dish,recipe:base,visibility:'private'});
check(recipe.content.elapsedMinutes===25&&recipe.content.metadataOrigins.yield==='estimated','elapsed/provenance survive save');
check(recipe.content.allergens.contains[0]==='milk'&&recipe.content.allergens.possible[0]==='wheat','recipe-specific allergen information');
let read=await rpc('recipes','get',{recipeID:id});check(JSON.stringify(read.content)===JSON.stringify(recipe.content),'fresh restore preserves all content');
await rpc('recipes','save',{recipeID:id,dishID:dish,expectedRevision:recipe.revision,recipe:{...base,yield:'5'},visibility:'private'});
const index=await rpc('recipes','cookbook_index');check(index.entries[0].elapsedMinutes===25&&index.entries[0].creatorMetadata===true,'cookbook cards retain actual elapsed time and Creator provenance rather than blindly adding prep/cook');
await db.exec('reset role');const snapshot=(await db.query('select content from staygrubby.recipe_revisions where recipe_id=$1 and revision=1',[id])).rows[0].content;check(snapshot.yield==='4'&&snapshot.allergens.contains[0]==='milk','older revision snapshot immutable');
for(const bad of [{elapsedMinutes:5},{elapsedMinutes:1.5},{elapsedMinutes:-1},{metadataOrigins:{yield:'user-said-but-invented'}},{metadataOrigins:{kosher:'derived'}},{allergens:{contains:['kosher'],possible:[],reviewIngredients:[]}},{allergens:{contains:['milk'],possible:[],reviewIngredients:[],allergenFree:true}}]){
 await rejects(()=>db.query('select staygrubby.recipe_content($1::jsonb)',[JSON.stringify({...base,...bad})]),'22023');
}
check((await db.query('select count(*)::int n from staygrubby.comparisons')).rows[0].n===0,'recipe metadata creates no ranking evidence');
check((await db.query('select cuisine from staygrubby.dishes where id=$1',[dish])).rows[0].cuisine===null,'Recipe cuisine never overwrites Dish identity');
await finish();
