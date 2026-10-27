import { type Extraction, validationReport } from "./contract.ts";
import { factualWords, groundingIssue, numericEvidence, tokens } from "./evidence.ts";

// Retrieval only: these words do NOT become an acceptance allowlist. Every
// replacement below is a literal source substring, checked again by validate().
const connective=new Set(['or','until','if','when','want','need','going','done','starts','can','should','would','optional','needed','taste','below','see','serving','garnish','topping','add','put','take','cook','boil','blend','mix','heat','top','move','cool','squeeze','season','bake','roast','fry','chop','slice','stir','whisk','serve','combine','pour','drizzle','sprinkle','remove','transfer','place','toss']);
const anchors=(text:string)=>new Set(factualWords(text).filter(w=>!connective.has(w)));
const numbers=(text:string)=>tokens(text).filter(w=>/^n\d/.test(w)).sort().join(' ');

function sourceCandidates(raw:string) {
 const cuts=new Set([0,raw.length]);
 // Generic prose boundaries, never recipe-specific names or expected sections.
 const boundary=/[.;,\n]+|\b(?:add|boil|cook|blend|mix|heat|top|put|take|move|squeeze|season|shave|bake|roast|fry|chop|slice|stir|whisk|serve|combine|pour|drizzle|sprinkle|cool|remove|transfer|place|toss|or|and|with|then|until)\b/gi;
 for(const m of raw.matchAll(boundary)){cuts.add(m.index);cuts.add(m.index+m[0].length);}
 const points=[...cuts].sort((a,b)=>a-b);
 if(points.length>512)return []; // Bound recovery work; never truncate the input.
 const values=new Set<string>();
 for(let i=0;i<points.length-1;i++)for(let n=i+1;n<Math.min(points.length,i+9);n++){
  const text=raw.slice(points[i],points[n]).trim().replace(/^(?:(?:or|and|with|then)\s+)+/i,'').replace(/^[.;,\s]+|[.;,\s]+$/g,'');
  if(text&&text.length<=2000)values.add(text);
 }
 if(raw.length<=2000)values.add(raw.trim());
 // Complete source sentences preserve a preparation's context when a short
 // retrieval window would omit its subject. Prefixes exclude descriptive prose
 // from ingredient labels. All candidates remain literal source substrings.
 for(const sentence of raw.split(/(?<=[.;\n])\s*/u))if(sentence.trim())values.add(sentence.trim());
 for(const text of [...values]){
  const description=text.search(/\s+(?:is|are|was|were)\s+(?:done|made|going|prepared)\b/i);
  if(description>0)values.add(text.slice(0,description));
  const repeated=text.match(/^(.+?)\s+\1(?:\s|$)/i);
  if(repeated){values.add(repeated[1]);values.add(text.slice(repeated[1].length).trimStart());}
 }
 return [...values].map(text=>({text,anchors:anchors(text),numbers:numbers(text)}));
}

export function reconcile(value:unknown,raw:string,polished=false):{extraction:Extraction;fields:string[];count:number}|null {
 const report=validationReport(value,raw,polished);if(!report.reconcilable)return null;
 const extraction=structuredClone(value) as Extraction, fields:string[]=[];
 let count=0;
 const record=(field:string)=>{count++;if(fields.length<20)fields.push(field);};
 const candidates=sourceCandidates(raw),origin=anchors(raw);
 const recover=(text:string,maximum:number,kind:'ingredient'|'step'):string|null=>{
  if(!numericEvidence(text,raw)||(kind==='ingredient'&&numbers(text)))return null; // Never reassign a supplied numeric ingredient amount/unit.
  const base=kind==='ingredient'?text.split(/\s+for\b|\s*\(/i)[0].trim().replace(/[,:;\-]+$/,'').trim():text;
  const wanted=new Set([...anchors(base)].filter(w=>origin.has(w)));
  if(!wanted.size)return null;
  const numeric=numbers(text);let best:string|null=null,score=-Infinity;
  for(const c of candidates){
   if(c.text.length>maximum||c.numbers!==numeric)continue;
   if(kind==='ingredient'&&/^(?:add|boil|cook|blend|mix|heat|top|put|take|move|squeeze|season|shave|bake|roast|fry|chop|slice|stir|whisk|serve|combine|pour|drizzle|sprinkle|cool|remove|transfer|place|toss)\b/i.test(c.text))continue;
   if(kind==='ingredient'&&/\b(?:is|are|was|were|taking|put|add|cook|boil|blend|stir|bake|roast|until)\b/i.test(c.text))continue;
   const matched=[...wanted].filter(w=>c.anchors.has(w)).length;
   if(matched<Math.min(2,wanted.size)||matched/wanted.size<0.5)continue;
   const rank=100*matched/wanted.size+3*Math.min(matched,5)-0.1*c.anchors.size-c.text.length/10000;
   if(rank>score){score=rank;best=c.text;}
  }
  if(best){
   if(kind==='step'){
    const start=raw.indexOf(best),tail=raw.slice(start),stop=tail.search(/[.;\n]/);
    const extended=(stop<0?tail:tail.slice(0,stop+1)).trim();
    // Keep an original completion qualifier (until crispy/done/etc.) rather
    // than trimming it merely because its word also occurred in a section label.
    if(extended.length>=best.length&&extended.length<=maximum&&numbers(extended)===numeric)return extended;
   }
   return best;
  }
  // If only a relational annotation obstructed a supported ingredient, retain
  // its literal source name. No amount is inferred from nearby prose.
  if(kind==='ingredient'&&base!==text){
   const escaped=base.replace(/[.*+?^${}()|[\]\\]/g,'\\$&').replace(/\s+/g,'\\s+');
   const match=raw.match(new RegExp(`\\b${escaped}\\b`,'i'));
   if(match&&match[0].length<=maximum)return match[0];
  }
  return null;
 };
 // Optional invented labels/metadata become unknown, rather than guessed facts.
 for(const key of ['title','yield','source'] as const)if(extraction[key]!==null&&groundingIssue(extraction[key]!,raw,key==='title'?'title':'metadata',polished)){extraction[key]=null;record(key);}
 for(const [i,part] of extraction.components.entries()){
  if(part.title!==null&&groundingIssue(part.title,raw,'title',polished)){part.title=null;record(`components[${i}].title`);}
  for(const [key,kind,max] of [['ingredients','ingredient',500],['steps','step',2000]] as const)for(const [n,text] of part[key].entries()){
   if(!groundingIssue(text,raw,kind,polished))continue;
   // Remove only a closed set of unsupported presentation modifiers when the
   // remaining edited sentence independently passes every source guard. Do not
   // erase uncertain ingredient varieties, numbers, negation or cooking verbs.
   let scoped=text;
   for(const modifier of ['extra[- ]virgin','freshly','finely','roughly']) {
    if(!new RegExp(`\\b${modifier}\\b`,'i').test(raw))scoped=scoped.replace(new RegExp(`\\b${modifier}\\b[ ,]*`,'gi'),'');
   }
   const restored=scoped!==text&&!groundingIssue(scoped,raw,kind,polished)?scoped:recover(text,max,kind);if(!restored)return null;
   part[key][n]=restored;record(`components[${i}].${key}[${n}]`);
  }
 }
 // No schema/source guard is bypassed, including caps hidden by bounded logs.
 if(!validationReport(extraction,raw,polished).valid||new TextEncoder().encode(JSON.stringify(extraction)).length>96_000)return null;
 return {extraction,fields,count};
}
