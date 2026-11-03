import {handler} from './handler.ts';
import {validationReport,invalidIngredientQuantity,geminiSchema} from './contract.ts';
import {construct,metadata} from './creator.ts';
const root=new URL('../../../StayGrubbyTests/Fixtures/',import.meta.url);
const captures=JSON.parse(await Deno.readTextFile(new URL('RecipeV25FinalVerification.json',root)));
function assert(v:unknown,message='Assertion failed'):asserts v{if(!v)throw Error(message);}
async function replay(provider:any,raw='casual unrelated words',version=4){let calls=0;const logs:any[]=[];const run=handler({key:'synthetic-test-only',authenticate:async()=>({user:'fixture',session:'fixture'}),reserve:async()=>true,log:x=>logs.push(x),fetch:async()=>{calls++;return Response.json({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(provider)}]}}]});}});const r=await run(new Request('https://example.invalid',{method:'POST',headers:{authorization:'Bearer synthetic','content-type':'application/json'},body:JSON.stringify({text:raw,cloudConsent:true,contractVersion:version})}));return {status:r.status,value:await r.json(),calls,logs};}
for(const c of captures.cases)Deno.test(`retained REAL ${c.id} now reaches draft structurally without rewriting`,async()=>{
 const p=structuredClone(c.provider),before=JSON.stringify(p);const r=await replay(p,c.raw);assert(r.status===200&&r.calls===1);
 assert(JSON.stringify(r.value.components.map((x:any)=>x.ingredients))===JSON.stringify(p.components.map((x:any)=>x.ingredients)));
 assert(JSON.stringify(r.value.components.map((x:any)=>x.steps))===JSON.stringify(p.components.map((x:any)=>x.steps)));
 assert(JSON.stringify(p)===before&&!JSON.stringify(r.logs).includes(c.raw));
});
Deno.test('old retained French failure remains content for user review, not a lexical rejection',async()=>{const f=JSON.parse(await Deno.readTextFile(new URL('RecipeLiveFrenchToastRejected.json',root)));const r=await replay(f.candidate);assert(r.status===200);assert(r.value.components[0].steps.some((s:string)=>s.includes('135°F')));});
Deno.test('arbitrary professional prose, description, alternatives and unmeasured ingredients survive',async()=>{
 const p={title:'A professional dish',description:'A velvety preparation with a crisp finish.',components:[{title:'Sauce and assembly',ingredients:['pasta','a little oil','chiles OR pepper flakes, optional'],steps:['Cook until golden brown.','Blend the kale mixture until smooth.','Toss pasta in the prepared sauce.']}]};
 const r=await replay(p,'cook it in pan till golden; blend all that');assert(r.status===200&&r.value.description===p.description);assert(JSON.stringify(r.value.components[0].steps)===JSON.stringify(p.components[0].steps));
});
Deno.test('optional metadata absent, partial, invalid or unquoted never blocks a core draft',async()=>{
 const core={components:[{ingredients:['rice'],steps:['Simmer until tender.']}]};
 for(const m of [undefined,null,{},'bad',{yield:{value:'4 servings',origin:'estimated'},prepMinutes:{value:10},cookMinutes:{value:-3},cuisine:{value:'unsupported'},allergenHints:['milk','kosher']}]){
  const r=await replay({...core,...(m===undefined?{}:{metadata:m})});assert(r.status===200);
  if(typeof m==='object'&&m?.yield){assert(r.value.metadata.yield.value==='4 servings'&&r.value.metadata.prepMinutes.origin==='estimated'&&r.value.metadata.cookMinutes.value===null&&r.value.metadata.cuisine.value===null&&r.value.metadata.allergenHints.join()==='milk');}
 }
});
Deno.test('chronology uses only explicit dependency graph; duplicate allocations and prose remain exact',()=>{
 const p={title:'Dinner',components:[{title:'Assembly',ingredients:['Sauce'],steps:['Serve sauce.'],after:[1]},{title:'Sauce',ingredients:['1 tbsp oil','1 tbsp oil','salt','salt'],steps:['Cook for 15 seconds at 135.'],after:[]}]};
 assert(validationReport(p).valid);const r=construct(p);assert(r.components[0].ingredients.length===4&&r.components[0].steps[0]===p.components[1].steps[0]);assert(r.components[1].ingredients[0]==='Sauce');
});
for(const p of [null,[],{}, {components:[]},{components:[{}]},{components:[{ingredients:['rice'],steps:[42]}]},{components:[{ingredients:['rice'],steps:[],after:[1]}]},{components:[{ingredients:['rice'],steps:[],after:[1]},{ingredients:['oil'],steps:[],after:[0]}]},{components:[{ingredients:['rice'],steps:[]}],admin:true}])Deno.test(`structural failure ${JSON.stringify(p).slice(0,85)}`,async()=>{assert((await replay(p)).status===422);});
for(const line of ['-1 cup salt','1/0 cup flour','1e999 cups water','Infinity cups water','1000000001 cups water'])Deno.test(`corrupt quantity remains rejected: ${line}`,async()=>{assert(invalidIngredientQuantity(line));assert((await replay({components:[{ingredients:[line],steps:[]}]})).status===422);});
Deno.test('source never causes reconstruction, automatic ingredient recovery or quantity invention',async()=>{
 const p={title:'Toast',components:[{ingredients:['bread','butter'],steps:['Cook for 15 seconds per side. Heat to 135.']} ]};
 const r=await replay(p,'Use 4 slices bread and 2 tbsp butter.');assert(r.status===200&&r.value.components[0].ingredients.join('|')==='bread|butter');
});
Deno.test('invalid optional description and inconsistent total are omitted rather than rejecting recipe',async()=>{
 const r=await replay({description:'x'.repeat(1201),components:[{ingredients:['rice'],steps:[]}],metadata:{prepMinutes:{value:20},cookMinutes:{value:10},totalMinutes:{value:5}}});assert(r.status===200&&r.value.description===null&&r.value.metadata.totalMinutes.value===null);
});
Deno.test('technical limits and bounded grammar remain; no source proof vocabulary in runtime',async()=>{
 assert(!JSON.stringify(geminiSchema).includes('maxItems'));
 for(const file of ['handler.ts','contract.ts','creator.ts']){const text=await Deno.readTextFile(new URL(file,import.meta.url));for(const old of ['source_word','ingredient_phrase','preserveEditorialFacts','from "./evidence.ts"'])assert(!text.includes(old));}
 assert(!validationReport({components:Array.from({length:21},()=>({ingredients:['rice'],steps:[]}))}).valid);
});
Deno.test('legacy contracts remain decodable without a new description field',async()=>{for(const v of [2,3]){const r=await replay({title:'Dish',description:'New description',components:[{ingredients:['rice'],steps:[]}]},'rice',v);assert(r.status===200&&!Object.hasOwn(r.value,'description'));}});
Deno.test('fresh real v27 responses replay without content reconstruction or new provider calls',async()=>{
 const f=JSON.parse(await Deno.readTextFile(new URL('RecipeGeminiFirstLive.json',root)));
 for(const c of f.cases){const r=await replay(c.provider,c.raw);assert(r.status===200&&JSON.stringify(r.value)===JSON.stringify(c.extraction));assert(r.value.description===c.provider.description);}
});
