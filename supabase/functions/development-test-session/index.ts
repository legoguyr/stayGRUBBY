import {handler,boundedJSON,EMAIL,MARKER} from './handler.ts';
const url=Deno.env.get('SUPABASE_URL')??'';
const admin=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')??'';
const anon=Deno.env.get('SUPABASE_ANON_KEY')??'';
async function call(path:string,body:unknown,key=admin,method='POST',rpc=false) {
 const response=await fetch(url+path,{method,headers:{apikey:key,authorization:`Bearer ${key}`,'content-type':'application/json',...(rpc?{'content-profile':'api'}:{})},...(method==='GET'?{}:{body:JSON.stringify(body)}),signal:AbortSignal.timeout(8000)});
 if(!response.ok)throw Error('auth_unavailable');return response.status===204?null:boundedJSON(response,64_000);
}
Deno.serve(handler({
 consume:(id,hash)=>call('/rest/v1/rpc/consume_recipe_test_login',{p_id:id,p_hash:hash},admin,'POST',true),
 create:()=>call('/auth/v1/admin/users',{email:EMAIL,email_confirm:true,app_metadata:{staygrubby_development_identity:MARKER}}),
 get:id=>call('/auth/v1/admin/users/'+encodeURIComponent(id),null,admin,'GET'),
 bind:async(request,user)=>{await call('/rest/v1/rpc/bind_recipe_test_identity',{p_request:request,p_user:user},admin,'POST',true);},
 generate:()=>call('/auth/v1/admin/generate_link',{type:'magiclink',email:EMAIL}),
 verify:hash=>call('/auth/v1/verify',{type:'magiclink',token_hash:hash},anon),
}));
