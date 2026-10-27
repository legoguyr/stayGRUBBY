import { heatAlternative, styleText } from './style.ts';
import type { Extraction } from './contract.ts';
import { editorialTokens, tokens } from './evidence.ts';

// Transient source obligations, never provider claims or permanent Recipe fields.
// This is deliberately bounded: it is not a general natural-language proof.
type Lock={identity:string;prefix?:string;suffix?:string;method?:boolean};
export function sourceLocks(raw:string):Lock[] {
 const locks:Lock[]=[];
 const end='(?=[,.;\\n]|\\b(?:or|and|add|blend|cook|boil|mix|top|put|take|heat|until)\\b|$)';
 const before=new RegExp(`\\b(a little|some|optional|maybe)\\s+([a-z][a-z -]{0,70}?)\\s*${end}`,'gi');
 for(const m of raw.matchAll(before))locks.push({identity:m[2].trim(),prefix:m[1]});
 for(const m of raw.matchAll(/\b([a-z]+(?:\s+[a-z]+){0,2})\s+(to taste|if (?:you )?(?:want(?: spice)?|desired)|per (?:person|serving))\b/gi))locks.push({identity:m[1].split(/\b(?:and|with|or)\b/i).at(-1)!.trim(),suffix:m[2]});
 for(const m of raw.matchAll(/\b(about|approximately)\s+((?:(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)|\d+(?:\.\d+)?)\s+(?:minutes?|mins?|hours?|hrs?))\b/gi))locks.push({identity:m[2],prefix:m[1],method:true});
 return locks;
}
export function preserveEditorialFacts(value:Extraction,raw:string,polished=false):Extraction|null {
 const copy=structuredClone(value);
 const proposals=copy.metadata?Object.values(copy.metadata).filter((p:any)=>p&&typeof p==='object'&&!Array.isArray(p)&&['provided','derived'].includes(p.origin)):[];
 const metadataTokens=proposals.flatMap((p:any)=>tokens(p.origin==='derived'?p.evidence??'':String(p.value??'')));

 const fields=copy.components.flatMap(p=>[...p.ingredients.map((_,i)=>({get:()=>p.ingredients[i],set:(s:string)=>p.ingredients[i]=s,method:false})),...p.steps.map((_,i)=>({get:()=>p.steps[i],set:(s:string)=>p.steps[i]=s,method:true}))]);
 const locks=sourceLocks(raw);if(locks.length>200)return null; // Fail closed; never silently truncate source obligations.
 for(const lock of locks){
  if(polished&&['some','a little'].includes(lock.prefix??''))continue;
  const identity=polished?editorialTokens(lock.identity,raw,'ingredient',true):tokens(lock.identity);
  if(!identity.length)continue;
  const candidates=fields.filter(f=>(!lock.method||f.method)&&identity.every(w=>(polished?editorialTokens(f.get(),raw,'ingredient',true):tokens(f.get())).includes(w)));
  // Prefer ingredients and unknown amounts, not a different quantified use of
  // the same ingredient (e.g. a garnish vs the main preparation).
  candidates.sort((a,b)=>Number(a.method)-Number(b.method)+Number(tokens(a.get()).some(w=>/^n\d/.test(w)))-Number(tokens(b.get()).some(w=>/^n\d/.test(w))));
  const marker=lock.prefix??lock.suffix!;
  const markerTokens=editorialTokens(marker,raw,'step');
  if(candidates.some(f=>markerTokens.every(w=>editorialTokens(f.get(),raw,'step').includes(w))&&(!/some|about|approximately/i.test(marker)||new RegExp(`\\b${/about|approximately/i.test(marker)?'(?:about|approximately)':marker}\\b`,'i').test(f.get()))))continue;
  const target=candidates[0];
  if(!target&&lock.method&&proposals.some((p:any)=>tokens(p.evidence??'').includes(identity[0])&&(p.evidence??'').toLowerCase().includes(marker.toLowerCase())))continue;
  if(!target)return null;
  // Restore ONLY a supplied qualifier; keep the provider's edited sentence.
  if(lock.prefix) {
   const words=lock.identity.trim().split(/\s+/).map(w=>w.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'));
   const pattern=new RegExp(`\\b${words.join('\\s+')}\\b`,'i');
   if(pattern.test(target.get()))target.set(target.get().replace(pattern,m=>`${lock.prefix} ${m}`));
   else if(lock.method){
    const span=target.get().match(/\b(?:\d+(?:\.\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s+(?:minutes?|mins?|hours?|hrs?)\b/i)?.[0];
    if(!span||tokens(span).join(' ')!==identity.join(' '))return null;
    target.set(target.get().replace(span,`${lock.prefix} ${span}`));
   }
   else if(!target.method)target.set(`${lock.prefix} ${target.get()}`);
   else return null;
  } else target.set(target.get().replace(/[.]$/,'')+` (${lock.suffix})${target.method?'.':''}`);
 }
 const text=fields.map(f=>f.get()).join('\n'),output=editorialTokens(text,raw,'step');
 // Amount/time/temperature evidence and preparation words may not disappear
 // merely to improve prose. Existing field guards still check their bindings.
 for(const word of tokens(raw))if((/^n\d/.test(word)||['cold','cubed','fresh','minced','chopped','grated','peeled','trimmed','softened'].includes(word))&&!output.includes(word)&&!(/^n\d/.test(word)&&metadataTokens.includes(word)))return null;
 // Keep each supplied alternative group together, including uncertain words.
 for(const clause of raw.split(/[.,;:\n]|\b(?:add|blend|cook|boil|mix|top|take|with|and)\b/i)){
  if(!/\bor\b/i.test(clause))continue;
  const group=clause.split(/\bif\b/i)[0].trim();
  if(polished&&heatAlternative(group)&&fields.some(f=>/\boptional\b/i.test(f.get())&&/\b(?:chiles?|chilies|chili|chillies)\b/i.test(f.get())&&!tokens(f.get()).some(t=>/^n\d/.test(t))))continue;
  const wanted=tokens(group).filter(w=>!['little','optional','maybe'].includes(w));
  if(wanted.length&& !fields.some(f=>wanted.every(w=>tokens(f.get()).includes(w))))return null;
 }
 return copy;
}
