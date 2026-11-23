import assert from'node:assert/strict';import{readFile}from'node:fs/promises';import{fixture}from'./social-harness.mjs';
const{db,users,actor,rpc,check,rejects,finish}=await fixture();
const me=()=>rpc('staff_status','me');
try{
 await actor(0);check(JSON.stringify(await me())==='{"role":null}','Ordinary active account receives exact null response');
 await db.exec('reset role');await db.query("insert into staygrubby.moderation_reviewers(account_id,role) values($1,'admin'),($2,'moderator')",[users[1].id,users[2].id]);
 await actor(1);assert.deepEqual(await me(),{role:'admin'});check(true,'Admin receives only own role');
 await actor(2);assert.deepEqual(await me(),{role:'moderator'});check(true,'Moderator receives only own role');
 await actor(0);check((await me()).role===null,'Other staff membership never affects ordinary caller');
 await db.exec('reset role');await db.exec("insert into staygrubby.feature_flags(key,enabled) values('staff_moderation',true),('fixture_flag',true)");
 await actor(0);check(!(await rpc('feature_flags','get')).enabled.includes('staff_moderation'),'Ordinary users never receive the staff gate');
 check((await rpc('feature_flags','get')).enabled.includes('fixture_flag'),'Unrelated enabled flags remain unchanged');
 await actor(1);check((await rpc('feature_flags','get')).enabled.includes('staff_moderation'),'Admin receives enabled staff gate');
 await actor(2);check((await rpc('feature_flags','get')).enabled.includes('staff_moderation'),'Moderator receives enabled staff gate');
 await db.exec('reset role');await db.exec("update staygrubby.feature_flags set enabled=false where key='staff_moderation'");
 await actor(1);check(!(await rpc('feature_flags','get')).enabled.includes('staff_moderation'),'Disabled staff gate remains off');
 await db.exec('reset role');await db.exec("update staygrubby.feature_flags set enabled=true where key='staff_moderation'");

 await actor(0);
 for(const payload of [{accountID:users[1].id},[],null,{role:'admin'}])await rejects(()=>rpc('staff_status','me',payload),'22023');
 await rejects(()=>rpc('staff_status','list'),'22023');await rejects(()=>rpc('staff_status',null),'22023');
 await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:users[0].user,session_id:users[0].session,user_metadata:{role:'admin'},app_metadata:{role:'admin'}})]);
 check((await me()).role===null,'JWT metadata does not grant staff authority');
 await db.exec('reset role');await db.query('delete from staygrubby.moderation_reviewers where account_id=$1',[users[2].id]);
 await actor(2);check((await me()).role===null,'Revoked moderator returns null immediately');
 check(!(await rpc('feature_flags','get')).enabled.includes('staff_moderation'),'Revoked membership loses flag delivery');
 await actor(1);await rpc('social_identity','save',{username:'grubwithguy',displayName:'Synthetic owner'});
 await db.exec('reset role');
 const activation=await readFile(new URL('../../DevelopmentTools/operations/enable_staff_interface.sql',import.meta.url),'utf8');
 await rejects(()=>db.exec(activation),'PT409');await db.exec('rollback');
 await db.query("select set_config('staygrubby.approved_owner_id',$1,false)",[users[1].id]);await db.exec(activation);
 await actor(1);check((await rpc('feature_flags','get')).enabled.includes('staff_moderation'),'Pinned sole-owner activation template succeeds');
 await actor(0);check(!(await rpc('feature_flags','get')).enabled.includes('staff_moderation'),'Activation never delivers staff gate to ordinary users');
 await db.exec('reset role');const before=(await db.query('select count(*)::int n from staygrubby.staff_role_audit')).rows[0].n;
 await actor(1);await db.exec('begin read only');for(let i=0;i<5;i++)await me();await db.exec('commit;reset role');
 check((await db.query('select count(*)::int n from staygrubby.staff_role_audit')).rows[0].n===before,'Status works in read-only transaction and creates no audit');
 for(const role of ['anon','service_role']){await db.exec('set role '+role);await rejects(()=>me());await db.exec('reset role');}
 await actor(3);await db.query("select set_config('request.jwt.claims','{}',false)");await rejects(()=>me());
 await actor(3);await db.exec('reset role');await db.query('delete from auth.sessions where id=$1',[users[3].session]);await actor(3);await rejects(()=>me());
 await db.exec('reset role');await db.query("update staygrubby.accounts set status='deleting' where id=$1",[users[1].id]);await actor(1);await rejects(()=>me());
 await db.exec('reset role');check((await db.query("select bool_and(provolatile='s') ok from pg_proc where oid in('api.staff_status(text,jsonb)'::regprocedure,'staygrubby.staff_status(text,jsonb)'::regprocedure)")).rows[0].ok,'Both projections are stable');
 await finish();
}catch(e){await db.close();throw e;}
