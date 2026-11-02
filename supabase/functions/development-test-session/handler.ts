// Developer tooling only. No Xcode target references this endpoint. A valid
// gateway JWT alone is insufficient: an administrator-issued, single-use proof
// is required BEFORE any Auth operation. Never log requests, responses or errors.
export const EMAIL='recipe-validation@staygrubby.invalid';
export const MARKER='recipe-validation';
export type User={id:string;email?:string;is_anonymous?:boolean;app_metadata?:Record<string,unknown>};
export function isTestUser(user:User|undefined):user is User {
 return !!user?.id&&user.email===EMAIL&&user.is_anonymous===false&&user.app_metadata?.staygrubby_development_identity===MARKER;
}
export type Dependencies={
 consume:(id:string,hash:string)=>Promise<{userID:string|null}>;
 create:()=>Promise<User>;get:(id:string)=>Promise<User>;
 bind:(request:string,user:string)=>Promise<void>;
 generate:()=>Promise<{id:string;hashed_token:string}>;
 verify:(hash:string)=>Promise<{user:User;access_token:string;refresh_token:string;expires_in:number}>;
};
export async function boundedJSON(response:Response|Request,limit:number):Promise<any> {
 const reader=response.body?.getReader();if(!reader)throw Error('invalid_body');
 const chunks:Uint8Array[]=[];let size=0;
 try {for(;;){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>limit)throw Error('invalid_body');chunks.push(value);}}
 finally{await reader.cancel();}
 const data=new Uint8Array(size);let offset=0;for(const c of chunks){data.set(c,offset);offset+=c.length;}
 return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(data));
}
export function handler(d:Dependencies) {
 return async(req:Request):Promise<Response>=>{
  const reply=(status:number,data:unknown)=>Response.json(data,{status,headers:{'cache-control':'no-store','pragma':'no-cache'}});
  if(req.method!=='POST')return reply(405,{error:'method_not_allowed'});
  if(!/^Bearer \S+$/.test(req.headers.get('authorization')??''))return reply(401,{error:'development_authorization_required'});
  try {
   const body=await boundedJSON(req,2048);
   if(!body||Object.keys(body).sort().join(',')!=='nonce,requestID'||typeof body.requestID!=='string'||!/^[0-9a-f-]{36}$/.test(body.requestID)||typeof body.nonce!=='string'||!/^[0-9a-f]{64}$/.test(body.nonce))return reply(400,{error:'invalid_request'});
   const hash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(body.nonce)))].map(b=>b.toString(16).padStart(2,'0')).join('');
   const identity=await d.consume(body.requestID,hash);
   // Never adopt an existing email collision or allow caller-selected targets.
   const user=identity.userID?await d.get(identity.userID):await d.create();
   if(!isTestUser(user)||identity.userID&&identity.userID!==user.id)throw Error('identity');
   await d.bind(body.requestID,user.id);
   const link=await d.generate();if(link.id!==user.id||!link.hashed_token)throw Error('identity');
   const session=await d.verify(link.hashed_token);
   if(!isTestUser(session.user)||session.user.id!==user.id||!session.access_token||!session.refresh_token)throw Error('identity');
   return reply(200,session);
  } catch {return reply(403,{error:'development_authorization_unavailable'});}
 };
}
