import { MODEL, INSTRUCTIONS, schema, validationReport } from "./contract.ts";
import { preserveEditorialFacts } from "./editorial.ts";
import { reconcile } from "./reconcile.ts";
export type Dependencies = {
  authenticate: (token:string)=>Promise<{user:string;session:string}|null>;
  reserve: (user:string,session:string)=>Promise<boolean>;
  fetch: typeof fetch;
  key?: string;
  log?: (event: Record<string,unknown>)=>void;
  timeoutMilliseconds?: number;
};
// Only enumerated categories/statuses; never provider message, text, token or key.
function providerReason(status: number, error: unknown): string {
 const message=typeof (error as any)?.error?.message==="string" ? (error as any).error.message : "";
 const reasons=Array.isArray((error as any)?.error?.details)?(error as any).error.details.map((d:any)=>d?.reason):[];
 if(reasons.includes("API_KEY_INVALID"))return "invalid_key";
 if(reasons.includes("SERVICE_DISABLED"))return "api_disabled";
 if(reasons.some((r:unknown)=>typeof r==="string"&&["API_KEY_SERVICE_BLOCKED","API_KEY_HTTP_REFERRER_BLOCKED","API_KEY_IP_ADDRESS_BLOCKED","API_KEY_ANDROID_APP_BLOCKED","API_KEY_IOS_APP_BLOCKED"].includes(r)))return "provider_access";
 if (/API key not valid|API key expired|API_KEY_INVALID/i.test(message)) return "invalid_key";
 if (/has not been used|is disabled|SERVICE_DISABLED/i.test(message)) return "api_disabled";
 if (/not found|not supported for|not available.*model/i.test(message)) return "model_unavailable";
 if (/location.*not supported|region.*not supported/i.test(message)) return "region_unavailable";
 if (/billing|paid tier/i.test(message)) return "billing_required";
 return status===404 ? "model_unavailable" : status===429 ? "quota" : status===401 || status===403 ? "provider_access" : status===400 ? "request_format" : "provider_unavailable";
}
// A 400 alone does not identify its rejected field. Preserve only fixed vocabulary,
// never a free-form message/field/metadata value (which could echo a key or input).
function providerDiagnostic(error:unknown):Record<string,string> {
 const e=(error as any)?.error, result:Record<string,string>={};
 if(["INVALID_ARGUMENT","FAILED_PRECONDITION","UNAUTHENTICATED","PERMISSION_DENIED","NOT_FOUND","RESOURCE_EXHAUSTED","INTERNAL","UNAVAILABLE"].includes(e?.status))result.googleStatus=e.status;
 const details=Array.isArray(e?.details)?e.details:[];
 const allowedReasons=["API_KEY_INVALID","SERVICE_DISABLED","API_KEY_SERVICE_BLOCKED","API_KEY_HTTP_REFERRER_BLOCKED","API_KEY_IP_ADDRESS_BLOCKED","API_KEY_ANDROID_APP_BLOCKED","API_KEY_IOS_APP_BLOCKED","BILLING_DISABLED","CONSUMER_INVALID","RATE_LIMIT_EXCEEDED"];
 const reason=details.find((d:any)=>allowedReasons.includes(d?.reason))?.reason;if(reason)result.googleReason=reason;
 const text=[typeof e?.message==="string"?e.message:"",...details.flatMap((d:any)=>Array.isArray(d?.fieldViolations)?d.fieldViolations.map((v:any)=>typeof v?.field==="string"?v.field:""):[])].join(" ");
 if(/too many states|schema.*(?:too complex|complexity|too large)|(?:complex|large).*schema/i.test(text))result.requestIssue="schema_complexity";
 for(const [field,pattern] of [
  ["response_format",/\bresponse_?format\b/i],["response_json_schema",/\bresponse_?json_?schema\b/i],
  ["response_schema",/\bresponse_?schema\b/i],["temperature",/\btemperature\b/i],
  ["max_output_tokens",/\bmax_?output_?tokens\b/i],["system_instruction",/\bsystem_?instruction\b/i],
 ] as const)if(pattern.test(text)){result.requestField=field;break;}
 return result;
}
/// Cap streaming bodies even when content-length is absent or dishonest.
export async function boundedText(response: Request|Response, maximum:number): Promise<string> {
  const reader=response.body?.getReader();if(!reader)return "";
  const chunks:Uint8Array[]=[];let length=0;
  try { for(;;) { const {done,value}=await reader.read();if(done)break;length+=value.byteLength;if(length>maximum){await reader.cancel();throw new Error("size");}chunks.push(value); } }
  finally {reader.releaseLock();}
  const bytes=new Uint8Array(length);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
  return new TextDecoder("utf-8",{fatal:true}).decode(bytes);
}
export function handler(d:Dependencies) {
 return async (req:Request):Promise<Response>=>{
  const requestID=crypto.randomUUID(), start=Date.now();let stage="request";
  const report=(event:Record<string,unknown>)=>d.log?.({requestID,stage,durationMS:Date.now()-start,...event});
  const headers=()=>({"Cache-Control":"no-store","x-recipe-request-id":requestID,"x-recipe-stage":stage,"x-recipe-configured":d.key?"true":"false"});
  const fail=(status:number,code:string,providerStatus?:number,reason?:string,diagnostic:Record<string,unknown>={})=>{
   report({result:code,httpStatus:status,...(providerStatus?{providerStatus}:{}),...(reason?{reason}:{}),...diagnostic});
   return Response.json({code,stage,requestID,...(providerStatus?{providerStatus}:{}),...(reason?{reason}:{})},{status,headers:headers()});
  };
  if(req.method!=="POST")return fail(405,"method_not_allowed");
  const token=req.headers.get("authorization")?.match(/^Bearer (\S+)$/i)?.[1];
  if(!token)return fail(401,"authentication_required");
  try {
   stage="authentication";const actor=await d.authenticate(token);if(!actor)return fail(401,"authentication_required");
   if(!req.headers.get("content-type")?.startsWith("application/json"))return fail(400,"invalid_request");
   let body;
   try {body=JSON.parse(await boundedText(req,40_000));}catch{return fail(413,"invalid_or_oversized_input");}
   if(!body || typeof body!=="object" || Array.isArray(body) || Object.keys(body).some(k=>!["text","cloudConsent"].includes(k)) || typeof body.text!=="string" || body.cloudConsent!==true || !body.text.trim())return fail(400,"invalid_request");
   if([...body.text].length>12_000 || new TextEncoder().encode(body.text).length>32_000)return fail(413,"input_too_long");
   // Owner confirmed the dedicated project has no billing. No recurring timestamp gate.
   stage="configuration";
   if(!d.key)return fail(503,"not_configured");
   stage="account_budget";if(!await d.reserve(actor.user,actor.session))return fail(429,"formatting_limit");
   const controller=new AbortController();const timer=setTimeout(()=>controller.abort(),d.timeoutMilliseconds??25_000);
   const abort=()=>controller.abort();req.signal.addEventListener("abort",abort,{once:true});
   if(req.signal.aborted)controller.abort();
   try {
    stage="provider";const upstream=await d.fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,{
     method:"POST",signal:controller.signal,headers:{"content-type":"application/json","x-goog-api-key":d.key},
     body:JSON.stringify({systemInstruction:{parts:[{text:INSTRUCTIONS}]},contents:[{role:"user",parts:[{text:body.text}]}],generationConfig:{temperature:0,maxOutputTokens:8000,responseFormat:{text:{mimeType:"APPLICATION_JSON",schema}}}}),
    });
    if(!upstream.ok){
     let error:unknown;try{error=JSON.parse(await boundedText(upstream,16_000));}catch{/* Never return/log raw upstream bytes. */}
     const reason=providerReason(upstream.status,error);
     return fail(upstream.status===429?429:503,upstream.status===429?"provider_quota":"provider_unavailable",upstream.status,reason,providerDiagnostic(error));
    }
    stage="provider_response";
    const envelope=JSON.parse(await boundedText(upstream,128_000));
    const candidate=envelope.candidates?.[0];
    if(candidate?.finishReason!=="STOP" || !Array.isArray(candidate.content?.parts))return fail(422,"invalid_recipe",200,"incomplete_output",{finishReason:["MAX_TOKENS","SAFETY","RECITATION","BLOCKLIST","PROHIBITED_CONTENT","SPII","OTHER"].includes(candidate?.finishReason)?candidate.finishReason:"OTHER"});
    const json=candidate.content.parts.filter((p:Record<string,unknown>)=>!p.thought && typeof p.text==="string").map((p:Record<string,unknown>)=>p.text).join("");
    if(new TextEncoder().encode(json).length>96_000)return fail(422,"invalid_recipe");
    stage="validation";let extraction;
    try{extraction=JSON.parse(json);}catch{return fail(422,"invalid_recipe",200,"structured_json");}
    const validation=validationReport(extraction,body.text);
    let recoveredFields:string[]=[],recoveredCount=0;
    if(!validation.valid){
     const restored=reconcile(extraction,body.text);
     if(!restored)return fail(422,"invalid_recipe",200,validation.issues[0]?.rule,{validationIssues:validation.issues,structure:validation.structure});
     extraction=restored.extraction;recoveredFields=restored.fields;recoveredCount=restored.count;
    }
    const locked=preserveEditorialFacts(extraction,body.text);
    if(!locked||!validationReport(locked,body.text).valid||new TextEncoder().encode(JSON.stringify(locked)).length>96_000)return fail(422,"invalid_recipe",200,"fact_lock");
    extraction=locked;
    stage="complete";report({result:"success",httpStatus:200,providerStatus:upstream.status,...(recoveredCount?{sourceRecoveredFields:recoveredFields,sourceRecoveredCount:recoveredCount}:{})});
    return Response.json(extraction,{headers:headers()});
   } catch {
    if(controller.signal.aborted)return fail(504,"formatting_timeout");
    return stage==="provider" ? fail(503,"provider_connection") : fail(422,"invalid_recipe");
   }
   finally {clearTimeout(timer);req.signal.removeEventListener("abort",abort);}

  } catch {return fail(503,"service_unavailable");}
 };
}
