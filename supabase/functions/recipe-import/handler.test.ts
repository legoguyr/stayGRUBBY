import { handler, type Dependencies } from "./handler.ts";
import { validate, validationReport, MODEL } from "./contract.ts";
const raw="Soup\n2 carrots\nstock\ncook chicken until done";
const value={title:"Soup",yield:null,source:null,components:[{title:null,ingredients:["2 carrots","stock"],steps:["cook chicken until done"]}]};
function assert(ok:unknown,message="Assertion failed"):asserts ok {if(!ok)throw new Error(message);}
function fixture(change:Partial<Dependencies>={}) {
 let calls=0,reservations=0;let sent:RequestInit|undefined;
 const deps:Dependencies={authenticate:async()=>({user:"fixture-user",session:"fixture-session"}),reserve:async()=>{reservations++;return true;},key:"synthetic-test-only",fetch:async(_url,init)=>{calls++;sent=init;return Response.json({candidates:[{finishReason:"STOP",content:{parts:[{text:JSON.stringify(value)}]}}]});},...change};
 return {run:handler(deps),calls:()=>calls,reservations:()=>reservations,sent:()=>sent};
}
function request(body:unknown={text:raw,cloudConsent:true},headers:Record<string,string>={authorization:"Bearer synthetic-session","content-type":"application/json"}) {return new Request("https://example.invalid/recipe-import",{method:"POST",headers,body:JSON.stringify(body)});}
Deno.test("rejects absent auth without upstream",async()=>{const f=fixture();const r=await f.run(request(undefined,{"content-type":"application/json"}));assert(r.status===401 && f.calls()===0 && f.reservations()===0);});
Deno.test("rejects invalid or revoked user",async()=>{const f=fixture({authenticate:async()=>null});assert((await f.run(request())).status===401 && !f.calls());});
Deno.test("POST only and no permissive CORS",async()=>{const f=fixture();const r=await f.run(new Request("https://example.invalid",{method:"OPTIONS"}));assert(r.status===405 && !r.headers.has("access-control-allow-origin"));});
Deno.test("rejects malformed fields and missing cloud consent",async()=>{for(const body of [{text:raw},{text:raw,cloudConsent:false},{text:raw,cloudConsent:true,url:"https://example.invalid"},[],null,{text:3,cloudConsent:true}]){const f=fixture();assert((await f.run(request(body))).status===400 && !f.calls());}});
Deno.test("rejects huge characters and UTF8 bytes",async()=>{for(const text of ["a".repeat(12001),"🧄".repeat(9000)]){const f=fixture();assert((await f.run(request({text,cloudConsent:true}))).status===413 && !f.calls() && !f.reservations());}});
Deno.test("stream bound rejects dishonest content length",async()=>{const f=fixture();const r=await f.run(request({text:"a".repeat(50000),cloudConsent:true}));assert(r.status===413 && !f.calls());});
Deno.test("missing key fails closed",async()=>{const f=fixture({key:undefined});assert((await f.run(request())).status===503 && !f.calls());});
Deno.test("no expiring timestamp or monthly lockout required",async()=>{const f=fixture();assert((await f.run(request())).status===200 && f.calls()===1);});
Deno.test("durable budget refusal prevents provider call",async()=>{const f=fixture({reserve:async()=>false});assert((await f.run(request())).status===429 && !f.calls());});
Deno.test("budget or auth service failure does not expose internals",async()=>{const f=fixture({reserve:async()=>{throw new Error("private server configuration");}});const r=await f.run(request());assert(r.status===503 && !f.calls() && !(await r.text()).includes("private"));});
Deno.test("successful structured response and fixed model schema",async()=>{const f=fixture();const r=await f.run(request());assert(r.status===200 && f.calls()===1 && f.reservations()===1);assert(JSON.stringify(await r.json())===JSON.stringify(value));const sent=JSON.parse(f.sent()!.body as string);assert(sent.generationConfig.responseFormat.text.mimeType==="APPLICATION_JSON" && sent.contents[0].parts[0].text===raw && MODEL==="gemini-3.5-flash-lite");assert(r.headers.get("cache-control")==="no-store");});
Deno.test("provider quota exhaustion is a safe retryable limit",async()=>{const f=fixture({fetch:async()=>new Response("sensitive upstream error",{status:429})});const r=await f.run(request());assert(r.status===429 && !(await r.text()).includes("sensitive"));});
Deno.test("provider error never returns secret or provider message",async()=>{const f=fixture({fetch:async()=>new Response("synthetic-test-only",{status:403})});const r=await f.run(request());assert(r.status===503 && !(await r.text()).includes("synthetic-test-only"));});
Deno.test("malformed, truncated, extra fields and hallucinations rejected",async()=>{for(const content of ["not json",JSON.stringify({...value,extra:1}),JSON.stringify({...value,components:[]}),JSON.stringify({...value,yield:"4"}),JSON.stringify({...value,components:[{title:null,ingredients:["2 cups stock"],steps:["cook at 375°F for 22 minutes"]}]})]){const f=fixture({fetch:async()=>Response.json({candidates:[{finishReason:"STOP",content:{parts:[{text:content}]}}]})});assert((await f.run(request())).status===422);}});
Deno.test("blocked or incomplete generation rejected",async()=>{for(const finishReason of ["MAX_TOKENS","SAFETY",undefined]){const f=fixture({fetch:async()=>Response.json({candidates:[{finishReason,content:{parts:[{text:JSON.stringify(value)}]}}]})});assert((await f.run(request())).status===422);}});
Deno.test("provider response byte ceiling",async()=>{const f=fixture({fetch:async()=>new Response("x".repeat(128001))});assert((await f.run(request())).status===422);});
Deno.test("provider timeout aborts request",async()=>{const f=fixture({timeoutMilliseconds:5,fetch:(_url,init)=>new Promise((_resolve,reject)=>{init!.signal!.addEventListener("abort",()=>reject(new Error("aborted")),{once:true});})});assert((await f.run(request())).status===504);});
Deno.test("provider connection failure stays distinct from invalid recipe",async()=>{const f=fixture({fetch:async()=>{throw new Error("private connection detail");}});const r=await f.run(request());const body=await r.json();assert(r.status===503 && body.code==="provider_connection" && body.stage==="provider" && !JSON.stringify(body).includes("private"));});
Deno.test("cancelled caller propagates abort",async()=>{const controller=new AbortController();controller.abort();const f=fixture({fetch:async(_url,init)=>{assert(init!.signal!.aborted);throw new Error("aborted");}});const req=new Request(request(),{signal:controller.signal});assert((await f.run(req)).status===504);});
Deno.test("natural missing data remains unknown and simple stays simple",()=>{assert(validate(value,raw));assert(value.components.length===1 && value.yield===null);assert(!validate({...value,components:[{...value.components[0],title:"Sauce"}]},raw));});
Deno.test("logs contain only safe stage/status metadata, never text or credentials",async()=>{const events:Record<string,unknown>[]=[];const f=fixture({log:e=>events.push(e)});await f.run(request());const json=JSON.stringify(events);assert(events[0].stage==="complete" && !json.includes(raw) && !json.includes("synthetic-test-only") && !json.includes("Bearer"));});

Deno.test("exact owner voice-text fixture allows organization and preserves uncertainty",async()=>{
 const fixture=JSON.parse(await Deno.readTextFile(new URL("../../../StayGrubbyTests/Fixtures/RecipeImportFailure.json",import.meta.url)));
 assert(validate(fixture.expected,fixture.raw));
 const f=fixtureRequest(fixture.expected);const r=await f(request({text:fixture.raw,cloudConsent:true}));assert(r.status===200);
});
function fixtureRequest(value:unknown){return handler({authenticate:async()=>({user:"fixture-user",session:"fixture-session"}),reserve:async()=>true,key:"synthetic-test-only",fetch:async()=>Response.json({candidates:[{finishReason:"STOP",content:{parts:[{text:JSON.stringify(value)}]}}]})});}
Deno.test("bounded normalization accepts source facts and rejects new facts",async()=>{
 const {grounded}=await import("./evidence.ts");
 const fixture=JSON.parse(await Deno.readTextFile(new URL("../../../StayGrubbyTests/Fixtures/RecipeImportFailure.json",import.meta.url)));
 for(const c of fixture.cases)assert(grounded(c.text,c.raw,c.kind)===c.valid,`grounding contract: ${c.kind}`);
});
Deno.test("upstream diagnostic reasons are safe enums",async()=>{
 for(const [status,message,reason] of [[404,"model not found","model_unavailable"],[400,"API key not valid. synthetic-test-only","invalid_key"],[403,"API has not been used or is disabled","api_disabled"],[403,"billing required","billing_required"],[429,"quota synthetic-test-only","quota"]] as const){
  const events:Record<string,unknown>[]=[];const f=fixture({log:e=>events.push(e),fetch:async()=>Response.json({error:{message}},{status})});const r=await f.run(request());const body=await r.json();assert(body.stage==="provider"&&body.providerStatus===status&&body.reason===reason);assert(!JSON.stringify(body).includes("synthetic-test-only")&&!JSON.stringify(events).includes("synthetic-test-only"));
 }
});
Deno.test("400 diagnostics identify only allowlisted status and request field",async()=>{
 const events:Record<string,unknown>[]=[];
 const f=fixture({log:e=>events.push(e),fetch:async()=>Response.json({error:{status:"INVALID_ARGUMENT",message:'Invalid JSON payload. Unknown name "responseFormat" at generation_config. synthetic-test-only',details:[{fieldViolations:[{field:'generation_config.response_format'}],metadata:{key:'synthetic-test-only'}}]}},{status:400})});
 const r=await f.run(request());assert(r.status===503);const event=events[0];
 assert(event.googleStatus==="INVALID_ARGUMENT" && event.requestField==="response_format" && !JSON.stringify(events).includes("synthetic-test-only") && !JSON.stringify(await r.json()).includes("synthetic-test-only"));
});
Deno.test("structured key error is classified without returning details or unknown values",async()=>{
 const events:Record<string,unknown>[]=[];
 const f=fixture({log:e=>events.push(e),fetch:async()=>Response.json({error:{status:"INVALID_ARGUMENT",message:"synthetic-test-only",details:[{reason:"API_KEY_INVALID",metadata:{key:"synthetic-test-only"}},{reason:"synthetic-test-only"}]}},{status:400})});
 const r=await f.run(request());assert((await r.json()).reason==="invalid_key" && events[0].googleReason==="API_KEY_INVALID" && !JSON.stringify(events).includes("synthetic-test-only"));
});
Deno.test("provider grammar avoids nested array bounds while runtime caps stay enforced",async()=>{
 const f=fixture();assert((await f.run(request())).status===200);
 const schema=JSON.stringify(JSON.parse(f.sent()!.body as string).generationConfig.responseFormat.text.schema);
 assert(!schema.includes("maxItems") && !schema.includes("minItems"));
 const component=value.components[0];
 for(const excessive of [
  {...value,components:Array.from({length:21},()=>component)},
  {...value,components:[{...component,ingredients:Array(101).fill("stock")}]},
  {...value,components:[{...component,steps:Array(101).fill("cook chicken until done")}]},
  {...value,components:Array.from({length:2},()=>({...component,ingredients:Array(51).fill("stock")}))},
 ])assert(!validate(excessive,raw));
});
Deno.test("schema compiler rejection logs a safe category without copying provider message",async()=>{
 const events:Record<string,unknown>[]=[];
 const f=fixture({log:e=>events.push(e),fetch:async()=>Response.json({error:{status:"INVALID_ARGUMENT",message:"The input schema has too many states for serving. synthetic-test-only"}},{status:400})});
 assert((await f.run(request())).status===503 && events[0].requestIssue==="schema_complexity" && !JSON.stringify(events).includes("synthetic-test-only"));
});
Deno.test("validation diagnostics locate source rule and structure without content",async()=>{
 const source="Dinner 2 cups kale and stock. Blend until smooth.";
 const extraction={title:"Dinner",yield:null,source:null,components:[{title:null,ingredients:["2 cups stock","3 cups kale"],steps:["Roast until smooth."]}]};
 const report=validationReport(extraction,source);
 assert(!report.valid && JSON.stringify(report.issues)===JSON.stringify([
  {field:"components[0].ingredients[0]",rule:"ingredient_phrase"},
  {field:"components[0].ingredients[1]",rule:"source_number"},
  {field:"components[0].steps[0]",rule:"source_word"},
 ]));
 assert(JSON.stringify(report.structure)===JSON.stringify({componentCount:1,ingredientCounts:[2],stepCounts:[1]}));
 const events:Record<string,unknown>[]=[];const f=fixture({log:e=>events.push(e),fetch:async()=>Response.json({candidates:[{finishReason:"STOP",content:{parts:[{text:JSON.stringify(extraction)}]}}]})});
 const response=await f.run(request({text:source,cloudConsent:true}));const body=await response.json();
 assert(response.status===422 && body.stage==="validation" && body.providerStatus===200 && body.reason==="ingredient_phrase");
 assert(!JSON.stringify(events).includes("kale") && !JSON.stringify(events).includes("Roast") && !JSON.stringify(events).includes(source));
});
Deno.test("validation diagnostics bound issues and never echo unknown property names",()=>{
 const e={...value,components:Array.from({length:20},()=>({...value.components[0],ingredients:Array(100).fill("private-test-marker")}))};
 const report=validationReport(e,raw);assert(!report.valid && report.issues.length===20 && !JSON.stringify(report).includes("private-test-marker"));
 const extra=validationReport({...value,"private-property-marker":true},raw);assert(extra.issues[0].rule==="object_fields" && !JSON.stringify(extra).includes("private-property-marker"));
});
Deno.test("invalid structured JSON is distinct from source validation",async()=>{
 const events:Record<string,unknown>[]=[];
 const f=fixture({log:e=>events.push(e),fetch:async()=>Response.json({candidates:[{finishReason:"STOP",content:{parts:[{text:"private-invalid-json"}]}}]})});
 const body=await (await f.run(request())).json();assert(body.reason==="structured_json" && events[0].stage==="validation" && !JSON.stringify(events).includes("private-invalid-json"));
});
Deno.test('repeated legitimate requests have no product daily allowance',async()=>{
 const f=fixture();for(let i=0;i<12;i++)assert((await f.run(request())).status===200);
});
Deno.test('cloud configuration has no recurring expiration gate',async()=>{
 const source=await Deno.readTextFile(new URL('./index.ts',import.meta.url));
 const runtime=await Deno.readTextFile(new URL('./handler.ts',import.meta.url));
 assert(!source.includes('STAYGRUBBY_GEMINI_FREE_TIER_UNTIL')&&!runtime.includes('FREE_TIER_UNTIL'));
 assert(!runtime.includes('getTime(')&&!runtime.includes('Date.parse('));
 assert((await fixture().run(request())).status===200);
});
