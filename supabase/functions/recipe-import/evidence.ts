import { styleText, heatAlternative } from './style.ts';
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
export type GroundingIssue = 'invalid_quantity'|'source_empty'|'source_number'|'source_word'|'quantity_unit_pair'|'preparation_binding'|'metadata_phrase'|'ingredient_phrase';
export function groundingIssue(value:string,raw:string,kind:'metadata'|'title'|'ingredient'|'step',polished=false):GroundingIssue|null {
 if(kind==='ingredient'&&(/^\s*-\s*\d/.test(value)||/\b\d+\s*\/\s*0\b/.test(value)))return 'invalid_quantity';
 const source=editorialTokens(raw,raw,kind,polished),output=editorialTokens(value,raw,kind,polished);if(!output.length)return 'source_empty';
 if(contains(source,output))return null;
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
 return tokens(text);
}
