import{fixture}from'./social-harness.mjs';import{readFile}from'node:fs/promises';
const{db,actor,check,rejects,finish}=await fixture();
try{
 await db.exec(`create schema vault;create table vault.decrypted_secrets(name text,decrypted_secret text);create schema net;create table net.http_request_queue(url text,body jsonb);
 create function net.http_post(url text,body jsonb,timeout_milliseconds integer) returns bigint language plpgsql as $$begin insert into net.http_request_queue values(url,body);return 1;end$$;`);
 let sql=await readFile(new URL('../../DevelopmentTools/operations/activate_capacity_email.sql',import.meta.url),'utf8');sql=sql.replace('create extension if not exists pg_net;','').replace(/^select cron.schedule.*$/m,'');await db.exec(sql);
 await rejects(()=>db.query('select operations.deliver_capacity_heartbeat()'),'55000');
 await db.exec("insert into vault.decrypted_secrets values('staygrubby_capacity_ping','https://hc-ping.com/00000000-0000-0000-0000-000000000000');insert into operations.capacity_state(singleton,sampled_at,stats_epoch,signals,metrics) values(true,now(),now(),'{}','{}') on conflict(singleton) do update set sampled_at=now(),signals='{}'");
 await db.query('select operations.deliver_capacity_heartbeat()');await db.query('select operations.deliver_capacity_heartbeat()');
 check((await db.query('select count(*)::int n from net.http_request_queue')).rows[0].n===1,'Unprocessed ping is coalesced');
 check((await db.query("select bool_and(body='{}'::jsonb and url not like '%/fail') yes from net.http_request_queue")).rows[0].yes,'Healthy ping has no content or identifiers');
 await db.exec("delete from net.http_request_queue;update operations.capacity_state set sampled_at=now()-interval '20 minutes'");await db.query('select operations.deliver_capacity_heartbeat()');
 check((await db.query("select bool_and(url like '%/fail') yes from net.http_request_queue")).rows[0].yes,'Stale sample sends failure');
 await db.exec("delete from net.http_request_queue;update vault.decrypted_secrets set decrypted_secret='https://other.invalid/'");await rejects(()=>db.query('select operations.deliver_capacity_heartbeat()'),'55000');
 await actor(0);await rejects(()=>db.query('select operations.deliver_capacity_heartbeat()'));
 await finish();
}catch(e){await db.close();throw e;}
