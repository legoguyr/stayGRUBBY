import { handler, type Dependencies } from './handler.ts';
function assert(v:unknown):asserts v { if(!v)throw new Error('Assertion failed'); }
const raw='Soup\n2 carrots\nstock\ncook chicken until done';
const value={title:'Soup',yield:null,source:null,components:[{title:null,ingredients:['2 carrots','stock'],steps:['cook chicken until done']}]};
const rejected={...value,title:'private-diagnostic-marker',components:[{...value.components[0],ingredients:['3 carrots','stock']}]};
function setup(change:Partial<Dependencies>={}, candidate:unknown=rejected) {
 let calls=0; const logs:Record<string,unknown>[]=[];
 const run=handler({authenticate:async()=>({user:'synthetic-user',session:'synthetic-session'}),reserve:async()=>true,key:'synthetic-test-only',log:e=>logs.push(e),fetch:async()=>{calls++;return Response.json({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(candidate)}]}}]});},...change});
 return {run,calls:()=>calls,logs};
}
const request=(extra:Record<string,unknown>={},authenticated=true)=>new Request('https://example.invalid/recipe-import',{method:'POST',headers:{'content-type':'application/json',...(authenticated?{authorization:'Bearer synthetic-session'}:{})},body:JSON.stringify({text:raw,cloudConsent:true,...extra})});
Deno.test('ordinary validation errors never return the rejected candidate',async()=>{
 for(const extra of [{},{diagnosticReview:false}]) { const f=setup();const r=await f.run(request(extra));const body=await r.json();assert(r.status===422&&!Object.hasOwn(body,'review')&&!JSON.stringify(body).includes('private-diagnostic-marker')); }
});
Deno.test('opt-in review returns only the callers bounded candidate while rejection and logs remain unchanged',async()=>{
 const f=setup();const r=await f.run(request({diagnosticReview:true}));const body=await r.json();
 assert(r.status===422&&body.stage==='validation'&&body.providerStatus===200&&f.calls()===1);
 assert(JSON.stringify(body.review.candidate)===JSON.stringify(rejected)&&body.review.validationIssues.some((i:any)=>i.rule==='source_number'));
 assert(r.headers.get('cache-control')==='no-store'&&!JSON.stringify(f.logs).includes('private-diagnostic-marker')&&!JSON.stringify(f.logs).includes(raw)&&!JSON.stringify(body).includes('synthetic-test-only'));
});
Deno.test('review opt-in does not change successful responses or the provider request contract',async()=>{
 let payload:unknown;const f=setup({fetch:async(_url,init)=>{payload=JSON.parse(init!.body as string);return Response.json({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(value)}]}}]});}},value);
 const r=await f.run(request({diagnosticReview:true}));assert(r.status===200&&JSON.stringify(await r.json())===JSON.stringify(value));
 assert(!JSON.stringify(payload).includes('diagnosticReview')&&(payload as any).contents[0].parts[0].text===raw);
});
Deno.test('missing or invalid authentication cannot reach diagnostic generation',async()=>{
 const missing=setup(),invalid=setup({authenticate:async()=>null});
 for(const [f,req] of [[missing,request({diagnosticReview:true},false)],[invalid,request({diagnosticReview:true})]] as const){const r=await f.run(req);assert(r.status===401&&f.calls()===0&&!Object.hasOwn(await r.json(),'review'));}
});
Deno.test('configuration and burst protections still gate diagnostic requests',async()=>{
 for(const change of [{key:undefined},{reserve:async()=>false}]) {const f=setup(change);const r=await f.run(request({diagnosticReview:true}));assert([503,429].includes(r.status)&&f.calls()===0&&!Object.hasOwn(await r.json(),'review'));}
});
Deno.test('review requires a boolean and does not authorize extra request fields',async()=>{
 for(const extra of [{diagnosticReview:'true'},{diagnosticReview:{}},{diagnosticReview:true,admin:true}]){const f=setup();const r=await f.run(request(extra));assert(r.status===400&&f.calls()===0&&!Object.hasOwn(await r.json(),'review'));}
});
Deno.test('diagnostic candidate state cannot leak into another request',async()=>{
 const f=setup();assert(Object.hasOwn(await (await f.run(request({diagnosticReview:true}))).json(),'review'));
 const next=await f.run(request());assert(next.status===422&&!Object.hasOwn(await next.json(),'review'));
});
Deno.test('malformed and oversized provider output is never reflected as private review',async()=>{
 for(const text of ['not structured JSON','x'.repeat(96_001)]){const f=setup({fetch:async()=>Response.json({candidates:[{finishReason:'STOP',content:{parts:[{text}]}}]})});const r=await f.run(request({diagnosticReview:true}));assert(r.status===422&&!Object.hasOwn(await r.json(),'review'));}
});
Deno.test('explicit development capture privately returns successful original candidate without changing normal responses',async()=>{
 const f=setup({},value),req=request({diagnosticReview:true});req.headers.set('x-staygrubby-development-review','candidate');
 const r=await f.run(req),b=await r.json();assert(r.status===200&&JSON.stringify(b.extraction)===JSON.stringify(value)&&JSON.stringify(b.review.candidate)===JSON.stringify(value));
 const normal=request();normal.headers.set('x-staygrubby-development-review','candidate');assert(!Object.hasOwn(await (await f.run(normal)).json(),'review'));
});
