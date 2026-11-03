// Gemini-first offline retained-response smoke test. No network, keys or writes.
// v26 lexical fact-lock/golden-output assumptions are historical Git evidence.
import {handler} from '../supabase/functions/recipe-import/handler.ts';
const f=JSON.parse(await Deno.readTextFile(new URL('../StayGrubbyTests/Fixtures/RecipeV25FinalVerification.json',import.meta.url)));
for(const c of f.cases){
 const run=handler({key:'synthetic-only',authenticate:async()=>({user:'fixture',session:'fixture'}),reserve:async()=>true,fetch:async()=>Response.json({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(c.provider)}]}}]})});
 const r=await run(new Request('https://example.invalid',{method:'POST',headers:{authorization:'Bearer synthetic','content-type':'application/json'},body:JSON.stringify({text:c.raw,cloudConsent:true,contractVersion:4})}));
 if(r.status!==200)throw Error(`${c.id}: technical mapping failed`);console.log(`${c.id}: captured model response accepted structurally (offline; user content review required)`);
}
