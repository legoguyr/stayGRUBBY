// Local AES-256-GCM envelope; no network or automatic deletion.
import{createCipheriv,createDecipheriv,randomBytes}from'node:crypto';import{createReadStream,createWriteStream}from'node:fs';
import{lstat,readFile,open,link,unlink}from'node:fs/promises';import{pipeline}from'node:stream/promises';
export async function backupCrypt(mode,input,output,keyPath){
 if(!['seal','open'].includes(mode)||input===output)throw Error('Invalid operation');
 const st=await lstat(keyPath);if(!st.isFile()||st.uid!==process.getuid()||(st.mode&0o077))throw Error('Private owned recovery key required');
 const key=await readFile(keyPath);if(key.length!==32)throw Error('32-byte recovery key required');
 const magic=Buffer.from('SGBAK001'),temp=output+'.pending-'+randomBytes(8).toString('hex');let h;
 try{
  const source=await lstat(input);if(!source.isFile())throw Error('Regular input file required');const size=source.size;
  if(mode==='seal'){
   const iv=randomBytes(12),head=Buffer.concat([magic,iv]),cipher=createCipheriv('aes-256-gcm',key,iv);cipher.setAAD(head);
   h=await open(temp,'wx',0o600);await h.write(head);await h.close();h=null;
   await pipeline(createReadStream(input),cipher,createWriteStream(temp,{flags:'a'}));h=await open(temp,'a');await h.write(cipher.getAuthTag());await h.close();h=null;
  }else{
   if(size<36)throw Error('Invalid encrypted backup');
   h=await open(input,'r');const head=Buffer.alloc(20),tag=Buffer.alloc(16);await h.read(head,0,20,0);await h.read(tag,0,16,size-16);await h.close();h=null;
   if(!head.subarray(0,8).equals(magic))throw Error('Invalid format');
   const cipher=createDecipheriv('aes-256-gcm',key,head.subarray(8));cipher.setAAD(head);cipher.setAuthTag(tag);
   if(size===36){cipher.end();await pipeline(cipher,createWriteStream(temp,{flags:'wx',mode:0o600}));}
   else await pipeline(createReadStream(input,{start:20,end:size-17}),cipher,createWriteStream(temp,{flags:'wx',mode:0o600}));
  }
  await link(temp,output);
 }finally{key.fill(0);if(h)await h.close();await unlink(temp).catch(()=>{});}
}
if(import.meta.url===new URL('file://'+process.argv[1]).href)backupCrypt(...process.argv.slice(2)).catch(()=>{console.error('Backup operation failed; check private paths, key and authenticated archive');process.exitCode=1;});
