import{fixture}from'./social-harness.mjs';import{readFile}from'node:fs/promises';import{randomUUID}from'node:crypto';
const name='20261124230000_love_it_reaction.sql';const{db,users,actor,rpc,cooking,check,finish}=await fixture({before:name});
async function fingerprint(){await db.exec('reset role');const out={};for(const{tablename:t}of(await db.query("select tablename from pg_tables where schemaname='staygrubby' order by tablename")).rows)out[t]=(await db.query(`select coalesce(jsonb_agg(x order by x::text),'[]') value from(select to_jsonb(t) x from staygrubby."${t}" t)y`)).rows[0].value;out.storage=(await db.query("select coalesce(jsonb_agg(x order by x::text),'[]') value from(select to_jsonb(t) x from storage.objects t)y")).rows[0].value;return JSON.stringify(out);}
try{
 const graph=await cooking(0,10);await actor(0);await rpc('social_identity','save',{displayName:'Fixture',username:'love_preflight',discoverable:true});await db.exec('reset role');
 const items=(await db.query('select id from staygrubby.ranked_items where account_id=$1 order by id',[users[0].id])).rows;
 const reactions=['Liked it','It was fine',"Didn't like it"];
 for(let i=0;i<items.length;i++)await db.query('update staygrubby.ranked_items set session_diagnostics=$1 where id=$2',[Buffer.from(JSON.stringify({initialReaction:reactions[i%3],scoreCalibrationVersion:1,rankingAssessments:[],completedReactions:[{id:randomUUID(),reaction:reactions[i%3]}],futureField:'preserve'})),items[i].id]);
 await db.query('insert into staygrubby.comparisons(account_id,id,ranking_id,first_item_id,second_item_id,preferred_item_id,is_tie,timestamp_ref) values($1,$2,$3,$4,$5,$4,false,1000)',[users[0].id,randomUUID(),graph.ranking,items[0].id,items[1].id]);
 await actor(0);const payload={postID:randomUUID(),attemptID:graph.attempts[0],expectedRevision:0,confirmed:true};const post=(await rpc('social_content','prepare',payload)).posts[0];await db.exec('reset role');
 const old=(await db.query("select pg_get_functiondef('staygrubby.calibrated_cooking_score(double precision,bytea)'::regprocedure) value")).rows[0].value;
 const catalog=async()=>(await db.query("select n.nspname,p.proname,p.prosrc,p.prosecdef,p.provolatile,p.proacl::text,p.proconfig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('api','staygrubby') and p.proname<>'calibrated_cooking_score' order by n.nspname,p.proname,p.oid")).rows;
 const scores=async()=>(await db.query('select id,staygrubby.calibrated_cooking_score(strength,session_diagnostics) score from staygrubby.ranked_items order by id')).rows;
 const acl=async()=>(await db.query("select proacl::text,provolatile,prosecdef,proconfig from pg_proc where oid='staygrubby.calibrated_cooking_score(double precision,bytea)'::regprocedure")).rows;
 const before=await fingerprint(),funcs=JSON.stringify(await catalog()),oldScores=JSON.stringify(await scores()),beforeACL=JSON.stringify(await acl());
 const migration=await readFile(new URL('../../supabase/migrations/'+name,import.meta.url),'utf8');await db.exec(migration);
 check(await fingerprint()===before,'Upgrade preserves every application/Storage row');check(JSON.stringify(await catalog())===funcs,'Only the scoring function changes');check(JSON.stringify(await acl())===beforeACL,'Existing scoring grants/security remain unchanged');check(JSON.stringify(await scores())===oldScores,'Existing three-reaction scores remain identical');
 await actor(0);check((await rpc('social_content','prepare',payload)).posts[0].scoreText===post.scoreText,'Existing post score stays immutable');await db.exec('reset role');
 const bytes=Buffer.from(JSON.stringify({initialReaction:'Liked it',initialSemanticReaction:'Loved it',semanticReaction:'Loved it',latestSemanticReaction:'Liked it',scoreCalibrationVersion:2}));
 const loved=(await db.query('select staygrubby.calibrated_cooking_score(0,$1) score',[bytes])).rows[0].score;check(Math.abs(loved-(7+3/(1+Math.exp(-.4))))<1e-12,'Love It native formula matches');
 await db.query(old);const fallback=(await db.query('select staygrubby.calibrated_cooking_score(0,$1) score',[bytes])).rows[0].score;check(Math.abs(fallback-(7+3/(1+Math.exp(.4))))<1e-12,'Function rollback restores compatibility fallback');await db.exec(migration);check(await fingerprint()===before,'Rollback/reapply preserves all rows');
}finally{await finish();}
