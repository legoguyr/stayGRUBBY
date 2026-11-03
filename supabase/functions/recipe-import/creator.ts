import type {Extraction} from './contract.ts';
import {cuisines,allergens} from './creator-taxonomy.ts';
export {cuisines,allergens};
export type Origin='provided'|'derived'|'estimated'|'unknown';
export type Proposal<T>={value:T|null;origin:Origin;evidence:string|null};
export type CreatorMetadata={yield:Proposal<string>;prepMinutes:Proposal<number>;cookMinutes:Proposal<number>;totalMinutes:Proposal<number>;cuisine:Proposal<string>;allergenHints:string[]};
const unknown=()=>({value:null,origin:'unknown' as Origin,evidence:null});
const optionalText=(v:any,max:number)=>typeof v==='string'&&v.trim()&&[...v].length<=max&&!/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/.test(v)?v:null;
// Optional metadata represents Gemini's editorial judgement, not source proof.
export function metadata(_raw:string,input:any,_polished=false):CreatorMetadata {
 const v=input&&typeof input==='object'&&!Array.isArray(input)?input:{};
 const out:any={};
 for(const key of ['yield','prepMinutes','cookMinutes','totalMinutes','cuisine']){
  const p=v[key];let value=key==='yield'?optionalText(p?.value,100):key==='cuisine'?cuisines.find(c=>typeof p?.value==='string'&&c.toLowerCase()===p.value.toLowerCase())??null:Number.isInteger(p?.value)&&p.value>=0&&p.value<=10080?p.value:null;
  out[key]=value===null?unknown():{value,origin:['provided','derived','estimated'].includes(p?.origin)?p.origin:'estimated',evidence:optionalText(p?.evidence,500)};
 }
 if(out.totalMinutes.value!==null&&out.totalMinutes.value<Math.max(out.prepMinutes.value??0,out.cookMinutes.value??0))out.totalMinutes=unknown();
 out.allergenHints=Array.isArray(v.allergenHints)?[...new Set(v.allergenHints.filter((x:any)=>allergens.includes(x)))].slice(0,9):[];
 return out;
}
export function construct(value:Extraction,_raw='',_polished=false):Extraction {
 const copy=structuredClone(value);
 if(copy.metadata!=null)copy.metadata=metadata('',copy.metadata);else delete copy.metadata;
 copy.description=optionalText(copy.description,1200);
 copy.title=copy.title??null;copy.yield=copy.yield??null;copy.source=copy.source??null;
 // Only topological ordering required by explicit dependencies. Never extract
 // ingredients from methods, repair prose, deduplicate allocations or fact-lock.
 const done:number[]=[];while(done.length<copy.components.length){const i=copy.components.findIndex((p,n)=>!done.includes(n)&&(p.after??[]).every(j=>done.includes(j)));if(i<0)throw Error('invalid_dependencies');done.push(i);}
 copy.components=done.map(i=>({...copy.components[i],title:copy.components[i].title??null,after:[]}));
 return copy;
}
