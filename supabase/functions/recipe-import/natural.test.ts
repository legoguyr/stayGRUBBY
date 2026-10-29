import { handler } from './handler.ts';
import { groundingIssue } from './evidence.ts';
import { validationReport } from './contract.ts';
const fixture=JSON.parse(await Deno.readTextFile(new URL('../../../StayGrubbyTests/Fixtures/RecipeFrenchToastAcceptance.json',import.meta.url)));
const shakshuka=JSON.parse(await Deno.readTextFile(new URL('../../../StayGrubbyTests/Fixtures/RecipeShakshukaAcceptance.json',import.meta.url)));
function assert(value:unknown,message:string):asserts value { if(!value)throw new Error(message); }
Deno.test('owner French toast input is unchanged; outputs are explicitly synthetic',async()=>{
 const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(fixture.raw))),b=>b.toString(16).padStart(2,'0')).join('');
 assert(hash==='1ad40c62f6d27cfbe0a0ca3150fb9f9ee90744f95af34385c01243b321f9b91d'&&fixture.rawSHA256===hash,'original input drift');
 assert(fixture.origin.includes('NOT a captured Gemini response'),'fixture origin');
});
for(const pair of fixture.pairs)Deno.test(`natural source ${pair.valid?'accepts':'rejects'}: ${pair.text}`,()=>{
 const issue=groundingIssue(pair.text,fixture.raw,pair.kind,true);
 assert((issue===null)===pair.valid,`${pair.text}: ${issue}`);
});
for(const pair of shakshuka.pairs)Deno.test(`Shakshuka ${pair.valid?'accepts':'rejects'}: ${pair.text}`,()=>{
 assert((groundingIssue(pair.text,shakshuka.raw,pair.kind,true)===null)===pair.valid,pair.text);
});
Deno.test('independent exact Shakshuka full Edge fixture preserves quantities, times and alternate method',async()=>{
 const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(shakshuka.raw))),b=>b.toString(16).padStart(2,'0')).join('');
 assert(hash==='18bc8a3d1f9e669cde93fc6db926dc5bfc9689068611999021a2b87a721859c9'&&hash===shakshuka.rawSHA256,'source changed');
 let calls=0;
 const run=handler({key:'synthetic-only',authenticate:async()=>({user:'fixture',session:'fixture'}),reserve:async()=>true,fetch:async(_url,options)=>{
  calls++;assert(JSON.parse(String(options?.body)).contents[0].parts[0].text===shakshuka.raw,'source altered');
  return Response.json({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(shakshuka.provider)}]}}]});
 }});
 const r=await run(new Request('https://example.invalid',{method:'POST',headers:{authorization:'Bearer synthetic-only','content-type':'application/json'},body:JSON.stringify({text:shakshuka.raw,cloudConsent:true,contractVersion:3})}));
 const result=await r.json();assert(r.status===200,JSON.stringify(result));assert(calls===1,'retry');
 assert(result.metadata.yield.value==='4'&&result.metadata.yield.origin==='provided','explicit servings dropped');
 const lines=result.components.flatMap((p:any)=>p.ingredients),steps=result.components.flatMap((p:any)=>p.steps).join(' ');
 for(const line of ['2 cups cherry tomatoes','3 cloves garlic','1 bell pepper','2 yellow onions','2 cups tomato sauce','8 eggs','1 teaspoon paprika','2 pinches cumin'])assert(lines.includes(line),`quantity changed: ${line}`);
 assert(steps.includes('5 to 10 minutes')&&steps.includes('about 3 minutes'),'procedural time changed');
 assert(steps.includes('Alternatively, turn on the broiler'),'alternative method lost');
 assert(!JSON.stringify(result).includes('°')&&!lines.some((s:string)=>s.includes('cup olive oil')),'missing measurement invented');
});
Deno.test('singular ingredient measures do not create quantities from vessels; broiler correction stays contextual and optional',()=>{
 assert(groundingIssue('1 teaspoon paprika','Add a teaspoon of paprika.','ingredient',true)===null,'explicit measure');
 assert(groundingIssue('1 cup egg','Crack an egg into a cup.','ingredient',true)!==null,'vessel became ingredient quantity');
 assert(groundingIssue('Broil the eggs.','Boil the eggs.','step',true)!==null,'boiling became broiling');
 assert(groundingIssue('Turn on the broiler.','Turn on the boiler to heat water.','step',true)!==null,'unrelated boiler context');
 assert(groundingIssue('Cook the eggs under the broiler.',shakshuka.raw,'step',true)!==null,'alternate method became mandatory');
});
Deno.test('title for four is provided yield; procedural durations are never serving headers',async()=>{
 const {metadata}=await import('./creator.ts');
 const proposal=shakshuka.provider.metadata;
 assert(metadata('Rice for four. Cook rice.',proposal,true)?.yield.value==='4','written-out header');
 for(const raw of ['Cook for 4 minutes.','Simmer sauce for 4.','Soup for 4 minutes.'])assert(metadata(raw,proposal,true)?.yield.value===null,'duration guessed as servings');
});
for(const prefix of ['', 'Challah French Toast\nServes 4\n'])Deno.test(`French toast full local Edge pipeline ${prefix?'with title/yield':'original input'}`,async()=>{
 const text=prefix+fixture.raw,events:Record<string,unknown>[]=[];let calls=0;
 const run=handler({key:'synthetic-only',authenticate:async()=>({user:'fixture',session:'fixture'}),reserve:async()=>true,log:e=>events.push(e),fetch:async(_url,options)=>{
  calls++;assert(JSON.parse(String(options?.body)).contents[0].parts[0].text===text,'source sent changed');
  return Response.json({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(fixture.provider)}]}}]});
 }});
 const response=await run(new Request('https://example.invalid',{method:'POST',headers:{authorization:'Bearer synthetic-only','content-type':'application/json'},body:JSON.stringify({text,cloudConsent:true,contractVersion:3})}));
 const result=await response.json();
 assert(response.status===200,JSON.stringify({result,events}));assert(calls===1,'provider retry');
 assert(validationReport(result,text,true).valid,'final guards bypassed');
 assert(result.components[0].ingredients.includes('1 cup heavy cream'),'cream amount lost');
 assert(result.components[0].ingredients.includes('2 cups whole milk'),'milk amount lost');
 assert(result.components.flatMap((p:any)=>p.steps).includes(fixture.provider.components[1].steps[2]),'supported method downgraded');
 assert(result.metadata.yield.value===(prefix?'4':null),'unknown/provided yield lost');
 assert(!JSON.stringify(result).includes('°F')&&!JSON.stringify(result).includes('vanilla'),'invented fact');
 assert(!JSON.stringify(events).includes('challah')&&!JSON.stringify(events).includes('Vermont'),'private content logged');
});
Deno.test('quantity movement stays within one literal ingredient phrase',()=>{
 for(const [raw,line] of [
  ['Use dry 1/2 cup white wine.','1/2 cup dry white wine'],
  ['Use chopped 2 cups carrots.','2 cups chopped carrots'],
  ['Use egg 4 yolks.','4 egg yolks'],
 ])assert(groundingIssue(line,raw,'ingredient',true)===null,`${line}: rejected local movement`);
 for(const [raw,line] of [
  ['Use cream and 1 cup milk.','1 cup cream milk'],
  ['Use cream with 1 cup milk.','1 cup cream milk'],
  ['Use cream. Add 1 cup milk.','1 cup cream milk'],
  ['Use heavy 1 cup cream and 2 cups whole milk.','2 cups heavy cream'],
  ['Use fresh parsley and 2 cups carrots.','2 cups fresh carrots'],
 ])assert(groundingIssue(line,raw,'ingredient',true)!==null,`${line}: reassigned source fact`);
});
for(const [i,c] of fixture.otherCases.entries())Deno.test(`other natural source ${i}: full Edge pipeline`,async()=>{
 const run=handler({key:'synthetic-only',authenticate:async()=>({user:'fixture',session:'fixture'}),reserve:async()=>true,fetch:async()=>Response.json({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(c.provider)}]}}]})});
 const response=await run(new Request('https://example.invalid',{method:'POST',headers:{authorization:'Bearer synthetic-only','content-type':'application/json'},body:JSON.stringify({text:c.raw,cloudConsent:true,contractVersion:3})}));
 assert(response.status===200,JSON.stringify(await response.json()));
});
Deno.test('approximation is not an OR choice; real choices and uncertainty stay protected',async()=>{
 const {preserveEditorialFacts}=await import('./editorial.ts');
 const content=(ingredients:string[],steps:string[])=>({title:null,yield:null,source:null,components:[{title:null,ingredients,steps}]});
 assert(preserveEditorialFacts(content(['bread'],['Use bread that is a day or so old.']),'Use day or so old bread.',true)!==null,'approximation rejected');
 assert(preserveEditorialFacts(content(['bread'],['Use bread.']),'Use bread or rice.',true)===null,'real alternative dropped');
 assert(preserveEditorialFacts(content(['bread'],['Use day-old bread.']),'Use bread a day or so old, or rice.',true)===null,'approximation masked real alternative');
});
