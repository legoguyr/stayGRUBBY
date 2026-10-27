import { metadata, construct, effectiveSource, cuisines, allergens } from './creator.ts';
import { creatorSchema } from './contract.ts';
import { assert as check } from '../../../DevelopmentTools/recipe_engine_acceptance.ts';
function assert(ok:unknown,message='Recipe Creator assertion failed'):asserts ok {check(ok,message);}
const p=(value:any=null,origin='unknown',evidence:any=null)=>({value,origin,evidence});
const m=(extra:any={})=>({yield:p(),prepMinutes:p(),cookMinutes:p(),totalMinutes:p(),cuisine:p(),allergenHints:[],...extra});
Deno.test('metadata exact source wins over generic estimates and hours normalize deterministically',()=>{
 const raw='Serves 4. Prep time 10 minutes. Cook time 1 hour. Boil rice.';
 const value=metadata(raw,m({yield:p('8','estimated',raw),cookMinutes:p(20,'estimated',raw)}))!;
 assert(metadata('Makes 1 loaf.',m())!.yield.value==='1 loaf');
 assert(metadata('Prep time 1.5 minutes.',m())!.prepMinutes.value===2&&metadata('Prep time 1.5 minutes.',m())!.prepMinutes.origin==='derived');
 assert(value.yield.value==='4'&&value.yield.origin==='provided'&&value.prepMinutes.value===10&&value.cookMinutes.value===60);
});
Deno.test('derived timing cannot add ingredient quantities as though they were minutes',()=>{
 const raw='Blend 2 cloves garlic with 1 cup stock.';
 assert(metadata(raw,m({cookMinutes:p(3,'derived',raw)}))!.cookMinutes.origin==='unknown');
});
Deno.test('estimates remain estimates, unknowns remain unknown, religions are not cuisine',()=>{
 const raw='Boil pasta.';const value=metadata(raw,m({yield:p('2','estimated',raw),cuisine:p('Kosher','estimated',raw),allergenHints:['halal','milk']}))!;
 assert(value.yield.origin==='estimated'&&value.cuisine.value===null&&value.prepMinutes.origin==='unknown');
 assert(!allergens.includes('kosher')&&!cuisines.includes('Halal'));
});
Deno.test('metadata schema rejects undeclared safety claims and invalid provenance',()=>{
 assert(metadata('Boil rice.',{...m(),allergenFree:true})===null);
 assert(metadata('Boil rice.',m({yield:p('2','claimed','Boil rice.')}))===null);
});
Deno.test('chronology rejects circular dependencies and preserves measured allocations',()=>{
 const base={title:null,yield:null,source:null,components:[{title:null,ingredients:['1 tbsp oil','2 tbsp oil'],steps:['Mix oil.'],after:[1]},{title:null,ingredients:[],steps:['Heat oil.'],after:[0]}]};
 assert(construct(base,'1 tbsp oil and 2 tbsp oil. Mix oil. Heat oil.')===null);
 base.components[1].after=[];const made=construct(base,'1 tbsp oil and 2 tbsp oil. Mix oil. Heat oil.')!;
 assert(made.components[1].ingredients.length===2&&made.components[0].steps[0]==='Heat oil.');
});
Deno.test('only explicit same-ingredient corrections change the factual source',()=>{
 assert(effectiveSource('Scramble 3 eggs, no, 2 eggs.')==='Scramble 2 eggs.');
 assert(effectiveSource('Mix 3 eggs and 2 tbsp butter.')==='Mix 3 eggs and 2 tbsp butter.');
});
Deno.test('new provider grammar remains bounded only at runtime and includes provenance',()=>{
 const text=JSON.stringify(creatorSchema);assert(!text.includes('maxItems')&&!text.includes('minItems')&&text.includes('estimated')&&text.includes('totalMinutes'));
});
Deno.test('server cuisine/allergen taxonomy matches the canonical native contract',async()=>{
 const swift=await Deno.readTextFile(new URL('../../../StayGrubby/Social/RecipeCreatorContract.swift',import.meta.url));
 const nativeCuisines=JSON.parse(swift.match(/cuisineLabels = (\[[^\n]+\])/u)![1]);
 const nativeAllergens=JSON.parse(swift.match(/allergenCodes = (\[[^\n]+\])/u)![1]);
 assert(JSON.stringify(nativeCuisines)===JSON.stringify(cuisines)&&JSON.stringify(nativeAllergens)===JSON.stringify(allergens));
});
