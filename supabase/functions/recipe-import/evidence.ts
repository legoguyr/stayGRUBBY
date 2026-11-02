import { styleText, heatAlternative, broilerClause } from './style.ts';
// Bounded lexical normalization, not culinary inference or AI recipe math.
// Keep Swift RecipeSourceEvidence behavior aligned with these focused contract fixtures.
const aliases:Record<string,string>={"tablespoon": "tbsp", "tablespoons": "tbsp", "tbsp": "tbsp", "tbs": "tbsp", "teaspoon": "tsp", "teaspoons": "tsp", "tsp": "tsp", "cup": "cup", "cups": "cup", "oz": "oz", "ounce": "oz", "ounces": "oz", "lb": "lb", "lbs": "lb", "pound": "lb", "pounds": "lb", "g": "g", "gram": "g", "grams": "g", "kg": "kg", "kilogram": "kg", "kilograms": "kg", "ml": "ml", "milliliter": "ml", "milliliters": "ml", "millilitre": "ml", "millilitres": "ml", "l": "l", "liter": "l", "liters": "l", "litre": "l", "litres": "l", "clove": "clove", "cloves": "clove", "minute": "min", "minutes": "min", "min": "min", "mins": "min", "hour": "hour", "hours": "hour", "hr": "hour", "hrs": "hour", "pinch": "pinch", "pinches": "pinch", "fahrenheit": "f", "celsius": "c", "salted": "salt", "blanche": "blanch", "blanched": "blanch", "blanching": "blanch", "boiling": "boil", "boiled": "boil", "cooking": "cook", "cooked": "cook", "baking": "bake", "baked": "bake", "blending": "blend", "blended": "blend", "mixing": "mix", "mixed": "mix", "crispy": "crisp", "till": "until"};
const numbers:Record<string,string>={"one": "1", "two": "2", "three": "3", "four": "4", "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10", "eleven": "11", "twelve": "12"};
const stops=new Set(["a", "an", "the", "of", "to", "with", "in", "into", "on", "it", "its", "is", "are", "be", "by", "for", "then", "and", "some", "about", "this", "that", "your", "as"]);
const preparation=new Set(["cubed", "cold", "fresh", "minced", "chopped", "grated", "peeled", "trimmed", "softened", "finely", "roughly", "small", "large"]);
const units=new Set(["tbsp", "tsp", "cup", "oz", "lb", "g", "kg", "ml", "l", "clove", "min", "hour", "f", "c"]);

function rational(text:string):string {
 const m=text.match(/^(?:(\d+)\s+)?(\d+)\/(\d+)$/);let n:number,d:number;
 if(m){d=Number(m[3]);n=Number(m[2])+Number(m[1]??0)*d;}
 else if(text.includes('.')){const [a,b]=text.split('.');d=10**b.length;n=Number(a)*d+Number(b);}
 else{n=Number(text);d=1;}
 if(!Number.isSafeInteger(n)||!Number.isSafeInteger(d)||d<=0||n>1e9||d>1e6)return text;
 let a=n,b=d;while(b){[a,b]=[b,a%b];}return `n${n/(a||1)}/${d/(a||1)}`;
}
export function tokens(input:string):string[] {
 let text=input.toLowerCase().replace(/\bdegrees?\s+(?:fahrenheit|f)\b/g,'f').replace(/\bdegrees?\s+(?:celsius|c)\b/g,'c').replace(/¼/g,' 1/4 ').replace(/½/g,' 1/2 ').replace(/¾/g,' 3/4 ')
 .replace(/\b(?:a |one )?quarter\b/g,'1/4').replace(/\b(?:a |one )?half\b/g,'1/2');
 text=text.replace(/\b(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b/g,v=>numbers[v]);
 text=text.replace(/\b(\d+) and (?:a )?(1\/2|1\/4)\b/g,'$1 $2');
 return (text.match(/\d+\s+\d+\/\d+|\d+(?:\/\d+|\.\d+)?|[a-z]+/g)??[])
 .map(v=>/^\d/.test(v)?rational(v):aliases[v]??v).filter(v=>!stops.has(v));
}
function contains(source:string[],value:string[]):boolean {return value.length>0 && (` ${source.join(' ')} `).includes(` ${value.join(' ')} `);}
// Informal "heavy 1 cup cream" -> "1 cup heavy cream". Move only ONE
// unchanged amount/unit block inside ONE source phrase, preserving every other
// word's order. Conjunction/clause boundaries must survive stop-word removal:
// "cream and 1 cup milk" is never evidence for a cream/milk ingredient amount.
function quantityFirstIngredient(output:string[],raw:string,polished:boolean):boolean {
 if(!polished||!/^n\d/.test(output[0])||output.slice(1).some(w=>/^n\d/.test(w)))return false;
 const size=units.has(output[1])?2:1,quantity=output.slice(0,size),identity=output.slice(size);
 if(!identity.length)return false;
 const phrases=raw.split(/[,;:\n\\()]|(?<!\d)\.|\.(?!\d)|\b(?:and|or|with|then|until|but)\b/i);
 for(const phrase of phrases){
  const source=editorialTokens(phrase,raw,'ingredient',true);
  for(let i=0;i<=source.length-output.length;i++){
   const span=source.slice(i,i+output.length);
   for(let n=0;n<=span.length-size;n++)if(span.slice(n,n+size).join(' ')===quantity.join(' ')&&[...span.slice(0,n),...span.slice(n+size)].join(' ')===identity.join(' '))return true;
  }
 }
 return false;
}
function preparedIngredient(value:string,raw:string):boolean {
 const comma=value.indexOf(',');if(comma<0)return false;
 const base=value.slice(0,comma).trim(),detail=value.slice(comma+1).trim();
 if(groundingIssue(base,raw,'ingredient',true))return false;
 const identity=editorialTokens(base,raw,'step',true).filter(w=>!/^n\d/.test(w)&&!units.has(w));
 if(!identity.length)return false;
 if(/^for serving$/i.test(detail))return raw.split(/[.!?;\n]/).some(s=>/\bserve\b/i.test(s)&&contains(editorialTokens(s,raw,'step',true),identity));
 const prep=editorialTokens(detail,raw,'step',true),origins=raw.split(/[.!?;,\n]/).map(s=>editorialTokens(s,raw,'step',true));
 if(!['dice','chop','slice','mince','grate','peel'].includes(prep[0]))return false;
 for(let i=0;i<identity.length;i++){
  const name=identity.slice(i);
  if(origins.some(origin=>contains(origin,[prep[0],...name,...prep.slice(1)])||contains(origin,[...name,...prep])))return true;
 }
 // One preparation verb may govern a comma-separated ingredient list, ending
 // before the next action. Never borrow a different ingredient's descriptor.
 if(prep.length===1)for(const m of raw.matchAll(/\b(diced?|chopped?|sliced?|minced?|grated?|peeled?)\s+([^.;\n]{1,180})/gi)){
  if(editorialTokens(m[1],raw,'step',true)[0]!==prep[0])continue;
  const list=m[2].split(/\b(?:chop(?:ped)?|dice[ds]?|slice[ds]?|mince[ds]?|grate[ds]?|peel(?:ed)?|add|cook|saute|sauté|heat|serve|season|mix)\b/i)[0];
  if(list.split(/,|\band\b/i).some(s=>editorialTokens(s,raw,'step',true).join(' ')===identity.join(' ')))return true;
 }
 return false;
}
export type GroundingIssue = 'invalid_quantity'|'source_empty'|'source_number'|'source_word'|'quantity_unit_pair'|'preparation_binding'|'metadata_phrase'|'ingredient_phrase';
export function groundingIssue(value:string,raw:string,kind:'metadata'|'title'|'ingredient'|'step',polished=false):GroundingIssue|null {
 if(kind==='ingredient'&&(/^\s*-\s*\d/.test(value)||/\b\d+\s*\/\s*0\b/.test(value)))return 'invalid_quantity';
 if(polished&&kind==='ingredient'&&preparedIngredient(value,raw))return null;
 if(polished&&kind==='step'&&/\b(?:boiler|broiler|broil(?:ed|ing)?)\b/i.test(value)&&/\b(?:alternatively|or|optional)\b/i.test(broilerClause(raw)??'')&&!/\b(?:alternatively|or|optional)\b/i.test(value))return 'source_word';
 const source=editorialTokens(raw,raw,kind,polished),output=editorialTokens(value,raw,kind,polished);if(!output.length)return 'source_empty';
 if(contains(source,output))return null;
 if(kind==='ingredient'&&quantityFirstIngredient(output,raw,polished))return null;
 if(polished&&kind==='ingredient')for(const m of raw.matchAll(/\b([a-z]+)\s*\(i (?:like|prefer|use) ((?:[a-z]+ ){0,3}\1)(?: for this)?\)/gi)){
  // Add evidence for this adjacent preference; retain the original base-name
  // evidence too. Do not make a preference erase legitimate generic wording.
  const expanded=raw.slice(0,m.index)+m[2]+raw.slice(m.index+m[0].length);
  if(contains(editorialTokens(expanded,raw,kind,true),output))return null;
 }
 const absent=output.filter(v=>!source.includes(v));
 if(absent.length)return absent.some(v=>/^n\d/.test(v))?'source_number':'source_word';
 for(let i=0;i<output.length;i++)if(output[i].startsWith('n')&&/^n\d/.test(output[i])&&units.has(output[i+1])&&!contains(source,output.slice(i,i+2)))return 'quantity_unit_pair';
 if(kind==='metadata')return 'metadata_phrase';
 if(kind==='title'||kind==='step')return null;
 if(polished&&kind==='ingredient'&&heatAlternative(raw)&&output.includes('chile')&&!output.some(t=>/^n\d/.test(t))&&output.every(t=>['chile','oil','or','optional'].includes(t)))return null;
 // A descriptor cannot be borrowed from another ingredient in the source.
 for(let i=0;i<output.length;i++)if(preparation.has(output[i])){
  const neighbors=(words:string[],at:number)=>{
   const useful=(w:string)=>!preparation.has(w)&&!units.has(w)&&!/^n\d/.test(w);
   const after=words.slice(at+1).find(useful),before=words.slice(0,at).reverse().find(useful);
   return [after,before].filter((v):v is string=>!!v);
  };
  const target=neighbors(output,i)[0];
  if(target&&!source.some((word,n)=>word===output[i]&&neighbors(source,n)[0]===target))return 'preparation_binding';
 }
 const core=output.filter(v=>!preparation.has(v));const origin=source.filter(v=>!preparation.has(v));
 if(contains(origin,core))return null;
 // Natural quantity-at-end notation may be normalized to quantity first.
 if(/^n\d/.test(core[0])&&units.has(core[1])&&contains(origin,[...core.slice(2),...core.slice(0,2)]))return null;
 return 'ingredient_phrase';
}
export function grounded(value:string,raw:string,kind:'metadata'|'title'|'ingredient'|'step',polished=false):boolean {return groundingIssue(value,raw,kind,polished)===null;}
// Reconciliation may restore original wording, never invent or move a numeric fact.
export function numericEvidence(value:string,raw:string):boolean {
 const source=tokens(raw),output=tokens(value);
 return output.every((v,i)=>!/^n\d/.test(v)||(source.includes(v)&&(!units.has(output[i+1])||contains(source,output.slice(i,i+2)))));
}
export function factualWords(value:string):string[] {return tokens(value).filter(v=>!/^n\d/.test(v)&&!units.has(v));}

// A closed, context-dependent editorial vocabulary, not a cooking thesaurus.
// No ingredient identity, number, unit, variety or doneness word is discarded.
export function editorialTokens(value:string,raw:string,kind:string,polished=false):string[] {
 let text=polished?styleText(value,raw,kind):value.toLowerCase();
 if(kind==='step') {
  text=text.replace(/\b(?:put|cook|cooking)\s+(?:it\s+)?(?:in\s+)?(?:the\s+)?oven\b/g,'bake')
   .replace(/\bmove (?:it )?around\b/g,'stir').replace(/\bcool (?:it )?down\b/g,'cool')
   .replace(/\bcooled\b/g,'cool').replace(/\bshaving\b/g,'shave');
  if(/\bmix(?:ing|ed)?\b/i.test(raw))text=text.replace(/\btoss(?:ing|ed)?\b/g,'mix');
  if(/\b(?:add|put)\b/i.test(raw))text=text.replace(/\b(?:transfer|place)\b/g,'add');
  if(/\bsqueeze out (?:all )?(?:the )?water\b/i.test(raw))text=text.replace(/\bdrain\b/g,'').replace(/\bas much water as possible\b/g,'water');
  text=text.replace(/\bheat up\b/g,'heat').replace(/\bsqueeze out (?:all )?(?:the )?water\b/g,'squeeze water').replace(/\b(?:until|add)\b/g,'');
 }
 text=text.replace(/\b(?:if (?:you )?(?:want(?: spice)?|desired)|optional)\b/g,'optional')
  .replace(/\bapproximately\b/g,'about');
 const result=tokens(text);
 if(!polished)return result;
 // Match a singular reference only to its actual plural in this source. Never
 // erase a noun or borrow an ingredient identity from a culinary dictionary.
 const actual=tokens(raw);
 return result.map(w=>w.length>=3&&w.endsWith('s')&&actual.includes(w.slice(0,-1))?w.slice(0,-1):w.length>=3&&!actual.includes(w)&&actual.includes(w+'s')?w+'s':w);
}
