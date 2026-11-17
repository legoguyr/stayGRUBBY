import { mkdtemp, chmod, writeFile, rm } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';

const root=await mkdtemp('/private/tmp/sg-local-guard-');
const file=root+'/status.json';
try{
 for(const config of [
  {API_URL:'https://production.example',DB_URL:'postgresql://fixture@127.0.0.1/postgres',ANON_KEY:'fixture-secret',SERVICE_ROLE_KEY:'fixture-secret'},
  {API_URL:'http://127.0.0.1:1',DB_URL:'postgresql://fixture@remote.example/postgres',ANON_KEY:'fixture-secret',SERVICE_ROLE_KEY:'fixture-secret'},
  {API_URL:'fixture-secret',DB_URL:'fixture-secret'},
 ]){
  await writeFile(file,JSON.stringify(config),{mode:0o600});await chmod(file,0o600);
  const result=spawnSync(process.execPath,[new URL('./local-backend-acceptance.mjs',import.meta.url).pathname],{
   env:{PATH:process.env.PATH,SG_LOCAL_STATUS:file},encoding:'utf8',timeout:3000
  });
  assert.equal(result.status,1);
  assert(result.stderr.includes('FAIL local configuration'));
  assert(!result.stderr.includes('fixture-secret')&&!result.stdout.includes('fixture-secret'));
 }
 console.log('PASS 3 local acceptance safety guards; zero network calls');
}finally{await rm(root,{recursive:true,force:true});}
