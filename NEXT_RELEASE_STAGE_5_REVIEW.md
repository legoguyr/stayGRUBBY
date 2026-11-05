# Stage 5 — Final Product Polish & V1 Readiness

November 5, 2026. Baseline clean main `7a2f7a389cac5b107c67bbf8c90c759651c9b64a`. Automated acceptance passed; owner physical acceptance and the separate compliance/release gate remain pending. One agent/current checkout/one Simulator lane. This stage replaces Photography and the former Stage 6 sequence; no further normal product stage starts automatically.

## Product changes / decisions

- As Written / US / Metric controls are hidden in every normal Recipe reader through the central false presentation gate. Conversion code/mappings/tests remain for post-V1. Written quantities, serving scaling, source content/revisions and exact cook snapshots remain intact.
- My Kitchen has a two-card owned-Recipe preview, reusing the same Food Bible card, Recipe photo transport and reader. Owner See All selects the real Food Bible tab and resets its navigation root. Other Kitchens have only authorized Recipe summaries and a paginated See All view. No bookmarks, private counts, private notes/history bodies or other users' cook IDs are exposed. Owner-only local cook-photo fallback is retained; foreign profile cards use authorized Recipe-owned photos/placeholders.
- Minimal `recipes.profile_index` branch reuses existing ownership/visibility/session/RLS boundaries, 25-item UUID pagination and closed raw tables. No new table/backfill/visibility policy/Storage writes/Edge Function/provider/credential change. New SQL deployment is explicitly authorized by the Stage 5 prompt after verification.
- Reused card no longer reserves an empty metadata line. New compact text actions have 44-point targets. Corrected Sous Chef removal language and made sharing-default wording truthful for both New Dish/New Version.
- Settings has one canonical offline-capable Privacy Policy reader plus its public link, and Support opens the existing public Support page. The redundant policy entry under Account & Sync is removed. Existing sign-out and deliberate deletion flow remain there; no real authorization/deletion is performed.
- Advanced photography, Recipe conversion, Saved Recipes/name TBD, privacy-aware Recipe Social History, Run It Back redesign, Source expansion and growth/admin/referral systems are post-V1. Referral success means an attributed genuinely new completed signup; five-tier concepts/rewards are not implemented or finalized. Core functionality cannot depend on recruiting friends.

## Deliberate surface audit

| Surface | Finding / disposition |
| --- | --- |
| Grub List / post detail | Accepted hierarchy, Hands, Comments, authorized metadata and compact sharing retained; no speculative redesign. Included in scoped product regression. |
| Grub Rank / cook/rank/detail | Accepted global ranks, score gates/colors, versions, compact entry/Details/tagging/re-rank remain. Existing end-to-end cooking regression selected once. |
| Food Bible / Recipe / history/editor | Hide unreliable conversion UI, retain serving/history/save semantics, reuse existing cards and correct empty metadata spacing. Creator pipeline unchanged; offline accepted draft fixture mapping selected, no live AI. |
| My Kitchen / other profile | Add compact owned Recipes with direct reader/library access; current server authorization is mandatory. No private cooking projections on other profiles. |
| Discovery / Requests / people selection | Existing symmetric Sous Chef/search/selector model retained; removal wording corrected. Requests/block/search regression selected. |
| Comments / Send / Order Up! | Existing keyboard-aware sheet, recipients and account-scoped foreground/read state retained; focused interaction/delivery routing scenarios selected. No APNs/chat. |
| Settings / account / policy/support | Remove duplicate policy destination, preserve offline policy reading and account actions. Support points to working public destination; Terms/Guidelines remain actual release-gate work. |
| Empty / loading / error / revoked | New previews expose concise empty/loading/retry; foreign pages clear on reauthorization/error/scene changes. Existing unavailable/social block behavior remains. No backend jargon added. |
| Photos / sharing | No gallery/editor/sync rewrite. Existing crop/cover/Recipe-cook ownership, lock-safe native exports and pointer routes remain; original media fingerprints and focused photo/security tests protect them. |
| Accessibility / small portrait | Native navigation/sheets, standard/large Dynamic Type, light/dark, Reduce Motion, keyboard, icon labels and tap targets reviewed through affected checks/screenshots. No landscape/iPad scope. |
| Debug/legacy terminology | Development tools remain visibly Debug-only with isolated UUID store/media and compile guards. Code/history/migration names remain intentional; no old brand/Followers/Cook Recipe/Link a Cook labels found in normal visible controls. |

## Verification / integrity ledger

- Local original-data/media baseline captured read-only before work; hosted 41 original data/Storage fingerprint groups captured before schema work. No real account/user/Recipe/photo fixtures are written remotely.
- CLI v2.120.0 retained; current changelog's v3 local-default breaking change reviewed. No upgrade/auth/configuration workaround. CLI-created local file was aligned byte-identically to deployed `20261105214537_stage5_kitchen_recipes.sql` (MD5 `5baa3e19ba76dfe817e1febd7167b019`). All 37 hosted/local migration hashes match; reference schema exactly concatenates migrations.
- First prototype compile exposed private access on the existing shared route; route visibility was generalized instead of creating another destination/card. Debug build now passes.
- New local Kitchen authorization tests: **23 assertions pass** (own/private/shared, borrowed/bookmarked exclusions, strangers/blocks/revocation, private-ID redaction, stable bounded pagination, closed anonymous/raw/predecessor access and revoked sessions). Schema/RLS/reference chain: **85 assertions pass**.
- First focused bundle: three native checks and the foreign-profile accessibility UI passed; owner/error UI exposed a container identifier overriding child action identifiers. Removed the unnecessary container identifier, fixed directional test scrolling and added real 44-point text-action targets. Assertions are retained; both targeted reruns now pass. All three new UI scenarios pass, with no remaining focused failure.

## Release readiness boundaries

[V1 Release Gate](V1_RELEASE_GATE.md) is the canonical next-cycle checklist. Terms of Use/Community Guidelines publication, moderation operations/process and platform/privacy/release verification remain genuine gate items, not completed by this product stage. No aspirational admin/growth/photo/conversion feature becomes a release blocker. No TestFlight/build-number/archive/App Store action here.

Physical checks will be consolidated once: real Apple/session restoration, two-account Recipes/relationships/revocation/Order Up!, native Messages/Safari HTTPS opening, photo upload/restore and representative device accessibility as appropriate. Existing Stage 3 physical sharing limitations remain evidence, not silently accepted by mocks.


## Hosted deployment closeout

The authorized function-only migration is deployed. All 41 preexisting full-row data/Storage fingerprints are identical before/after; Storage remains **83 objects**, its Stage 5 baseline (not a new object created by this stage). All private tables retain RLS, authenticated Recipe wrapper access remains enabled, anonymous wrapper and direct predecessor execution remain denied, and direct client writes remain zero. Security advisor is unchanged: 27 expected INFO closed RPC-only RLS tables and the preexisting leaked-password-protection warning; disposition belongs in the Apple-only production-config review at the release gate. No credential/Auth/billing/Storage configuration changed.

Focused backend regression: **289 assertions pass** across schema/RLS (85), new Kitchen collection (23), Recipe/cook links (32), Recipe photo/media access (19), Recipe history/tickets/links (42), directed sharing (30), Sous Chef relationships (31) and Hands/Comments (27). These are isolated multi-account PGlite checks, not real-account writes.

## Final verification

- **50 distinct native test methods pass** (58 executions including dynamic parameter cases), covering session/account boundaries, sort/evidence preservation, serving math, Recipe/cook/photo links, new presentation/routing, and seven offline Recipe Creator tests with retained French toast/Shakshuka/kale/v27 structures. No fresh Apple/Gemini/provider request is part of this evidence.
- **14 distinct UI scenarios pass** on iPhone 17e/iOS 26.5 (390-point upright portrait), including isolated account gate/development exit, full create/version/edit/re-rank/delete/relaunch, standalone Recipe save/edit/history/restore/fork/relaunch, Kitchen Recipes, Requests/acceptance/blocking, Hands/Comments, Send/Order Up!, native Copy payload, four-tab light/dark geometry/bottom reach, hidden units with serving scaling, Settings/policy/deletion-confirmation cancellation and forced offline preview recovery. Standard/large accessibility type, Reduce Motion and keyboard composition are covered. Screenshots were inspected; smaller legacy hardware and actual VoiceOver/device behavior remain physical checks, not claimed automation.
- The single broad bundle initially reported **53/55 passing, two navigation failures, zero skips**. Existing test helpers tapped Requests/Settings before confirming selection/destination. Bounded state-aware waits/re-taps retain all meaningful assertions; the two targeted cases subsequently pass, alongside all seven Creator fixture tests (**9/9**). The earlier owner/offline Kitchen identifier/scroll fixes also pass **2/2**. No expensive full-suite repeat or app behavior weakening was used to obtain these results. No unresolved test failure/skip remains in the selected scope.
- **Debug and Release simulator builds succeed.** The Release executable contains none of the new fixture flags/private fixture title or development-library label. Existing concurrency compiler warnings remain. Three non-failing `Invalid frame dimension` runtime warnings occurred during keyboard focus in cooking, Recipe editing and Comments; each flow continued successfully. They have no proven visible failure in this evidence and are retained for the release-candidate diagnostics review rather than prompting an unrelated redesign.
- **289 focused backend assertions pass** as itemized above. **18 Worker route tests and seven website builder/policy tests pass.** Final deployed real HTTP verification passes **22 GET/HEAD checks**, including direct inline HTML/no redirects, invalid-route fallback, both exact AASA responses, Privacy and Support.
- Final read-only local check matches the original baseline exactly in both development-store copies: **1 ranking / 12 Dishes / 15 CookingAttempts and RankedItems / 356 Comparisons / 10 Sources / 21 tags / 48 memberships**, with **190 original JPEG hashes** unchanged. The hosted 41-group/83-object fingerprint and 37-migration verification above remain intact; no real remote test records or Storage bytes were created.
- Privileged-secret/local-artifact scan: **541 text files, zero findings**. Whitespace and changed-document local-link checks pass. No ranking, Creator, stored quantities/scores, sync, auth, photo architecture or account data changes. Release/distribution versions were not changed.

## Actual hosted sharing regression found during the audit

The final public HTTP check initially failed: valid profile/Recipe/post pointers returned empty untyped 404s. Read-back proved active version `a53e89dd-e0fc-4f7c-a8eb-3961e287886d` was assets-only (no handler/bindings, Worker-first disabled), displacing the accepted Stage 3 router. Privacy/Support/static AASA still returned 200. This is deployed configuration drift, not a new URL/parser failure; repository route tests alone could not prove hosted behavior.

Restored the **unchanged accepted router**, exact existing eight-file asset manifest, ASSETS binding, explicit Worker-first paths and original compatibility/security settings. No static asset bytes were uploaded or changed; no DNS, content, credential, paid-service or private-data changes. Active hosted version is **`19b93d04-f64d-4aa1-988c-2877aa5d2ac9`**. Read-back confirms fetch handler/binding/routing and workers.dev/previews both disabled. The 22 actual HTTP checks pass after restoration. This contained evidenced regression is the scope exception; no sharing redesign was undertaken. Future website publishes must retain the canonical config/router and run the live guard.

## One owner acceptance procedure

On the existing physical build/data, without resetting anything:

1. Cold-launch the real account, open My Kitchen Recipes → reader → See All/Food Bible; confirm written units only, serving scaling, and normal light/dark/large-text scrolling.
2. With a second authorized account/device when available, check the other Kitchen's shared Recipes, one request/comment/Send/Order Up! round trip, then revoke sharing/block and confirm content becomes unavailable. Private Recipes/cook activity must stay hidden. Use disposable records only; do not delete the real account.
3. Send one Recipe/profile HTTPS link through Messages, open in Safari/installed StayGrubby, and check no-app fallback where available. Share one ranked/no-photo or locked-score Dish with the native sheet; confirm useful Copy/Messages payload and no private notes/locked score.
4. Confirm normal photo selection/upload and subsequent sync/restore with a disposable test cook if needed, and review keyboard/VoiceOver on the owner's supported device. No fresh AI request is required for Stage 5.

These physical checks do not authorize TestFlight/App Store distribution. The next cycle is the release gate, not Stage 6 or another normal feature phase.
