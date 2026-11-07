// App-first pointers only. This Worker never fetches private application data.
import association from './association.json' with {type:'json'};
import distribution from './distribution.json' with {type:'json'};

const betaURL = /^https:\/\/testflight\.apple\.com\/join\/[A-Za-z0-9]+$/.test(distribution.url ?? '');
const storeURL = /^https:\/\/apps\.apple\.com\/[A-Za-z]{2}\/app\/[A-Za-z0-9-]+\/id[0-9]+$/.test(distribution.url ?? '');
const acquisition = betaURL || storeURL ? distribution.url : null;
export function referral(url) {
 const tokens = url.searchParams.getAll('ref');
 return tokens.length === 1 && /^[A-Za-z0-9_-]{16,64}$/.test(tokens[0]) ? tokens[0] : null;
}
const headers={
 'Content-Security-Policy':"default-src 'none'; img-src 'self'; style-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; object-src 'none'",
 'X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer',
 'Permissions-Policy':'camera=(), microphone=(), geolocation=(), payment=(), usb=()',
 'Strict-Transport-Security':'max-age=31536000'
};
export function destination(url){
 if(url.hash || [...url.searchParams.keys()].some(key=>key!=='ref'))return null;
 const token=referral(url);
 const suffix=token ? '?ref='+token : '';
 let path;try{path=decodeURIComponent(url.pathname)}catch{return null}
 const uuid='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';
 if(/^\/@[a-z0-9]+(?:_[a-z0-9]+)*$/.test(path)&&path.length>=5&&path.length<=26)return 'staygrubby://open'+path+suffix;
 if(new RegExp('^/(?:p/'+uuid+'(?:/recipe)?|r/'+uuid+')$').test(path))return 'staygrubby://open'+path.toLowerCase()+suffix;
 return null;
}
export function fallback(appURL,unavailable=false,direct=false){
 const heading=unavailable ? 'Link unavailable' : storeURL ? 'Your cooking. Your taste.' : 'We’re in beta.';
 const cta=acquisition ? `<p><a class="button" href="${acquisition}">${storeURL ? 'Download StayGrubby' : 'Join StayGrubby Beta'}</a></p>`
  : '<p>Ask the person who invited you for beta access.</p>';
 const open=appURL ? `<p><a href="${appURL}">Open StayGrubby</a></p><p>After installing, reopen the original link to see what was shared. Sign in and the owner’s sharing settings still apply.</p>` : '';
 // Only validated pointers and the configured Apple acquisition URL enter HTML.
 return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow"><title>${direct ? 'Join StayGrubby' : 'Open in StayGrubby'}</title><link rel="stylesheet" href="/assets/site.css"></head><body><header class="site-header"><a class="brand" href="/"><img src="/assets/wordmark.png" alt="#stayGRUBBY" width="1254" height="1254"></a></header><main class="reading"><article class="policy"><h1>${heading}</h1><p class="intro">Rank what you cook, save the recipes worth making again, and share them with friends.</p>${cta}${open}<p><a href="/support">Support</a> · <a href="/privacy">Privacy Policy</a></p></article></main></body></html>`;
}
export default {
 async fetch(request,env){
  const url=new URL(request.url);
  if(!['GET','HEAD'].includes(request.method))return new Response(null,{status:405,headers:{...headers,Allow:'GET, HEAD'}});
  if(url.pathname==='/.well-known/apple-app-site-association'||url.pathname==='/apple-app-site-association'){
   return new Response(request.method==='HEAD'?null:JSON.stringify(association),{headers:{...headers,'Content-Type':'application/json','Cache-Control':'public, max-age=3600'}});
  }
  const target=destination(url);
  if(target||url.pathname==='/kitchen'||url.pathname==='/beta')return new Response(request.method==='HEAD'?null:fallback(target,false,url.pathname==='/beta'),{headers:{...headers,'Content-Type':'text/html; charset=utf-8','Content-Disposition':'inline','Cache-Control':'no-store','X-Robots-Tag':'noindex, nofollow'}});
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
