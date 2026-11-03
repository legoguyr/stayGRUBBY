// Manual, opt-in development CLI. Outside every Xcode target. No provider key,
// service-role key, real-user login, persistence, or automatic provider retries.
import {readFile,writeFile,mkdir,chmod,open,unlink,rename,lstat} from 'node:fs/promises';
import {randomBytes,randomUUID,createHash} from 'node:crypto';
import {homedir} from 'node:os';
import {join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {request as httpsRequest} from 'node:https';
import {isIP} from 'node:net';
export const approval='77dd8c13-six-approved-calls';
export const finalV25={approval:'v25-final-live-20261102',maximum:3,minimum:0,once:true,budget:'v25-final-budget.json',prefix:'v25-final-'};
const legacy={approval,maximum:6,minimum:1,once:false,budget:'budget.json',prefix:''};
export const directory=join(homedir(),'Library/Application Support/StayGrubbyDevelopment/recipe-validation');
const root=fileURLToPath(new URL('../',import.meta.url));
const project='https://lgjxbpycphhsswxoncmz.supabase.co';
const digest=s=>createHash('sha256').update(s).digest('hex');
export function reserve(budget,id,hash,grant=legacy) {
 if(budget.approval!==grant.approval||!Array.isArray(budget.attempts)||budget.attempts.length<grant.minimum||budget.attempts.length>=grant.maximum||budget.stopped)throw Error('budget_unavailable');
 if(grant.once&&(!['french','shakshuka','kale'].includes(id)||budget.attempts.some(a=>a.id===id)))throw Error('fixture_already_reserved');
 return {...budget,attempts:[...budget.attempts,{id,sha256:hash,at:new Date().toISOString()}]};
}
async function save(name,value){const temp=join(directory,name+'.tmp');await writeFile(temp,JSON.stringify(value,null,2)+'\n',{mode:0o600});await chmod(temp,0o600);await rename(temp,join(directory,name));}
async function read(name){const p=join(directory,name);const stat=await lstat(p);if(!stat.isFile()||stat.mode&0o077)throw Error('private_permissions_required');return JSON.parse(await readFile(p,'utf8'));}
async function api(path,body,key,token=key,method='POST') {
 // Optional per-process DNS diagnosis, never a system setting or TLS override.
 const address=process.env.STAYGRUBBY_TEST_ADDRESS;let lookup;
 if(address){if(isIP(address)!==4)throw Error('invalid_test_address');lookup=(_host,options,cb)=>cb(null,options?.all?[{address,family:4}]:address,4);}
 return new Promise((resolve,reject)=>{
  const req=httpsRequest(project+path,{method,lookup,signal:AbortSignal.timeout(60000),headers:{apikey:key,authorization:`Bearer ${token}`,'content-type':'application/json',...(path.startsWith('/functions/v1/recipe-import')?{'x-staygrubby-development-review':'candidate'}:{}),...(path.startsWith('/rest/')?{'content-profile':'api','accept-profile':'api'}:{})}},r=>{
   const chunks=[];let size=0;r.on('data',c=>{size+=c.length;if(size>200000){r.destroy();reject(Error('response_too_large'));}else chunks.push(c);});r.on('error',reject);r.on('end',()=>{try{resolve({status:r.statusCode,requestID:r.headers['x-recipe-request-id']??null,value:JSON.parse(Buffer.concat(chunks).toString('utf8'))});}catch{reject(Error('response_not_json'));}});
  });req.on('error',reject);req.end(method==='GET'?undefined:JSON.stringify(body));
 });
}
function testUser(u){return u?.email==='recipe-validation@staygrubby.invalid'&&u.is_anonymous===false&&u.app_metadata?.staygrubby_development_identity==='recipe-validation';}
async function session(config) {
 let s=await read('session.json');
 if(!testUser(s.user))throw Error('identity_mismatch');
 if(Date.now()/1000>=s.expires_at-60){const r=await api('/auth/v1/token?grant_type=refresh_token',{refresh_token:s.refresh_token},config.publishable);if(r.status!==200||!testUser(r.value.user)||r.value.user.id!==s.user.id)throw Error('test_session_expired');s={...r.value,expires_at:Date.now()/1000+r.value.expires_in};await save('session.json',s);}
 const verified=await api('/auth/v1/user',null,config.publishable,s.access_token,'GET');
 if(verified.status!==200||!testUser(verified.value)||verified.value.id!==s.user.id)throw Error('identity_mismatch');return s;
}
async function main() {
 await mkdir(directory,{recursive:true,mode:0o700});const stat=await lstat(directory);if(!stat.isDirectory()||stat.mode&0o077)throw Error('private_permissions_required');
 const command=process.argv[2];
 if(command==='prepare') {
  const requestID=randomUUID(),nonce=randomBytes(32).toString('hex');await save('proof.json',{requestID,nonce});
  // Only an administrator connection can execute this. A hash cannot redeem it.
  console.log(`select development.issue_recipe_test_login('${requestID}'::uuid,'${digest(nonce)}');`);return;
 }
 const config=await read('public-client.json');
 if(command==='login') {
  const r=await api('/functions/v1/development-test-session',await read('proof.json'),config.anon);
  if(r.status!==200||!testUser(r.value.user)){await save('login-failure.json',{status:r.status,value:r.value});throw Error('development_login_denied');}
  await save('session.json',{...r.value,expires_at:Date.now()/1000+r.value.expires_in});await unlink(join(directory,'proof.json'));
  console.log('Dedicated test session established; credentials retained privately.');return;
 }
 const s=await session(config);
 if(command==='status') {
  const r=await api('/auth/v1/settings',null,config.publishable,config.publishable,'GET');
  if(r.status!==200)throw Error('settings_unavailable');
  console.log(JSON.stringify({dedicatedTestSession:true,apple:r.value.external?.apple,email:r.value.external?.email,anonymous:r.value.external?.anonymous_users??r.value.external?.anonymous}));return;
 }
 if(command==='provision') {
  const r=await api('/rest/v1/rpc/provision_account',{},config.publishable,s.access_token);if(r.status!==200||r.value.auth_user_id!==s.user.id)throw Error('test_account_unavailable');
  await save('account.json',r.value);console.log('Dedicated account provisioned through the normal authenticated RPC; no cooking library created.');return;
 }
 if(command!=='run')throw Error('usage_prepare_login_provision_status_run');
 const selected=process.env.STAYGRUBBY_RECIPE_CAMPAIGN;
 if(selected&&selected!==finalV25.approval)throw Error('unknown_campaign');
 const grant=selected?finalV25:legacy;
 const cases={french:['RecipeFrenchToastAcceptance.json','1ad40c62f6d27cfbe0a0ca3150fb9f9ee90744f95af34385c01243b321f9b91d'],shakshuka:['RecipeShakshukaAcceptance.json','18bc8a3d1f9e669cde93fc6db926dc5bfc9689068611999021a2b87a721859c9'],kale:['RecipeEngineCanonicalKale.txt','774a33291a4e216bb55ce4b1d476d0b9c12a4b8aeb3faa2163f3be51da933915']};
 const id=process.argv[3],spec=cases[id];if(!spec)throw Error('unknown_fixture');
 const text=await readFile(join(root,'StayGrubbyTests/Fixtures',spec[0]),'utf8'),raw=spec[0].endsWith('.json')?JSON.parse(text).raw:text;
 if(digest(raw)!==spec[1])throw Error('fixture_changed');
 const lock=await open(join(directory,'live-call.lock'),'wx',0o600);
 try {
  // Missing state must fail closed, never silently reset a spent approval.
  let b=await read(grant.budget);
  b=reserve(b,id,spec[1],grant);await save(grant.budget,b); // Persist BEFORE invocation; ambiguous failures consume the call.
  const number=b.attempts.length;
  let r;try{r=await api('/functions/v1/recipe-import',{text:raw,cloudConsent:true,contractVersion:3,diagnosticReview:true},config.publishable,s.access_token);}
  catch{await save(grant.budget,{...b,stopped:'transport_ambiguous'});throw Error('live_transport_stopped');}
  const artifact=`${grant.prefix}call-${number}-${id}.json`;
  await save(artifact,{fixture:id,raw,sha256:spec[1],at:new Date().toISOString(),...r});
  if([401,403,429,503].includes(r.status)||['configuration','authentication','quota'].includes(r.value.stage))await save(grant.budget,{...b,stopped:'auth_configuration_or_provider_limit'});
  console.log(JSON.stringify({fixture:id,call:number,maximum:grant.maximum,status:r.status,stage:r.value.stage??'success',code:r.value.code??null,requestID:r.requestID??r.value.requestID??null,artifact}));
 } finally{await lock.close();await unlink(join(directory,'live-call.lock'));}
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))main().catch(e=>{console.error('Development validation stopped safely; inspect the private artifact/state. No retry was made.');if(/^[a-z_]{3,60}$/.test(e.message??''))console.error(e.message);for(const code of [e.code,e.cause?.code])if(/^[A-Z_]{3,40}$/.test(code??''))console.error(code);process.exitCode=1;});
