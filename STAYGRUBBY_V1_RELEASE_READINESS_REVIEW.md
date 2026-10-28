# StayGrubby V1 release readiness

> Historical release-readiness evidence. Current release status/gates are consolidated in [STAYGRUBBY_MASTER_ROADMAP.md](STAYGRUBBY_MASTER_ROADMAP.md), with implementation truth in [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md) and verification policy in [AGENTS.md](AGENTS.md). Later Food Bible/Recipe Creator work supersedes old no-AI, active Tickets, pending Creator acceptance and policy-version statements below. Recipe Creator V1/refinement is now owner physically accepted. No new release test or distribution is claimed by this reconciliation.

This is the central release-readiness record, superseding historical pending-state reports where explicitly updated below. Starting HEAD: `9a0e9934005b3ccdd2d9e887e0312369e7996772`, clean `main`, three ahead of tracking `origin/main`. Preserve the three accepted Food Bible commits. One agent/current checkout/one Simulator lane. No archive, TestFlight upload, App Store Connect change, real account deletion or AI implementation is authorized or performed.

## Assessment and remaining gates

**GO for preparation and owner acceptance work; NOT YET for external distribution or App Store submission.** Final test/build results and checkpoint SHAs are recorded below. Owner physical acceptance, operational UGC safety decisions, the deployment-target decision, publication of the clarified policy and Apple distribution/review setup remain explicit gates. The intentionally deferred real Apple deletion/revocation test is **not** a blocker for this cycle.

## Hosted Food Bible deployment and data preservation

Owner explicitly authorized the existing migration. Initial `apply_migration` attempts failed with expired `requestState`, then `Transport closed`. Read-only history checks confirmed no application. The owner refreshed the existing Supabase connection; the next attempt succeeded. No password/key/token was requested or exposed and no alternate credential path was used.

Supabase assigned version **20261023135617**, `dish_linked_recipe_components`. The local file was renamed from `20261022235205` without changing SQL bytes: MD5 **3634b481189b1f5915f530067d474999**. All **24/24** local/hosted version/name/SQL hashes match. The reference schema remains the exact sorted migration concatenation. Checkpoint **dcebf7c** records this bookkeeping and deployment evidence.

Hosted post-deployment checks: **34/34** application tables have RLS; `dish_recipes` and `recipe_revisions` deny direct anonymous/authenticated CRUD; prohibited anonymous API execution count **0**; archive trigger enabled; one exact archived legacy revision; zero Dish–Recipe links. The existing Recipe had no completed exact provenance and remains safely unlinked. No title guessing or cooking/ranking backfill. Local focused migration/lifecycle checks passed 45 assertions against the deployed SQL; broader security checks are appended below. Security advisor retains 19 intentional closed/RPC-only no-policy INFO entries and the existing unused password-protection WARN, no new ERROR. [RLS advisor](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [password advisor](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

All **33 original hosted application/Storage fingerprint groups** match the fresh baseline. Counts include history: 3 accounts/rankings, 33 Dishes, 38 attempts/items, 137 comparisons, 14 Sources, 10 tags, 51 memberships, 35 media metadata/backups, 70 sync receipts, 5 posts, 1 comment, 1 Recipe, 0 Tickets and 3 incomplete Recipe reservations. **57 Storage objects**, all three buckets private. The one revision archive was the intentional additive migration result, not new user content. At the later final check, the owner confirmed changing a Recipe during this run: Recipe count is now 0, its archive cascaded to 0, and the three reservation rows remain with Recipe references cleared (one now completed). This explains the changed `recipes`/`recipe_cooks` fingerprints; the other **31/33** original groups still match, including all private cooking, ranking, evidence and Storage. No agent reset, purge, repair or recreation was performed. Do not restore owner-deleted content to match the earlier baseline.

Demo remains 1 ranking / 12 Dishes / 15 attempts/items / 356 comparisons / 10 Sources / 21 tags / 48 memberships / 190 media files. Complete semantic/media manifest SHA-256 `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`. Read-only audits during and after the main Simulator/Release checks match the complete baseline, including identities, scores, evidence, relationships and media bytes.

## Product contracts and release hardening

| Surface | Verified architecture / boundary |
| --- | --- |
| Grub Rank | Authoritative cooked/ranked history; default of four tabs; versions independently ranked |
| Food Bible | Derived existing cooked Dish + eligible authorized Recipe, no second Dish database or manual membership flag |
| Tickets | Separate Want to Cook destination from Food Bible, no fifth tab; idempotent existing Recipe saves |
| My Kitchen | Photo/name/@username, authorized own post grid, Signature Dishes, Share My Kitchen, Sous Chefs and Settings |
| Settings | One Profile editor, Sharing Preferences, Account & Sync, sent requests, blocked accounts, policy/support and separated destructive actions |

Adding/editing/linking/unlinking/deleting Recipes never creates cooking, items or evidence, nor changes ranks/photos. Recipe identity, current revision and historical snapshots remain distinct. Components/ingredients/steps retain IDs and order; one unnamed component remains simple. Existing source/creator/Added by/social inspiration semantics stay separate. Current manual Recipe/RecipeDraft schema is serializable and ready for a future parser returning an editable, user-confirmed draft. No provider/AI, math/scaling, OCR or scraping is implemented.

Tickets → Make This → existing editable cook → normal ranking preserves independent provenance through the account-bound durable worker. Completed exact Recipe provenance derives cookbook membership. Known linked Dishes open New Version; uncooked Recipes use New Dish. Cancel creates no cooking. Removing a Ticket does not delete Recipe, Dish or social origin. Existing Recipe-based Tickets do not implement arbitrary non-Recipe post bookmarks.

Release fixes are limited to actual findings: obsolete Recipes/Tickets segmented-navigation assertions updated to the current cookbook/secondary Ticket contract; the Debug-only mock-dependent native tests are compile-time guarded for Release; Recipe editing holds a stable selected Recipe snapshot so parent reauthorization does not reconstruct/discard an unsaved draft. Targeted background/foreground evidence is appended below. The historical structured-sync harness now applies the actual pre-Cuisine prefix before populating legacy data, then the complete remaining migration suffix in order. Previously it skipped Cuisine while loading newer dependent migrations and failed before exercising sync. All existing parity/security assertions remain; the corrected test passes 75 assertions. No ranking, score, persistence, private sync or sharing redesign.

## Account, ranking, private data and social

Required account path remains onboarding → native Sign in with Apple → Supabase session → permanent internal account → account-store readiness → app. Auth user IDs are not library owners. SDK Keychain session storage, account/generation fences, cache validation, sign-out and account-bound sync are preserved. No production guest mode. Development library/review fixtures are `#if DEBUG`, isolated UUID stores/media and never authenticated/provisioned/uploaded as real accounts. A transient restore/loading transition remains future startup polish, not redesigned.

Deletion UI remains My Kitchen → Settings → Account & Sync → Delete account with deliberate confirmation and matching Apple proof. Hosted delete-account **v4 ACTIVE**, `verify_jwt=true`, original SHA-256 `61be13a0430ab018a0557855e79b4eac05fecc4af456b11f20bd7ac5d7a14f14`. No Edge redeployment, real deletion or physical Apple revocation. New Recipe link/revision FKs follow the existing account/Recipe cascades. Survivor-owned historical snapshots and independent cooking follow disclosed retention semantics.

Bradley–Terry, comparison selection/evidence, strength ordering and reaction calibration are frozen: Liked `7+3σ(s/1.6−0.4)`, Fine `4.8+3σ(s/1.6)`, Disliked `1+4.8σ(s/1.6)`, legacy fallback unchanged. Display score never sorts Grub Rank; equal displayed values can have distinct true ranks; #1 is not forced to 10. Completed re-rank metadata uses the existing atomic transaction, canceled re-rank writes nothing. Unlock remains 10 eligible attempts/versions. Exports remain protected by unlock and uniform brand-red scores. No private ranks, evidence or Personal Notes are added to social/Recipe responses.

Social remains mutual Sous Chefs, not followers. Chronological feed/profile grid pages and post detail enforce current authorization; unavailable/deleted/blocked content is not a private-data fallback. Explicit descriptions are social; Personal Notes are private; Recipe visibility is separate and opt-in. Hands/comments, Shared Cooking invitations/claims, Run It Back and Order Up! retain their existing actor/account/current-source checks, idempotency and failure recovery.

### UGC safety gap requiring owner decision

Implemented: profile/post/comment report controls, six report reasons, private deduplicated/rate-limited reports, blocking, owner/post-author comment removal, post retirement, account deletion, service-only hide/unhide states and support contact. Operators can inspect reports and hide content through protected SQL; client roles cannot moderate or see report/reporter data.

**Not established:** a proactive objectionable text/image filtering method and a documented monitored report/response process. Length/control-character validation is not an objectionable-content filter; friends-only authorization is not moderation. Do not claim this is solved by backend architecture. Before broad external distribution/App Store submission, the owner must choose and operate a proportionate safety policy, response owner/cadence and appropriate filtering safeguards. This may require a separately scoped implementation decision; no arbitrary profanity list, paid moderation vendor, AI moderator or massive admin platform was invented. [Apple Guideline 1.2](https://developer.apple.com/app-store/review/guidelines/#user-generated-content).

## Release identity and minimum iOS

Unchanged project/target/scheme/product/display name **StayGrubby**, bundle **com.guyrettig.StayGrubby**, Team **5DSB36G7LZ**, automatic signing, version **1.0**, app build **2**, iPhone-only upright portrait. Official icon/wordmark and semantic score palette are preserved. Existing Sign in with Apple and `applinks:staygrubby.com` entitlements remain. This is local configuration evidence, not proof of current portal capability/provisioning or a newly signed physical install.

Current minimum remains **iOS 26.5** for application and tests. Inspection found no explicit 26.5-only API dependency. A compile-only Debug probe with `IPHONEOS_DEPLOYMENT_TARGET=17.0` **succeeded**, demonstrating current API availability at that lower target with this SDK. There is only an iOS 26.5 runtime installed, so this is **not** proof of iOS 17 runtime/UI/store compatibility. No project target was lowered in this cycle.

Recommendation: evaluate **iOS 26.0** as the conservative first external-beta minimum, with one real/Simulator 26.0 acceptance pass, rather than the unnecessarily narrow 26.5 setting. iOS 17 is a technically compiling candidate for broader later support but needs oldest-supported-runtime testing and is a larger product/support decision. The future original on-device Foundation Models framework starts at iOS 26 on compatible Apple Intelligence devices with the feature available/enabled; it does not itself require 26.5. Future provider availability must be gated, with manual/free-tier fallback preserved. No Foundation Models import or integration. [Apple availability](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/).

Release build/binary and actual Release auth-gate results are appended below. No signing credential or version/build-number changes; no archive or upload.

## Links, public site and policy

Native strict canonical HTTPS profile parser, auth-aware retained destination, owner/server resolver, old-slug ownership reservations and unavailable/private/blocked handling remain. Only profile routes exist; no public post/Recipe/food content routes. Unit/targeted UI routing checks do not prove physical Universal Link association. Confirm the Apple capability/provisioning and test cold/warm Messages/Mail links on signed iPhone later.

Live website is the existing **Cloudflare assets-only Worker `staygrubby`**, not Pages. Custom domain `staygrubby.com` remains attached; no DNS/MX/TXT changes. Baseline version `18fe03f1-d306-4d53-86d2-e39d39018b93`, deployment `e0292694-5333-41bf-aaf1-478e576b4771`. `/`, `/privacy`, `/support` return 200 with TLS/CSP/nosniff/referrer/permissions headers. AASA returns **200 JSON directly**, exact Team/bundle and `/@*`; `/@release_review` canonicalizes via **307 → `/kitchen` → 200**, generic app-required landing, no Supabase/profile content/scripts. Unknown route returns 404. No cookies/analytics added; provider network-error headers are infrastructure, not app tracking.

`Website/distribution.json` remains `{ "url": null }`; fallback honestly says external beta access is not open. Owner must supply the actual approved Apple public join/product URL later; no fabricated link or TestFlight link creation. Current site cannot deliver an uninstalled app and does not falsely claim to do so.

Policy clarification effective **October 22, 2026** now accurately describes Dish-linked cookbook membership, structured components/tips/revision history, link removal versus Recipe deletion, private photo reuse and the current deletion navigation. It retains existing privacy/retention boundaries, not a casual legal rewrite. Bundled canonical text and generated complete HTML match. Local static tests **7 pass** and assets-only Worker dry run succeeds. New `Website/wrangler.jsonc` targets the existing account/Worker, no script/backend/DNS bindings, previews/workers.dev disabled; local CLI state is excluded.

**Publication blocker:** authenticated Cloudflare inspection and asset-session registration work, but documented asset upload through the connected execution context returns **HTTP 401** (plain Unauthorized). Two attempts, no Worker deployment. The ephemeral CLI reports not signed in; no login, token, temporary account or credential workaround was used. The live policy therefore still shows **October 21**. Owner publication step: with their normal authenticated Cloudflare CLI session, run `python3 Website/build.py`, the seven site tests, dry run, then `wrangler deploy --config Website/wrangler.jsonc`. Publish only the tested public allowlist, preserve the existing custom domain/email DNS, and recheck policy/AASA/fallback. Full instructions are in Website/README.md.

## App Store privacy and metadata preparation

This is an evidence-based owner checklist, not submitted answers. No App Store Connect access/change occurred. [Apple data-type definitions](https://developer.apple.com/app-store/app-privacy-details/).

| Candidate disclosure | Actual implemented behavior / owner confirmation |
| --- | --- |
| Contact Info: Email Address | Apple/Supabase Auth may retain supplied/private-relay email; app requests email scope, does not use email as library ownership |
| Contact Info: Name | User-entered display name/nickname and profile identity |
| Identifiers: User ID | Apple/Auth/internal account IDs, username, relationship/content identifiers linked to accounts |
| Identifiers: Device ID review | Sync installation/store UUID is an app-scoped library/sync identity, not IDFA/hardware ID; owner must map this conservatively against Apple's device-level-ID definition |
| User Content: Photos or Videos | Selected cooking photos, optional avatar and explicitly shared food photos; private Storage and existing deletion lifecycle |
| User Content: Other User Content | Dishes, versions, dates, comparisons/results, private notes, sources/food metadata, Recipes/components/tips/revisions, Tickets, descriptions, comments, friends/Hands/shared provenance/notifications |
| User Content: Customer Support | Voluntary emailed support/privacy requests and private report context; provider/email handling must be included where applicable |
| Usage Data / Diagnostics review | No conventional analytics/crash/advertising SDK observed. Functional ranking diagnostic fields are not a general usage analytics feed. Supabase/hosting operational logs may include IP/request/error/security information; confirm actual provider retention/purposes before answers |
| Location / Contacts / Health | No device location/contact-address-book/HealthKit collection APIs observed. Dish allergens/dietary labels are food attributes, not a clinical diagnosis feature; owner should separately review any future personal-health collection |
| Tracking / advertising | No ATT/IDFA, advertising SDK, cross-app tracking or analytics added; do not claim provider security logs do not exist |

Purposes observed: App Functionality and security/abuse handling; account/cloud content is linked to account identity. Do not select advertising/data-sale purposes absent implementation, or blanket “no data collected.” Privacy manifest declares the implemented app-owned UserDefaults reason CA92.1; source inspection found no timestamp/uptime/free-disk APIs requiring an additional app declaration. SDK privacy manifests must remain bundled. Final built-resource checks below are local evidence; owner confirms legal/disclosure answers.

Metadata owner checklist: app name StayGrubby; decide subtitle/description/keywords; Food & Drink category candidate; answer current age-rating questions honestly for UGC/social interaction and moderation; privacy `https://staygrubby.com/privacy`, support `https://staygrubby.com/support`; capture actual supported-iPhone screenshots after approval; prepare review notes describing Apple-only account requirement, first-account empty state, account restore, friend-only social/Recipe permissions and account deletion path. Arrange a legitimate reviewer-access/test path without putting credentials in this repository or inventing production guest mode. Explain moderation controls and operational response/filtering once chosen. Existing uploaded **1.0 (1) Internal Only** is historical; source is **1.0 (2)**. No new upload/public beta link created here. [Apple review preparation](https://developer.apple.com/app-store/review/).

## Accessibility, performance and recovery

Portrait-only review remains required; no landscape requirement. Existing scalable type, VoiceOver names/headings, non-color score semantics, 44-point editor/reader actions, photos/placeholders, overflow confirmations, reduced-motion behavior and full-width Settings/Sous Chefs interactions are preserved. Final representative screenshots are inspected, not substituted for a physical VoiceOver/haptics pass.

Inspection: cookbook uses compact 50-row server pages and thumbnail loading, no remote query per card or full revision bodies; feed/profile use bounded 25-row authorized pages, cached/downsampled photos and request/account fences. Recipe reader loads one body. Rendering does not recompute ranking. No speculative performance rewrite or new profiling claim. Existing remote/private cooking work uses the established coordinator/defer/account fences.

Failure-state review: auth/setup errors remain gated/retryable; saved verified account/private library can remain available offline under existing rules; Recipe management is online with unavailable/retry messages and draft preservation on save failure; social feed retries; publication and Shared Cooking use durable scoped retries after actual private save; comments/Hands errors do not manufacture success; blocked/deleted link/post/Recipe targets show unavailable; avatar/photo failures remain scoped and retryable. No new offline Recipe cache or second sync engine is claimed. First-run/empty ranking/unlock, cookbook, Tickets, friends/posts/notifications/photo/comments states retain intentional next actions. Diagnostic tests/results below must identify any actual failures instead of treating runner flakiness as app defects.

## Owner physical and multi-account acceptance

Do not mark these complete from Simulator mocks:

1. Real Sign in with Apple and cold account/session/library restore; sign-out returns to onboarding. Do not perform account deletion/revocation for this checklist.
2. Real photo selection/preparation/upload/relaunch/restore with private account; inspect a real photo and a placeholder.
3. Add a Recipe to an existing Dish; same Dish enters cookbook; edit through Dish and Food Bible; reorder/move ingredients, steps and components; background/foreground a draft; cancel safely; detach/delete leaves cooking/rank/photos/evidence intact.
4. Ticket → Make This → cancel, then actually cook/rank; known Dish uses New Version, provenance remains correct and no duplicate cooking from request retry.
5. Score feel, completed/canceled re-rank, unlock/relock, native share preview/export privacy; evaluate feel without retuning frozen math.
6. Physical haptics, light/dark, representative Dynamic Type and VoiceOver/reading/action order.
7. Signed iPhone Universal Links from Messages/Mail: cold/warm, logged out/in, valid/invalid/renamed/unavailable/private/blocked profile; confirm capability/provisioning and AASA cache behavior.

Two real consenting test accounts, safe disposable content (no reset): discovery/find/request/accept/remove; authorized profile grid/Post Detail and descriptions; Hands/comment/delete/report/block; private notes/ranks/evidence stay hidden; locked scores remain omitted; private versus friends-only Recipe access; opt-out/revocation denies new access while entitled completed historical snapshots remain disclosed; Shared Cooking invite/decline/join/cancel and Run It Back with independent cooking; Order Up! routes to actual accessible targets; block/remove/deleted targets lose normal access. Verify photo visibility and deletion behavior across accounts without deleting either real account.

## Verification and final checkpoints

Final selected regression, Debug/Release build and actual Release gate/binary results are recorded below. Diagnostic failures are retained honestly alongside corrected affected reruns. Final hosted/demo/secret/whitespace evidence and checkpoint inventory follow. No further feature phase is authorized. The Intelligent Recipe Engine is not needed for external beta. It can be separately authorized during beta after the release baseline and safety decisions are settled; preserve the $0-cost/manual fallback contract. It was not started here.

### Final regression selection and diagnostics

One risk-based selected Debug run covers 27 native suites (including the XCTest gate-presentation class) plus 24 representative UI methods across account/onboarding, full cooking lifecycle, Food Bible, components, background draft, four-tab/Profile/Settings, scores/unlock, social recovery/interactions/avatar/sharing, Shared Cooking, Order Up! and profile links. Historical ranking simulation sweeps and every visual permutation are deliberately excluded. An initial sandbox invocation stopped at package-cache permissions before tests; the normal authorized Xcode execution is the actual run.

Native diagnostics found two stale expectations: the policy test still named October 20 and a deletion test still expected pre-calibration 5.5 from a surviving Liked cook. The tests now require October 22, zero fitted strength, unchanged reaction diagnostics and the approved Liked score formula. No ranking code/calibration was changed. Only the affected native suites are rerun after this correction.

Backend selection: schema/RLS, structured sync, photo policies, Food Bible lifecycle/migration, Recipes/Tickets/links, provenance, social integration/avatar/descriptions, Shared Cooking, notifications, score calibration, safety and sharing defaults. **555 assertions pass across 15 local disposable-database suites** after correcting the obsolete migration-order harness. No hosted fixtures or real credentials are used. Website **7/7** static checks pass.

Broad Debug bundle: `/private/tmp/staygrubby-release-final-debug-verified.xcresult` — **212 test definitions / 301 executions**, 210 definitions (299 executions) passed, two stale native expectations failed, **0 skips / 0 expected failures**. All **24/24 UI methods passed** (845.8 seconds). The native portion has 188 definitions / 277 executions including the one XCTest presentation gate; only the policy-date and obsolete single-item score expectations failed. This bundle remains honestly marked Failed; corrected affected-test evidence follows.

Visual review inspected the completed run's saved images: Grub Rank locked and calibrated scores in both appearances, locked completion, cookbook with photo fixture and placeholder, linked multi-component reader, simple reader at accessibility size, component editor/keyboard, separate empty Tickets, light Kitchen/grid, dark large-text Post Detail/Grub List, full-width Settings/Profile editor, Sous Chefs, Order Up! at large text, and onboarding's reachable native Apple button. Reduce Motion is enabled in the large-text cookbook/profile fixtures. Synthetic colored image fixtures exercise local media loading; they are not real food/user photos. No new visual release blocker was found. Auth/recovery rendering is also covered by the native hosted-view snapshots. These are Simulator/fixture observations, not physical Apple authorization or real multi-account proof.

Corrected native rerun: `/private/tmp/staygrubby-release-native-corrections.xcresult` — **2/2 tests and executions passed**, 0 failures/skips. Across the broad run plus this narrowly affected rerun, all **212 selected definitions / 301 selected executions have passing coverage**, including 24/24 UI. Initial standalone draft-test diagnostic attempts failed before reaching the editor (unacknowledged tab / near-tab-bar Saved Recipes link taps); measured reach plus bounded destination-acknowledged navigation stabilized the harness. The focused draft test then passed, and it passed again in the combined run. No assertion or app behavior was weakened to obtain green output.

Debug build succeeded; final Debug test rebuild succeeded. Optimized **Release build succeeded (133.8 seconds)** with no reported warnings/errors. Built Release bundle is `com.guyrettig.StayGrubby`, StayGrubby, **1.0 (2)**, minimum **26.5**, device family `[1]`, only `UIInterfaceOrientationPortrait`, exempt-encryption flag false. Known development launch/UI strings and Debug fixture symbols are absent from the Release application binary. Canonical policy is the single exact bundled policy (SHA-256 `e6ca867a8111ce6325fba9d0cd1315e383cda01105e4633e6fc08d0186c79110`). App/SDK privacy manifests and compiled official asset catalog are present. Client configuration contains only ProjectReference/ProjectURL/PublishableKey for the expected hosted project; no secret values were printed. Actual Release gate results follow.

The first Release **test** invocation stopped at compilation because the normal optimized app module correctly has testability disabled while the shared test target uses `@testable import`. No test executed and the ordinary Release build remains successful. The focused test-only invocation uses command-line `ENABLE_TESTABILITY=YES` (still Release, no `DEBUG` define); no project/signing/production configuration is modified. Its results are recorded separately.

### Checkpoint scope and owner distribution actions

Besides deployment bookkeeping, intended files for this cycle are:

- `StayGrubby/Social/RecipeViews.swift`: stable Recipe editor snapshot.
- `StayGrubbyTests/FoodBibleTests.swift`, `StayGrubbyTests/SocialAvatarTests.swift`: Debug-only mock test guards.
- `StayGrubbyTests/AccountDeletionTests.swift`, `StayGrubbyTests/CookingModelTests.swift`: current policy/calibrated-score assertions.
- `StayGrubbyUITests/FoodBibleUITests.swift`, `StayGrubbyUITests/ProductStructureUITests.swift`: background-draft coverage and current navigation assertions.
- `Backend/tests/structured-sync.test.mjs`: chronological legacy-to-current migration harness.
- `StayGrubby/Legal/PrivacyPolicy.md`: conservative Food Bible/revision/deletion-path clarification.
- `Website/build.py`, `Website/test_site.py`, `Website/README.md`, `Website/wrangler.jsonc`, `.gitignore`: matching static policy, tested existing-Worker deployment and excluded local CLI state.
- `STAYGRUBBY_V1_RELEASE_READINESS_REVIEW.md`: central evidence, limitations and owner checklist.

No engine, calibration, unlock, private persistence/sync, asset, entitlement, schema SQL-body, signing, version/build or social-product redesign is included. No local backup, credentials, fixture media, dependency/cache or generated public/build output is intended for Git.

Owner order after review: push checkpoints through GitHub Desktop if HTTPS auth remains unavailable; publish the tested policy using the existing Cloudflare Worker workflow; accept the current iOS 26.5 minimum or separately authorize/evaluate 26.0 on that runtime; complete the concise physical/two-account checks above; choose monitored UGC response ownership/cadence and appropriate objectionable-content safeguards; finalize privacy answers/age rating/metadata/screenshots/reviewer access. Only then approve an archive/upload and External TestFlight/Beta App Review setup. Supply a real approved Apple distribution URL later; keep the website destination unset until then. App Store submission additionally needs its final metadata/screenshots/disclosures and operational UGC safety/review readiness. Real Apple deletion/revocation remains intentionally deferred, not a fabricated blocker.

The test-enabled Release compile then exposed one additional pre-existing mock-dependent avatar test referring to the Debug-only `SocialReview`. Only that method is now compile-time guarded, just like the Food Bible mock test. The avatar image/initials test remains Release-capable; the unchanged failure/retry/removal method already passed in the broad Debug run. No meaningful Debug coverage or mock assertions were removed, and no mock implementation was compiled into Release. This diagnostic compile ran no tests; the next focused Release bundle is authoritative below.

Actual Release result: `/private/tmp/staygrubby-release-final-release-complete.xcresult` — **5 definitions / 5 executions passed, 0 failures / 0 unexpected failures / 0 skips / 0 expected failures**. Four built-configuration native tests plus the Release UI gate: both normal launch and attempted development arguments remain at native Apple onboarding, with no ranking/personal tabs, New Dish, guest or development access. No real Apple authorization occurs. Temporary testability does not enable Debug code. The normal Release build and binary inspection above were performed independently before this test instrumentation.

Final read-only hosted fingerprints remain **31/33 identical to the original baseline**, with only the owner-confirmed Recipe/reservation activity already explained above. Cooking/score/evidence/media/Storage and all other groups remain exact; no new users, Storage bytes or hosted test fixtures. All 24 version/name/SQL hashes match. Demo complete manifest remains exact. Privileged-secret/local-artifact scan: **325 text files, zero findings**. Whitespace checks pass for unstaged and staged changes. Protected engine/calibration/private-sync/assets/config/project inspection remains unchanged. Local backups, node dependencies, Supabase linkage, generated website output, CLI caches, build products, personal stores/media and signing credentials remain excluded.

The directly affected avatar suite was rerun after its guard: `/private/tmp/staygrubby-release-avatar-debug.xcresult` — **2/2 tests passed**, 0 failures/skips, proving the retry/removal mock method remains included in Debug. The complete demo/media audit passed again after this final test, with the same `bedd790e…` manifest, identities, evidence and counts. No full regression was repeated after the two narrowly scoped test-compatibility fixes.

### Final Git record

| Checkpoint | Scope | Files |
| --- | --- | --- |
| `dcebf7cf7408353a9b7234930aae296d9bee0111` | Hosted Food Bible deployment/history alignment and review evidence | 2 (one SQL filename-only rename) |
| `07a152dc1453505080e12a76c89c9572a2933422` | Verified draft lifecycle, current assertions/Debug test guards, chronological sync harness, policy and static website preparation | 14 |
| Commit containing this record: **Document V1 release readiness and owner distribution gates** | Central final evidence and owner handoff | 1 |

Final HEAD is this documentation checkpoint; its exact SHA is returned in the completion report (`git rev-parse HEAD`). This avoids a self-referential commit hash inside its own contents. Branch remains **main**. After this record, there are six local commits beyond tracking `origin/main` at `27707003c7edb52d8aef117edfc18e6dbab0336a`, including the three accepted Food Bible commits preserved from the start.

One normal `git push origin main` was attempted after the verified fix checkpoint. It failed with **could not read Username for https://github.com (terminal prompts disabled)**. No force push, history rewrite, credential/configuration change or alternate authentication was attempted. **Owner must push main through GitHub Desktop**, including this final record. No second unauthenticated push is useful. The intended final working tree is clean; final status/HEAD and ahead count are verified after the documentation commit and reported to the owner.

**Final assessment: GO for owner acceptance/preparation, NOT YET for external distribution.** Remaining gates are specifically the owner physical/two-account checks, moderation/filtering/response decisions, policy publication, explicit minimum-iOS support choice and Apple beta/review/privacy/metadata setup. No unresolved automated app regression remains. The real Apple deletion/revocation test remains deliberately deferred and is not a blocker. No TestFlight archive/upload, App Store Connect update, public beta link or Intelligent Recipe Engine was created. Stop this cycle here.
