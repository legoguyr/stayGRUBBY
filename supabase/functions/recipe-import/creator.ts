import type { Extraction } from './contract.ts';
import { tokens, grounded } from './evidence.ts';
import { cuisines, allergens } from './creator-taxonomy.ts';
export { cuisines, allergens };
export type Origin='provided'|'derived'|'estimated'|'unknown';
export type Proposal<T>={value:T|null;origin:Origin;evidence:string|null};
export type CreatorMetadata={yield:Proposal<string>;prepMinutes:Proposal<number>;cookMinutes:Proposal<number>;totalMinutes:Proposal<number>;cuisine:Proposal<string>;allergenHints:string[]};
const unknown=()=>({value:null,origin:'unknown' as Origin,evidence:null});
const normalize=(s:string)=>s.toLowerCase().replace(/\s+/g,' ').trim();
function number(s:string){const v=tokens(s).find(w=>/^n\d/.test(w))?.match(/^n(\d+)\/(\d+)$/);return v?Number(v[1])/Number(v[2]):null;}
export function effectiveSource(raw:string):string {
 // Only explicit same-ingredient self-corrections. Original input stays visible.
 const q='(?:\\d+(?:[./]\\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)';
 return raw.replace(new RegExp(`\\b${q}\\s+([a-z]+(?:\\s+[a-z]+){0,2})\\s*,?\\s+(?:no,?|actually,?|sorry,? I mean)\\s+(${q})\\s+\\1\\b`,'gi'),(_all,name,amount)=>`${amount} ${name}`);
}
function numericToken(word:string):number|null {const m=word?.match(/^n(\d+)\/(\d+)$/);return m?+m[1]/+m[2]:null;}
function servingHeader(raw:string):string|null {
 const first=raw.split(/[.!?\n]/)[0].trim();
 if(/^(?:cook|bake|simmer|boil|poach|heat|fry|roast|wait|rest)\b/i.test(first))return null;
 return first.match(/^.{1,120}\b(for\s+(?:\d{1,3}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)(?:\s+(?:people|servings|portions))?)$/i)?.[1]??null;
}
function durations(text:string):number[]{const t=tokens(text);return t.flatMap((w,i)=>{const n=numericToken(w);return n!==null&&['min','hour'].includes(t[i+1])?[n*(t[i+1]==='hour'?60:1)]:[];});}
function explicit(raw:string,key:string):number|null {
 const t=tokens(raw);
 for(let i=0;i<t.length;i++){
  if(key==='yield'&&['serves','servings','yield','makes'].includes(t[i])){const n=numericToken(t[i+1]);if(n!==null)return n;}
  const role=key==='prepMinutes'?['prep','preparation']:key==='cookMinutes'?['cook','cooking']:['total','elapsed'];
  if(key!=='yield'&&role.includes(t[i])&&t[i+1]==='time'){
   const n=numericToken(t[i+2]);if(n!==null&&['min','hour'].includes(t[i+3]))return n*(t[i+3]==='hour'?60:1);
  }
 }
 return key==='yield'&&servingHeader(raw)?number(servingHeader(raw)!):null;
}
function statement(raw:string,key:string):string {
 const role=key==='yield'?'(?:serves|servings|yield|makes)':key==='prepMinutes'?'(?:prep(?:aration)? time)':key==='cookMinutes'?'(?:cook(?:ing)? time)':'(?:total time|elapsed time)';
 return raw.match(new RegExp(`\\b${role}\\b[^.;\\n]{0,180}`,'i'))?.[0]??(key==='yield'?servingHeader(raw):null)??raw.slice(0,180);
}

function yieldLabel(raw:string,n:number):string {
 const t=tokens(statement(raw,'yield')),at=t.findIndex(w=>numericToken(w)!==null),tail=t.slice(at+1);
 if(!tail.length||['servings','serving','people','persons','person','portions'].includes(tail[0]))return String(n);
 return [String(n),...tail.slice(0,2).filter(w=>/^[a-z]+$/.test(w))].join(' ');
}
export function metadata(raw:string,input:unknown,polished=false):CreatorMetadata|null {
 if(!input||typeof input!=='object'||Array.isArray(input))return null;
 const v=input as any, keys=['yield','prepMinutes','cookMinutes','totalMinutes','cuisine'];
 if(Object.keys(v).some(k=>![...keys,'allergenHints'].includes(k))||!keys.every(k=>Object.hasOwn(v,k))||!Array.isArray(v.allergenHints)||v.allergenHints.length>9)return null;
 const result=structuredClone(v) as CreatorMetadata;
 for(const key of keys){
  const p=v[key];if(!p||typeof p!=='object'||Array.isArray(p)||Object.keys(p).sort().join(',')!=='evidence,origin,value'||!['provided','derived','estimated','unknown'].includes(p.origin))return null;
  const explicitValue=explicit(raw,key);
  if(key!=='cuisine'&&explicitValue!==null&&!(key==='yield'&&p.origin==='derived')){(result as any)[key]=key!=='yield'&&explicitValue>10080?unknown():{value:key==='yield'?yieldLabel(raw,explicitValue):Math.ceil(explicitValue),origin:key!=='yield'&&!Number.isInteger(explicitValue)?'derived':'provided',evidence:statement(raw,key)};continue;}
  if(p.origin==='unknown'){(result as any)[key]=unknown();continue;}
  if(polished&&p.origin==='estimated'){
   const valid=key==='yield'?typeof p.value==='string'&&p.value.trim()&&p.value.length<=100:key==='cuisine'?cuisines.includes(p.value):Number.isInteger(p.value)&&p.value>=0&&p.value<=10080;
   (result as any)[key]=valid?{value:p.value,origin:'estimated',evidence:raw.slice(0,500)}:unknown();continue;
  }
  const string=key==='yield'||key==='cuisine';
  if((string?(typeof p.value!=='string'||!p.value.trim()||p.value.length>100):(!Number.isInteger(p.value)||p.value<0||p.value>10080))||typeof p.evidence!=='string'||!p.evidence.trim()||p.evidence.length>500||!normalize(raw).includes(normalize(p.evidence))){(result as any)[key]=unknown();continue;}
  if(key==='cuisine'){
   if(!cuisines.includes(p.value)||(p.origin==='provided'&&!normalize(p.evidence).includes(normalize(p.value))))result.cuisine=unknown();
   continue;
  }
  const value=string?number(p.value):p.value, stated=explicit(raw,key);
  if(stated!==null&&value!==stated&&!(key==='yield'&&p.origin==='derived')){(result as any)[key]=unknown();continue;}
  if(p.origin==='provided'&&(stated===null||value!==stated)){(result as any)[key]=unknown();continue;}
  if(p.origin==='derived'){
   const ns=key==='yield'?tokens(p.evidence).filter(w=>/^n\d/.test(w)).map(w=>numericToken(w)!):durations(p.evidence);
   const parts=[result.prepMinutes?.value,result.cookMinutes?.value].filter((n):n is number=>typeof n==='number');
   const ok=key==='yield'?ns.length===2&&/per (?:person|serving)/i.test(p.evidence)&&ns[1]>0&&ns[0]/ns[1]===value:
    ns.includes(value)||(!/parallel|while|meanwhile/i.test(p.evidence)&&ns.reduce((a,b)=>a+b,0)===value)||(key==='totalMinutes'&&parts.length>0&&(parts.reduce((a,b)=>a+b,0)===value||Math.max(...parts)===value));
   if(!ok)(result as any)[key]=unknown();
  }
 }
 if(result.totalMinutes.value===null&&result.prepMinutes.value!==null&&result.cookMinutes.value!==null&&result.prepMinutes.value+result.cookMinutes.value<=10080&&!/parallel|while|meanwhile/i.test(raw)){
  result.totalMinutes={value:result.prepMinutes.value+result.cookMinutes.value,origin:'derived',evidence:raw.slice(0,500)};
 }
 const total=result.totalMinutes.value;
 if(total!==null&&total<Math.max(result.prepMinutes.value??0,result.cookMinutes.value??0))result.totalMinutes=unknown();
 result.allergenHints=[...new Set<string>((v.allergenHints as unknown[]).filter((x):x is string=>typeof x==='string'&&allergens.includes(x)))];
 return result;
}
export function construct(value:Extraction,raw:string,polished=false):Extraction|null {
 const copy=structuredClone(value);
 if(copy.metadata){const m=metadata(raw,copy.metadata,polished);if(!m)return null;copy.metadata=m;}
 // Recover explicit measured ingredient facts already present in this
 // component's structured method; never invent an ingredient or sum quantities.
 for(const part of copy.components){
  const quantity='(?:\\d+(?:[./]\\d+)?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|quarter|half)';
  const unit='(?:(?:tablespoons?|tbsp|teaspoons?|tsp|cups?|cloves?|oz|ounces?|g|grams?|kg|ml|lb|pounds?)\\s+)?';
  const word='(?!(?:and|or|until|then|with|to|for|add|cook|boil|mix|blend|minutes?|hours?|servings?|people)\\b)[a-z]+';
  const pattern=new RegExp(`\\b${quantity}\\s+${unit}${word}(?:\\s+${word}){0,2}`,'gi');
  for(const step of part.steps)for(const match of step.matchAll(pattern)){
   const line=match[0].trim();if(!grounded(line,raw,'ingredient'))continue;
   const identity=tokens(line).filter(w=>!/^n\d/.test(w)&&!['cup','tbsp','tsp','clove','oz','g','kg','ml','lb'].includes(w));
   const existing=part.ingredients.findIndex(i=>identity.every(w=>tokens(i).includes(w)));
   if(existing<0)part.ingredients.push(line);
   else if(!tokens(part.ingredients[existing]).some(w=>/^n\d/.test(w)))part.ingredients[existing]=line;
  }
 }
 const ordered:number[]=[],pending=new Set(copy.components.map((_,i)=>i));
 while(pending.size){
  const ready=[...pending].find(i=>{
   const a=copy.components[i].after??[];
   return a.length<=20&&a.every(n=>Number.isInteger(n)&&n>=0&&n<copy.components.length&&n!==i&&ordered.includes(n));
  });
  if(ready===undefined)return null;
  pending.delete(ready);ordered.push(ready);
 }
 copy.components=ordered.map(i=>{
  const p=copy.components[i];const seen=new Set<string>();
  // Do not sum or merge separately measured allocations. Only exact unmeasured
  // duplicates within one component are mechanical repetition.
  p.ingredients=p.ingredients.filter(line=>{if(tokens(line).some(w=>/^n\d/.test(w)))return true;const k=normalize(line);if(seen.has(k))return false;seen.add(k);return true;});
  p.after=[];return p;
 });
 return copy;
}
