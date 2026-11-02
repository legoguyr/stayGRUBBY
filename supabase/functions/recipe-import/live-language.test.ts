import {handler} from './handler.ts';
import {groundingIssue} from './evidence.ts';
import {construct} from './creator.ts';
import {polish} from './style.ts';
import {preserveEditorialFacts} from './editorial.ts';
const root=new URL('../../../StayGrubbyTests/Fixtures/',import.meta.url);
const f=JSON.parse(await Deno.readTextFile(new URL('RecipeFrenchToastAcceptance.json',root)));
const captured=JSON.parse(await Deno.readTextFile(new URL('RecipeLiveFrenchToastRejected.json',root)));
function assert(v:unknown):asserts v{if(!v)throw Error('Assertion failed');}
async function replay(candidate:unknown){const run=handler({key:'synthetic-test-only',authenticate:async()=>({user:'synthetic',session:'synthetic'}),reserve:async()=>true,fetch:async()=>Response.json({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(candidate)}]}}]})});return run(new Request('https://example.invalid/recipe-import',{method:'POST',headers:{authorization:'Bearer synthetic','content-type':'application/json'},body:JSON.stringify({text:f.raw,cloudConsent:true,contractVersion:3,diagnosticReview:true})}));}
Deno.test('captured live response still rejects invented temperature scale and optionality',async()=>{const r=await replay(captured.candidate);assert(r.status===422);const b=await r.json();assert(b.stage==='validation'&&b.review.validationIssues.some((i:any)=>i.field==='components[0].steps[1]'));});
Deno.test('same captured wording without invented facts survives complete mocked pipeline',async()=>{const candidate=JSON.parse(JSON.stringify(captured.candidate).replaceAll('135°F','135').replaceAll(' (optional)','').replaceAll(' as desired',''));const r=await replay(candidate);assert(r.status===200);const b=await r.json();assert(b.components[0].steps.some((s:string)=>s.includes('remaining dairy'))&&b.components[0].ingredients.includes('Pinch of sea salt'));assert(!JSON.stringify(b.components).includes('°F'));});
Deno.test('grammatical equivalence and parenthetical ingredient preferences are general, not recipe identities',()=>{
 for(const [raw,text,kind,valid] of [
  ['Add a pinch of salt (I prefer flaky salt for this).','Pinch of flaky salt','ingredient',true],
  ['Add a pinch of salt. Use flaky salt on bread.','Pinch of flaky salt','ingredient',false],
  ['Mix egg yolks with cream. Continue until all is mixed.','Continue pouring the remaining cream into the yolk mixture.','step',false],
  ['Pour cream into egg yolks. Continue until all is mixed.','Continue pouring the remaining cream into the yolk mixture.','step',true],
  ['Slice apples. Serve the apples.','Cooking and Serving','title',false],
  ['Cook apples. Serve the apples.','Cooking and Serving','title',true],
 ] as const)assert((groundingIssue(text,raw,kind,true)===null)===valid);
});
Deno.test('measured ingredient recovery never manufactures ingredients from procedural durations or temperatures',()=>{
 const raw='Use bread and butter. Dunk bread for 15 seconds per side. Heat to 135 on low. Add 1 tbsp butter.';
 const value={title:null,yield:null,source:null,components:[{title:null,ingredients:['bread','butter'],steps:['Dunk bread for 15 seconds per side.','Heat to 135 on low.','Add 1 tbsp butter.']}]};
 const made=construct(value,raw,true)!;assert(made.components[0].ingredients.join('|')==='bread|1 tbsp butter');
 assert(groundingIssue('Custard Base','Mix to form a custard.','title',true)===null);
});
Deno.test('displaced source descriptors remain bound to their exact measure and ingredient',()=>{
 const value={title:null,yield:null,source:null,components:[{title:null,ingredients:['1 cup cream','2 cups milk'],steps:[]}]};
 assert(polish(value,'Heat heavy 1 cup cream and 2 cups milk.').components[0].ingredients.join('|')==='1 cup heavy cream|2 cups milk');
 assert(polish(value,'Use heavy cream and 1 cup milk.').components[0].ingredients.join('|')==='1 cup cream|2 cups milk');
});
Deno.test('measured handling cautions are restored once without duplicating an already preserved risk',()=>{
 const raw='Soak bread for 15 seconds (too much time will make it fall apart).';
 const value={title:null,yield:null,source:null,components:[{title:null,ingredients:['bread'],steps:['Soak bread for 15 seconds.']}]};
 const made=preserveEditorialFacts(value,raw,true)!;assert(made.components[0].steps[0].includes('fall apart'));
 assert(JSON.stringify(preserveEditorialFacts(made,raw,true))===JSON.stringify(made));
});
Deno.test('actual successful Gemini candidate replays to the recorded final native contract',async()=>{
 const live=JSON.parse(await Deno.readTextFile(new URL('RecipeLiveFrenchToastAccepted.json',root)));
 const r=await replay(live.provider);assert(r.status===200);assert(JSON.stringify(await r.json())===JSON.stringify(live.extraction));
});
Deno.test('captured Shakshuka response now passes with exact quantities, preparation and contextual component references',async()=>{
 const live=JSON.parse(await Deno.readTextFile(new URL('RecipeLiveShakshukaReplay.json',root)));
 const run=handler({key:'synthetic-test-only',authenticate:async()=>({user:'synthetic',session:'synthetic'}),reserve:async()=>true,fetch:async()=>Response.json({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(live.provider)}]}}]})});
 const r=await run(new Request('https://example.invalid',{method:'POST',headers:{authorization:'Bearer synthetic','content-type':'application/json'},body:JSON.stringify({text:live.raw,cloudConsent:true,contractVersion:3})}));
 assert(r.status===200&&JSON.stringify(await r.json())===JSON.stringify(live.extraction));
});
Deno.test('preparation annotation cannot borrow another food, amount, technique, or component title',()=>{
 for(const [raw,line] of [
  ['Dice carrots. Slice onions.','onions, diced'],
  ['2 yellow onions. Dice red onions.','2 yellow onions, diced'],
  ['3 cloves garlic, chopped.','4 cloves garlic, chopped'],
  ['Slice tomatoes in half.','tomatoes, sliced in quarters'],
  ['Toast bread. Serve cheese.','bread, for serving'],
 ])assert(groundingIssue(line,raw,'ingredient',true)!==null);
});
