import { handler, boundedText } from "./handler.ts";
// Native-app endpoint: no browser CORS allowance, external SDK or Recipe persistence.
// Logging is limited to enumerated stages/statuses; never text or credentials.
const url=Deno.env.get("SUPABASE_URL")??"";
const anon=Deno.env.get("SUPABASE_ANON_KEY")??"";
const admin=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")??"";
Deno.serve(handler({
 key:Deno.env.get("STAYGRUBBY_GEMINI_API_KEY"),
 log:event=>console.info(JSON.stringify(event)),
 fetch,
 authenticate:async token=>{
  const response=await fetch(`${url}/auth/v1/user`,{headers:{apikey:anon,Authorization:`Bearer ${token}`},signal:AbortSignal.timeout(8000)});
  if(!response.ok)return null;
  const user=JSON.parse(await boundedText(response,32_000));
  if(!user.id || user.is_anonymous)return null;
  // Decode only AFTER Auth verifies the token; never trust editable user_metadata.
  const part=token.split(".")[1];if(!part)return null;
  const claims=JSON.parse(atob(part.replaceAll("-","+").replaceAll("_","/")));
  if(!claims.session_id)return null;
  return {user:user.id,session:claims.session_id};
 },
 reserve:async(user,session)=>{
  const response=await fetch(`${url}/rest/v1/rpc/reserve_recipe_import`,{method:"POST",headers:{apikey:admin,Authorization:`Bearer ${admin}`,"content-type":"application/json","content-profile":"api"},body:JSON.stringify({p_user:user,p_session:session}),signal:AbortSignal.timeout(8000)});
  if(!response.ok)throw new Error("budget_unavailable");
  return await response.json()===true;
 },
}));
