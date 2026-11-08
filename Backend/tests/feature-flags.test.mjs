import { fixture } from './social-harness.mjs';

// Feature flag foundation: global on/off, cohorts reserved and off, server-managed only.
const { db, actor, rpc, check, rejects, finish } = await fixture();
try {
    await actor(0);
    let flags = await rpc('feature_flags', 'get');
    check(Array.isArray(flags.enabled) && flags.enabled.length === 0, 'No flag is on by default');
    await rejects(() => db.query("insert into staygrubby.feature_flags(key,enabled) values('sneaky',true)"));
    await rejects(() => db.query('select * from staygrubby.feature_flags'));
    await rejects(() => rpc('feature_flags', 'set', { key: 'x' }), '22023');

    await db.exec('reset role');
    await db.query(`insert into staygrubby.feature_flags(key,enabled,audience,description) values
        ('dish_aggregate_scores',false,'everyone','Future: shared Dish score and cook count'),
        ('global_on',true,'everyone','Test'),('beta_only',true,'beta','Test'),('internal_only',true,'internal','Test')`);
    await rejects(() => db.query("insert into staygrubby.feature_flags(key) values('Bad-Key')"), '23514');
    await rejects(() => db.query("insert into staygrubby.feature_flags(key,audience) values('x_y','everybody')"), '23514');
    await actor(1);
    flags = await rpc('feature_flags', 'get');
    check(JSON.stringify(flags.enabled) === JSON.stringify(['global_on']), 'Only globally enabled flags are on; disabled and cohort flags stay off');
    await db.exec('reset role'); await db.exec("set role anon");
    await rejects(() => db.query("select api.feature_flags('get','{}'::jsonb)"));
} finally {
    await finish();
}
