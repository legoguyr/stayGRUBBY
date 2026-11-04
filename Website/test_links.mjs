import assert from 'node:assert/strict';
import {test} from 'node:test';
import worker,{destination} from './link-worker.mjs';
const id='20000000-0000-0000-0000-000000000001';
for(const path of ['/@friendly_cook','/%40friendly_cook','/p/'+id,'/p/'+id+'/recipe','/r/'+id])test('valid private pointer retains destination: '+path,async()=>{
 let reads=0;const response=await worker.fetch(new Request('https://staygrubby.com'+path),{ASSETS:{fetch:()=>{reads++;throw Error('Private fallback must not fetch any data')}}});
 assert.equal(response.status,200);assert.equal(response.headers.get('location'),null);assert.equal(reads,0);
 assert.equal(response.headers.get('content-type'),'text/html; charset=utf-8');
 assert.equal(response.headers.get('content-disposition'),'inline');
 const html=await response.text();assert(html.includes('href="staygrubby://open'+decodeURIComponent(path)+'"'));assert(!html.includes('<script'));assert(!html.includes('supabase'));assert(response.headers.get('content-security-policy').includes("default-src 'none'"));
});
test('HEAD and invalid app paths are explicit HTML, never untyped download responses',async()=>{
 for(const [path,status] of [['/r/'+id,200],['/p/bad',404]]){
  for(const method of ['GET','HEAD']){
   const r=await worker.fetch(new Request('https://staygrubby.com'+path,{method}),{});
   assert.equal(r.status,status);assert.equal(r.headers.get('content-type'),'text/html; charset=utf-8');
   assert.equal(r.headers.get('content-disposition'),'inline');assert.equal(r.headers.get('location'),null);
   const text=await r.text();if(method==='HEAD')assert.equal(text,'');else assert(text.startsWith('<!doctype html>'));
  }
 }
});
for(const path of ['/@ab','/@a__b','/@evil/extra','/p/bad','/p/'+id+'/history','/r/'+id+'?token=secret','/@safe_name?redirect=https://evil.invalid','/%40%22%3Ebad'])test('malformed path has no app action: '+path,()=>{assert.equal(destination(new URL('https://staygrubby.com'+path)),null)});
test('association is JSON200 without redirect and matches actual native identity',async()=>{const r=await worker.fetch(new Request('https://staygrubby.com/.well-known/apple-app-site-association'),{});assert.equal(r.status,200);assert.equal(r.headers.get('location'),null);const j=await r.json();assert.deepEqual(j.applinks.details[0].appIDs,['5DSB36G7LZ.com.guyrettig.StayGrubby']);assert.deepEqual(j.applinks.details[0].components.map(x=>x['/']),['/@*','/p/*','/r/*']);});
test('fallback makes no existence claim or public content request',async()=>{const a=await (await worker.fetch(new Request('https://staygrubby.com/p/'+id),{})).text();const b=await (await worker.fetch(new Request('https://staygrubby.com/p/30000000-0000-0000-0000-000000000001'),{})).text();assert.equal(a.replaceAll(id,'ID'),b.replaceAll('30000000-0000-0000-0000-000000000001','ID'));});
test('unsupported methods cannot write; canonical pages use exact assets',async()=>{const r=await worker.fetch(new Request('https://staygrubby.com/p/'+id,{method:'POST'}),{});assert.equal(r.status,405);let path;const p=await worker.fetch(new Request('https://staygrubby.com/privacy'),{ASSETS:{fetch:r=>{path=new URL(r.url).pathname;return new Response('Canonical policy')}}});assert.equal(path,'/privacy.html');assert.equal(p.status,200);});

test('root explicitly serves index without HTML canonicalization',async()=>{
 let seen;const r=await worker.fetch(new Request('https://staygrubby.com/'),{ASSETS:{fetch:async request=>{seen=new URL(request.url).pathname;return new Response('home')}}});
 assert.equal(r.status,200);assert.equal(seen,'/index.html');assert.equal(await r.text(),'home');
});
