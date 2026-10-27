import { fixture } from './social-harness.mjs';
import { randomUUID } from 'node:crypto';
const {db,users,check,rejects,finish}=await fixture();
const call=async(u=users[0])=>(await db.query('select api.reserve_recipe_import($1,$2) v',[u.user,u.session])).rows[0].v;
for(const role of ['anon','authenticated']){await db.exec(`set role ${role}`);await rejects(()=>call());await db.exec('reset role');}
await db.exec('set role service_role');await rejects(()=>call({...users[0],session:users[1].session}));
check(await call(),'first');check(await call(),'second');check(await call(),'third');check(!await call(),'brief burst guard');
for(let i=0;i<30;i++){
 await db.exec("reset role;update staygrubby.recipe_import_usage set attempts=0 where bucket like '%-minute';set role service_role");
 check(await call(),'legitimate later requests have no daily allowance');
}
await db.exec('reset role');
await db.query("insert into staygrubby.recipe_import_usage(bucket,window_start,attempts,successes) values('global-month',date_trunc('month',now()),999999,0) on conflict(bucket,window_start) do update set attempts=999999");
await db.query("insert into staygrubby.recipe_import_usage(bucket,window_start,account_id,attempts,successes) values($1,date_trunc('day',now()),$2,999999,999999) on conflict(bucket,window_start) do update set attempts=999999,successes=999999",[users[0].id+'-day',users[0].id]);
await db.exec("update staygrubby.recipe_import_usage set attempts=0 where bucket like '%-minute';set role service_role");check(await call(),'old daily/monthly/success counters cannot disable cloud');
check((await db.query('select api.begin_recipe_import($1,$2,$3) v',[users[0].user,users[0].session,randomUUID()])).rows[0].v==='allowed','transition wrapper has no daily cap');
await db.exec('reset role');check((await db.query('select count(*)::int n from staygrubby.recipe_import_reservations')).rows[0].n===0,'no success reservations created');
for(const table of ['recipe_import_usage','recipe_import_reservations']){
 check((await db.query('select relrowsecurity v from pg_class where oid=$1::regclass',['staygrubby.'+table])).rows[0].v,'RLS retained');
 check(!(await db.query("select has_table_privilege('authenticated',$1,'SELECT') v",['staygrubby.'+table])).rows[0].v,'private bookkeeping');
}
await finish();
