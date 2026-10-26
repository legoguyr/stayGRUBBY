import { MODEL, INSTRUCTIONS, schema, validate } from "./contract.ts";
export type Dependencies = {
  authenticate: (token:string)=>Promise<{user:string;session:string}|null>;
  reserve: (user:string,session:string)=>Promise<boolean>;
  fetch: typeof fetch;
  key?: string;
  freeTierUntil?: string;
  now?: ()=>number;
  timeoutMilliseconds?: number;
};
const fail = (status:number,code:string)=>Response.json({code},{status,headers:{"Cache-Control":"no-store"}});
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
  if(req.method!=="POST")return fail(405,"method_not_allowed");
  const token=req.headers.get("authorization")?.match(/^Bearer (\S+)$/i)?.[1];
  if(!token)return fail(401,"authentication_required");
  try {
   const actor=await d.authenticate(token);if(!actor)return fail(401,"authentication_required");
   if(!req.headers.get("content-type")?.startsWith("application/json"))return fail(400,"invalid_request");
   let body;
   try {body=JSON.parse(await boundedText(req,40_000));}catch{return fail(413,"invalid_or_oversized_input");}
   if(!body || typeof body!=="object" || Array.isArray(body) || Object.keys(body).some(k=>!["text","cloudConsent"].includes(k)) || typeof body.text!=="string" || body.cloudConsent!==true || !body.text.trim())return fail(400,"invalid_request");
   if([...body.text].length>12_000 || new TextEncoder().encode(body.text).length>32_000)return fail(413,"input_too_long");
   // Fail CLOSED. There is no paid mode and the client cannot choose key/model/budget.
   // Owner must confirm a dedicated UNBILLED project; confirmation expires within 30 days.
   const now=d.now?.()??Date.now(), until=Date.parse(d.freeTierUntil??"");
   if(!d.key || !Number.isFinite(until) || until<=now || until>now+30*86400_000)return fail(503,"formatting_unavailable");
   if(!await d.reserve(actor.user,actor.session))return fail(429,"formatting_limit");
   const controller=new AbortController();const timer=setTimeout(()=>controller.abort(),d.timeoutMilliseconds??25_000);
   const abort=()=>controller.abort();req.signal.addEventListener("abort",abort,{once:true});
   if(req.signal.aborted)controller.abort();
   try {
    const upstream=await d.fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,{
     method:"POST",signal:controller.signal,headers:{"content-type":"application/json","x-goog-api-key":d.key},
     body:JSON.stringify({systemInstruction:{parts:[{text:INSTRUCTIONS}]},contents:[{role:"user",parts:[{text:body.text}]}],generationConfig:{temperature:0,maxOutputTokens:8000,responseFormat:{text:{mimeType:"APPLICATION_JSON",schema}}}}),
    });
    if(upstream.status===429){await upstream.body?.cancel();return fail(429,"formatting_limit");}
    if(!upstream.ok){await upstream.body?.cancel();return fail(503,"formatting_unavailable");}
    const envelope=JSON.parse(await boundedText(upstream,128_000));
    const candidate=envelope.candidates?.[0];
    if(candidate?.finishReason!=="STOP" || !Array.isArray(candidate.content?.parts))return fail(422,"invalid_recipe");
    const json=candidate.content.parts.filter((p:Record<string,unknown>)=>!p.thought && typeof p.text==="string").map((p:Record<string,unknown>)=>p.text).join("");
    if(new TextEncoder().encode(json).length>96_000)return fail(422,"invalid_recipe");
    const extraction=JSON.parse(json);
    if(!validate(extraction,body.text))return fail(422,"invalid_recipe");
    return Response.json(extraction,{headers:{"Cache-Control":"no-store"}});
   } catch {return fail(controller.signal.aborted?504:422,controller.signal.aborted?"formatting_timeout":"invalid_recipe");}
   finally {clearTimeout(timer);req.signal.removeEventListener("abort",abort);}
  } catch {return fail(503,"formatting_unavailable");}
 };
}
