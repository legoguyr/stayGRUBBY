import {randomUUID} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {fixture} from './social-harness.mjs';
const migration='20261123225308_staff_reported_photo_operation.sql';
const {db,users,actor,rpc,check,finish}=await fixture({before:migration});
const photo=randomUUID(),privatePhoto=randomUUID(),recipe=randomUUID();
const path=id=>users[0].id+'/'+id+'.jpg';
async function read(name,operation){
 await db.query("select set_config('storage.operation',$1,false)",[operation]);
 return (await db.query("select id from storage.objects where bucket_id='recipe-photos' and name=$1",[name])).rows.length;
}
try{
 for(let i=0;i<4;i++){await actor(i);await rpc('social_identity','save',{displayName:'Fixture '+i,username:'staffop_'+i,discoverable:true});}
 await actor(0);await rpc('social_people','request',{peerID:users[1].id});
 await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
 for(const id of [photo,privatePhoto]){
  await actor(0);await rpc('recipes','prepare_photo',{assetID:id,photoHash:'a'.repeat(64),photoBytes:100});
  await db.exec('reset role');await db.query("insert into storage.objects(bucket_id,name,metadata) values('recipe-photos',$1,'{\"mimetype\":\"image/jpeg\",\"size\":100}')",[path(id)]);
  await actor(0);await rpc('recipes','complete_photo',{assetID:id});
  await rpc('recipes','save',{recipeID:id===photo?recipe:randomUUID(),recipe:{title:'Fixture soup',ingredients:['water'],steps:['Heat.'],photoID:id},visibility:id===photo?'friends':'private'});
 }
 await db.exec('reset role');await db.query('insert into staygrubby.moderation_reviewers(account_id) values($1)',[users[2].id]);
 await actor(1);await rpc('social_report','report',{targetType:'recipe',targetID:recipe,sourceRevision:1,reason:'inappropriate'});
 await actor(2);
 check(await read(path(photo),'object.get_authenticated')===1,'Predecessor accepts the stub-only operation form');
 check(await read(path(photo),'storage.object.get_authenticated')===0,'Reproduces real Storage prefixed operation denial before correction');
 await db.exec('reset role');
 const before=JSON.stringify((await db.query("select (select count(*) from staygrubby.social_reports) reports,(select count(*) from storage.objects) objects,(select count(*) from staygrubby.recipes) recipes")).rows);
 await db.exec(await readFile(new URL('../../supabase/migrations/'+migration,import.meta.url),'utf8'));
 check(before===JSON.stringify((await db.query("select (select count(*) from staygrubby.social_reports) reports,(select count(*) from storage.objects) objects,(select count(*) from staygrubby.recipes) recipes")).rows),'Correction creates or deletes no records');
 await actor(2);
 for(const op of ['object.get_authenticated','storage.object.get_authenticated']){
  check(await read(path(photo),op)===1,'Reported original GET accepts '+op);
  check(await read(path(privatePhoto),op)===0,'Unreported private original remains denied');
 }
 for(const op of ['', 'object.list','storage.object.list','object.sign','storage.object.sign','object.get_public','storage.object.get_public','object.get_authenticated_transform','storage.object.get_authenticated_transform','object.get_authenticated_info','storage.object.get_authenticated_info'])
  check(await read(path(photo),op)===0,'Staff evidence never authorizes alternate operation '+op);
 await actor(3);check(await read(path(photo),'storage.object.get_authenticated')===0,'Outsider remains denied');
 await actor(0);check(await read(path(privatePhoto),'storage.object.get_authenticated')===1,'Owner private read remains intact');
 await actor(1);check(await read(path(photo),'storage.object.get_authenticated')===1,'Existing authorized peer read remains intact');
 await db.exec('reset role');await db.query('delete from staygrubby.moderation_reviewers where account_id=$1',[users[2].id]);
 await actor(2);check(await read(path(photo),'storage.object.get_authenticated')===0,'Role removal revokes reported-image access');
 await finish();
}catch(e){await db.close();throw e;}
