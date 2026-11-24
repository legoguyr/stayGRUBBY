import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { fixture } from './social-harness.mjs';

const migration = '20261121161724_social_dish_identity.sql';
const { db, users, actor, rpc, cooking, check, rejects, finish } = await fixture({ before: migration });
try {
 for (let n=0;n<3;n++) {
  await actor(n); await rpc('social_identity','save',{displayName:'Dish '+n,username:'dish_group_'+n,discoverable:true});
 }
 await actor(0); await rpc('social_people','request',{peerID:users[1].id});
 await actor(1); await rpc('social_people','accept',{peerID:users[0].id});
 const graph = await cooking(0,30);
 const ids=[];
 const dishes=(await db.query('select id,dish_id from staygrubby.cooking_attempts where account_id=$1 order by id',[users[0].id])).rows;
 const sharedDish=dishes[0].dish_id;
 for (let n=0;n<dishes.length-1;n++) {
  await db.query('update staygrubby.cooking_attempts set dish_id=$1,sequence_number=$2 where account_id=$3 and id=$4',
   [sharedDish,n+1,users[0].id,dishes[n].id]);
 }
 await actor(0);
 for (const attempt of graph.attempts) {
  const post=randomUUID(); ids.push(post);
  await rpc('social_content','prepare',{postID:post,attemptID:attempt,expectedRevision:0,confirmed:true});
 }
 await db.exec('reset role');
 const sourcePost=(await db.query('select id from staygrubby.social_posts where source_attempt_id=$1',[dishes[0].id])).rows[0].id;
 const otherDishPost=(await db.query('select id from staygrubby.social_posts where source_attempt_id=$1',[dishes.at(-1).id])).rows[0].id;
 // Deliberate isolated snapshot fixtures exercise score ordering alongside locked cards.
 await db.query('update staygrubby.social_posts set score_text=null,rank_at_sharing=null,ranked_count_at_sharing=null');
 for (let n=1;n<=3;n++) {
  await db.query('update staygrubby.social_posts set score_text=$1 where source_attempt_id=$2',
   [['7.4','9.2','5.0'][n-1],dishes[n].id]);
 }
 const fingerprint=async()=>JSON.stringify((await db.query("select jsonb_agg(to_jsonb(p) order by p.id) value from staygrubby.social_posts p")).rows[0].value);
 const before=await fingerprint();
 await db.exec(await readFile(new URL('../../supabase/migrations/'+migration,import.meta.url),'utf8'));
 check(await fingerprint()===before,'Exact grouping migration does not rewrite posts');
 await actor(1);
 const source=(await rpc('social_feed','post',{postID:sourcePost})).posts[0];
 const other=(await rpc('social_feed','post',{postID:otherDishPost})).posts[0];
 check(/^[a-f0-9]{32}$/.test(source.dishKey)&&source.dishKey!==sharedDish,'Opaque key never projects the private Dish UUID');
 check(source.dishKey!==other.dishKey&&source.title===other.title,'Different Dishes with identical titles remain separate');
 const first=(await rpc('social_feed','dish',{postID:sourcePost})).posts;
 check(first.length===25&&first.every(post=>post.dishKey===source.dishKey&&post.id!==source.id),'A page contains only authorized exact-Dish siblings');
 const last=first.at(-1);
 const second=(await rpc('social_feed','dish',{postID:sourcePost,beforeTime:last.createdAt,beforeID:last.id})).posts;
 check(second.length===3&&!first.some(a=>second.some(b=>b.id===a.id)),'Stable recent cursor completes the exact group');
 await db.exec('reset role');
 await db.query("update staygrubby.dishes set name='Renamed soup' where account_id=$1 and id=$2",[users[0].id,sharedDish]);
 await actor(1);
 check((await rpc('social_feed','post',{postID:sourcePost})).posts[0].dishKey===source.dishKey,'Rename preserves exact shared identity');
 const ranked=(await rpc('social_feed','dish',{postID:sourcePost,order:'highestRated'})).posts;
 check(ranked.length===25,'Highest-rated supports bounded pages');
 check(ranked.slice(0,3).map(p=>p.scoreText).join(',')==='9.2,7.4,5.0'&&ranked.slice(3).every(p=>p.scoreText===null),'Highest-rated orders numeric snapshot scores with locked scores last');
 const scored=ranked.at(-1);
 const rankTail=(await rpc('social_feed','dish',{postID:sourcePost,order:'highestRated',beforeTime:scored.createdAt,beforeID:scored.id,beforeScore:scored.scoreText===null?-1:Number(scored.scoreText)})).posts;
 check(rankTail.length===3&&!ranked.some(a=>rankTail.some(b=>b.id===a.id)),'Highest-rated cursor uses exact snapshot score and tie-breakers');
 await rejects(()=>rpc('social_feed','dish',{postID:sourcePost,order:'highestRated',beforeTime:last.createdAt,beforeID:last.id}),'22023');
 await actor(2); await rejects(()=>rpc('social_feed','dish',{postID:sourcePost}));
 await actor(1); await rpc('social_people','block',{peerID:users[0].id});
 await rejects(()=>rpc('social_feed','dish',{postID:sourcePost}));
 await db.exec('reset role');
 check(await fingerprint()===before,'Grouped reads create no post writes or counter records');
 await db.query("update staygrubby.social_posts set moderation_state='hidden' where id=$1",[sourcePost]);
 await actor(0); await rejects(()=>rpc('social_feed','dish',{postID:sourcePost}));
 await rejects(()=>db.query('select staygrubby.social_dish_key($1)',[sourcePost]));
} finally {await finish();}
