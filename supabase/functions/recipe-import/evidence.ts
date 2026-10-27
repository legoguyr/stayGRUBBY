// Bounded lexical normalization, not culinary inference or AI recipe math.
// Keep Swift RecipeSourceEvidence behavior aligned with these focused contract fixtures.
const aliases:Record<string,string>={"tablespoon": "tbsp", "tablespoons": "tbsp", "tbsp": "tbsp", "tbs": "tbsp", "teaspoon": "tsp", "teaspoons": "tsp", "tsp": "tsp", "cup": "cup", "cups": "cup", "oz": "oz", "ounce": "oz", "ounces": "oz", "lb": "lb", "lbs": "lb", "pound": "lb", "pounds": "lb", "g": "g", "gram": "g", "grams": "g", "kg": "kg", "kilogram": "kg", "kilograms": "kg", "ml": "ml", "milliliter": "ml", "milliliters": "ml", "millilitre": "ml", "millilitres": "ml", "l": "l", "liter": "l", "liters": "l", "litre": "l", "litres": "l", "clove": "clove", "cloves": "clove", "minute": "min", "minutes": "min", "min": "min", "mins": "min", "hour": "hour", "hours": "hour", "hr": "hour", "hrs": "hour", "pinch": "pinch", "pinches": "pinch", "salted": "salt", "blanche": "blanch", "blanched": "blanch", "blanching": "blanch", "boiling": "boil", "boiled": "boil", "cooking": "cook", "cooked": "cook", "baking": "bake", "baked": "bake", "blending": "blend", "blended": "blend", "mixing": "mix", "mixed": "mix", "crispy": "crisp", "till": "until"};
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
 let text=input.toLowerCase().replace(/¼/g,' 1/4 ').replace(/½/g,' 1/2 ').replace(/¾/g,' 3/4 ')
 .replace(/\b(?:a |one )?quarter\b/g,'1/4').replace(/\b(?:a |one )?half\b/g,'1/2');
 text=text.replace(/\b(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b/g,v=>numbers[v]);
 text=text.replace(/\b(\d+) and (?:a )?(1\/2|1\/4)\b/g,'$1 $2');
 return (text.match(/\d+\s+\d+\/\d+|\d+(?:\/\d+|\.\d+)?|[a-z]+/g)??[])
 .map(v=>/^\d/.test(v)?rational(v):aliases[v]??v).filter(v=>!stops.has(v));
}
function contains(source:string[],value:string[]):boolean {return value.length>0 && (` ${source.join(' ')} `).includes(` ${value.join(' ')} `);}
export function grounded(value:string,raw:string,kind:'metadata'|'title'|'ingredient'|'step'):boolean {
 const source=tokens(raw),output=tokens(value);if(!output.length)return false;
 if(contains(source,output))return true;
 if(!output.every(v=>source.includes(v)))return false; // Never guess a named ingredient or new fact.
 for(let i=0;i<output.length;i++)if(output[i].startsWith('n')&&/^n\d/.test(output[i])&&units.has(output[i+1])&&!contains(source,output.slice(i,i+2)))return false;
 if(kind==='metadata')return false;
 if(kind==='title'||kind==='step')return true;
 const core=output.filter(v=>!preparation.has(v));const origin=source.filter(v=>!preparation.has(v));
 if(contains(origin,core))return true;
 // Natural quantity-at-end notation may be normalized to quantity first.
 if(/^n\d/.test(core[0])&&units.has(core[1]))return contains(origin,[...core.slice(2),...core.slice(0,2)]);
 return false;
}
