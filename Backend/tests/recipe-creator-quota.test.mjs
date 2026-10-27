import { fixture } from './social-harness.mjs';
import { randomUUID } from 'node:crypto';
const {db,users,check,rejects,finish}=await fixture();
const begin=async(u,id=randomUUID())=>(await db.query('select api.begin_recipe_import($1,$2,$3) v',[u.user,u.session,id])).rows[0].v;
const end=async(u,id,ok)=>(await db.query('select api.finish_recipe_import($1,$2,$3,$4) v',[u.user,u.session,id,ok])).rows[0].v;
const resetMinute=async()=>{await db.exec("reset role;update staygrubby.recipe_import_usage set attempts=0 where bucket like '%-minute';set role service_role");};
for(const role of ['anon','authenticated']){await db.exec(`set role ${role}`);await rejects(()=>begin(users[0]));await rejects(()=>end(users[0],randomUUID(),true));await db.exec('reset role');}
await db.exec('set role service_role');
await rejects(()=>begin({...users[0],session:users[1].session}));
const failed=randomUUID();check(await begin(users[0],failed)==='allowed','failed attempt reserved');check(await end(users[0],failed,false),'failure released');check(!await end(users[0],failed,true),'failed receipt cannot become success');
for(let i=0;i<5;i++){
 await resetMinute();const id=randomUUID();check(await begin(users[0],id)==='allowed','successful slot reserved');check(await end(users[0],id,true),'validated success charged');check(await end(users[0],id,true),'success retry idempotent');
}
await resetMinute();check(await begin(users[0])==='daily_limit','sixth successful import denied across sessions/devices');
await db.exec('reset role');check((await db.query('select successes from staygrubby.recipe_import_usage where account_id=$1 and bucket like $2',[users[0].id,'%-day'])).rows[0].successes===5,'exactly five successes, failure not charged');
await db.exec('set role service_role');
const ids=[];for(let i=0;i<3;i++){const id=randomUUID();ids.push(id);check(await begin(users[1],id)==='allowed','pending seat');}
await resetMinute();for(let i=0;i<2;i++){const id=randomUUID();ids.push(id);check(await begin(users[1],id)==='allowed','fifth pending seat');}
await resetMinute();check(await begin(users[1])==='attempt_limit','in-flight seats cannot overshoot five');
check(await end(users[1],ids[0],false),'failed seat returns');await resetMinute();check(await begin(users[1])==='allowed','released seat reused');
await db.exec('reset role');await db.query("update staygrubby.recipe_import_reservations set expires_at=now()-interval '1 second' where id=$1",[ids[1]]);await db.exec('set role service_role');check(!await end(users[1],ids[1],true),'expired model cannot charge/deliver');
await db.exec('reset role');for(const table of ['recipe_import_usage','recipe_import_reservations']){check((await db.query('select relrowsecurity v from pg_class where oid=$1::regclass',['staygrubby.'+table])).rows[0].v,'RLS');check(!(await db.query("select has_table_privilege('authenticated',$1,'SELECT') v",['staygrubby.'+table])).rows[0].v,'no direct user access');}
await db.query('delete from staygrubby.accounts where id=$1',[users[1].id]);check((await db.query('select count(*)::int n from staygrubby.recipe_import_reservations where account_id=$1',[users[1].id])).rows[0].n===0,'account deletion cascades receipts');
await finish();
