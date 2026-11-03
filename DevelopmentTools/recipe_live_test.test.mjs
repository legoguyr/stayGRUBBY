import {test} from 'node:test';
import assert from 'node:assert/strict';
import {reserve,approval,finalV25} from './recipe_live_test.mjs';
test('the prior owner call cannot disappear and six remains the hard maximum',()=>{
 assert.throws(()=>reserve({approval,attempts:[]},'french','hash'));
 let b={approval,attempts:[{id:'owner'}]};for(let i=1;i<6;i++)b=reserve(b,'fixture','hash');
 assert.equal(b.attempts.length,6);assert.equal(b.attempts[0].id,'owner');assert.throws(()=>reserve(b,'seventh','hash'));
});
test('stopped or different authorizations cannot spend calls',()=>{for(const b of [{approval,attempts:[{}],stopped:'quota'},{approval:'other',attempts:[{}]}])assert.throws(()=>reserve(b,'fixture','hash'));});
test('new explicit three-call grant is separate and each canonical fixture is allowed once',()=>{
 let b={approval:finalV25.approval,attempts:[]};
 b=reserve(b,'french','hash',finalV25);assert.throws(()=>reserve(b,'french','hash',finalV25));
 b=reserve(b,'shakshuka','hash',finalV25);b=reserve(b,'kale','hash',finalV25);
 assert.equal(b.attempts.length,3);assert.throws(()=>reserve(b,'fourth','hash',finalV25));
 assert.throws(()=>reserve({approval,attempts:Array(6).fill({})},'french','hash',finalV25));
 assert.throws(()=>reserve({approval:finalV25.approval,attempts:[]},'other','hash',finalV25));
});
