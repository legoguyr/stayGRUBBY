import {randomUUID} from 'node:crypto';import{fixture}from'./social-harness.mjs';
const{db,users,actor,rpc,check,rejects,finish}=await fixture();
const change=(i,role,expected,op=randomUUID())=>rpc('staff_roles',role?'assign':'remove',{accountID:users[i].id,role,expectedRole:expected,reason:'Disposable test',operationID:op});
try{
 for(let i=0;i<4;i++){await actor(i);await rpc('social_identity','save',{username:'roles_'+i,displayName:'Fixture',discoverable:true});}
 await rejects(()=>rpc('staff_roles','list'));
 await rejects(()=>change(0,'admin',null));
 await db.exec('reset role');await db.query("insert into staygrubby.moderation_reviewers(account_id,role) values($1,'admin')",[users[0].id]);
 check((await db.query('select count(*)::int n from staygrubby.staff_role_audit')).rows[0].n===1,'Operator bootstrap is audited');
 await actor(0);const op=randomUUID();await change(1,'moderator',null,op);await change(1,'moderator',null,op);
 await db.exec('reset role');check((await db.query('select count(*)::int n from staygrubby.staff_role_audit')).rows[0].n===2,'Lost response retry writes one audit');
 await actor(0);await rejects(()=>change(2,'moderator',null,op),'PT409');
 await rejects(()=>change(0,'moderator','admin'),'PT409');await rejects(()=>change(0,null,'admin'),'PT409');
 await actor(1);await rejects(()=>change(1,'admin','moderator'));await rejects(()=>rpc('staff_roles','list'));
 check(Array.isArray((await rpc('moderation_review','queue')).reports),'Moderator can use existing review API');
 await rejects(()=>db.query("update staygrubby.moderation_reviewers set role='admin'"));
 await actor(0);await change(2,'admin',null);await change(0,'moderator','admin');
 await actor(2);await change(0,'admin','moderator');await change(2,null,'admin');
 await actor(2);await rejects(()=>rpc('moderation_review','queue'));
 await actor(0);await rejects(()=>change(1,null,null),'PT409');await change(1,null,'moderator');
 await actor(1);await rejects(()=>rpc('moderation_review','queue'));
 // Admin is not exempt from self-target report exclusion.
 await rpc('social_report','report',{targetType:'profile',targetID:users[0].id,reason:'other'});
 await actor(0);check((await rpc('moderation_review','queue')).reports.length===0,'Admin cannot review own profile reports');
 await db.exec('reset role');await rejects(()=>db.query('delete from staygrubby.moderation_reviewers where account_id=$1',[users[0].id]),'PT409');
 await actor(0);await db.query('select api.begin_account_deletion()');await db.exec('reset role;set role service_role');
 await db.query("select api.advance_account_deletion($1,'apple_revoked')",[users[0].user]);await db.query("select api.advance_account_deletion($1,'storage_cleared')",[users[0].user]);
 await db.query('select api.erase_account_data($1)',[users[0].user]);await db.query('select api.erase_account_data($1)',[users[0].user]);
 await db.exec('reset role');check((await db.query('select count(*)::int n from staygrubby.moderation_reviewers')).rows[0].n===0,'Deliberate last-admin erasure and retry succeed');
 check((await db.query('select count(*)::int n from staygrubby.staff_role_audit where subject_id=$1 or actor_id=$1',[users[0].id])).rows[0].n===0,'Erased account audit references are cleared');
 check((await db.query("select count(*)::int n from staygrubby.staff_role_audit where previous_role='admin' and new_role is null")).rows[0].n>=1,'Erasure leaves nonpersonal audit outcome');
 await db.query("insert into staygrubby.moderation_reviewers(account_id,role) values($1,'admin')",[users[3].id]);
 await actor(3);check((await rpc('staff_roles','list')).staff.length===1,'Authenticated operator recovery can enroll an existing successor');
 await finish();
}catch(e){await db.close();throw e;}
