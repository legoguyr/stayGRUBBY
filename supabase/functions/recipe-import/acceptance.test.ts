import { corpus, runCase, assert } from "../../../DevelopmentTools/recipe_engine_acceptance.ts";
import { handler } from "./handler.ts";
import { validationReport } from "./contract.ts";
import { reconcile } from "./reconcile.ts";
const fixtures=new URL("../../../StayGrubbyTests/Fixtures/",import.meta.url);
const golden=JSON.parse(await Deno.readTextFile(new URL("RecipeEngineServerOutputs.json",fixtures)));
const negative=JSON.parse(await Deno.readTextFile(new URL("RecipeEngineNegative.json",fixtures)));
Deno.test("canonical source bytes and isolated UI contract never drift",async()=>{
 const canonical=JSON.parse(await Deno.readTextFile(new URL("RecipeImportFailure.json",fixtures)));
 const digest=new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(canonical.raw)));
 assert([...digest].map(v=>v.toString(16).padStart(2,'0')).join('')==='774a33291a4e216bb55ce4b1d476d0b9c12a4b8aeb3faa2163f3be51da933915','canonical source changed');
 assert(await Deno.readTextFile(new URL("RecipeEngineCanonicalKale.txt",fixtures))===canonical.raw,'copyable canonical text changed');
 const ui=JSON.parse(await Deno.readTextFile(new URL("../../../StayGrubbyUITests/Fixtures/RecipeEngineKaleUI.json",import.meta.url)));
 assert(ui.raw===canonical.raw&&JSON.stringify(ui.extraction)===JSON.stringify(golden.cases.find((c:any)=>c.id===ui.id).extraction),'UI fixture differs from server/client contract');
});
for(const c of corpus.cases)Deno.test(`phase ${c.phase}: ${c.id} full Edge/client-contract fixture`,async()=>{
 const actual=await runCase(c),expected=golden.cases.find((v:any)=>v.id===c.id);
 assert(!!expected,`${c.id}: missing client contract`);
 assert(JSON.stringify(actual.extraction)===JSON.stringify(expected.extraction),`${c.id}: server/client contract drift`);
 assert(actual.raw===expected.raw,`${c.id}: source changed`);
});
for(const c of negative.cases)Deno.test(`adversarial: ${c.id}`,async()=>{
 const events:Record<string,unknown>[]=[];
 const run=handler({key:"synthetic-only",authenticate:async()=>({user:"fixture",session:"fixture"}),reserve:async()=>true,log:e=>events.push(e),fetch:async()=>Response.json({candidates:[{finishReason:"STOP",content:{parts:[{text:JSON.stringify(c.provider)}]}}]})});
 const response=await run(new Request("https://example.invalid",{method:"POST",headers:{authorization:"Bearer synthetic-only","content-type":"application/json"},body:JSON.stringify({text:c.raw,cloudConsent:true})}));
 assert(!validationReport(c.provider,c.raw).valid,`${c.id}: unsupported fact not detected`);
 assert(reconcile(c.provider,c.raw)===null,`${c.id}: unsafe output repaired as if equivalent`);
 assert(response.status===422,`${c.id}: hallucination accepted`);
});
Deno.test("bounded diagnostics cannot hide a hard structural failure behind soft failures",()=>{
 const value={title:null,yield:null,source:null,components:[{title:null,ingredients:Array(21).fill('unknown'),steps:[]},{title:null,ingredients:[],steps:42}]};
 const report=validationReport(value,'Soup');assert(report.issues.length===20&&!report.reconcilable&&reconcile(value,'Soup')===null,'hard failure hidden by log bound');
});
Deno.test("recovery never changes input or treats uncertain variety as equivalent",()=>{
 const raw='Chili oil or clabbering chilies or red pepper flakes.';
 const value={title:null,yield:null,source:null,components:[{title:null,ingredients:['Calabrian chilies'],steps:[]}]};
 const snapshot=JSON.stringify(value),restored=reconcile(value,raw);
 assert(!!restored,'conservative source recovery failed');
 assert(JSON.stringify(value)===snapshot,'provider response mutated');
 assert(restored.extraction.components[0].ingredients[0].includes('clabbering chilies'),'uncertain source lost');
 assert(!JSON.stringify(restored.extraction).includes('Calabrian'),'inferred variety retained');
});
Deno.test("long field and empty recipe bounds remain hard failures",()=>{
 for(const value of [
  {title:null,yield:null,source:null,components:[]},
  {title:null,yield:null,source:null,components:[{title:null,ingredients:['a'.repeat(501)],steps:[]}]},
  {title:null,yield:null,source:null,components:[{title:null,ingredients:[],steps:['a'.repeat(2001)]}]},
 ])assert(!validationReport(value,'a'.repeat(2001)).reconcilable&&reconcile(value,'a'.repeat(2001))===null,'bounds repaired away');
});
Deno.test("relational ingredient annotations preserve source names and vague qualifiers",()=>{
 const raw='Parmesan cheese is for garnish. Finish with salt to taste and optional parsley garnish.';
 const value={title:null,yield:null,source:null,components:[{title:null,ingredients:['Parmesan cheese, for serving','salt (for serving)','parsley for serving'],steps:[]}]};
 const restored=reconcile(value,raw);assert(!!restored,'annotation recovery failed');
 const lines=restored.extraction.components[0].ingredients;
 assert(lines[0]==='Parmesan cheese'&&lines[1].includes('to taste')&&lines[2].includes('optional'),'uncertainty or ingredient identity lost');
});
