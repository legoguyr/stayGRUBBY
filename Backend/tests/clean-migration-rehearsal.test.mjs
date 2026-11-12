import assert from 'node:assert/strict';
import { createHash, createHmac, randomUUID } from 'node:crypto';
import { createReadStream, createWriteStream } from 'node:fs';
import { lstat, readFile, readdir, mkdir } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { join } from 'node:path';
import { pipeline } from 'node:stream/promises';
import pg from 'pg';

// Both service stacks must be fresh, local and initialized with official Auth and Storage.
// Never point this synthetic fixture at a linked Supabase project.
const root = process.env.SG_REHEARSAL_DIR;
assert(/^\/private\/tmp\/sg-phase2a\.[\w]+$/.test(root ?? ''));
const info = await lstat(root);
assert(info.isDirectory() && info.uid === process.getuid() && (info.mode & 0o077) === 0);
const local = JSON.parse(await readFile(join(root, 'services.json'), 'utf8'));
const { to: copyTo, from: copyFrom } = createRequire(import.meta.url)(join(root, 'copy/package'));
const catalog = JSON.parse(await readFile(new URL('../../supabase/clean-migration-phase-1-catalog.json', import.meta.url)));
const catalogSQL = await readFile(new URL('../../DevelopmentTools/supabase_clean_migration_catalog.sql', import.meta.url), 'utf8');
const fixture = JSON.parse(await readFile(new URL('./fixtures/swift-cooking-operations.json', import.meta.url)));
const migrations = new URL('../../supabase/migrations/', import.meta.url);
const files = (await readdir(migrations)).filter(name => name.endsWith('.sql')).sort();
const erasureMigration = files.at(-1);
assert(erasureMigration.endsWith('_erase_account_cooking_photo_manifests.sql'));
const erasureSQL = await readFile(new URL(erasureMigration, migrations), 'utf8');
const graphTables = [
    'accounts', 'auth_account_links', 'profiles', 'profile_routes',
    'rankings', 'account_libraries', 'dishes', 'dish_sources', 'ranked_items', 'cooking_attempts',
    'comparisons', 'tags', 'attempt_tags', 'media', 'sync_operations', 'sync_imports', 'recipes',
    'recipe_photos', 'friendships', 'shared_cooks', 'social_notifications', 'social_blocks',
    'username_reservations', 'media_backups', 'dish_recipe_links', 'dish_recipes',
    'recipe_cook_links', 'recipe_cooks', 'recipe_revisions', 'recipe_activity', 'shared_participants',
    'social_posts', 'recipe_tickets', 'cooking_origins', 'post_recipes', 'recipe_forks',
    'social_comments', 'social_likes', 'social_reports',
].map(name => 'staygrubby.' + name);
const authTables = ['auth.users', 'auth.identities'];
const operationalTables = ['staygrubby.feature_flags', 'staygrubby.account_deletion_jobs',
    'staygrubby.recipe_import_usage', 'staygrubby.recipe_import_reservations',
    'development.recipe_test_login'];
const tables = [...authTables, ...graphTables];
const blankAuthFields = ['confirmation_token', 'recovery_token', 'reauthentication_token',
    'email_change_token_new', 'email_change_token_current', 'phone_change_token', 'email_change', 'phone_change'];
const owner = fixture.initial.accountID.toLowerCase();
const ranking = fixture.initial.rankings[0];
const user = randomUUID();
const peer = randomUUID();
const stranger = randomUUID();
const testUser = randomUUID();
const sessionIDs = new Map();
let checks = 0;

function check(condition, label) {
    assert.ok(condition, label);
    checks++;
}
function sha(bytes) {
    return createHash('sha256').update(bytes).digest('hex');
}
function quote(name) {
    assert(/^[a-z_][a-z0-9_]*$/.test(name), 'Unexpected SQL identifier');
    return '"' + name + '"';
}
function qualified(name) {
    return name.split('.').map(quote).join('.');
}
function jwt(side, role, sub, sessionID) {
    const encode = object => Buffer.from(JSON.stringify(object)).toString('base64url');
    const payload = encode({ role, sub, session_id: sessionID, aud: 'authenticated',
        exp: Math.floor(Date.now() / 1000) + 600 });
    const unsigned = encode({ alg: 'HS256', typ: 'JWT' }) + '.' + payload;
    return unsigned + '.' + createHmac('sha256', local[side].jwtSecret).update(unsigned).digest('base64url');
}
async function request(side, service, path, { role = 'service_role', actor, method = 'GET', bytes, json } = {}) {
    const session = sessionIDs.get(side + actor);
    const token = jwt(side, role, actor, session);
    const port = local[side][service];
    assert(Number.isInteger(port) && port > 1024 && port < 65536);
    const headers = { authorization: 'Bearer ' + token };
    if (bytes) Object.assign(headers, { 'content-type': 'image/jpeg', 'cache-control': 'max-age=120',
        'x-upsert': 'false' });
    if (json) headers['content-type'] = 'application/json';
    return fetch('http://127.0.0.1:' + port + path, { method, headers,
        body: bytes ?? (json ? JSON.stringify(json) : undefined), redirect: 'error',
        signal: AbortSignal.timeout(10000) });
}
async function ok(response, label) {
    if (!response.ok) {
        const error = await response.json().catch(() => ({}));
        throw new Error(label + ' returned ' + response.status + ' (' + (error.code ?? error.error ?? 'unknown') + ')');
    }
    checks++;
    return response;
}
async function actor(db, side, uid) {
    await db.query('reset role; set role authenticated');
    const claims = JSON.stringify({ sub: uid, role: 'authenticated', session_id: sessionIDs.get(side + uid) });
    await db.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)", [uid, claims]);
}
async function newSession(db, side, uid) {
    const session = randomUUID();
    await db.query('insert into auth.sessions(id,user_id,created_at,updated_at) values($1,$2,now(),now())', [session, uid]);
    sessionIDs.set(side + uid, session);
}
async function rpc(db, name, action, payload = {}) {
    return (await db.query(`select api.${name}($1,$2::jsonb) value`, [action, JSON.stringify(payload)])).rows[0].value;
}
async function value(db, sql, args) {
    return (await db.query(sql, args)).rows[0].value;
}
function restoreRecords(graph) {
    // Restore's top-level collections are sets. Leave ordered nested data intact.
    return Object.fromEntries(Object.entries(graph).map(([key, item]) => [key,
        Array.isArray(item) ? [...item].sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b))) : item]));
}
async function identityGraph(db) {
    return (await db.query(`select i.provider_id, i.identity_data->>'sub' subject,
        u.id auth_id, l.account_id, p.account_id profile_id, i.id identity_id
        from auth.users u join auth.identities i on i.user_id=u.id
        join staygrubby.auth_account_links l on l.auth_user_id=u.id
        join staygrubby.profiles p using(account_id) where i.provider='apple' order by u.id`)).rows;
}
async function columns(db, table) {
    return (await db.query(`select attname from pg_attribute where attrelid=$1::regclass
        and attnum>0 and not attisdropped and attgenerated='' and attidentity='' order by attnum`, [table]))
        .rows.map(row => row.attname);
}
async function apply(db) {
    await db.query("set time zone 'UTC'; set datestyle='ISO, YMD'; set extra_float_digits=3");
    for (const file of files.slice(0, -1)) {
        const sql = await readFile(new URL(file, migrations), 'utf8');
        const row = catalog.migrations.find(entry => file === entry.version + '_' + entry.name + '.sql');
        // The hosted ledger for the incident fix stores the SQL without its final newline.
        const ledgerSQL = row?.version === '20261111020303' ? sql.trimEnd() : sql;
        assert.equal(createHash('md5').update(ledgerSQL).digest('hex'), row?.migration_hash, file);
        await db.query(sql);
    }
}
async function snapshot(db) {
    return (await db.query(catalogSQL)).rows[0];
}
function copyQuery(table, cols, where = '') {
    return `COPY (select ${cols} from ${qualified(table)} t ${where} order by to_jsonb(t)::text) TO STDOUT WITH (FORMAT csv)`;
}
function importQuery(table, cols) {
    return `COPY ${qualified(table)} (${cols}) FROM STDIN WITH (FORMAT csv)`;
}
async function digestCopy(db, sql) {
    const hash = createHash('sha256');
    for await (const chunk of db.query(copyTo(sql))) hash.update(chunk);
    return hash.digest('hex');
}
async function rejected(action, code, label) {
    await assert.rejects(action, { code }, label);
    checks++;
}

const client = database => new pg.Client({
    host: join(root, 'socket'), port: local.dbPort, user: 'postgres', database, connectionTimeoutMillis: 5000,
});
const source = client('rehearsal_source');
const target = client('rehearsal_target');
const exports = join(root, 'fixture-export');
try {
    await Promise.all([source.connect(), target.connect()]);
    for (const db of [source, target]) {
        check((await db.query('show server_version')).rows[0].server_version.startsWith('17.11'), 'PostgreSQL 17.11');
        assert.equal(await value(db, 'select count(*)::int value from auth.users'), 0, 'Refuse a nonempty Auth database');
        assert.equal(await value(db, 'select count(*)::int value from storage.objects'), 0, 'Refuse nonempty Storage');
    }
    assert.equal(files.length, catalog.migrations.length + 1);
    await apply(source);
    await apply(target);
    const structural = await snapshot(target);
    const platformLedger = table => table.schema_name === 'public' && table.name === 'schema_migrations';
    check(structural.tables.some(platformLedger), 'Standalone Auth ledger identified');
    structural.tables = structural.tables.filter(table => !platformLedger(table));
    check(structural.tables.length === 45 && structural.tables.every(table => table.rls), 'All application tables retain RLS');
    for (const key of ['functions', 'tables', 'triggers', 'sequences']) {
        const expected = catalog.sourceCatalog[key].filter(row => row.schema_name !== 'public');
        assert.deepEqual(structural[key], expected, 'Source catalog parity: ' + key);
        checks++;
    }
    const relevant = rows => rows.filter(row => ['staygrubby', 'development', 'storage'].includes(row.schemaname));
    assert.deepEqual(relevant(structural.policies), relevant(catalog.sourceCatalog.policies), 'All 30 application/Storage policies');
    check(relevant(structural.policies).length === 30, 'All 30 application/Storage policies');
    check(!structural.functions.some(entry => entry.mentions_retry_code), 'No unbounded retry error codes');
    await target.query(erasureSQL);
    const corrected = await snapshot(target);
    corrected.tables = corrected.tables.filter(table => !platformLedger(table));
    const erasure = corrected.functions.find(fn => fn.schema_name === 'staygrubby' && fn.name === 'erase_account_data');
    const originalErasure = structural.functions.find(fn => fn.schema_name === 'staygrubby' && fn.name === 'erase_account_data');
    check(erasure.definition_md5 !== originalErasure.definition_md5 && !erasure.mentions_retry_code,
        'Fresh target loads the erasure correction before importing data');
    erasure.definition_md5 = originalErasure.definition_md5;
    assert.deepEqual(corrected, structural, 'Erasure body is the only catalog delta, including grants and FKs');
    checks++;
    for (const db of [source, target]) {
        check(await value(db, `select md5(pg_get_functiondef('storage.allow_any_operation(text[])'::regprocedure))
            ='ccefb34283c346cc88e224d075bd5312' value`), 'Official Storage operation helper matches both hosted projects');
        const auth = (await db.query(`select table_name,column_name,udt_name,is_identity,is_nullable,
            is_generated,column_default,ordinal_position from information_schema.columns
            where table_schema='auth' and table_name in ('users','identities') order by table_name,ordinal_position`)).rows;
        assert.deepEqual(auth, catalog.managedAuth[0].auth_columns, 'All 44 managed Auth columns');
        const constraints = (await db.query(`select c.relname, x.conname, pg_get_constraintdef(x.oid,true)
            from pg_constraint x join pg_class c on c.oid=x.conrelid
            where c.relnamespace='auth'::regnamespace and c.relname in ('users','identities')
            order by c.relname,x.conname`)).rows.map(Object.values);
        assert.deepEqual(constraints, catalog.managedAuth[0].auth_constraints, 'Managed Auth constraints');
        checks += 2;
    }

    // Equivalent public-only safeguard. This block runs only in the disposable target.
    await target.query(`create function public.rls_auto_enable() returns event_trigger
        language plpgsql security definer set search_path='' as $$
        declare command record;
        begin
            for command in select * from pg_catalog.pg_event_trigger_ddl_commands()
            loop
                if command.schema_name='public' and command.object_type in ('table','partitioned table') then
                    execute 'alter table ' || command.object_identity || ' enable row level security';
                end if;
            end loop;
        end $$;
        revoke all on function public.rls_auto_enable() from public,anon,authenticated;
        create event trigger ensure_rls on ddl_command_end when tag in ('CREATE TABLE','CREATE TABLE AS','SELECT INTO')
        execute function public.rls_auto_enable();`);
    await target.query(`begin;
        create table public.rehearsal_probe(id integer);
        create table public.rehearsal_ctas as select 1 id;
        select 1 id into public.rehearsal_select_into;`);
    check(await value(target, `select count(*)=3 value from pg_class
        where relnamespace='public'::regnamespace and relname like 'rehearsal_%' and relrowsecurity`), 'Public-schema safety reconciliation');
    await target.query('rollback');

    for (const [i, uid] of [user, peer, stranger, testUser].entries()) {
        const provider = uid === testUser ? 'email' : 'apple';
        const subject = provider === 'apple' ? 'synthetic-apple-subject-' + i : uid;
        const email = 'sg-fixture-' + i + '@example.invalid';
        await source.query(`insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,
            raw_app_meta_data,raw_user_meta_data,created_at,updated_at,${blankAuthFields.map(quote).join(',')})
            values($1,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',$2,
            '2026-01-01',jsonb_build_object('provider',$3::text,'providers',jsonb_build_array($3::text)),
            jsonb_build_object('sub',$4::text),'2026-01-01','2026-01-01',${blankAuthFields.map(() => "''").join(',')})`,
        [uid, email, provider, subject]);
        await source.query(`insert into auth.identities(user_id,provider,provider_id,identity_data,created_at,updated_at)
            values($1,$2,$3,jsonb_build_object('sub',$3::text,'email',$4::text),'2026-01-01','2026-01-01')`,
        [uid, provider, subject, email]);
        await newSession(source, 'source', uid);
    }
    await source.query('insert into staygrubby.accounts(id,sync_revision) values($1,1)', [owner]);
    await source.query('insert into staygrubby.auth_account_links(auth_user_id,account_id) values($1,$2)', [user, owner]);
    await source.query('insert into staygrubby.profiles(account_id) values($1)', [owner]);
    await source.query("insert into staygrubby.rankings(account_id,id,name,created_at_ref,role) values($1,$2,$3,$4,'global')",
        [owner, ranking.id, ranking.name, ranking.createdAt]);
    await source.query("insert into staygrubby.account_libraries(account_id,library_key,global_ranking_id,bridge_version) values($1,'local',$2,1)", [owner, ranking.id]);
    for (const uid of [peer, stranger, testUser]) {
        await actor(source, 'source', uid);
        await source.query('select api.provision_account()');
    }
    await source.query('reset role');
    const peerAccount = await value(source, 'select account_id value from staygrubby.auth_account_links where auth_user_id=$1', [peer]);
    const strangerAccount = await value(source, 'select account_id value from staygrubby.auth_account_links where auth_user_id=$1', [stranger]);
    await source.query('update development.recipe_test_identity set auth_user_id=$1 where singleton', [testUser]);
    // Both accounts intentionally have the same local IDs, backed by different bytes.
    await source.query("update staygrubby.accounts set sync_revision=1 where id=$1", [peerAccount]);
    await source.query("insert into staygrubby.rankings(account_id,id,name,created_at_ref,role) values($1,$2,$3,$4,'global')",
        [peerAccount, ranking.id, ranking.name, ranking.createdAt]);
    await source.query("insert into staygrubby.account_libraries(account_id,library_key,global_ranking_id,bridge_version) values($1,'local',$2,1)", [peerAccount, ranking.id]);
    await actor(source, 'source', peer);
    for (const operation of fixture.operations.slice(0, 4)) {
        await source.query('select api.apply_cooking_operation($1::jsonb)', [JSON.stringify({ ...operation, accountID: peerAccount })]);
    }
    await actor(source, 'source', user);
    for (const operation of fixture.operations) {
        await source.query('select api.apply_cooking_operation($1::jsonb)', [JSON.stringify(operation)]);
    }
    const restore = db => value(db, 'select api.open_account_library() value');
    async function applyDelta(upserts, deletions = []) {
        const payload = Buffer.from(JSON.stringify({
            upserts: upserts.map(({ entity, record }) => ({
                reference: { entity, key: record.id },
                data: Buffer.from(JSON.stringify(record)).toString('base64'),
            })), deletions, rankingAssessmentVersion: 1, photoCollectionVersion: 1,
        }));
        return value(source, 'select api.apply_cooking_operation($1::jsonb) value', [JSON.stringify({
            operationID: randomUUID(), storeID: randomUUID(), accountID: owner, kind: 'migrationRehearsalFixture',
            expectedRevision: (await restore(source)).account.sync_revision,
            payloadHash: sha(payload), payload: payload.toString('base64'),
        })]);
    }
    const initialRestore = await restore(source);
    const [first, second] = initialRestore.graph.items;
    const comparison = { id: randomUUID(), rankingID: ranking.id, firstItemID: first.id,
        secondItemID: second.id, preferredItemID: first.id, isTie: false, timestamp: 813546011 };
    await applyDelta([{ entity: 'comparison', record: comparison }]);
    const before = await restore(source);
    const media = before.graph.media[0];
    const liveCook = before.graph.attempts.find(attempt => attempt.id === media?.attemptID);
    check(before.graph.deletions.length > 0 && before.graph.comparisons.length === 1 && media && liveCook, 'Synthetic Swift wire evidence and tombstones');
    await rpc(source, 'social_identity', 'save', { displayName: 'Fixture Owner', username: 'fixture_owner', discoverable: true });
    await actor(source, 'source', peer);
    await rpc(source, 'social_identity', 'save', { displayName: 'Fixture Peer', username: 'fixture_peer', discoverable: true });
    await actor(source, 'source', user);
    await rpc(source, 'social_people', 'request', { peerID: peerAccount });
    await actor(source, 'source', peer);
    await rpc(source, 'social_people', 'accept', { peerID: owner });

    // Real JPEGs generated locally; no actual StayGrubby media or accounts.
    const jpeg = await readFile(join(root, 'synthetic.jpg'));
    const thumbnail = await readFile(join(root, 'synthetic-thumbnail.jpg'));
    assert.equal(jpeg.readUInt16BE(), 0xffd8);
    assert.notEqual(sha(jpeg), sha(thumbnail));
    const approved = [];
    async function add(bucket, key, bytes, { uid = user, visibleToSousChef = false, retain = true } = {}) {
        await ok(await request('source', 'storage', `/object/${bucket}/${key}`,
            { role: 'authenticated', actor: uid, method: 'POST', bytes }), 'Source ' + bucket + ' fixture upload');
        const object = { bucket, key, path: `/object/authenticated/${bucket}/${key}`, bytes, uid, visibleToSousChef };
        if (retain) approved.push(object);
        return object;
    }
    await actor(source, 'source', user);
    await rpc(source, 'social_identity', 'save', { displayName: 'Fixture Owner', username: 'fixture_owner', discoverable: false });
    const manifest = { accountID: owner, mediaID: media.id.toLowerCase(),
        displayHash: sha(jpeg), thumbnailHash: sha(thumbnail), displayBytes: jpeg.length, thumbnailBytes: thumbnail.length };
    const registration = (await rpc(source, 'media_backup', 'register', manifest)).backups[0];
    await add('cooking-photos', registration.displayKey, jpeg);
    await add('cooking-photos', registration.thumbnailKey, thumbnail);
    await rpc(source, 'media_backup', 'complete', manifest);

    // Model all three observed hosted states: active ready, retired ready and
    // cleaned, and retired cleaned before upload completion.
    const retired = [true, false].map(ready => ({ ready, id: randomUUID() }));
    await applyDelta(retired.map(({ id }, index) => ({ entity: 'media', record: {
        ...media, id, displayFilename: id + '-display.jpg', thumbnailFilename: id + '-thumbnail.jpg',
        sortOrder: 10 + index,
    } })));
    for (const row of retired) {
        row.manifest = { ...manifest, mediaID: row.id };
        const backup = (await rpc(source, 'media_backup', 'register', row.manifest)).backups.find(item => item.mediaID === row.id);
        row.keys = [backup.displayKey, backup.thumbnailKey];
        if (row.ready) {
            await add('cooking-photos', row.keys[0], jpeg, { retain: false });
            await add('cooking-photos', row.keys[1], thumbnail, { retain: false });
            await rpc(source, 'media_backup', 'complete', row.manifest);
        }
    }
    await applyDelta([], retired.map(row => ({ entity: 'media', key: row.id })));
    for (const row of retired) {
        if (row.ready) await ok(await request('source', 'storage', '/object/cooking-photos', {
            role: 'authenticated', actor: user, method: 'DELETE', json: { prefixes: row.keys },
        }), 'Retired photo variants removed through Storage');
        await rpc(source, 'media_backup', 'cleaned', row.manifest);
    }

    await actor(source, 'source', peer);
    const peerLibrary = await restore(source);
    const peerCook = peerLibrary.graph.attempts.find(attempt => attempt.id === liveCook.id);
    check(peerCook && peerLibrary.graph.media[0].id === media.id, 'Peer fixture deliberately shares local cook and media UUIDs');
    const peerManifest = { ...manifest, accountID: peerAccount, displayHash: sha(thumbnail),
        thumbnailHash: sha(jpeg), displayBytes: thumbnail.length, thumbnailBytes: jpeg.length };
    const peerBackup = (await rpc(source, 'media_backup', 'register', peerManifest)).backups[0];
    await add('cooking-photos', peerBackup.displayKey, thumbnail, { uid: peer });
    await add('cooking-photos', peerBackup.thumbnailKey, jpeg, { uid: peer });
    await rpc(source, 'media_backup', 'complete', peerManifest);

    await actor(source, 'source', user);

    const avatar = await rpc(source, 'social_avatar', 'prepare', { assetID: randomUUID() });
    const excludedAvatar = await add('profile-photos', avatar.path, jpeg, { retain: false });
    const replacement = await rpc(source, 'social_avatar', 'prepare', { assetID: randomUUID() });
    await add('profile-photos', replacement.path, thumbnail, { visibleToSousChef: true });
    await rpc(source, 'social_avatar', 'publish', { avatarPath: replacement.path });

    const recipeID = randomUUID();
    const recipe = { title: 'Synthetic lemon broth', ingredients: ['1 lemon'], steps: ['Simmer the peel'] };
    const assetID = randomUUID();
    const photo = await rpc(source, 'recipes', 'prepare_photo', { assetID, photoHash: sha(jpeg), photoBytes: jpeg.length });
    await add('recipe-photos', photo.path, jpeg);
    await rpc(source, 'recipes', 'complete_photo', { assetID });
    await rpc(source, 'recipes', 'save', { recipeID, recipe: { ...recipe, photoID: assetID }, visibility: 'friends' });
    await rpc(source, 'recipes', 'associate_cook', { recipeID, attemptID: liveCook.id,
        targetID: liveCook.rankedItemID, originID: randomUUID(), expectedRevision: 1 });
    const reservation = await rpc(source, 'recipes', 'begin', { originID: randomUUID(), recipeID });
    await actor(source, 'source', peer);
    const peerCookOrigin = randomUUID();
    await rpc(source, 'recipes', 'associate_cook', { recipeID, attemptID: peerCook.id,
        targetID: peerCook.rankedItemID, originID: peerCookOrigin, expectedRevision: 1 });
    const peerRecipeID = randomUUID();
    const copy = await rpc(source, 'recipes', 'fork', { recipeID, targetID: peerRecipeID, confirmed: true });
    const peerAssetID = randomUUID();
    const peerPhoto = await rpc(source, 'recipes', 'prepare_photo', {
        assetID: peerAssetID, photoHash: sha(thumbnail), photoBytes: thumbnail.length,
    });
    await add('recipe-photos', peerPhoto.path, thumbnail, { uid: peer });
    await rpc(source, 'recipes', 'complete_photo', { assetID: peerAssetID });
    await rpc(source, 'recipes', 'save', { recipeID: peerRecipeID, expectedRevision: copy.revision,
        recipe: { ...recipe, title: 'Peer’s own Recipe copy', photoID: peerAssetID } });
    await rpc(source, 'social_identity', 'save', { displayName: 'Fixture Peer', username: 'fixture_peer', discoverable: false });
    const peerAvatar = await rpc(source, 'social_avatar', 'prepare', { assetID: randomUUID() });
    await add('profile-photos', peerAvatar.path, jpeg, { uid: peer, visibleToSousChef: true });
    await rpc(source, 'social_avatar', 'publish', { avatarPath: peerAvatar.path });
    const peerPostID = randomUUID();
    const peerPost = (await rpc(source, 'social_content', 'prepare', { attemptID: peerCook.id, postID: peerPostID,
        expectedRevision: peerLibrary.account.sync_revision, confirmed: true, includePhoto: true })).posts[0];
    await add('social-photos', peerPost.photoPath, jpeg, { uid: peer, visibleToSousChef: true });
    await rpc(source, 'social_content', 'publish', { postID: peerPostID });

    await actor(source, 'source', user);
    await rpc(source, 'recipes', 'save', { recipeID, recipe: { ...recipe, title: 'Second lemon broth' },
        expectedRevision: 1, visibility: 'private', removeRecipePhoto: true });
    const postID = randomUUID();
    const post = (await rpc(source, 'social_content', 'prepare', { attemptID: liveCook.id, postID, confirmed: true,
        expectedRevision: (await restore(source)).account.sync_revision, includePhoto: true })).posts[0];
    await add('social-photos', post.photoPath, thumbnail, { visibleToSousChef: true });
    await rpc(source, 'social_content', 'publish', { postID });
    await actor(source, 'source', peer);
    await rpc(source, 'social_interactions', 'like', { postID });
    await rpc(source, 'social_interactions', 'comment', { postID, commentID: randomUUID(), body: 'Fixture comment' });
    await actor(source, 'source', user);
    await rpc(source, 'social_interactions', 'like', { postID: peerPostID });
    await rpc(source, 'social_interactions', 'comment', { postID: peerPostID, commentID: randomUUID(), body: 'Owner comment' });
    const replaySQL = 'select api.apply_cooking_operation($1::jsonb) value';
    const replayArgs = [JSON.stringify(fixture.operations[0])];
    const expectedReceipt = await value(source, replaySQL, replayArgs);
    const expectedRestore = await restore(source);
    await source.query('reset role');
    const peerRecreationID = randomUUID();
    await source.query(`insert into staygrubby.cooking_origins(id,account_id,kind,post_id,creator_id,item_id,attempt_id,completed_at)
        values($1,$2,'recreated',$3,$4,$5,$6,now())`,
    [peerRecreationID, peerAccount, postID, owner, peerCook.rankedItemID, peerCook.id]);
    const expectedGraph = await identityGraph(source);
    check(expectedGraph.length === 3 && expectedGraph.every(row => row.provider_id === row.subject && row.auth_id !== row.account_id), 'Source Apple subject and permanent identity graph');
    check(await value(source, `select bool_and(l.auth_user_id::text=o.owner_id) value from storage.objects o
        join staygrubby.auth_account_links l on l.account_id::text=split_part(o.name,'/',1)`),
    'Source fixture uses owner-authenticated uploads');

    const columnLists = new Map();
    const fileFor = table => join(exports, table + '.csv');
    await mkdir(exports, { mode: 0o700 });
    await source.query(`begin isolation level repeatable read read only;
        create temporary table forbidden_probe(id int)`).then(
        () => assert.fail('Probe should fail in a read-only transaction'),
        error => assert.equal(error.code, '25006'),
    );
    await source.query('rollback');
    await source.query('begin isolation level repeatable read read only');
    const testAccount = await value(source, `select l.account_id value from staygrubby.auth_account_links l
        join development.recipe_test_identity d using(auth_user_id) where d.singleton`);
    assert.equal(await value(source, `select count(*)::int value from auth.identities i
        join development.recipe_test_identity d on d.auth_user_id=i.user_id where i.provider='email'`), 1);
    check(await value(source, `select bool_and(encrypted_password is null and phone is null and
        ${blankAuthFields.map(field => `${quote(field)} is not distinct from ''`).join(' and ')}) value
        from auth.users u where exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='apple')`),
    'Only known-empty Auth token and pending-change fields enter the export');
    for (const table of tables) {
        const sourceColumns = await columns(source, table);
        assert.deepEqual(await columns(target, table), sourceColumns, table + ' columns');
        const cols = sourceColumns.map(quote).join(',');
        columnLists.set(table, cols);
        let where = '';
        if (table === 'auth.users') where = "where exists(select 1 from auth.identities i where i.user_id=t.id and i.provider='apple')";
        if (table === 'auth.identities') where = "where provider='apple'";
        if (['staygrubby.accounts', 'staygrubby.auth_account_links', 'staygrubby.profiles'].includes(table)) {
            const accountColumn = table.endsWith('.accounts') ? 'id' : 'account_id';
            where = `where t.${accountColumn} <> '${testAccount}'::uuid`;
        } else if (table.startsWith('staygrubby.')) {
            assert.equal(await value(source, `select count(*)::int value from ${qualified(table)} t
                where to_jsonb(t)::text like '%'||$1::uuid::text||'%'`, [testAccount]), 0, table + ' unexpected fixture reference');
        }
        await pipeline(source.query(copyTo(copyQuery(table, cols, where))), createWriteStream(fileFor(table), { mode: 0o600, flags: 'wx' }));
    }
    await source.query('commit');
    const appTriggers = structural.triggers.filter(row => graphTables.includes(row.schema_name + '.' + row.table_name));
    assert(appTriggers.every(row => row.enabled === 'O'), 'Unexpected trigger mode; inspect before transfer');
    async function load(injectFailure) {
        await target.query('begin; set constraints all deferred');
        try {
            for (const row of appTriggers) await target.query(`alter table ${qualified(row.schema_name + '.' + row.table_name)} disable trigger ${quote(row.name)}`);
            for (const table of tables) {
                const cols = columnLists.get(table);
                await pipeline(createReadStream(fileFor(table)), target.query(copyFrom(importQuery(table, cols))));
            }
            if (injectFailure) await target.query(`insert into staygrubby.dish_sources
                (account_id,id,type_code,dish_id,created_at_ref,updated_at_ref)
                values($1,gen_random_uuid(),'original',gen_random_uuid(),1,1)`, [owner]);
            // Flush FK events before ALTER TABLE takes its DDL lock.
            await target.query('set constraints all immediate');
            for (const row of appTriggers) await target.query(`alter table ${qualified(row.schema_name + '.' + row.table_name)} enable trigger ${quote(row.name)}`);
            for (const table of tables) {
                const actual = await digestCopy(target, copyQuery(table, columnLists.get(table)));
                assert.equal(actual, sha(await readFile(fileFor(table))), table + ' exact CSV SHA-256');
            }
            await target.query('commit');
        } catch (error) {
            await target.query('rollback');
            throw error;
        }
    }
    await rejected(() => load(true), '23503', 'Injected FK failure rolls back Auth, app rows and trigger DDL');
    for (const table of [...tables, ...operationalTables]) {
        check(await value(target, `select count(*)=0 value from ${qualified(table)}`), 'Empty after rollback: ' + table);
    }
    assert.deepEqual((await snapshot(target)).triggers, structural.triggers);
    await load(false);
    checks += tables.length;
    assert.deepEqual((await snapshot(target)).triggers, structural.triggers);
    assert.deepEqual(await identityGraph(target), expectedGraph);
    checks += 2;
    check(await value(target, 'select count(*)=0 value from auth.sessions'), 'No source sessions imported');
    check(await value(target, 'select count(*)=0 value from auth.refresh_tokens'), 'No source refresh tokens imported');
    check(await value(target, 'select count(*)=0 value from auth.users where id=$1', [testUser]), 'Marked Auth account excluded');
    check(await value(target, 'select auth_user_id is null value from development.recipe_test_identity where singleton'), 'Rebuilt development binding remains empty');
    for (const uid of [user, peer, stranger]) await newSession(target, 'target', uid);
    const authRead = await ok(await request('target', 'auth', '/user', { role: 'authenticated', actor: user }), 'Official Auth resolves a fresh local session');
    const authRecord = await authRead.json();
    check(authRecord.id === user && authRecord.identities.some(identity =>
        identity.provider === 'apple' && identity.identity_data.sub === expectedGraph.find(row => row.auth_id === user).subject), 'Auth returns unchanged Apple-shaped identity');
    const expiredProjectToken = jwt('source', 'authenticated', user, sessionIDs.get('source' + user));
    const staleSession = await fetch('http://127.0.0.1:' + local.target.auth + '/user', {
        headers: { authorization: 'Bearer ' + expiredProjectToken }, redirect: 'error', signal: AbortSignal.timeout(10000),
    });
    check(staleSession.status === 403 || staleSession.status === 401, 'Old project token rejected by the target Auth service');
    await actor(target, 'target', user);
    check((await value(target, 'select api.provision_account() value')).account_id === owner, 'Provision reuses original permanent account');
    assert.deepEqual(restoreRecords((await restore(target)).graph), restoreRecords(expectedRestore.graph),
        'Restore gives identical scores, evidence, diagnostics and tombstones');
    checks++;
    assert.deepEqual(await value(target, replaySQL, replayArgs), expectedReceipt, 'First accepted sync receipt still idempotent');
    check((await restore(target)).account.sync_revision === expectedRestore.account.sync_revision, 'No revision advance on replay');
    const revisions = await rpc(target, 'recipes', 'history', { recipeID });
    check(revisions.versions.some(revision => revision.revision === 1), 'Archived Recipe revision remains');
    const existingCook = await rpc(target, 'recipes', 'cook', { attemptID: liveCook.id });
    check(existingCook.usedRecipe.revision === 1 && existingCook.usedRecipe.snapshot.title === recipe.title &&
        existingCook.usedRecipe.snapshot.photoID === assetID, 'Completed cook retains exact archived Recipe and photo ID');
    await actor(target, 'target', peer);
    check((await rpc(target, 'social_feed', 'post', { postID })).posts[0].likeCount === 1, 'Sous Chef retains published post and Hands');
    check((await rpc(target, 'social_interactions', 'comments', { postID })).comments[0].body === 'Fixture comment', 'Comment preserved');
    await actor(target, 'target', stranger);
    await rejected(() => rpc(target, 'social_feed', 'post', { postID }), '42501', 'Unrelated account cannot read post');
    await target.query('reset role; set role anon');
    await rejected(() => target.query('select api.open_account_library()'), '42501', 'Anonymous app data denied');
    await target.query('reset role');

    async function readObject(side, object, options = {}) {
        const response = await request(side, 'storage', object.path, options);
        return response;
    }
    async function unavailable(response, label) {
        const result = await response.json().catch(() => ({}));
        check([400, 401, 403, 404].includes(response.status) && !String(result.code).includes('Database'), label);
    }
    async function copyObject(object, expectedHash) {
        const original = await ok(await readObject('source', object), 'Source original byte download');
        const bytes = Buffer.from(await original.arrayBuffer());
        check(sha(bytes) === expectedHash && bytes.length === object.bytes.length, 'Source hash and length');
        const existing = await readObject('target', object);
        if (!existing.ok) {
            assert([400, 404].includes(existing.status), 'Unexpected lookup failure');
            await ok(await request('target', 'storage', `/object/${object.bucket}/${object.key}`,
                { method: 'POST', bytes }), 'Target original byte upload');
        }
        const after = await ok(await readObject('target', object), 'Fresh target byte download');
        const restored = Buffer.from(await after.arrayBuffer());
        check(sha(restored) === expectedHash && restored.length === bytes.length, 'Target hash and length');
        check(after.headers.get('content-type') === 'image/jpeg', 'Target MIME');
        return existing.ok;
    }
    const occupied = approved[0];
    await ok(await request('target', 'storage', `/object/${occupied.bucket}/${occupied.key}`,
        { method: 'POST', bytes: thumbnail }), 'Fixture creates a conflicting target object');
    await assert.rejects(() => copyObject(occupied, sha(occupied.bytes)), /Target hash and length/);
    const conflicting = await ok(await readObject('target', occupied), 'Read conflicting target after refusal');
    check(sha(Buffer.from(await conflicting.arrayBuffer())) === sha(thumbnail), 'Retry refuses to overwrite mismatched bytes');
    await ok(await request('target', 'storage', '/object/' + occupied.bucket,
        { method: 'DELETE', json: { prefixes: [occupied.key] } }), 'Remove only the disposable conflict fixture');
    for (const object of approved) {
        check(!await copyObject(object, sha(object.bytes)), 'First transfer creates one object');
        check(await copyObject(object, sha(object.bytes)), 'Retry keeps an exact match');
        await assert.rejects(() => copyObject(object, '0'.repeat(64)), /Source hash/);
        checks++;
        await ok(await readObject('target', object, { role: 'authenticated', actor: object.uid }), 'Original owner still authorized');
        const peerRead = await readObject('target', object, { role: 'authenticated', actor: object.uid === user ? peer : user });
        if (object.visibleToSousChef) await ok(peerRead, 'Sous Chef read allowed for ' + object.bucket);
        else await unavailable(peerRead, 'Sous Chef read denied for ' + object.bucket);
        await unavailable(await readObject('target', object, { role: 'authenticated', actor: stranger }), 'Unrelated actor denied');
        await unavailable(await readObject('target', object, { role: 'anon' }), 'Anonymous denied');
    }
    check(!(await readObject('target', excludedAvatar)).ok, 'Orphan avatar excluded');
    check(await value(target, 'select count(*)=$1 and bool_and(owner_id is null and owner is null) value from storage.objects',
        [approved.length]), 'Service upload leaves platform owner_id and legacy owner empty');
    assert.deepEqual((await target.query('select bucket_id,name from storage.objects order by bucket_id,name')).rows,
        approved.map(object => ({ bucket_id: object.bucket, name: object.key }))
            .sort((a, b) => (a.bucket_id + '/' + a.name).localeCompare(b.bucket_id + '/' + b.name)));
    checks++;

    const claimItem = reservation.itemID;
    await target.query(`insert into staygrubby.ranked_items(account_id,id,ranking_id,name,created_at_ref,strength,uncertainty)
        values($1,$2,$3,'Late fixture',2100,0,1)`, [owner, claimItem, ranking.id]);
    const newCook = randomUUID();
    await target.query(`insert into staygrubby.cooking_attempts(account_id,id,dish_id,ranked_item_id,course_code,sequence_number,created_at_ref,updated_at_ref,is_legacy_import)
        values($1,$2,$3,$4,'soup',99,2100,2100,false)`, [owner, newCook, liveCook.dishID, claimItem]);
    check(await value(target, `select completed_at is not null and attempt_id=$2 and snapshot->>'title'=$3 and recipe_revision=1 value
        from staygrubby.recipe_cooks where id=$1`, [reservation.id, newCook, recipe.title]), 'Preserved reservation completes with original revision');

    const erase = (db, uid) => value(db, 'select api.erase_account_data($1) value', [uid]);
    const advance = (db, uid, stage) => value(db, 'select api.advance_account_deletion($1,$2) value', [uid, stage]);
    const roleService = db => db.query('reset role; set role service_role');
    const graphFingerprint = async db => {
        const digests = [];
        for (const table of [...tables, ...operationalTables, 'auth.sessions', 'storage.objects']) {
            digests.push(await digestCopy(db, copyQuery(table, 'to_jsonb(t)::text')));
        }
        return digests;
    };
    async function peerFingerprint(db) {
        const rows = {};
        for (const table of [
            'accounts', 'auth_account_links', 'profiles', 'profile_routes', 'rankings', 'account_libraries',
            'dishes', 'dish_sources', 'ranked_items', 'cooking_attempts', 'comparisons', 'tags', 'attempt_tags',
            'media', 'media_backups', 'sync_operations', 'recipes', 'recipe_photos', 'social_posts',
        ]) {
            const ownerColumn = table === 'accounts' ? 'id' :
                ['recipes', 'recipe_photos'].includes(table) ? 'owner_id' : table === 'social_posts' ? 'author_id' : 'account_id';
            rows[table] = await value(db, `select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text) value
                from staygrubby.${quote(table)} t where t.${quote(ownerColumn)}=$1`, [peerAccount]);
        }
        rows.revisions = await value(db, 'select jsonb_agg(to_jsonb(t) order by revision) value from staygrubby.recipe_revisions t where recipe_id=$1', [peerRecipeID]);
        rows.recipeSnapshot = await value(db, "select to_jsonb(t)-'recipe_id' value from staygrubby.recipe_cooks t where id=$1", [peerCookOrigin]);
        rows.fork = await value(db, "select to_jsonb(t)-'source_recipe_id'-'source_owner_id' value from staygrubby.recipe_forks t where recipe_id=$1", [peerRecipeID]);
        rows.recreation = await value(db, "select to_jsonb(t)-'post_id'-'creator_id' value from staygrubby.cooking_origins t where id=$1", [peerRecreationID]);
        rows.storage = await value(db, "select jsonb_agg(to_jsonb(t) order by bucket_id,name) value from storage.objects t where split_part(name,'/',1)=$1", [peerAccount]);
        rows.auth = await value(db, `select jsonb_build_array(to_jsonb(u),to_jsonb(i),to_jsonb(s)) value from auth.users u
            join auth.identities i on i.user_id=u.id join auth.sessions s on s.user_id=u.id where u.id=$1`, [peer]);
        return rows;
    }
    async function deleteAuth(side, db, uid) {
        await ok(await request(side, 'auth', '/admin/users/' + uid,
            { method: 'DELETE', json: { should_soft_delete: false } }), 'Official Auth hard-deletes the user');
        await unavailable(await request(side, 'auth', '/user', { role: 'authenticated', actor: uid }), 'Erased user token denied');
        check(await value(db, `select not exists(select 1 from auth.users where id=$1)
            and not exists(select 1 from auth.identities where user_id=$1)
            and not exists(select 1 from auth.sessions where user_id=$1)
            and not exists(select 1 from staygrubby.account_deletion_jobs where auth_user_id=$1) value`, [uid]),
        'Auth user, identity, sessions and final job removed');
    }
    async function verifyDeletion(db, side, ownedObjects) {
        const peerBefore = await peerFingerprint(db);
        check(peerBefore.media.length > 0 && peerBefore.storage.length === 5 && peerBefore.comparisons.length > 0 &&
            peerBefore.recipeSnapshot && peerBefore.fork && peerBefore.recreation, 'Peer has real independent and shared-origin data');
        check(await value(db, `select convalidated and not condeferrable and confdeltype='a' value
            from pg_constraint where conrelid='staygrubby.media_backups'::regclass
            and conname='media_backups_account_id_media_id_fkey'`), 'Immediate validated NO ACTION FK remains');
        const states = await value(db, `select jsonb_agg(jsonb_build_array(b.ready,b.cleaned,m.deleted_at is not null)
            order by b.ready,b.cleaned) value from staygrubby.media_backups b join staygrubby.media m
            on (m.account_id,m.id)=(b.account_id,b.media_id) where b.account_id=$1`, [owner]);
        assert.deepEqual(states, [[false, true, true], [true, false, false], [true, true, true]], 'All observed hosted manifest states');
        checks++;

        await actor(db, side, user);
        const job = await value(db, 'select api.begin_account_deletion() value');
        assert.deepEqual(await value(db, 'select api.begin_account_deletion() value'), job, 'Begin retry reuses the job');
        check(job.accountID === owner && job.state === 'requested' &&
            job.objectKeys.every(key => key.startsWith(owner + '/')) && job.objectKeys.length === 2, 'Known keys contain only active owner variants');
        await rejected(() => erase(db, peer), '42501', 'Authenticated caller cannot erase another account');
        await roleService(db);
        await rejected(() => advance(db, user, 'storage_cleared'), '55000', 'Stages cannot be skipped');
        await advance(db, user, 'apple_revoked');
        const firstBucket = ownedObjects[0].bucket;
        const buckets = new Set(ownedObjects.map(object => object.bucket));
        async function remove(bucket) {
            const prefixes = ownedObjects.filter(object => object.bucket === bucket).map(object => object.key);
            await ok(await request(side, 'storage', '/object/' + bucket, { method: 'DELETE', json: { prefixes } }),
                'Storage deletion by canonical account path');
        }
        await remove(firstBucket);
        await actor(db, side, user);
        check((await value(db, 'select api.account_deletion_state() value')).state === 'apple_revoked',
            'Interruption mid-Storage leaves the job resumable');
        await roleService(db);
        await rejected(() => erase(db, user), '55000', 'Erasure refuses an unfinished Storage stage');
        await advance(db, user, 'storage_cleared');
        await rejected(() => erase(db, user), '55000', 'Remaining bucket objects block the graph even with a recorded Storage checkpoint');
        for (const bucket of buckets) await remove(bucket);
        check(await value(db, "select count(*)=0 value from storage.objects where split_part(name,'/',1)=$1", [owner]),
            'Storage leaves no erased-account object metadata');
        for (const object of ownedObjects) await unavailable(await readObject(side, object), 'Removed bytes inaccessible');
        await db.query('reset role');
        const intact = await graphFingerprint(db);

        if (side === 'source') {
            await roleService(db);
            await assert.rejects(() => erase(db, user), { code: '23503', constraint: 'media_backups_account_id_media_id_fkey' },
                'Historical source implementation reproduces the exact blocker');
            await db.query('reset role');
            await db.query(erasureSQL);
            assert.deepEqual(await graphFingerprint(db), intact, 'Installing the correction changes no data, including a pending erasure job');
            checks += 2;
        }

        await db.query('begin');
        await db.query("update staygrubby.accounts set status='active' where id=$1", [owner]);
        await roleService(db);
        await rejected(() => erase(db, user), '55000', 'An inconsistent job cannot erase an active account');
        await db.query('rollback; reset role');

        await db.query('begin');
        await roleService(db);
        check((await erase(db, user)).state === 'account_erased', 'Erasure reaches its completion checkpoint');
        await db.query('reset role; rollback');
        assert.deepEqual(await graphFingerprint(db), intact, 'Interrupted erasure rolls back manifests, account rows and job together');
        checks++;
        await roleService(db);
        const erased = await erase(db, user);
        check(erased.state === 'account_erased' && erased.accountID === owner, 'Retry commits the account graph without an FK violation');
        assert.deepEqual(await erase(db, user), erased, 'Lost graph response repeats idempotently before Auth cleanup');
        checks++;
        await db.query('reset role');

        for (const table of [...graphTables, 'staygrubby.recipe_import_usage', 'staygrubby.recipe_import_reservations']) {
            check(await value(db, `select not exists(select 1 from ${qualified(table)} t
                where $1::text in (to_jsonb(t)->>'account_id',to_jsonb(t)->>'owner_id',to_jsonb(t)->>'author_id',
                to_jsonb(t)->>'actor_id',to_jsonb(t)->>'recipient_id',to_jsonb(t)->>'creator_id',
                to_jsonb(t)->>'reporter_id',to_jsonb(t)->>'target_account_id',to_jsonb(t)->>'source_owner_id',
                to_jsonb(t)->>'blocker_id',to_jsonb(t)->>'blocked_id',to_jsonb(t)->>'low_id',
                to_jsonb(t)->>'high_id',to_jsonb(t)->>'requester_id')
                or ($2 and to_jsonb(t)->>'id'=$1) or to_jsonb(t)->>'recipe_id'=$3 or to_jsonb(t)->>'post_id'=$4) value`,
            [owner, table === 'staygrubby.accounts', recipeID, postID]), 'No erased owner rows or live references in ' + table);
        }
        check(await value(db, "select account_id is null value from staygrubby.profile_routes where username='fixture_owner'"),
            'Former handle remains unlinked');
        check(await value(db, `select c.recipe_id is null and f.source_recipe_id is null and f.source_owner_id is null
            and o.creator_id is null and o.post_id is null value
            from staygrubby.recipe_cooks c cross join staygrubby.recipe_forks f cross join staygrubby.cooking_origins o
            where c.id=$1 and f.recipe_id=$2 and o.id=$3`, [peerCookOrigin, peerRecipeID, peerRecreationID]),
        'Peer history and independent Recipe copy detach from deleted live sources');
        check(await value(db, `select not exists(select 1 from staygrubby.social_likes where post_id=$1)
            and not exists(select 1 from staygrubby.social_comments where post_id=$1) value`, [peerPostID]),
        'Deleted owner interactions disappear while the peer post survives');
        await actor(db, side, user);
        check((await value(db, 'select api.account_deletion_state() value')).state === 'account_erased',
            'Existing Auth session can resume at the final checkpoint after a failed Auth cleanup');
        await db.query('reset role');
        await deleteAuth(side, db, user);
        assert.deepEqual(await peerFingerprint(db), peerBefore, 'Peer account, Auth, library, evidence, Recipes, post, metadata and snapshots unchanged');
        checks++;
        for (const object of approved.filter(object => object.uid === peer)) {
            const response = await ok(await readObject(side, object, { role: 'authenticated', actor: peer }), 'Peer still reads owned photo');
            check(sha(Buffer.from(await response.arrayBuffer())) === sha(object.bytes), 'Peer photo SHA-256 unchanged');
        }
    }
    const ownedObjects = approved.filter(object => object.uid === user);
    await verifyDeletion(source, 'source', [...ownedObjects, excludedAvatar]);
    await verifyDeletion(target, 'target', ownedObjects);

    const peerBeforeNoPhotos = await peerFingerprint(target);
    await actor(target, 'target', stranger);
    const emptyJob = await value(target, 'select api.begin_account_deletion() value');
    check(emptyJob.accountID === strangerAccount && emptyJob.objectKeys.length === 0, 'No-photo owner starts without backup keys');
    await roleService(target);
    await advance(target, stranger, 'apple_revoked');
    await advance(target, stranger, 'storage_cleared');
    check((await erase(target, stranger)).state === 'account_erased', 'No-photo account erases while peer Storage remains populated');
    await target.query('reset role');
    await deleteAuth('target', target, stranger);
    check(await value(target, 'select not exists(select 1 from staygrubby.accounts where id=$1) value', [strangerAccount]), 'No-photo account removed');
    assert.deepEqual(await peerFingerprint(target), peerBeforeNoPhotos, 'No-photo deletion also preserves peer');
    checks++;
    console.log(`PASS ${checks} disposable assertions; ${files.length} migrations per database, ${tables.length} CSV/digest pairs, ${approved.length} actual objects in four buckets.`);
} finally {
    await Promise.allSettled([source.end(), target.end()]);
}
