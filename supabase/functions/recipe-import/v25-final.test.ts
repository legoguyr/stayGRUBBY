import {handler} from './handler.ts';
import {ingredientComponentReference} from './contract.ts';
import {groundingIssue} from './evidence.ts';
const fixture=JSON.parse(await Deno.readTextFile(new URL('../../../StayGrubbyTests/Fixtures/RecipeV25FinalVerification.json',import.meta.url)));
function assert(v:unknown):asserts v{if(!v)throw Error('Assertion failed');}
for(const c of fixture.cases)Deno.test(`fresh v25 ${c.id} capture: corrected offline status ${c.expectedStatus}; no live request`,async()=>{
 let calls=0;const run=handler({key:'synthetic-test-only',authenticate:async()=>({user:'fixture',session:'fixture'}),reserve:async()=>true,fetch:async()=>{calls++;return Response.json({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(c.provider)}]}}]});}});
 const r=await run(new Request('https://example.invalid',{method:'POST',headers:{authorization:'Bearer synthetic','content-type':'application/json'},body:JSON.stringify({text:c.raw,cloudConsent:true,contractVersion:3})}));
 assert(r.status===c.expectedStatus&&calls===1);
 const value=await r.json();if(r.status===200)assert(JSON.stringify(value)===JSON.stringify(c.extraction));else assert(value.stage==='validation'&&value.code==='invalid_recipe');
});
Deno.test('whole unmeasured component references require grounded names and a preceding/explicit prerequisite',()=>{
 const raw='Use bread and cream. Form a custard. Cook bread in custard.';
 const p={title:'Custard Base',ingredients:['cream'],steps:['Form a custard.'],after:[]};
 const value={components:[p,{title:'Cooking',ingredients:['Custard Base'],steps:['Cook bread in custard.'],after:[0]}]};
 assert(ingredientComponentReference(value,raw,1,'Custard Base'));
 for(const line of ['1 cup Custard Base','Custard Base and bacon','Saffron Custard','Custard Base, deep-fried'])assert(!ingredientComponentReference(value,raw,1,line));
 assert(!ingredientComponentReference(value,raw,0,'Custard Base'));
 assert(!ingredientComponentReference({components:[value.components[1],p]},raw,0,'Custard Base'));
 assert(ingredientComponentReference({components:[{...value.components[1],after:[1]},p]},raw,0,'Custard Base'));
});
Deno.test('at first matches an explicit to-begin-with cue, without licensing timing or method changes',()=>{
 const raw='Pour cream slowly to begin with, whisking to not cook the eggs.';
 assert(groundingIssue('Pour cream slowly at first, whisking to avoid cooking the eggs.',raw,'step',true)===null);
 assert(groundingIssue('Cook the eggs for 3 minutes at first.',raw,'step',true)!==null);
 const kale=fixture.cases.find((c:any)=>c.id==='kale');
 assert(groundingIssue('Boil water in a separate pot and add pasta, cooking until done.',kale.raw,'step',true)!==null);
});
