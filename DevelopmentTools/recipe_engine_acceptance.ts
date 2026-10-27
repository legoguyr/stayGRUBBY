// Deterministic full Edge pipeline, using approved synthetic sources only.
// No network, tokens, keys or persistent Recipe writes. Test fixtures are not
// claimed to be captured Gemini output; live v10 recorded structure/rules only.
import { handler } from "../supabase/functions/recipe-import/handler.ts";
import { validate, validationReport } from "../supabase/functions/recipe-import/contract.ts";
const root=new URL("../StayGrubbyTests/Fixtures/",import.meta.url);
export const corpus=JSON.parse(await Deno.readTextFile(new URL("RecipeEngineAcceptance.json",root)));
const canonical=JSON.parse(await Deno.readTextFile(new URL("RecipeImportFailure.json",root)));
export function assert(ok:unknown,message:string):asserts ok {if(!ok)throw new Error(message);}
export function source(c:any):string {return c.checks?.canonical?canonical.raw:c.raw;}
export async function runCase(c:any) {
 const raw=source(c),events:Record<string,unknown>[]=[];let calls=0;
 const run=handler({key:"synthetic-test-only",authenticate:async()=>({user:"fixture",session:"fixture"}),reserve:async()=>true,log:e=>events.push(e),fetch:async()=>{
  calls++;return Response.json({candidates:[{finishReason:"STOP",content:{parts:[{text:JSON.stringify(c.provider)}]}}]});
 }});
 const start=performance.now();
 const response=await run(new Request("https://example.invalid/recipe-import",{method:"POST",headers:{authorization:"Bearer synthetic-test-session","content-type":"application/json"},body:JSON.stringify({text:raw,cloudConsent:true})}));
 const value=await response.json(),milliseconds=performance.now()-start;
 assert(response.status===200,`${c.id}: HTTP ${response.status} ${JSON.stringify(value)}; rules ${JSON.stringify(validationReport(c.provider,raw).issues)}`);
 assert(calls===1,`${c.id}: unexpected provider retry`);
 assert(validate(value,raw),`${c.id}: recovered extraction bypassed validation`);
 assert(!JSON.stringify(events).includes(raw)&&!JSON.stringify(events).includes("synthetic-test-only"),`${c.id}: unsafe logs`);
 const text=JSON.stringify(value);
 if(c.checks?.preserve)assert(text.includes(c.checks.preserve),`${c.id}: source uncertainty lost`);
 if(c.checks?.forbid)assert(!text.includes(c.checks.forbid),`${c.id}: unsupported certainty retained`);
 if(c.checks?.minimumComponents)assert(value.components.length>=c.checks.minimumComponents,`${c.id}: components lost`);
 if(c.checks?.recovery)assert(events.some(e=>Number(e.sourceRecoveredCount)>0),`${c.id}: recovery path not exercised`);
 for(const forbidden of c.checks?.ingredientForbidden??[])assert(!value.components.flatMap((p:any)=>p.ingredients).join(' ').toLowerCase().includes(forbidden),`${c.id}: preparation prose became an ingredient`);
 for(const required of c.checks?.lastStepRequired??[])assert(value.components.at(-1)?.steps.at(-1)?.toLowerCase().includes(required),`${c.id}: recovered method lost its subject/context`);
 for(const requirement of c.checks?.methodRequired??[])for(const word of requirement.words)assert(value.components[requirement.component].steps[requirement.step].toLowerCase().includes(word),`${c.id}: recovered method lost a supplied completion qualifier`);
 return {id:c.id,phase:c.phase,raw,extraction:value,checks:c.checks,milliseconds};
}
if(import.meta.main){
 const results=[];for(const c of corpus.cases){const r=await runCase(c);results.push(r);console.log(`Phase ${r.phase} ${r.id}: PASS (${r.milliseconds.toFixed(1)} ms; mocked provider)`);}
 if(Deno.args.includes("--record-contracts")){
  const cases=results.map(({milliseconds,...r})=>r);
  await Deno.writeTextFile(new URL("RecipeEngineServerOutputs.json",root),JSON.stringify({origin:"deterministic-production-handler-output; mocked provider",cases},null,2)+"\n");
  await Deno.writeTextFile(new URL("../StayGrubbyUITests/Fixtures/RecipeEngineKaleUI.json",import.meta.url),JSON.stringify(cases.find(c=>c.id==='canonical-v10-rule-shape'),null,2)+"\n");
 }
}
