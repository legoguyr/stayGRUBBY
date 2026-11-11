# StayGrubby V1 Release Gate

Canonical release checklist — reconciled November 7, 2026 at Build 4 (`c09c18e`). Sequence: Build 4 (complete) → unified Dish foundation and UI overhaul (D1 → D2 → F → C → E → G) → **this gate** → Release Candidate → App Store V1 ([roadmap](STAYGRUBBY_MASTER_ROADMAP.md)). The UI overhaul is the last normal product work before this gate; Discover, Personal Cooking Intelligence, Want to Cook and Collections are not V1 requirements. This gate authorizes no submission, upload, credential change, paid service or destructive real-account test. Record evidence/owner decisions here during the separately requested gate; unchecked items are not compliance claims.

## Hard V1 blockers / required gate evidence

- [ ] UGC filtering appropriate to the product; working Report/Block entry points and enforcement across posts, comments, Recipes (including the new creation activity), profiles and shared destinations. Review account-level Recipe activity reporting/hidden-profile enforcement and whether object-level Recipe moderation is required; the activity does not reuse cooking-post moderation IDs.
- [ ] A complete report → review → resolution capability and staffed moderation process, escalation/contact and auditable outcomes. Broad admin dashboards are not required merely to satisfy this operational need.
- [ ] Focused privacy/security review of current audience rules, RLS/private Storage, account isolation, revocation, shared links and data flows. No private activity may leak through profiles/counts.
- [x] Deploy the Recipe cook lifecycle and D1 Dish Recipe links migrations with scoped before/after fingerprints. Deployed November 8 (hosted `20261108171024` lifecycle, `20261108171120` Dish Recipe links); all 43 hosted/local migration hashes match; before/after counts and content hashes of dishes, cooks, ranked items, comparisons, Recipes, revisions, legacy Dish links, cook links, used snapshots, posts and sync operations were identical, and the 1 legacy link was copied once (not Main). ([food architecture §3](FOOD_ARCHITECTURE.md#3-one-dish-identity-owner-decision-11)).
- [x] Deploy D2 `20261108210256_food_bible_dish_resolution` (read path only). Deployed November 8: all 44 hosted/local hashes match; counts and content hashes of every cooking, Recipe, link, post and sync table identical; predecessor function body byte-identical; client privileges unchanged.
- [x] Deploy `20261108221250_dish_recipe_identity` (adds `recipes.dish_id`, narrows the Recipe History archive trigger). Deployed November 8: all 45 hosted/local hashes match; every table count and content hash unchanged except the new column; all 5 Recipes took exactly the predicted existing, active Dish; no Recipe History rows added; replaced function bodies byte-identical; client privileges and RLS unchanged.
- [x] Deploy `20261108234407_feature_flags`. Deployed November 8: all 46 hosted/local hashes match; every existing table count and content hash unchanged; the table is empty, RLS-closed with no client grants; only authenticated callers can execute `api.feature_flags`; no new advisor findings beyond the expected RPC-only note.
- [x] Deploy `20261109002508_food_bible_diet_index` (read path only). Deployed November 9: all 47 hosted/local hashes match; every table count and content hash unchanged; replaced function body byte-identical; privileges unchanged.
- [ ] On authorized test identities, confirm exact-revision restore, owner privacy and stale-link retirement on authorized test identities. Review dated reaction retention and disclosure alongside the cooking sync/deletion contract. [Data foundation follow-up](V1_DATA_FOUNDATION_AUDIT.md#november-8-follow-up). This deployment precedes D1 because Dish Recipe links and Main Recipe build on it ([food architecture §2.1](FOOD_ARCHITECTURE.md#21-accepted-provenance-and-integrity-codex-a6de6b8)).
- [ ] Account deletion and associated UGC/media cleanup review using isolated/test identities. Preserve valid synchronization history semantics; do not require deleting Guy's real account. Real Apple revocation testing is intentionally deferred and needs a separately authorized disposable account/device procedure where necessary.
- [ ] Publish/approve Terms of Use and Community Guidelines. Neither dedicated document is currently supplied by the existing website builder; this is genuine release-gate work.
- [ ] Appropriate Recipe/allergen/serving/quantity-estimate disclaimers and actionable safety coverage in Terms/disclaimer/safety documents. Cover AI/editor interpretation and missing/estimated amounts, scaling/serving estimates, ingredient-derived Contains/Possible, product-label/substitution/cross-contact limitations and user review. The November 6 UI correction intentionally removes repeated generic estimate paragraphs and collapses draft review; it does not fulfill this legal obligation. Do not put non-privacy limitations solely in the Privacy Policy or repeat them throughout readers.
- [ ] Verify that the hosted Privacy Policy matches the bundled canonical version. For any production website publish, run the [Worker and assets deployment](Website/README.md#source-verification-and-deployment) and require its live-link gate before release. Verify browser fallbacks as well as AASA.
- [ ] Confirm current Privacy Policy, external-AI consent and actual social/cloud/photo/data processing; update App Store privacy disclosures accordingly.
- [ ] Verify public Support/contact and policy destinations, contact ownership and response process. Stage 5 supplies Settings access, not an operations/compliance certification.
- [ ] Complete age-rating/social-media/UGC considerations using current platform requirements during the gate.
- [ ] Verify Sign in with Apple, account readiness/sign-out, offline ready-account behavior and App Review access strategy. Automated fixtures cannot establish physical Apple authorization.
- [ ] Disposition existing security advisories, including the leaked-password linter warning against the intended Apple-only Auth configuration. Do not change Auth settings merely to suppress a warning.
- [ ] Review the production `development-test-session` Edge Function (v1, administrator-proof gated, JWT on): keep with documented justification or remove under separate authorization before public release.
- [ ] Grub Rank score/order semantic consistency investigation concluded and its owner-approved presentation implemented (no ranking math change without explicit reopening). See [architecture](STAYGRUBBY_ARCHITECTURE.md#ranking--protected).
- [ ] At release, update the homepage beta wording and switch `Website/distribution.json` to the verified App Store listing. Use `sh Website/deploy-production.sh` for production, including from the Cloudflare Git build trigger, and require the live HTML and acquisition-link checks to pass.
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
9. The Grub List shows the post.
10. A second device restores the account.

Record the build, date, device and result here. A failure message on the gate screen now carries a support code (`SG-NET` connection, `SG-SVC` service, `SG-AUTH` sign-in, `SG-ERR` other) that points to the failing layer.

- [ ] Smoke gate recorded for the next TestFlight candidate.
- [x] November 11, 2026 incident repaired: `20261111020303_non_retryable_conflicts` deployed; all 48 hosted/local migrations aligned; all 43 table fingerprints unchanged; retry storm stopped. Owner physical acceptance pending.

## Recommended but deferrable

- Additional device/text-size coverage beyond supported representative checks, low-impact copy/pixel refinements, expanded beta feedback and nonessential analytics.
- Broader performance profiling only if observed latency/memory/crash evidence warrants it.
- Larger moderation tooling only when necessary scale/operations evidence exists; roles and entitlements remain separate.

## Post-V1 — not release blockers

- Crop/reposition/advanced galleries/editing and optional photography improvements; existing upload/ownership/multi-photo/sync/restore remain V1.
- Recipe Unit Conversion improvements (controls hidden), Saved Recipes/bookmarks (name TBD), privacy-aware Recipe Social History/Made X times, Run It Back redesign and broader Source integrations.
- Want to Cook, Collections / Cooking Series, Stars, Personal Cooking Intelligence (Flavor/Ability Profiles), Discover, rich external link previews and meal planning (dormant).
- Public discovery/feed, optional Contacts, referral/invite analytics, five-tier referral progression/rewards, manual entitlements/tester tooling, broader admin/follower/push/community/creator systems and monetization.
- A referral counts only after an attributed genuinely new successful signup. Core functionality cannot require recruiting friends. Rewards are undecided; no AI daily allowance, billing or paid-provider setup is introduced by this roadmap.

Follow [AGENTS](AGENTS.md) and [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md): only product coherence, safety/privacy/platform compliance, integrity and a credible first public release justify moving a feature ahead of V1. Do not start another normal feature stage automatically.
