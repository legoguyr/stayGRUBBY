# StayGrubby V1 Release Gate

Canonical release checklist — reconciled November 22, 2026 against accepted main `c6fb1c3` and owner-accepted Build **1.0 (7)**; MVP timeline (target January 2027, stretch December 2026) and the MVP Required / Post-launch classification live in the [roadmap](STAYGRUBBY_MASTER_ROADMAP.md#development-strategy--accelerated-public-mvp-owner-decision-november-16-2026). External TestFlight is optional; physical iPhone acceptance is owner-led through Xcode. Sequence: internal TestFlight → Connected UI Overhaul and near-term product work → **this gate** → Release Candidate → App Store V1 ([roadmap](STAYGRUBBY_MASTER_ROADMAP.md)). The UI overhaul is the last normal product work before this gate; Discover, Personal Cooking Intelligence, Want to Cook and Collections are not V1 requirements. This gate authorizes no submission, upload, credential change, paid service or destructive real-account test. Record evidence/owner decisions here during the separately requested gate; unchecked items are not compliance claims.

- [x] **Cook / Pass description integrity:** backend chain deployed November 21, client correction integrated into the accepted baseline. Owner approves Build 7 and existing-data checks. Blank new Cooks use nil; intentional unsupported descriptions preserve the causal queue without retry storms. [Contract](COOK_DESCRIPTION_INTEGRITY.md).
- [ ] **Cook / Pass description integrity:** backend deployed November 21, 2026 (`20261121161925`, with the full moderation/text chain); nil-default correction integrated with Claude's Cook-bound UI on `agent/claude` (`7dd1368`), not yet on `main` or in a build; owner physical acceptance pending. Ordinary blank new Cooks remain old-server compatible; intentional unsupported descriptions retain the causal queue without retry loops until deployment and Retry. Preserve and explicitly reconcile legacy conflicts; deploy only after the required pending backend chain and focused acceptance. No Dish fanout, automatic post creation or private-note fallback. [Contract and evidence](COOK_DESCRIPTION_INTEGRITY.md)

## Build 7 candidate — November 22, 2026

- [x] Build 6 physical review: every checklist item passed except three, which are fixed on `agent/claude`: Unlink from Dish, Recently Deleted/Restore, and the launch flash. Focused unit and UI tests pass. Airplane Mode is excluded from this round.
- [x] The first-time onboarding journey is implemented, with automated tests for new, returning and interrupted accounts.
- [x] **Preview First-Time Experience** is Debug-only and installed from Xcode, never distributed through TestFlight (owner decision, November 22, 2026; replaces the short-lived Internal configuration). Release excludes it, and the focused isolation and exit tests pass.
- [x] **1.0 (7) uploaded to TestFlight, internal testing only** on November 22, 2026, with owner authorization. It was archived as Release from `main` `2dfb241`, with the build number passed at archive time; the checked-in setting is unchanged.
  - `check_release_excludes_preview.sh` passed on the archive: no preview code and no developer tools.
  - Info.plist and entitlements were checked, and the privacy manifest is present.
  - Export used `testFlightInternalTestingOnly`, so it can't go to external testers or App Store review.
  - Since Build 6: no data model, migration or backend changes. Database health is ok (149 MB).
- [x] Owner physical acceptance of 1.0 (7) from TestFlight (owner-confirmed, November 22, 2026).
- [x] **1.0 (8) uploaded for external TestFlight** on November 22, 2026 (owner-authorized). It has the same app code as accepted build 7: `main` `c6fb1c3` differs from `2dfb241` only in website and doc files. It used the Release configuration and standard App Store Connect distribution, and the archive passed `check_release_excludes_preview.sh` (no preview code, no developer tools).
- [ ] Beta App Review submission for the existing external group: the owner chose to submit it personally (November 22); outcome not recorded here. No further TestFlight release is required (owner, November 23). Never submit for public App Store release without a separate decision.

## Debug-only first-run preview

Settings › **Developer Tools — Debug Only** › *Preview First-Time Experience* exists only in Debug builds installed directly from Xcode. It is compiled out of Release, and TestFlight and App Store builds are always Release, so it can't be distributed by mistake. The AGENTS.md rule is unchanged: developer and test controls never compile into Release. There is no Internal configuration or scheme.

- **Check:** `sh DevelopmentTools/check_release_excludes_preview.sh` verifies that Release doesn't compile `DEBUG` and that the StayGrubby scheme archives Release. It then builds Release and confirms the preview is absent. Pass an `.xcarchive`, `.app` or `.ipa` to scan a specific build.
- **Owner use:** connect the iPhone and run the **StayGrubby** scheme in Xcode (Product → Run, which builds Debug). Reinstall from TestFlight afterwards to return to the normal build.

## Current public-launch decision — November 22, 2026

**Not yet cleared for public submission. No confirmed live cross-account exposure or data-loss defect was found.** Owner acceptance of Build 7 and live Website V2 is preserved. [Current security evidence and exact remaining actions](PUBLIC_LAUNCH_SECURITY_REVIEW.md) supersede the older pending-deployment/build statements below.

- [x] Read-only production parity: all **65** migration versions and ordered statements match; 40 critical function/grant definitions and 31 application/Storage policies match the isolated current schema. No pending migration or deployment is required by this audit.
- [x] Four photo buckets remain private. RLS/grants and focused disposable tests cover owner/shared/blocked/moderated access and erasure peer isolation. Missing/foreign-signature Edge requests are rejected; both hosted functions retain JWT verification and match checked-in source.
- [x] Disposable signed Auth/Gateway/Storage/erasure rehearsal: **34 actual HTTP/SQL checks pass** using CLI 2.120.0 native runtime and synthetic accounts; original private peer bytes survive erasure. No Gemini or Apple revocation. This verifies the local candidate, not a live signed production-user probe.
- [ ] Approve integration/deployment of `20261123035208_staff_reported_photo_operation.sql`: actual Storage uses `storage.object.get_authenticated`; the deployed staff predicate directly compares the unprefixed name. The correction reuses the existing normalized allowlist helper and passes 22 focused assertions plus the real local byte path. No grants, records or policies change.
- [ ] Prepare the minimal admin/moderator distinction and audited role controls, then enroll **only the owner’s existing account** with separate approval and exercise the authenticated staff workflow. No backup/new account is required. Production has **zero** reviewer memberships; API contracts exist, but no staff-facing operations client was found. Agree response/escalation coverage and App Review 1.2 filtering disposition. No mandatory image approval or paid classifier.
- [ ] Approve/publish Terms, Community Guidelines and appropriate Recipe/allergen/estimate safety language; `/terms` currently returns 404. Privacy/Support render correctly; hosted Privacy HTML matches the current build output.
- [ ] Complete owner App Store privacy/age-rating answers and a working Apple-only reviewer-access procedure. The privacy manifest is not a substitute for App Store privacy disclosures.
- [ ] Prove an external capacity alert reaches a named operator; document a practical backup/recovery procedure. Cron is active, but delivery is log-only and the Free project has no managed backups.
- [x] Dashboard disk headroom: **0.31 GB / 2 GB (16%)**; current monitor has no alerts. No upgrade, throttling activation or sync rewrite is justified. Keep structured-sync throttling off while Build 5 is supported.


## Build 7 — owner accepted November 22, 2026

- [x] Build 6 physical review: every checklist item passed except three, which are fixed on `agent/claude`: Unlink from Dish, Recently Deleted/Restore, and the launch flash. Focused unit and UI tests pass. Airplane Mode is excluded from this round.
- [x] The first-time onboarding journey is implemented, with automated tests for new, returning and interrupted accounts.
- [x] **Preview First-Time Experience** is Debug-only and installed from Xcode, never distributed through TestFlight (owner decision, November 22, 2026; replaces the short-lived Internal configuration). Release excludes it, and the focused isolation and exit tests pass.
- [x] Owner physical acceptance: complete onboarding, Recipe recovery, launch experience and existing data checks passed. Archive metadata is **1.0 (7)** (owner shorthand “1.0.7”), iOS 17.0 minimum; the archived Release passes the Debug-preview exclusion scan. This audit authorizes no new upload or distribution.

## Debug-only first-run preview

Settings › **Developer Tools — Debug Only** › *Preview First-Time Experience* exists only in Debug builds installed directly from Xcode. It is compiled out of Release, and TestFlight and App Store builds are always Release, so it can't be distributed by mistake. The AGENTS.md rule is unchanged: developer and test controls never compile into Release. There is no Internal configuration or scheme.

- **Check:** `sh DevelopmentTools/check_release_excludes_preview.sh` verifies that Release doesn't compile `DEBUG` and that the StayGrubby scheme archives Release. It then builds Release and confirms the preview is absent. Pass an `.xcarchive`, `.app` or `.ipa` to scan a specific build.
- **Owner use:** connect the iPhone and run the **StayGrubby** scheme in Xcode (Product → Run, which builds Debug). Reinstall from TestFlight afterwards to return to the normal build.

## Historical Build 6 internal candidate — November 15, 2026

- [x] Combined `f7b0c19` with the previously deployed backend safeguards and the Build 5 target configuration. Generic iPhone Release compile succeeded with Xcode 27.2. Signing was disabled for the compile.
- [x] Hosted read-only check confirmed both safeguards, a fresh healthy capacity sample, authenticated-only sync RPCs, private owner photo metadata operations and no structured sync throttle. The database health SQL returned six OK verdicts. Prior backend and migration verification remains the same.
- [ ] Complete the physical smoke gate on a signed Build 6 candidate. Include a first-time Apple setup, existing-account in-place update with any pending local work preserved, a new private photo with restore/second-device read, and the ranking → immediate share → The Pass path. Confirm the Dashboard's full disk distribution in addition to PostgreSQL-visible health.
- [ ] Confirm the next available App Store Connect build number at release time. Obtain separate approval for signing/archive and internal TestFlight upload/group assignment. The branch retains the checked-in build settings.

Keep the write throttle off while Build 5 remains supported. Future changes require minimum-build enforcement and verification of the real cooldown response on supported client transports. The two signed Edge Function probes waived for Build 5 remain unverified; any Build 6 waiver requires an explicit decision.

## Hard V1 blockers / required gate evidence

- [x] Implement and locally verify Recipe reports, a staff-authorized review queue and audited hide/dismiss. The populated local upgrade rehearsal preserved accounts, cooking/ranking evidence, Recipes, prior reports and the synthetic Storage catalog, and verified report access, peer isolation and erasure. Existing post, comment and profile reports and server blocks remain in use. [Moderation runbook and API contracts](PUBLIC_MVP_MODERATION.md).
- [x] Integrate the optional social `dishKey` and exact-Dish paging into iOS, preserving renamed Dish identity, locked scores, first-page cache bounds and legacy-card behavior. Focused native and affected Dish Details UI checks passed. Hosted migration/acceptance remains a separate gate.
- [ ] **Staff moderation interface (Settings → Moderation):** client and `api.staff_status` integrated locally; flag `staff_moderation` off; automated acceptance passed, owner physical acceptance pending. Before enabling: deploy the three security migrations, enroll the pinned `@grubwithguy` account, ship a build with the interface, then enable the flag. [Interface and activation order](PUBLIC_MVP_MODERATION.md#in-app-staff-interface-settings--moderation)
- [x] Ordered moderation, owner-private Recipe, sharing, text-screening and canonical Cook-description chain deployed November 21; all 65 migration entries match on November 22. No redeployment is needed. [Deployment record](PUBLIC_MVP_MODERATION.md#rehearsal-and-deployment). Staffed end-to-end rehearsal remains separately unchecked above.
- [ ] Confirm an actionable capacity alert reaches its assigned operator. The active five-minute Cron currently logs to Supabase Postgres Logs. The read-only external check passed offline. Approve the monitoring login and delivery destination, verify receipt and confirm Dashboard disk headroom. [Delivery and response](supabase/README.md#external-capacity-alert-delivery).
- [ ] Accept text-screening boundaries and rehearse immediate image publishing, report-based staff removal and privacy/cache revocation. Enroll named report reviewers and establish coverage; do not require approval of every image. No image provider, key, classifier or scheduler is required. Record the App Review 1.2 filtering disposition and approve Community Guidelines/contact coverage without claiming that file validation filters objectionable images. Coordinate `PT422` explanations and pending photo states for social clients. Confirm staffed response and a reachable support/contact path. [Filtering acceptance and operating responsibilities](PUBLIC_MVP_MODERATION.md#technical-safeguards). Keep the public release gate open until these are verified.
- [x] Focused read-only SQL/configuration and disposable security review completed November 22; signed HTTP/byte-transport acceptance remains separately open above. No private activity may leak through profiles/counts.
- [x] Deploy the Recipe cook lifecycle and D1 Dish Recipe links migrations with scoped before/after fingerprints. Deployed November 8 (hosted `20261108171024` lifecycle, `20261108171120` Dish Recipe links); all 43 hosted/local migration hashes match; before/after counts and content hashes of dishes, cooks, ranked items, comparisons, Recipes, revisions, legacy Dish links, cook links, used snapshots, posts and sync operations were identical, and the 1 legacy link was copied once (not Main). ([food architecture §3](FOOD_ARCHITECTURE.md#3-one-dish-identity-owner-decision-11)).
- [x] Deploy D2 `20261108210256_food_bible_dish_resolution` (read path only). Deployed November 8: all 44 hosted/local hashes match; counts and content hashes of every cooking, Recipe, link, post and sync table identical; predecessor function body byte-identical; client privileges unchanged.
- [x] Deploy `20261108221250_dish_recipe_identity` (adds `recipes.dish_id`, narrows the Recipe History archive trigger). Deployed November 8: all 45 hosted/local hashes match; every table count and content hash unchanged except the new column; all 5 Recipes took exactly the predicted existing, active Dish; no Recipe History rows added; replaced function bodies byte-identical; client privileges and RLS unchanged.
- [x] Deploy `20261108234407_feature_flags`. Deployed November 8: all 46 hosted/local hashes match; every existing table count and content hash unchanged; the table is empty, RLS-closed with no client grants; only authenticated callers can execute `api.feature_flags`; no new advisor findings beyond the expected RPC-only note.
- [x] Deploy `20261109002508_food_bible_diet_index` (read path only). Deployed November 9: all 47 hosted/local hashes match; every table count and content hash unchanged; replaced function body byte-identical; privileges unchanged.
- [ ] On authorized test identities, confirm exact-revision restore, owner privacy and stale-link retirement on authorized test identities. Review dated reaction retention and disclosure alongside the cooking sync/deletion contract. [Data foundation follow-up](V1_DATA_FOUNDATION_AUDIT.md#november-8-follow-up). This deployment precedes D1 because Dish Recipe links and Main Recipe build on it ([food architecture §2.1](FOOD_ARCHITECTURE.md#21-accepted-provenance-and-integrity-codex-a6de6b8)).
- [ ] Account deletion and associated UGC/media cleanup review using isolated test identities. The [cooking-photo manifest fix](supabase/CLEAN_MIGRATION_PHASE_2A.md#account-erasure-blocker) passed the disposable import, erasure, retry and peer-isolation checks. The hosted source remains read-only on the old function. The target correction was applied before the verified November 13 import. See [Phase 2B live progress](supabase/CLEAN_MIGRATION_PHASE_2A.md#phase-2b-live-progress) for reconciliation and controlled Apple/JWT acceptance gates. Real Apple revocation testing requires a separately authorized disposable account/device.
- [ ] Publish/approve Terms of Use and Community Guidelines. The app side is built ahead behind the `legal_terms` flag: Settings links and the kitchen-setup agreement line. Enable it only after both pages are live ([drafts](APP_STORE_SUBMISSION.md)). Neither dedicated document is currently supplied by the existing website builder; this is genuine release-gate work.
- [ ] Appropriate Recipe/allergen/serving/quantity-estimate disclaimers and actionable safety coverage in Terms/disclaimer/safety documents. Cover AI/editor interpretation and missing/estimated amounts, scaling/serving estimates, ingredient-derived Contains/Possible, product-label/substitution/cross-contact limitations and user review. The November 6 UI correction intentionally removes repeated generic estimate paragraphs and collapses draft review; it does not fulfill this legal obligation. Do not put non-privacy limitations solely in the Privacy Policy or repeat them throughout readers.
- [x] Hosted Privacy Policy matches the current generated canonical page byte-for-byte (November 22). For any production website publish, run the [Worker and assets deployment](Website/README.md#source-verification-and-deployment) and require its live-link gate before release. Verify browser fallbacks as well as AASA.
- [ ] Confirm current Privacy Policy, external-AI consent and actual social/cloud/photo/data processing; update App Store privacy disclosures accordingly. Privacy manifest corrected November 22, 2026: disk space E174.1, file timestamp C617.1, no tracking. Proposed labels are in [APP_STORE_SUBMISSION.md](APP_STORE_SUBMISSION.md).
- [ ] **Gemini API terms (public-launch blocker, found November 22, 2026):** Paste Recipe uses the unpaid Gemini API. Google's current terms require users to be 18 or older, exclude apps likely to be accessed by under-18s, and allow only paid services for users in the EEA, UK and Switzerland. This needs an owner decision with legal advice ([APP_STORE_SUBMISSION.md §3a](APP_STORE_SUBMISSION.md)).
- [ ] Verify public Support/contact and policy destinations, contact ownership and response process. Stage 5 supplies Settings access, not an operations/compliance certification.
- [ ] Complete age-rating/social-media/UGC considerations using current platform requirements during the gate.
- [ ] Verify Sign in with Apple, account readiness/sign-out, offline ready-account behavior and App Review access strategy. The migration target passed native Apple sign-in, original-account restore, photos, signed target library HTTP access and relaunch on the owner’s iPhone. Separate issuers and signing keys were verified. The local update path preserved pending work in focused tests. Build 1.0 (5) is available to the four internal Alpha Testers. The owner waived the two live signed Edge Function probes for this rollout; both remain unverified. The owner verified the build 5 update in place, original account, library, photos and sync. Wider distribution requires separate approval. [Final staging acceptance](supabase/CLEAN_MIGRATION_PHASE_2A.md#final-staging-acceptance)
- [ ] Disposition existing security advisories, including the leaked-password linter warning against the intended Apple-only Auth configuration. Do not change Auth settings merely to suppress a warning.
- [x] Verify the migrated target excludes `development-test-session`. Hosted probes returned 404 and the checked-in default configuration skips deployment.
- [ ] Verify signed target Edge Function calls to `recipe-import` and `delete-account` on an authorized session. Hosted missing and malformed JWT probes returned 401 for both. Local tests cover handler authorization and refusal before mutation. The earlier internal waiver does not satisfy this public gate.
- [ ] Grub Rank score/order semantic consistency investigation concluded and its owner-approved presentation implemented (no ranking math change without explicit reopening). See [architecture](STAYGRUBBY_ARCHITECTURE.md#ranking--protected).
- [ ] At release, switch `Website/distribution.json` to the verified App Store listing (Website V2 renders the homepage CTA wording from it: "Download on the App Store"). Use `sh Website/deploy-production.sh` for production, including from the Cloudflare Git build trigger, and require the live HTML and acquisition-link checks to pass.
- [ ] Production configuration/signing/entitlements/portrait identity, iOS 17+ physical smoke and retirement of incompatible historical TestFlight builds where needed, client-safe configuration, secrets/local-artifact scan and no Release development bypass.
- [ ] One release-candidate regression/crash review proportionate to final changes, including real-device photos/auth/sync/sharing/accessibility where needed; resolve actual blockers without reopening frozen systems.
- [ ] Prepare and owner-approve a release TestFlight candidate; obtain owner approval before archive/build-number changes/upload/distribution.
- [ ] Prepare App Store metadata/screenshots, reviewer instructions and final submission checklist. Obtain explicit owner approval before submission/publication.

## Pre-TestFlight / pre-App Store smoke gate (every candidate)

Added after the [November 11, 2026 P0 incident](supabase/README.md#p0-incident-retry-storm-read-only-database--november-11-2026): automated suites ran on PGlite/mocks and never exercised the hosted PostgREST retry behavior, the read-only database or physical Apple sign-in. **A TestFlight build is not release-ready until all of these pass on a production-like (Release) build against the hosted project:**

1. Backend: `npm test` in `Backend/tests` passes, including the schema guard that no function raises a PostgREST-retried SQLSTATE.
2. Database health: `DevelopmentTools/database_health.sql` shows no STOP verdict, and the dashboard Disk Size Distribution is below 70% (between 70% and 80% only with a written explanation).
3. Fresh install → Sign in with Apple completes to the ready library.
4. Existing-account sign-in restores the same account (same Dishes, cooks, Recipes and history).
5. An existing private photo loads.
6. A new photo backs up and loads after reinstall or on a second device.
7. Ranking completes.
8. Share immediately after ranking succeeds.
9. The The Pass shows the post.
10. A second device restores the account.

Record the build, date, device and result here. A failure message on the gate screen now carries a support code (`SG-NET` connection, `SG-SVC` service, `SG-AUTH` sign-in, `SG-ERR` other) that points to the failing layer.

- [ ] Smoke gate recorded for the next TestFlight candidate.
- [ ] Build 6 candidate includes the November 15 sync-efficiency client. Before enabling any server write throttle, establish a compatible minimum supported build and verify transport cooldown behavior.
- [x] November 11, 2026 incident repaired and accepted: `20261111020303_non_retryable_conflicts` deployed; all 48 hosted/local migrations aligned; all 43 table fingerprints unchanged; retry storm stopped. Owner physical acceptance PASSED on TestFlight Build 4: existing phone (sign-in, photos, sync, ranking, share), fresh install and second-phone restore.
- [x] Current migrated target is below 70%: 0.31 GB / 2 GB on November 22. The old-source disk incident is historical; do not modify the frozen source.
- [ ] Next TestFlight build carries the incident client fixes (PT409 conflicts, classified sign-in errors, share revision retry, stale share-draft retirement, sharp Recipe fallback photos) and passes the smoke gate above.

## Recommended but deferrable

- Additional device/text-size coverage beyond supported representative checks, low-impact copy/pixel refinements, expanded beta feedback and nonessential analytics.
- Broader performance profiling only if observed latency/memory/crash evidence warrants it.
- Larger moderation tooling only when necessary scale/operations evidence exists; roles and entitlements remain separate.

## Post-V1 — not release blockers

- Crop/reposition/advanced galleries/editing and optional photography improvements; existing upload/ownership/multi-photo/sync/restore remain V1.
- Recipe Unit Conversion improvements (controls hidden), detailed Recipe Social History beyond the near-term Makes and Saves counts, Run It Back redesign and broader Source integrations.
- Want to Cook, Collections / Cooking Series, Stars, Personal Cooking Intelligence (Flavor/Ability Profiles), Discover, rich external link previews and meal planning (dormant).
- Public discovery/feed, optional Contacts, referral/invite analytics, five-tier referral progression/rewards, manual entitlements/tester tooling, broader admin/follower/push/community/creator systems and monetization.
- A referral counts only after an attributed genuinely new successful signup. Core functionality cannot require recruiting friends. Rewards are undecided; no AI daily allowance, billing or paid-provider setup is introduced by this roadmap.

Follow [AGENTS](AGENTS.md) and [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md): only product coherence, safety/privacy/platform compliance, integrity and a credible first public release justify moving a feature ahead of V1. Do not start another normal feature stage automatically.

**November 23 final security candidate:** both photo normalization and staff roles are local/tested, not deployed. Owner identity `grubwithguy` has one active read-only match; no enrollment performed. Twenty role assertions, real concurrent demotion and encrypted restore of all Auth/application/Storage-catalog tables plus seven photo files across four buckets pass. Free-email setup and backup destination/key custody remain owner actions. [Exact final activation package](DevelopmentTools/operations/README.md). No merge/push/deployment or Apple auth/demo change authorized.

**Staff interface integration, November 23:** Claude `005a178` is implemented/verified on its branch; Codex now supplies the compatible stable `api.staff_status` own-role projection and staff-only delivery of `staff_moderation`. Three security migrations await authorized integration/deployment; no enrollment/flag activation. [Ordered integration and activation](DevelopmentTools/operations/README.md#staff-status-and-claude-005a178-integration). No native UI or production data changed in the endpoint cycle.
