import{backupCrypt}from'./encrypted_backup.mjs';import{mkdtemp,writeFile,readFile,chmod,access}from'node:fs/promises';import{randomBytes}from'node:crypto';import assert from'node:assert/strict';
const p=await mkdtemp('/private/tmp/sg-backup-unit-');await chmod(p,0o700);await writeFile(p+'/key',randomBytes(32),{mode:0o600});await writeFile(p+'/wrong',randomBytes(32),{mode:0o600});
for(const [i,bytes]of [Buffer.alloc(0),randomBytes(1024)].entries()){
 await writeFile(p+'/input'+i,bytes,{mode:0o600});await backupCrypt('seal',p+'/input'+i,p+'/sealed'+i,p+'/key');await backupCrypt('open',p+'/sealed'+i,p+'/out'+i,p+'/key');assert((await readFile(p+'/out'+i)).equals(bytes));
 await assert.rejects(()=>backupCrypt('open',p+'/sealed'+i,p+'/bad'+i,p+'/wrong'));await assert.rejects(()=>access(p+'/bad'+i));
 await assert.rejects(()=>backupCrypt('open',p+'/sealed'+i,p+'/out'+i,p+'/key'));assert((await readFile(p+'/out'+i)).equals(bytes));
}
await chmod(p+'/key',0o644);await assert.rejects(()=>backupCrypt('seal',p+'/input0',p+'/unsafe',p+'/key'));
console.log('PASS empty/binary encrypted roundtrips, wrong-key rejection, no plaintext publication on failure, no overwrite and private-key permission checks');
