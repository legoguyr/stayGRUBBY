# StayGrubby hosted setup — October 11, 2026

> Current hosted system map (schemas, tables, buckets, Edge Functions, advisors): [architecture — Supabase system map](../STAYGRUBBY_ARCHITECTURE.md#supabase-system-map).
>
> This setup record preserves historical deployment evidence. Current product/provider/privacy boundaries are in [STAYGRUBBY_ARCHITECTURE.md](../STAYGRUBBY_ARCHITECTURE.md); development/deployment rules are in [AGENTS.md](../AGENTS.md). Old initial empty-project counts, provisioning limitations and publication requirements below are dated observations. Inspect actual migration history and current authorization for a deployment; do not replay historical setup against the live project.

## Post-V1 account deletion deployment — October 20, 2026

The ninth migration `20261020141022_account_deletion_foundation.sql` and authenticated `delete-account` version 2 are deployed. Supabase assigned that version at deployment; the earlier unapplied local filename was `20261018202309_account_deletion_foundation.sql`. SQL bytes/hash are unchanged, and all nine local hashes match hosted history. The original eight migrations were not edited. The function has JWT verification enabled and rejects unauthenticated POSTs. All 17 private tables have RLS, with zero anonymous table grants and zero direct authenticated writes. No user/account/data deletion was invoked.

The owner has configured the correct Sign in with Apple server key for Team `5DSB36G7LZ` and client ID `com.guyrettig.StayGrubby` directly in Supabase. The protected Edge Function secret `STAYGRUBBY_APPLE_CREDENTIALS` contains JSON fields `teamID`, `keyID`, `clientID`, and `privateKey`. Only the name's presence was inspected; no secret value or private key was read. Never place those values in Git, app/website assets, shell history, logs or chat. Remaining: validate cancellation, failure, retry and full Apple revocation/deletion on a disposable physical-iPhone account, never the owner's account. The server compares Apple's signed subject to the linked identity's `identity_data.sub`; `identity_id` is a Supabase row UUID and is not valid for that purpose.

The function fails closed before beginning database deletion if Apple configuration/token verification/revocation fails. The current hosted aggregate data counts remain unchanged and no deletion jobs exist. The canonical privacy policy, effective October 20, is prepared for `https://staygrubby.com/privacy`, with `privacy@staygrubby.com` and `support@staygrubby.com`. Cloudflare website publication remains an owner step (`../Website/README.md`). See `../ACCOUNT_DELETION_PRIVACY_REVIEW.md` for final evidence and limitations.

Current native application/Apple Client ID: `com.guyrettig.StayGrubby`. The project/source rename preserves the client-safe plist, pinned SDK and all hosted migrations/account behavior; see `../PROJECT_RENAME.md`. Initial setup/provider limitations below are historical, not instructions to revert the manually configured Apple provider.

## Target and tooling

Project: `StayGrubby`, reference `lgjxbpycphhsswxoncmz`, region `us-east-1`, PostgreSQL `17.11.0.003`. Preflight confirmed ACTIVE_HEALTHY, no application tables/migrations and zero Auth users. Repository was clean on main with Phase 3B commit `ff6c66ff88246b8cb8ddde78eb7d87a423747b6c`.

Official CLI **2.120.0** generated `config.toml`, `.gitignore`, and both migration files. It was downloaded to temporary storage, not installed as an app dependency. Local config uses PostgreSQL 17, automatic table exposure disabled, migrations enabled and seeding disabled. It exposes only empty `public`; it excludes private `staygrubby`. This is LOCAL configuration, not a claim that hosted settings were changed or a file to blindly push to hosted Auth settings. No Docker stack was started.

The authenticated Supabase connector targeted the exact project, applied both migrations, and verified them. The CLI itself was NOT authenticated or linked; no fake `.temp/project-ref` was written. After application, CLI-generated filenames were reconciled to the server-recorded migration versions; SQL bodies were preserved. No manual migration-history repair was used.

## Initial setup migrations (historical checkpoint)

- `20261011211144_private_cloud_foundation.sql`: Phase 3B schema, explicit client privilege revocation and predecessor FK index.
- `20261011211235_schema_access_hardening.sql`: two additional composite-FK indexes and revocation of client execution on the existing optional `public.rls_auto_enable()` event-trigger helper. The `ensure_rls` event trigger remains enabled. No managed Auth schema or helper body was changed.

`Backend/schema.sql` concatenates these files for first-install reference/tests. Future schema changes belong in new CLI-generated migrations, never in edits to applied migrations. New installations must replay the whole chain.

## Initial setup objects and permissions (historical checkpoint)

Exactly 15 empty application tables in private `staygrubby`:

`accounts`, `auth_account_links`, `profiles`, `account_libraries`, `rankings`, `dishes`, `dish_sources`, `ranked_items`, `cooking_attempts`, `comparisons`, `tags`, `attempt_tags`, `media`, `sync_operations`, `sync_imports`.

Exactly three application helper functions: `current_account_id()` (security definer, fixed empty search path, Auth UID lookup plus active account check), `stamp_record()` and `immutable_comparison()` (security invoker trigger functions). Authenticated execution is granted only on the resolver; anonymous execution is denied on all three. Their schema is unexposed.

Fourteen `owner_read` SELECT policies, one per table except `auth_account_links`, restricted to `authenticated` and the resolved permanent account. All 15 tables have RLS. Auth links intentionally have no policy and no client grants. There are no client write policies or write grants. There are 89 constraints including 28 FKs, 33 indexes and 14 actual triggers (the information_schema lists INSERT/UPDATE events separately, yielding 27 rows).

Composite account-scoped keys prevent cross-account relationships. Account libraries allow one owner row, active global ranking uniqueness is enforced, repeated/tie Comparisons remain individual UUID observations, and Source/version uniqueness retains soft deletion. Server stamping controls row versions; evidence and owned entity identity changes are rejected by triggers. Clients cannot supply versions or write any data directly. A future authorized RPC must also validate server timestamps and active-parent/deletion invariants; those workflows are not implemented here.

Provider identity -> Supabase Auth UUID -> protected auth_account_links -> permanent account UUID remains the ownership boundary. Future provisioning must derive the verified Auth UUID server-side, allocate an independent account UUID, serialize concurrent bootstrap calls, return the existing mapping on retries and insert account/link/profile atomically. Never accept an owner from email, username, user_metadata, a provider ID or a client-supplied account UUID. No bootstrap RPC or real account was created in this setup.

## Initial exposure plan (superseded for provisioning by Part 1 below)

Hosted REST explicitly reports exposed schemas `public, graphql_public`. `staygrubby` table and resolver requests with the publishable key return **406/PGRST106**; requests without a key return **401**. Thus application tables/functions remain private even though Data API is enabled. Automatic exposure is OFF; explicit table grants alone do not add a custom schema to the exposed list.

Later create a dedicated `api` schema in a reviewed migration, with only carefully authenticated provisioning/mutation/import/snapshot entry points. Grant schema USAGE and EXECUTE on specific approved signatures to authenticated only. Keep `staygrubby` and Auth mappings/helpers out of the exposed list. Then intentionally add `api` in Dashboard -> Integrations -> Data API -> Settings -> Exposed schemas, reload/verify the API and test with real sessions. Do not copy broad GRANT ALL examples. This setup creates no `api` schema, exposed views or RPC endpoints.

## Initial client configuration and SDK (historical checkpoint)

`StayGrubby/Configuration/SupabaseClient.plist` centralizes exactly ProjectURL, ProjectReference and the supplied PublishableKey. These are client-safe values, deliberately bundled, not secrets. The existing filesystem-synchronized Xcode group includes the resource without project edits. Build succeeded and the bundled plist matches the source.

No Swift SDK was added. Next integration step: select and pin the then-current reviewed `supabase-swift` release from `https://github.com/supabase/supabase-swift` through Xcode Swift Package Dependencies, add only the required Supabase product to the app target, retain Package.resolved, and instantiate a client from `Bundle.main.url(forResource: "SupabaseClient", withExtension: "plist")`. Add a validated configuration loader then; do not scatter URLs/keys, add privileged keys, or activate sync at startup. SDK integration belongs with the authenticated transport work.

## Initial setup validation and boundaries (historical checkpoint)

- 40 isolated PostgreSQL assertions passed against the entire tracked migration chain, including two-account security/constraints and deletion behavior. Auth claims are simulated only in that disposable engine.
- Hosted catalog confirms RLS, exact owner-read policies, no anonymous table grants, no authenticated write/bypass grants, inaccessible Auth links and restricted helper execution. An authenticated database-role test with no Auth claims resolves no account and reads no ranking rows.
- Hosted REST checks: no-key 401; private table/helper profile requests 406. No real JWT session test was performed, because no real account was created.
- Security advisors: zero warnings/errors; one intentional INFO for Auth links with RLS/no policies. Performance advisors: zero missing-FK-index findings; unused-index INFO is expected for eleven new indexes on an empty project. Retain them for FK cleanup/joins.
- iOS compile-only build succeeded with zero warnings/errors; centralized resource packaging verified. App Swift sources, Xcode project, UI, engine and live guest store were not modified or launched for these checks. The complete app suite was not rerun for configuration/documentation-only changes.
- No credentials, users, guest-library uploads, photos, buckets, social tables or synchronization worker were created. No commit or push.

Advisor references: [private mapping intentionally has no policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [unused indexes](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index). Exposure guidance: [securing the API](https://supabase.com/docs/guides/api/securing-your-api), [custom schemas](https://supabase.com/docs/guides/api/using-custom-schemas).

## Manual CLI access, if needed later

No credential/action is required to complete this checkpoint. Connector authentication was sufficient. For future local CLI deployment, use a supported pinned CLI and run these yourself in Terminal at the repository root:

```sh
supabase login
supabase link --project-ref lgjxbpycphhsswxoncmz
supabase migration list --linked
supabase db push --linked --dry-run --skip-vault
```

`login` opens Supabase's browser login/token flow; its credential remains local to the CLI/OS credential store. `link` may prompt in Terminal for the project's database password (Dashboard -> Project Settings -> Database). Enter it only in that local secure prompt. Do not put it in command arguments, source files or tracked config. Do NOT paste access tokens, database passwords, service-role/secret keys or signing keys into Codex/chat. Check that both server versions match local history before any future push; these two migrations are already applied. Stop if authentication is requested by an agent; no secret workaround is allowed.

Before Apple sign-in: implement/test atomic idempotent account provisioning, real authenticated sessions and dedicated RPC exposure; decide anonymous-provider access; prepare the Apple Developer capability/provider and redirect/nonce flow separately. Guest adoption, multi-device conflict/tombstone handling, mutation/import/snapshot RPCs and production transport remain later implementation. This checkpoint does not authorize those features.

## Phase 3C Part 1 — account provisioning foundation

Two additional migrations are now applied: `20261012021032_account_provisioning.sql` and `20261012021504_provisioning_session_guard.sql`. The SQL reference and four-file migration history match. Only `api.provision_account()` is added to the exposed Data API surface. It accepts zero arguments and delegates to the private trusted function; the existing 15 tables/14 owner-read policies and direct-write denial remain intact. The session guard validates the current non-anonymous Auth user and matching non-expired server session after acquiring the identity-scoped lock. Accounts/profile/link creation is atomic and idempotent; libraries/rankings remain uninitialized. No hosted user/account or guest data was created during validation.

The migration sets authenticator pgrst.db_schemas to retain public/graphql_public and add api, then reloads configuration/schema. This is a supported explicit role override and is deliberately maintained in migrations; the Dashboard exposed-schema list is no longer authoritative while this override exists. Private staygrubby/auth are not exposed. Hosted POST checks returned 401 without a key, 401/42501 with the publishable key as an anonymous caller, and 406/PGRST106 for private staygrubby. Real authenticated success awaits a separately authorized real login; local-equivalent success/concurrency was verified instead.

Official Supabase Swift 2.55.3 is now an exact SPM dependency. Package.resolved pins the SDK and transitive revisions. Client-safe plist values remain centralized; SDK defaults use Keychain and no logger. The app's guest launch does not construct a client or contact Supabase. AccountSessionCoordinator prepares only an isolated, unresolved/unmounted account store after validated provisioning. See ../ACCOUNT_ARCHITECTURE.md. No Apple capability, Development Team, native login flow, adoption, cloud photos, social feature or production sync was added.

Apple Developer enrollment is processing. Activation is needed for App ID/Sign in with Apple capability, paid-team provisioning and eventual real native login validation, but not this implementation. Do not generate or paste privileged credentials.

## November 2 Recipe + Social integration

Owner-approved `20261103024938_recipe_social_integration` is deployed. All 33 hosted/local migration hashes match; the CLI-created filename was aligned byte-identically to Supabase’s assigned timestamp. New post-revision attachments and independent-copy provenance remain closed/RLS, with existing Recipe/social APIs enforcing deliberate friends-only access. Existing data/Storage fingerprints and all 190 original development media hashes are unchanged. No Edge Function/secret/provider configuration changed. See [current contract](../STAYGRUBBY_ARCHITECTURE.md#recipe--social-integration--current-contract) and [focused verification / limitations](../RECIPE_SOCIAL_INTEGRATION_REVIEW.md).

The owner-approved additive `20261103030054_recipe_owned_copy_share_options` follow-up fixes owned-copy eligibility after a foreign historical Recipe cook. Four new regression assertions pass, existing sharing/media checks pass, and no snapshots/data/ownership were rewritten. Both applied migration files retain their tested SQL bytes.


## Next-release Stage 4 — specific Recipe/cook association

`20261105033728_stage4_recipe_cook_experience.sql` is deployed. All 36 local/hosted migration hashes match, including the byte-identical CLI→hosted timestamp alignment. The new owner-private `recipe_cook_links` is RLS/closed/RPC-only; existing Dish-family links and immutable Recipe-used snapshots remain intact with no backfill. Wrapper authorization, live-account/session checks and stale-link conflict guards are retained. Original 40 data/Storage fingerprints match, Storage remains 82 objects and the new table is empty. No Edge Function/provider/secret/auth configuration changes. See [current Recipe contract](../STAYGRUBBY_ARCHITECTURE.md#food-bible-and-recipes--architecture-v2) and [Stage 4 evidence](../NEXT_RELEASE_STAGE_4_REVIEW.md).


## V1 Stage 5 — authorized Kitchen Recipes

`20261105214537_stage5_kitchen_recipes.sql` is deployed; all 37 local/hosted migration hashes match and reference SQL remains exact. `recipes.profile_index` returns up to 25 minimal owned-Recipe summaries subject to existing live-account/mutual-Sous-Chef/visibility/block rules, with no new tables, raw grants or data backfill. Other profiles receive no private cook/family IDs; owner-only fallback remains local/private. All 41 original data/Storage fingerprints match; Stage 5 Storage baseline/final is 83 objects. No Edge Function/Auth/secret/provider configuration change. See [Stage 5 evidence](../NEXT_RELEASE_STAGE_5_REVIEW.md).

## V1 Product Closeout — November 5

`20261106022814_v1_product_closeout.sql` is deployed, aligned byte-identically from the CLI scaffold; all 38 hashes match. One closed/RLS Recipe creation/first-sharing event per Recipe, fresh audience/block/moderation checks and the new typed `activity_page` leave old-client feeds unchanged. New private historical creator credit is separate from exact Recipe content/revision. No existing Recipe audience/data backfill, raw client grant, account/Auth/Edge Function/secret/provider or Storage change. All 41 existing data/Storage fingerprints and 83 objects match; new activity and attributed-cook rows are zero at deployment. [Review](../V1_PRODUCT_CLOSEOUT_REVIEW.md).

## Recipe cook lifecycle and Dish Recipe links — November 8, 2026

Owner-authorized. The connector applied `20261108171024_recipe_cook_lifecycle` (Codex `a6de6b8`) and then `20261108171120_dish_recipe_links` (D1); the local files were renamed to Supabase's assigned versions byte-identically, and all 43 hosted/local migration hashes match. Before/after counts and content hashes of dishes (50), cooking attempts (56), ranked items (56), comparisons (241), Recipes (5), revisions (23), legacy Dish links (1), cook links (4), used snapshots (11), posts (21) and sync operations (113) were identical. There were no pending reservations to repair or stale links to retire. The single legacy link was copied into `dish_recipe_links` (not marked Main). The new table has RLS, no client grants and RPC-only access; the security advisor reports only the usual informational RLS-without-policy note shared by every RPC-only table. Live test-identity checks of restore, privacy and stale-link retirement remain a release-gate item.

## Food Bible Dish resolution — November 8, 2026 (D2)

Owner-authorized. The connector applied `20261108210256_food_bible_dish_resolution` (local scaffold `20261108200000`, renamed byte-identically); all 44 hosted/local migration hashes match. Read path only: `library_index` now names the Main-Recipe Dish first, then the exact-linked cook's Dish, then the first related Dish by name, and adds `cooked`. Counts and content hashes of dishes (50), cooks (56), ranked items (56), comparisons (241), Recipes (5), revisions (23), legacy Dish links (1), Dish Recipe links (1), cook links (4), used snapshots (11), posts (21) and sync operations (113) were identical before and after. All 5 hosted Recipes resolve to the same Dish as under the previous rule. The renamed predecessor's body is byte-identical; anonymous users cannot execute the Recipe API and authenticated users cannot call `recipe_primary_dish` or the predecessor directly. The security advisor reported no new findings.

## One Dish identity — November 8, 2026

Owner-authorized. The connector applied `20261108221250_dish_recipe_identity` (local scaffold `20261108230000`, renamed byte-identically); all 45 hosted/local migration hashes match. It adds `recipes.dish_id` (unique per owner; owner-scoped Dish identity), narrows `archive_recipe_revision` to revision/content updates, adds the cook-claim trigger and wraps `recipe_card` / `recipe_api` (`save` with `recipeDishID`, `set_dish`, `dish`, `library_index`). Baseline taken immediately before (it already included the owner's own re-ranking since the previous deployment: 247 comparisons, 114 sync operations). Before/after counts and content hashes of dishes (50), cooks (56), ranked items (56), comparisons (247), Recipes excluding the new column (5), revisions (23), legacy Dish links (1), Dish Recipe links (1), cook links (4), used snapshots (11), posts (21), sync operations (114) and Recipe activity (2) were identical. All 5 Recipes received exactly the predicted Dish, each an existing active Dish; no Recipe History rows were added. The renamed predecessors' bodies are byte-identical. Anonymous users cannot execute the Recipe API; authenticated users cannot call the predecessors or the new helper functions, and have no direct `recipes` access. The security advisor reported no new findings.

## Feature flag foundation — November 8, 2026 (Stage F)

Owner-authorized. The connector applied `20261108234407_feature_flags` (local scaffold `20261108233000`, renamed byte-identically); all 46 hosted/local migration hashes match. It adds the empty, RLS-closed `staygrubby.feature_flags` table and the read-only `api.feature_flags('get')` (authenticated only; returns flags enabled for `audience = 'everyone'`; internal/beta audiences reserved and off). Counts and content hashes of dishes (52), cooks (59), ranked items (59), comparisons (269), Recipes (5), revisions (23), used snapshots (15), posts (21), sync operations (124) and accounts (9) were identical before and after (the baseline already included the owner's acceptance testing since the previous deployment). No flag row exists; nothing is enabled. The advisor adds only the expected RPC-only RLS note for the new table.

## Food Bible Diet index — November 9, 2026 (Stage F)

Owner-authorized. The connector applied `20261109002508_food_bible_diet_index` (local scaffold `20261109010000`, renamed byte-identically); all 47 hosted/local migration hashes match. Read path only: `library_index` entries gain each visible Recipe's `dietary` codes for the Food Bible Diet filter. Counts and content hashes of dishes (54), cooks (61), ranked items (61), comparisons (279), Recipes (5), revisions (23), used snapshots (16), posts (23), sync operations (130) and feature flags (0) were identical before and after; the renamed predecessor's body is byte-identical; anonymous users cannot execute the Recipe API and authenticated users cannot call the predecessor. No new advisor findings.

## P0 incident: retry storm, read-only database — November 11, 2026

**Symptoms.** Fresh TestFlight Sign in with Apple returned to "Let's try signing in again", a second phone could not restore its account, existing photos stopped loading, and sharing after ranking reported a connection failure.

**Root cause.** PostgREST runs each RPC in a transaction and retries it **without limit** when PostgreSQL reports SQLSTATE `40001` (serialization failure). Sixteen StayGrubby functions raised `40001` for deterministic business conflicts ("Link changed; reload", "Media not accepted", "Wait for cooking sync", "Revision conflict", …). A request that hit one never returned: one pooled connection re-ran it forever.
- **The loops.** Three `recipes` `link_cook` requests and one photo `media_backup` request had looped since November 7 at 01:18–01:34 UTC. A post-ranking `social_content` `prepare` ("Wait for cooking sync") joined them on November 11 at 01:25.
- **Volume.** About 193 million rolled-back transactions since the server started on October 11, roughly 500 per second at the end. They generated about 7 GB of WAL a day: 61 GB archived through a 2 GB disk, plus host-side log volume.
- **Read-only.** Platform "System" disk usage reached 95%, and Supabase set `default_transaction_read_only = on` at about 01:23 UTC on November 11.
- **Consequences.** Auth could not write: Apple `id_token` sign-in and refresh-token rotation failed with `25006 cannot execute UPDATE/SELECT FOR UPDATE in a read-only transaction`. Storage authorization (`SELECT … FOR SHARE`) failed, so photos returned 400. Sharing could not write.
- **Before read-only.** The loops still churned locks on the owner's account row and pinned pool connections. That is why photos and sharing degraded from November 7.

**Repair.** `20261111020303_non_retryable_conflicts` (hosted version; local file identical) re-creates each affected function from its own definition with `PT409`. PostgREST returns PT409 once as HTTP 409 and never retries it. A guard in the migration, and `Backend/tests/schema.test.mjs`, fail if any function raises `40001`/`40P01`.
- **Applying it.** The migration ran in one explicitly `read write` transaction during read-only mode, Supabase's documented override for remediation. The project-level flag itself was not changed.
- **Effect.** PL/pgSQL recompiled the changed functions, so every looping request ended by itself. Rollbacks dropped from about 500 per second to 0, and WAL from about 80 KB/s to idle. No backend was terminated.
- **Owner data.** Before/after count and content hashes of all 43 `staygrubby` tables were identical. Account identity, Dishes, cooks, ranked items, comparisons, Recipes, revisions, posts, social graph, media manifests and sync operations were unchanged.
- **Photos.** All 42 active photo manifests have both stored objects (84 in `cooking-photos`). All four buckets remain private.

**Restart did not reclaim System (02:42 UTC).** After the owner's project restart, the dashboard still showed 1.86 GB of 2 GB used, mostly "System", and `default_transaction_read_only = on` persisted from `postgresql.auto.conf`.
- **Storm stopped:** 0 rollbacks and 0 bytes of WAL over a sampled interval, with no busy PostgREST backends.
- **Postgres-visible usage unchanged:** 31 MB of databases, 80 MB of WAL (6 segments), 154 MB of logs (12 files).
- **Log volume during the storm:** the CSV log rotated about every 5 minutes at about 127 MB per file uncompressed, roughly 36 GB a day through the host log pipeline. The remaining ~1.6 GB of System is outside Postgres and was escalated to Supabase support.
- **Why not lift read-only and wait:** WAL may grow from 80 MB to its 128 MB floor (`min_wal_size`) once writes resume, which puts the disk at about 95% again. Lifting read-only is safe for data, but it will likely re-trip until System is reclaimed. Use the dashboard's temporary override only for verification windows.

**Controlled writable window (03:05:33 to about 03:20 UTC, owner's 15-minute override).**
- **Writes and data:** a rolled-back test insert succeeded. The 43-table fingerprint was identical to before the incident (`7aad4e45…`).
- **Health check:** every verdict ok.
- **Existing phone:** Sign in with Apple completed at 03:06:32 (`token` 200, `provision_account` 200) for the same auth user and account. Library open, cooking sync, ranking (5 comparisons, 1 photo) and private photo reads/backups all returned 200.
- **Share:** the first attempt failed on the phone. Prepare keeps one active snapshot per cook, so it kept returning an unpublished draft (`bd3cc400…`) created at 01:25:56 by the share that got stuck in the storm. That draft expected a photo whose upload had failed during read-only mode. The draft had no stored photo, no Hands and no comments, so it was soft-deleted (`deleted_at`, the same as the built-in stale-draft cleanup). The next share published (`b9a00122…`, 03:13:52). The client now retires a draft whose photo choice disagrees with the share, then prepares once more.
- **Owner physical acceptance — PASSED (November 11, 2026, TestFlight Build 4):** existing phone (sign-in, photos, sync, ranking, Grub List share after the stale draft was cleared), fresh TestFlight install (Sign in with Apple restored the existing account and data) and second phone (account restored).
- **Normal-use baseline** (owner actively using one phone plus monitoring queries, 520 s): about 2 commits/s, 4 rollbacks total (one the test insert), Postgres logs +2.5 KB (about 0.4 MB/day), WAL directory flat at 80 MB / 6 files. The WAL position advances by one 16 MB segment roughly every 2 minutes of activity (`archive_timeout = 120 s`), and segments are archived and recycled. The incident, by comparison, ran about 500 rollbacks/s, about 80 KB/s of WAL records and about 127 MB of log every 5 minutes.
- **Cleanup:** nothing in Postgres was worth reclaiming. All app data is about 3 MB with negligible dead tuples, and VACUUM FULL or dropping compatibility functions would free kilobytes while risking old-client compatibility. The ~1.6 GB of System can only be reclaimed by Supabase (support ticket filed).

**Not caused by data growth.** App data is about 3 MB and the entire database 31 MB. WAL on disk was 80 MB and Postgres logs 154 MB. The space was platform "System" usage from the storm, which only a project restart or Supabase can reclaim. Read-only mode is lifted from the dashboard once disk is below 95%.

**Status.** Application-side recovery and cross-device acceptance passed. Still open: the ~1.6 GB of platform System disk (Supabase support ticket filed). Until Supabase reclaims it, the disk sits near 93% and read-only mode can return when the temporary override expires; lifting it again is safe. The client fixes (PT409 handling, classified sign-in errors, revision-aware share retry, stale share-draft retirement, sharp Recipe fallback photos) ship with the next TestFlight build.

## Database capacity and health (permanent)

**Rule.** Never raise SQLSTATE `40001`/`40P01` (or `serialization_failure`/`deadlock_detected`) from a StayGrubby function. Use `PT409` for "changed; reload" conflicts. Clients treat `PT409` and legacy `40001` as the same conflict (`StayGrubbyConflict`).

**Check.** `DevelopmentTools/database_health.sql` is read-only and returns a JSON verdict. It covers read-only state, Postgres-visible disk (database, WAL, logs), retry-code functions, long-running/idle-in-transaction PostgREST backends, rollback ratio, dead tuples and the largest tables. Run it:
- before every TestFlight/App Store candidate,
- after every migration deployment,
- whenever the dashboard disk graph moves.

Read the dashboard's Disk Size Distribution at the same time, because Postgres cannot see the "System" category.

**Thresholds** (dashboard disk, provisioned 2 GB as of November 11, 2026):

| Disk used | Meaning | Action |
| --- | --- | --- |
| < 70% | Normal | None. |
| 70–80% | Warning | Run the health check; find what grew (WAL, System, a table). No TestFlight upload until explained. |
| 80–90% | Incident | Stop deployments and test traffic to production. Find and stop the writer (retry storm, runaway sync, test fixtures). Restart the project if System is inflated. |
| 90–95% | Critical | As above, now. Owner decision on disk increase only after the cause is stopped. |
| ≥ 95% | Supabase read-only | All sign-ins, restores, syncs, uploads and posts fail. Stop the cause, reclaim, then lift read-only from the dashboard. |

**Data classes and retention.**
- **Canonical product evidence is never pruned for capacity:** accounts, Dishes, cooks, ranked items, comparisons, Recipes and revisions, used snapshots, links, media manifests/objects, posts, comments, Hands, Tickets, friendships and Personal Cooking Intelligence inputs.
- **Operational data may get bounded retention, but only via a reviewed migration that names the table:** `sync_operations` receipts (idempotency window), `recipe_import_reservations`/`usage`, unpublished social drafts (already cleaned after 1 day), `account_deletion_jobs` after completion, and Supabase-managed auth/audit tables.
- **No automatic job may delete rows because disk is high.**

**Expected growth.** About 10–50 KB of rows per active cook including comparisons, so 1,000 active beta users with 100 cooks each is about 1–5 GB over time. Photos live in Storage, not the database. Beta can run on the current disk once the storm is fixed. Before App Store V1, provision Pro (8 GB+ disk, auto-scaling) as a capacity decision, not as the fix for pathological growth.

**New datasets.** Every new persistent table's migration header states its expected growth, whether it is canonical or operational, and its retention/cleanup rule.

**Test traffic.** Automated tests use PGlite or mocks. The only production-touching tool is the administrator-gated `development-test-session`. A dedicated non-production Supabase project for live integration tests is a pre-V1 roadmap item.
