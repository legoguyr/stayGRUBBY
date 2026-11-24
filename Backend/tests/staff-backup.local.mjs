import pg from 'pg';import{readFile,writeFile,mkdtemp,mkdir,chmod,access}from'node:fs/promises';import{randomBytes,randomUUID,createHash}from'node:crypto';import{spawnSync}from'node:child_process';import assert from'node:assert/strict';
import{backupCrypt}from'../../DevelopmentTools/encrypted_backup.mjs';
const configPath=process.env.SG_LOCAL_STATUS;assert(/^\/private\/tmp\/staygrubby-final-gates-[^/]+\/status[.]json$/.test(configPath??''));
const c=JSON.parse(await readFile(configPath,'utf8'));
assert(new URL(c.API_URL).hostname==='127.0.0.1'&&new URL(c.DB_URL).hostname==='127.0.0.1');
const db=new pg.Client({connectionString:c.DB_URL});await db.connect();let restore;const root=await mkdtemp('/private/tmp/sg-restore-proof-');await chmod(root,0o700);
const bin=process.env.SG_POSTGRES_BIN;assert(bin?.endsWith('/'));
const u=new URL(c.DB_URL),env={PATH:'/usr/bin:/bin',PGHOST:u.hostname,PGPORT:u.port,PGUSER:decodeURIComponent(u.username),PGPASSWORD:decodeURIComponent(u.password),PGDATABASE:'postgres'};
function run(cmd,args,extra={}){const r=spawnSync(cmd,args,{env,encoding:'utf8',maxBuffer:1024*1024,...extra});if(r.status!==0)throw Error(cmd.split('/').at(-1)+' failed: '+r.stderr?.split('\n').filter(x=>/ERROR|error:/.test(x)).slice(0,2).join(' ').replace(/postgres(?:ql)?:\/\/\S+/g,'[redacted]'));}
const call=async(path,key,body,method='POST')=>fetch(c.API_URL+path,{method,headers:{apikey:c.ANON_KEY,Authorization:'Bearer '+key,'Content-Type':'application/json','Content-Profile':'api'},body:body===undefined?undefined:JSON.stringify(body),redirect:'error',signal:AbortSignal.timeout(15000)});
try{
 assert((await db.query("select count(*)::int n from auth.users where email not like '%@example.invalid'")).rows[0].n===0);
 if(!(await db.query("select exists(select 1 from information_schema.columns where table_schema='staygrubby' and table_name='moderation_reviewers' and column_name='role') yes")).rows[0].yes)await db.query(await readFile(new URL('../../supabase/migrations/20261123225337_moderation_staff_roles.sql',import.meta.url),'utf8'));
 const actors=(await db.query("select p.account_id,l.auth_user_id,u.email from staygrubby.profiles p join staygrubby.auth_account_links l on l.account_id=p.account_id join auth.users u on u.id=l.auth_user_id where p.username in ('local_fixture_1','local_fixture_2') order by p.username")).rows;assert.equal(actors.length,2);
 const tokens=[];
 for(const a of actors){
  const password=randomBytes(24).toString('hex');assert((await call('/auth/v1/admin/users/'+a.auth_user_id,c.SERVICE_ROLE_KEY,{password},'PUT')).ok);
  const s=await call('/auth/v1/token?grant_type=password',c.ANON_KEY,{email:a.email,password});assert(s.ok);tokens.push((await s.json()).access_token);
  await db.query("insert into staygrubby.moderation_reviewers(account_id,role) values($1,'admin') on conflict(account_id) do update set role='admin'",[a.account_id]);
 }
 const responses=await Promise.all(actors.map((a,i)=>call('/rest/v1/rpc/staff_roles',tokens[i],{action:'assign',payload:{accountID:a.account_id,role:'moderator',expectedRole:'admin',reason:'Disposable concurrency',operationID:randomUUID()}})));
 assert.deepEqual(responses.map(r=>r.status).sort(),[200,409]);assert.equal((await db.query("select count(*)::int n from staygrubby.moderation_reviewers where role='admin'")).rows[0].n,1);
 console.log('PASS real concurrent admin demotions: one success, one conflict, one admin retained');
 await mkdir(root+'/bundle');await mkdir(root+'/bundle/photos');
 const seed=(await db.query('select bucket_id,name from storage.objects limit 1')).rows[0];assert(seed);
 const seedResponse=await call('/storage/v1/object/authenticated/'+seed.bucket_id+'/'+seed.name,c.SERVICE_ROLE_KEY,undefined,'GET');assert(seedResponse.ok);const seedBytes=Buffer.from(await seedResponse.arrayBuffer());
 for(const bucket of ['cooking-photos','social-photos','profile-photos']){
  const response=await fetch(c.API_URL+'/storage/v1/object/'+bucket+'/'+actors[0].account_id+'/'+randomUUID()+'.jpg',{method:'POST',headers:{apikey:c.ANON_KEY,Authorization:'Bearer '+c.SERVICE_ROLE_KEY,'Content-Type':'image/jpeg'},body:seedBytes,redirect:'error'});assert(response.ok);
 }
 const photos=(await db.query('select bucket_id,name from storage.objects order by bucket_id,name')).rows;
 const manifest=[];
 for(let i=0;i<photos.length;i++){
  const p=photos[i];const r=await call('/storage/v1/object/authenticated/'+p.bucket_id+'/'+p.name,c.SERVICE_ROLE_KEY,undefined,'GET');assert(r.ok);
  const bytes=Buffer.from(await r.arrayBuffer());await writeFile(root+'/bundle/photos/'+i,bytes,{mode:0o600});manifest.push({...p,file:String(i),sha256:createHash('sha256').update(bytes).digest('hex')});
 }
 assert(photos.length>0);await writeFile(root+'/bundle/manifest.json',JSON.stringify(manifest),{mode:0o600});
 run(bin+'pg_dump',['--format=custom','--no-owner','--no-acl','--schema=auth','--schema=staygrubby','--schema=storage','--schema=api','--file='+root+'/bundle/database.dump']);
 run('/usr/bin/tar',['-czf',root+'/backup.tgz','-C',root+'/bundle','.']);await writeFile(root+'/recovery.bin',randomBytes(32),{mode:0o600});
 await backupCrypt('seal',root+'/backup.tgz',root+'/backup.enc',root+'/recovery.bin');await backupCrypt('open',root+'/backup.enc',root+'/restored.tgz',root+'/recovery.bin');
 assert((await readFile(root+'/backup.tgz')).equals(await readFile(root+'/restored.tgz')));
 const corrupt=await readFile(root+'/backup.enc');corrupt[22]^=1;await writeFile(root+'/corrupt.enc',corrupt,{mode:0o600});await assert.rejects(()=>backupCrypt('open',root+'/corrupt.enc',root+'/invalid.tgz',root+'/recovery.bin'));await assert.rejects(()=>access(root+'/invalid.tgz'));
 await mkdir(root+'/restore');run('/usr/bin/tar',['-xzf',root+'/restored.tgz','-C',root+'/restore']);
 const name='sg_restore_'+randomBytes(6).toString('hex');await db.query('create database '+name);restore=new pg.Client({connectionString:c.DB_URL,database:name});await restore.connect();await restore.query('create schema if not exists extensions');
 run(bin+'pg_restore',['--no-owner','--no-acl','--exit-on-error','--dbname='+name,root+'/restore/database.dump']);
 for(const schema of ['staygrubby','auth','storage']){
  const tables=(await db.query("select tablename from pg_tables where schemaname=$1 order by tablename",[schema])).rows;
  for(const{tablename:t}of tables){const sql=`select coalesce(jsonb_agg(v order by v::text),'[]') value from (select to_jsonb(r) v from "${schema}"."${t}" r) x`;assert.deepEqual((await db.query(sql)).rows,(await restore.query(sql)).rows);}
 }
 for(const p of manifest)assert.equal(createHash('sha256').update(await readFile(root+'/restore/photos/'+p.file)).digest('hex'),p.sha256);
 console.log('PASS encrypted full logical Auth/application/Storage-catalog restore and '+manifest.length+' actual photo files; all table contents identical; tampering rejected');
 console.log('Disposable evidence directory:',root);
 await restore.end();restore=null;await db.query('drop database '+name);
}finally{if(restore)await restore.end();await db.end();}
