// App-first pointers only. This Worker never fetches private application data.
import association from './association.json' with {type:'json'};
const headers={
 'Content-Security-Policy':"default-src 'none'; img-src 'self'; style-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; object-src 'none'",
 'X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer',
 'Permissions-Policy':'camera=(), microphone=(), geolocation=(), payment=(), usb=()',
 'Strict-Transport-Security':'max-age=31536000'
};
export function destination(url){
 if(url.search||url.hash)return null;
 let path;try{path=decodeURIComponent(url.pathname)}catch{return null}
 const uuid='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';
 if(/^\/@[a-z0-9]+(?:_[a-z0-9]+)*$/.test(path)&&path.length>=5&&path.length<=26)return 'staygrubby://open'+path;
 if(new RegExp('^/(?:p/'+uuid+'(?:/recipe)?|r/'+uuid+')$').test(path))return 'staygrubby://open'+path.toLowerCase();
 return null;
}
export function fallback(appURL,unavailable=false){
 // appURL is constructed only from the strict route grammar above, never arbitrary request text.
 return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow"><title>Open in StayGrubby</title><link rel="stylesheet" href="/assets/site.css"></head><body><header><a href="/"><img src="/assets/wordmark.png" alt="#stayGRUBBY" width="160"></a></header><main class="reading"><article class="policy"><h1>${unavailable?"Link unavailable":"There’s something cooking."}</h1><p>View this Kitchen, cook or Recipe in StayGrubby. Sign in to your own account; the owner’s current sharing and privacy choices still apply.</p>${appURL?`<p><a class="button" href="${appURL}">Open StayGrubby</a></p>`:''}<p>If StayGrubby is not installed, ask the person who shared this link for beta access. There is no public Recipe or cooking library on this website.</p><p>On iPhone, you can also open the original link from Messages or Mail, or press and hold it and choose Open in StayGrubby when iOS offers that action.</p><p><a href="/support">Need help?</a> · <a href="/privacy">Privacy Policy</a></p></article></main></body></html>`;
}
export default {
 async fetch(request,env){
  const url=new URL(request.url);
  if(!['GET','HEAD'].includes(request.method))return new Response(null,{status:405,headers:{...headers,Allow:'GET, HEAD'}});
  if(url.pathname==='/.well-known/apple-app-site-association'||url.pathname==='/apple-app-site-association'){
   return new Response(request.method==='HEAD'?null:JSON.stringify(association),{headers:{...headers,'Content-Type':'application/json','Cache-Control':'public, max-age=3600'}});
  }
  const target=destination(url);
  if(target||url.pathname==='/kitchen')return new Response(request.method==='HEAD'?null:fallback(target),{headers:{...headers,'Content-Type':'text/html; charset=utf-8','Content-Disposition':'inline','Cache-Control':'no-store','X-Robots-Tag':'noindex, nofollow'}});
  if(/^\/(?:@|%40|p\/|r\/)/i.test(url.pathname))return new Response(request.method==='HEAD'?null:fallback(null,true),{status:404,headers:{...headers,'Content-Type':'text/html; charset=utf-8','Content-Disposition':'inline','Cache-Control':'no-store','X-Robots-Tag':'noindex, nofollow'}});
  // Canonical HTML pages are requested by their real file, with html_handling=none.
  // This avoids the old rewrite-to-.html / redirect-to-extensionless loop.
  if(['/','/privacy','/support'].includes(url.pathname)){
   const asset=new URL(url);asset.pathname=url.pathname==='/'?'/index.html':url.pathname+'.html';
   return env.ASSETS.fetch(new Request(asset,request));
  }
  return env.ASSETS.fetch(request);
 }
};
