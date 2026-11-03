# Next-Version Integration — November 2–3, 2026

**AUTOMATED ACCEPTANCE PASSED — OWNER PHYSICAL ACCEPTANCE PENDING.** Baseline `a49a10354758d94f4645512ebbba171b1f2e22f8`, clean main aligned with origin at cycle start. One primary agent, existing checkout, one Simulator lane. No next roadmap cycle/distribution/provider calls. The owner's additional sharing-link requirement explicitly reopens the contained Universal Link dependency; it supersedes older deferral without authorizing a public social/Recipe website.

## Proven defects and corrections

- Active recipients previously had no remote refresh source: Order Up! fetched on mounting, foreground/local changes only. Existing server triggers/dedupe already generated supported events. One account-mounted foreground poll (30s, 60s on failure) now shares unread bell/tab state and refreshes visible social readers. No APNs/background delivery. Read responses update counts immediately; revision/account guards prevent late polls or previous sessions restoring stale counts. Failed refresh clears stale badge and recovers on later normal refresh.
- Feed/profile refresh cleared rows before loading, destabilizing Comments sheets; engagement's local override could outlive parent updates. Ordinary successful replacement now preserves anchors until authorization succeeds, resets superseded engagement, and broadcasts engagement changes separately. Errors/background clear inaccessible friend content. Empty profile/post responses show unavailable, never stale identity/content. Relationship lists, read-only Recipes, posts, comments and shared-cook entry refresh without relaunch; searches/editor text are preserved.
- Feed cards exposed Recipe access only after opening Detail. They now offer the existing pinned reader directly. Make This/Cook It Again and copy/Run It Back appear before long methods; shared reader uses common content width and unchanged content/scaling. Own-profile links select actual My Kitchen; Order Up! is beside Settings in its fixed header. A failed cookbook refresh no longer claims an empty library. Social/cookbook placeholders use the official cropped wordmark.
- No ranking/calibration/unlock/photo transport/Recipe Creator/schema/content-ownership changes. Four tabs, chronological feed, private defaults, deliberate publishing, immutable shared revisions, independent copies and provenance remain authoritative.

## Sharing links: complete flow and root cause

A generated profile URL previously returned **307 → `/kitchen` → 307 `/kitchen`**. The `/@* → /kitchen.html` asset rewrite interacted with default HTML canonicalization, discarded the profile destination and looped. Privacy and Support had the same rewrite/canonicalization failure. Existing associated-domain entitlement/team identity were already correct. Native parsing also rejected normal `%40` escaping; post/Recipe link generation and destinations did not exist.

Generators now pass validated HTTPS URLs to native `ShareLink`. iOS delivers installed Universal Links through the existing app handlers; the authenticated root retains destination only until account readiness, then reads through existing server-authorized APIs. The website serves direct generic fallbacks retaining the destination, plus user-initiated `staygrubby://open/...` registered in the app Info.plist. It never fetches content, tests existence, shows social metadata, accepts tokens/redirects or grants access. Invalid/private/deleted/blocked destinations fail gracefully in-app. Shared pointer UUIDs remain unchanged by content edits; profile routes retain existing anti-recycling semantics.

| Share type | Export/destination and verification |
| --- | --- |
| Dish/cook | Existing approved image/native sheet; no public private-cook URL. If deliberately published, its separate post can share a post link. Native sharing/unlock/privacy tests preserved. |
| Signature Dish(es) | Approved individual/Top 3 images, fixed brand-red scores and no private rank leakage; no invented ranking link. |
| Grub List post | `/p/<post UUID>` → authorized post. Direct native destination, unavailable path and hosted fallback tested. |
| Current Recipe | `/r/<Recipe UUID>` → current authorized living Recipe. Friends-visible share action; native route/explicit scheme and hosted fallback tested. |
| Post's Recipe | `/p/<post UUID>/recipe` → that post's pinned shared revision, not today's Recipe. Parser, existing pinned-reader/copy/privacy/backend tests and hosted fallback tested. |
| My Kitchen/profile | `/@username` including `%40` → authorized discoverable Kitchen, or actual own Kitchen tab. Native sheet, profile/own/private UI cases and hosted fallback tested. |

Without the app: direct privacy-safe HTML, beta-access explanation, Support/Privacy and explicit Open button; no automatic redirect, public data or invented installation URL. With the app: automatic Universal Link delivery remains an owner two-iPhone acceptance item despite matching hosted/Apple-CDN AASA and native automated routing. Safari same-domain preference and device-local association cache can keep navigation in the browser; the explicit app-open action is the fallback. See [Apple associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains) and [debugging Universal Links](https://developer.apple.com/documentation/technotes/tn3155-debugging-universal-links).

## Deployment and preservation

No Supabase migration/function deployment was required. Hosted `recipe-import` remains v27, `delete-account` v7 and `development-test-session` v1; JWT verification remains enabled on all three. All **33 hosted/local SQL hashes match**; all **39 application + 2 development tables have RLS**. All 15 protected count/row-hash groups match before/after: 42 Dishes, 47 attempts/items, 185 comparisons, 4 rankings, 3 Recipes, 6 revisions, 4 Recipe-cook snapshots, zero Recipe-photo manifests, 78 Storage objects, plus unchanged links/Sources/tags/media/backups. No hosted test users, records or Storage bytes were created or deleted.

Read-only copied Simulator-store audits confirm **1 ranking, 12 Dishes, 15 attempts/items, 356 comparisons, 10 Sources** and **190/190 original media hashes**. Original stores were never opened for writing by audit scripts; isolated UUID test stores/media stayed separate. No account-deletion test, real Apple authorization, credential change, paid configuration, billing change, Gemini call, version/build change or distribution.

Existing Cloudflare Worker final version **e392a755-ffe1-4261-b0f3-f4f39d2bbba4**. Current source/bundle, strict destination grammar, AASA and security headers were tested. Assets were reattached unchanged using an internal short-lived upload completion capability; no protected values were printed/persisted. Initial `keep_assets` retained old routing; live checks caught and corrected it. Final public sweep also caught the home-page 404 caused by disabled HTML canonicalization; explicit `/ → /index.html` handling and a regression test correct it. Final config: HTML handling none, empty redirects, explicit Worker-first paths, workers.dev/previews disabled. Domain/DNS/email/account/plan unchanged. All 14 public paths pass, both AASA endpoints match source, Apple CDN matches, hosted canonical November 2 policy text exactly matches, official logo/CSS bytes unchanged.

## Verification

- Focused native link/config/state: 13 tests passed; earlier coordinator/session check 6 passed.
- One broader native integration: **92 tests /15 suites**, including account isolation, Recipe contract/replay/scaling, ranking/calibration/unlock/re-rank, photo sync, share/privacy/color and configuration. No live AI.
- Final focused coordinator regression: **4 tests**, covering late-poll/read and detached-account guards. Three overlap broader coverage; **93 distinct native tests** across final coverage.
- Social/Recipe/link UI: **11 passed**. Connected surfaces/direct links plus Shared Cooking/Order Up!: **10 passed**. Updated current-navigation visual review across cooking/ranking/Recipe editor/Settings/accessibility: **4 passed**. Final read-all UI regression: **1 repeat passed**. **25 distinct UI tests, 26 successful executions**, zero failures/skips in final runs.
- Backend integration: **22 disposable PostgreSQL programs /676 assertions passed** (social relationships, content, Hands/comments/reports/blocks, notifications, invitations/recreations, pinned Recipes/private copies/photos, schema/RLS, structured/photo sync). The old schema smoke test had stale migration/table/API counts; updated exact expected inventories plus closed development-function/table checks. No security assertion removed.
- Web: **7 static site tests +17 route tests** passed; dry-run bundle succeeds. **14 live public path checks** passed, no redirect loops, correct 404s; canonical policy/official assets match. Apple CDN exact-match check passed.
- Debug and Release builds pass. Existing Swift 5 sendability-conversion warnings in session/media closures and no-AppIntents metadata warning remain nonfatal; no new provider/auth architecture introduced.
- Light/dark and accessibility/Reduce Motion screenshots inspected; portrait identity/config tests pass. Final secret/local-artifact scan and whitespace/staged inventory checks accompany the checkpoint.

## Whole-product review and retained decisions

| Surface/domain | Review result |
| --- | --- |
| Launch/onboarding/auth | Existing required Apple/account gate and Debug-only isolated review retained; no real authorization. Root links wait for account readiness. No new startup animation. |
| Grub List | Chronological friends-only cards, identity/food/score/Recipe/provenance/engagement hierarchy; remote refresh and error/block recovery verified. |
| My Kitchen/Sous Chefs/Requests | Distinct own vs other actions, actual own-profile destination, visible bell/Settings, request routes and relationship transitions verified. |
| Order Up! | Request/accepted/Hands/comment/invite/join/Run It Back generation, dedupe, read state, routing and privacy tested; foreground bounded refresh, not push. |
| Cooking/Grub Rank | New/edit/version/re-rank/comparison/result/share connections reviewed; accepted calculations/unlock/export rules untouched and regression checked. |
| Food Bible/Recipes | Current independent membership/search/filter, create/edit/read/history/scaling/photos retained; primary cook/copy routes moved up, failure/placeholder consistency improved. No Creator tuning or source validation. |
| Run It Back/Shared Cooking | Separate owned cooks/evidence, explicit consent, idempotent claims/copies, historical revision/provenance preserved. |
| Sharing/Settings/states | Real native share sheet checked; valid pointers vs image-only exports explicit. Generic web and unavailable/offline recovery; no private note/rank leakage. |
| Accessibility | Portrait, adaptive tokens, Dynamic Type/VoiceOver labels/counts, Reduce Motion and reachable actions; light/dark screenshots inspected. Formal exhaustive VoiceOver/contrast certification not claimed. |

[Apple UGC guideline 1.2](https://developer.apple.com/app-store/review/guidelines/#user-generated-content) still requires filtering objectionable material, reporting/timely response, blocking and published contact. Existing closed APIs, report/block/moderation states and contact pages are tested; comprehensive filtering and staffed response operations remain **external-release gates**, not completed by this integration or by a simplistic word blacklist. No App Store compliance/distribution claim. APNs, public browsing, Recipe-only posts/feed filters, followers/DMs/Discover/challenges/AI discovery and a dedicated ground-up Food Bible redesign remain out of scope. Physical acceptance is pending, never inferred from mocks.

## One owner acceptance pass — two iPhones, two authorized accounts

Use the latest Debug build, existing data and a small clearly identified test cook; no reset, reinstall or account deletion. A and B should be current Sous Chefs; use only accounts/content you control.

1. **Overall UI:** check Grub List, Grub Rank, Food Bible, My Kitchen and Settings in light/dark; one accessibility text size. Confirm normal sizing after relaunch.
2. **Cooking/Grub Rank:** create/re-rank one test cook, review its result/Detail/version return path. Keep private evidence independent of social activity.
3. **Food Bible/Creator:** open/edit an existing Recipe, review description/components/serving projection/history and Make This. Creator v27 is unchanged; no extra provider regression run is required by this cycle.
4. **Grub List:** A deliberately shares the test cook; B sees its identity/photo/Recipe availability and can give Hands/comment without relaunch or a dropped Comments sheet.
5. **Sous Chefs:** exercise one request/accept on controlled accounts if not already connected; verify own Kitchen vs another Kitchen controls and current relationship state.
6. **Recipe/Run It Back:** deliberately attach a Recipe, B views the pinned revision, saves an independent copy and starts/cancels or completes Run It Back. Editing A's current Recipe must not rewrite the post's selected revision or B's copy.
7. **Order Up!:** while B stays foregrounded, A gives Hands/comments/tags a shared cook. Within roughly 30 seconds check bell/tab count, open destination, mark read and confirm badge clearing. Background push is not expected.
8. **Sharing:** send A's Kitchen, published post, current Recipe and post-Recipe links through Messages to B. Test B cold and already open; signed-out opening must gate then resume. Check correct destination/revision, own link → actual My Kitchen, fallback Open button and native image/Signature Dishes exports. Use a desktop browser without the iOS app to check the no-app fallback; **do not uninstall and risk local data**. Test association/browser preferences if an HTTPS link stays in Safari; origin and Apple CDN are already verified.
9. **Privacy/blocking:** make the controlled Recipe private/remove attachment or block a controlled account; B's next refresh/link must be unavailable. B's legitimately saved independent copy/history must remain. Unblock does not silently restore friendship.
10. **Persistence:** relaunch both apps, verify account separation, existing library and test state. Report any wrong destination, stale badge/content after foreground refresh, unexpected publication or lost draft.

Direct OS `simctl openurl` delivery also passed in the same UUID-isolated Debug fixture: iOS displayed its Open StayGrubby confirmation, then opened the intended current Recipe with Edit/Make This and its expected ingredients. This confirms registered custom-scheme delivery, not physical automatic Universal Link association. The 25 distinct UI tests and native routing/configuration tests passed. Physical installed-app association, native recipient-app behavior and real multi-device timing are the remaining acceptance work. This checkpoint is not authorization for TestFlight/App Store distribution.
