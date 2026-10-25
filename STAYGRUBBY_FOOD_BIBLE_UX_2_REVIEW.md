# Food Bible UX 2.0 — owner acceptance review

Date: October 25, 2026. This is an owner-acceptance correction before External TestFlight, not an AI or cooking-mode phase.

## Checkpoints and scope

Starting checkout: clean `main`, `0a7f7a3c5e93cb87000b2bfe7e8efb1eacd4a404`, matching the existing `origin/main` tracking ref. No owner changes were discarded. Single-agent development, one Simulator lane.

- `ddaaa0c`: Add authorized local cookbook search index (read-only API, value helpers and focused tests; subsequently deployed with explicit owner approval).
- `45f3a69`: Preserve profile URLs through Universal Link fallback (website routing/configuration/tests and ignored local runtime state).
- `1920a9a`: Redesign Food Bible recipe browsing and editing (reader/editor/chooser, Ticket hiding, isolated fixtures and affected UI tests).
- Final verification checkpoint: recorded in the final Git report. The final documentation commit is identified by `git log -1 --format=%H -- STAYGRUBBY_FOOD_BIBLE_UX_2_REVIEW.md`; embedding that commit's own SHA in its content would be self-referential.
- Exact cycle inventory: `git diff --name-status 0a7f7a3c5e93cb87000b2bfe7e8efb1eacd4a404 HEAD`. Changes are limited to Food Bible, recipe value/editor/reader and Debug fixtures, focused tests, an additive read-only search action/reference SQL, website fallback routing, and review/architecture/roadmap documentation.

Exact changed-file inventory (22 files):

- Website: `.gitignore`, `Website/README.md`, `Website/build.py`, `Website/test_site.py`, `Website/wrangler.jsonc`.
- Backend: `Backend/schema.sql`, `Backend/tests/schema.test.mjs`, `Backend/tests/cookbook-search.test.mjs`, `supabase/migrations/20261025222821_cookbook_search_index.sql`.
- Values/native tests: `StayGrubby/Social/RecipeComponents.swift`, `StayGrubbyTests/CookbookUXTests.swift`.
- App UI/isolated fixture: `StayGrubby/Views/Cooking/FoodBibleView.swift`, `StayGrubby/Social/RecipeEditor.swift`, `StayGrubby/Social/RecipeReadingBody.swift`, `StayGrubby/Social/RecipeViews.swift`, `StayGrubby/Social/SocialReview.swift`.
- UI tests: `StayGrubbyUITests/FoodBibleUITests.swift`, `StayGrubbyUITests/ProductStructureUITests.swift`, `StayGrubbyUITests/RecipesLinksUITests.swift`.
- Documentation: `UI_ARCHITECTURE.md`, `STAYGRUBBY_MASTER_ROADMAP.md`, `STAYGRUBBY_FOOD_BIBLE_UX_2_REVIEW.md`.

No ranking, calibration, score mapping, unlock, comparison, re-ranking, data-model, media transport, authentication, signing, bundle identity or app version changes. No reset, account deletion, TestFlight upload or App Store Connect changes.

## Design decisions

[Crouton](https://crouton.app/) informed the browsing/editing principles: a visual cookbook, immediate local search, a strong reader hierarchy, inline ingredients and multiline instructions, lightweight sections, and deliberate independent row controls. No Crouton assets, branding or exact layouts were copied. StayGrubby retains cream/charcoal, restrained brand red, editorial typography and existing Dish photography.

Not adopted: meal plans, groceries, feeds, import/scraping/OCR, scales, timers, scaling, hands-free controls, cooking sessions or AI providers. No billing or new media service.

### Food Bible and Choose Dish

- Food Bible remains a derived projection of cooked Dishes linked to authorized Recipes. No membership table or duplicate Dish identity.
- Two photographic columns normally, one at accessibility sizes. Recipe title dominates; cuisine and genuine time/course are secondary. Scores are deliberately omitted here, preventing locked-score leakage and keeping Grub Rank distinct.
- Existing optimized thumbnails are reused. A cream/charcoal fork-and-knife fallback is used without a photo; small chooser thumbnails omit its caption.
- Search matches all partial whitespace-separated tokens, case/diacritic insensitive, across Dish/Recipe title, ingredients, cuisine, explicit Recipe source/original creator. Empty query restores the collection. No private cook notes or tags are copied into the search index.
- Restrained Course/Cuisine filters and Recently Updated/A–Z sorting. No network request per keystroke.
- Choose Dish searches local Dish title, cuisine and Course; clearing restores eligible cooked Dishes. Existing representative photo prefers the newest cook with an available photo, otherwise the newest cook.
- Already-linked Dishes say View existing recipe when the index is available. Before opening creation, an authoritative existing `recipes/dish` request resolves the current link; errors show Retry, never guess that no Recipe exists. Existing links open the reader; absent links open a prefilled editor.
- No standalone Create Recipe or Ticket entry point in normal V1 navigation. Preserved unlinked Recipes can still be attached from Dish Detail.

### Reader

Hero photography/fallback → prominent title and introduction → genuine servings/prep/cook/total → Ingredients → Method → optional tips → secondary provenance and Dish/Versions context. Quantities/units are distinguished from names, with stacked layouts at accessibility sizes. Method numbering continues across sections. Simple recipes omit a meaningless Main heading. Recipe tips, original creator, explicit source, Added by and immutable cook provenance stay distinct.

The same value-based `RecipeReadingBody` renders current Recipes and cook snapshots. This is the future Start Cooking seam; no cooking session or storage architecture was added.

### Editor

One `RecipeDraft` value, one Save. New drafts prefill Dish title, Course and cuisine, with a Dish photo/fallback immediately visible. Personal Notes are never copied.

- Compact quantity/unit/name fields. Next advances quantity → unit → ingredient; Return in ingredient creates/focuses a new ingredient. Units and fractions remain user-entered text; no conversion/guessing.
- Preparation and optional note are progressively disclosed, with existing values summarized.
- Multiline steps keep Return as a newline. Steps are numbered continuously and editable inline.
- Multiple sections show lightweight editable names; simple recipes suppress the section heading. Add Section, rename, section up/down, confirmed delete, ingredient/step up/down and Move to… are available.
- Dedicated 44-point action controls do not attach drag gestures to editable text. Boundary moves are disabled; row and section deletions require confirmation. Stable UUIDs survive moves and save canonicalization.
- Unsaved changes block swipe dismissal and Cancel presents Keep Editing / Discard Changes. App switching/backgrounding preserves the value and stable sheet identity. One coherent failure message retains the draft for retry; cloud failure is never reported as success.
- Drafts are in-memory for the presented editor. This does not promise recovery after process termination/force quit. No second disk cache or sync system was introduced.
- An already-open owned Recipe remains readable on a network-only refresh failure. Shared Recipes are cleared and reauthorized on lifecycle changes; auth/server denial clears content. Cold/offline cookbook loading and new cloud saves still require a connection.

The initializer accepts `RecipeDraft`, preserving the future parser → draft → same editor → explicit review/save seam. Foundation Models, Gemini and any parser/import UI remain unimplemented.

## Search backend and privacy

`20261025222821_cookbook_search_index.sql` adds only a compact read-only action to the existing authorized Recipes RPC. It is necessary to search ingredients/source locally without an N+1 fetch of full bodies/revision histories. Pages contain at most 50 eligible Dish summaries and are keyed by Dish UUID. The client loads the index once on refresh/content change, deduplicates IDs, and filters locally.

The existing Recipe API is retained behind a private forwarding helper. The new function has an empty search path, authenticated-only execution, verified actor/active-account checks and existing Recipe visibility rules. No tables, records, grants to anon, Ticket behavior or private cooking payloads change. Existing actions, including null/invalid action handling, forward to the existing implementation.

Deployment status: **deployed with explicit owner approval on October 25, 2026**, hosted version `20261025222821`. The original local migration filename was aligned to Supabase’s assigned timestamp without changing SQL bytes (MD5 `8cbf1a316b67003d1fa5aed0ee4f76de`). All **25 hosted/local migration hashes match**. No hosted Edge Function deployment was needed.

Post-deployment verification: all 36 checked application/Storage tables retain RLS, and table grants/policy fingerprints are identical. The public API remains authenticated-only; the forwarding helper remains inaccessible to anon/authenticated roles, with empty search paths retained. A rolled-back SQL smoke check through the actual `api.recipes` entry point passed **16 assertions across 3 existing valid account/session mappings**, including the existing cookbook entry, Recipe reader, Dish association, pagination, oversize rejection, missing-session denial, anonymous denial and helper isolation. It did not create users/sessions, obtain tokens, write records or simulate physical sign-in. All 35 table/Storage data fingerprints remain unchanged. Security advisors show only the same pre-existing RPC-only-table INFO and unused password-protection warning. **The real-account Food Bible is ready for owner physical testing**; that is distinct from a physical acceptance pass.

A 520-entry test verifies 11 bounded index requests and no extra request while search changes. The chooser filters local Dishes and uses thumbnails. This is functional responsiveness evidence, not a measured physical-device performance benchmark. No full-resolution grid loading or revision decoding per card.

## Tickets deferred without destruction

Normal Food Bible, Recipe reader, standalone creation and related empty-state paths no longer expose Tickets/Want to Cook. Existing social/Run It Back, Settings and profile-link routes were reviewed; they do not introduce a Ticket destination. No Ticket deep-link route was added.

Preserved: `TicketsView`, `RecipeTicket`/`TicketsPage`, summary styling, database tables/records, recipe ticket/unticket/tickets actions and completed-cook handling. Backend lifecycle assertions continue to pass.

To restore later: explicitly add a reviewed navigation entry to `TicketsView` and a Recipe ticket action using the existing Recipes service; restore UI coverage for save/remove/cook lifecycle. Re-review visibility, deleted/private recipes and provenance. No data migration or recreation should be needed merely to re-expose the feature.

## Universal Links: findings and physical retest

This investigation did not treat a static AASA pass as proof of physical success.

Verified:

- Origin and Apple's CDN return direct 200 JSON AASA, 197 bytes, `5DSB36G7LZ.com.guyrettig.StayGrubby`, `/@*`.
- Debug/Release source entitlements use `applinks:staygrubby.com`. The local signed physical Debug app's XML entitlements match the Team/app identity and Apple sign-in entitlement; its valid-through-2027-10-22 provisioning profile permits associated domains.
- Read-only paired iPhone metadata identifies developer build `com.guyrettig.StayGrubby`, 1.0 (2). Device tooling exposes app data rather than an installed bundle entitlement export; the installed signature was not independently extracted. No install/uninstall, device data copy or signing change was performed.
- Native strict HTTPS username parsing and auth-retained pending routing already exist; focused routing tests are included in final verification. No speculative native rewrite.
- **A real website routing defect was found:** `/@username` redirected 307 to `/kitchen`, losing the original path. The assets configuration now disables implicit HTML redirects and explicitly rewrites `/@*` to the kitchen HTML with **200**, preserving the requested URL. Privacy/support/kitchen and AASA stay direct 200; unknown paths remain 404.
- Local Wrangler routing engine and live requests confirm this correction. Same-domain Safari behavior, user preference and Apple's device cache can still affect app opening; the redirect defect is not proven to be the sole physical failure.

Effective live assets-only Worker version: `f1fedb0b-a7e7-460b-8839-9c6edb8c6b2e`, deployment `2a6880d0-8ddf-4aea-be26-e8aee19ada8c`. Eight cached assets were reused; zero asset bytes uploaded, no bindings/DNS/email configuration changed. An earlier keep-assets attempt retained the previous routing configuration; read-back exposed that, and the final assets-session deployment corrected it. No credentials were exposed or changed.

Exact owner retest, preserving all data:

1. Run the updated signed StayGrubby build from Xcode onto the same iPhone/bundle identity. **Do not delete the app or reset its store.**
2. Put a valid existing discoverable profile URL `https://staygrubby.com/@USERNAME` in Messages, Notes or Mail. Tap that link from that app. Do not use a typed Safari address-bar navigation or a link tapped on another staygrubby.com Safari page as the sole test.
3. Test while StayGrubby is already open, then cold-start from that link. Verify the correct requested profile, not merely app launch.
4. Test signed out: open the link, complete normal authentication and verify the requested profile resumes. Private/invalid/blocked/renamed profiles must fail safely, without opening private data.
5. If Safari still wins, long-press the external link and select Open in StayGrubby if offered. In iPhone Settings → Developer → Universal Links → Diagnostics, enter the exact URL; record the site/framework/user approval result. Send the observable behavior/diagnostic status, **not credentials**.
6. Follow [Apple TN3155](https://developer.apple.com/documentation/technotes/tn3155-debugging-universal-links) for device approval/CDN diagnostics if still failing. No `?mode=developer` entitlement hack or destructive reinstall was introduced.

**Physical Universal Link success remains unverified until the owner retests.** Owner's requested description of the original failure is still pending. Same-domain Safari behavior is an investigative possibility, not a claimed root cause.

## Preservation and verification

- Hosted full-row fingerprints: all 34 application tables plus Storage objects (35 groups) match the task-start baseline. Raw row totals remain 3 accounts/rankings, 36 Dishes, 41 attempts/items, 152 comparisons, 1 Recipe, 1 revision, 1 Dish link, 3 Recipe cook snapshots, 0 Tickets and 64 Storage objects. These include retained history/tombstones and are not claims about active records. No fixture writes to hosted data, no auth/account creation, no real deletion test.
- Demo manifest unchanged: `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`; 1 global ranking, 12 Dishes, 15 attempts/items, 356 comparisons, 10 Sources, 21 tags, 48 memberships; 190 media files unchanged. UI fixtures use UUID-isolated stores/media roots.
- Protected engine/calibration/unlock/sync/assets/client configuration/project files unchanged. Original scores/evidence/order/identities remain intact.
- Backend final selection: schema/RLS 82, structured sync 75, Food Bible 34, upgrade 11, compact search 23, Recipe provenance 16, Recipes/Tickets/links 42, shared cooking 46: **329 assertions**, no hosted fixtures. Initial schema assertion expected the prior 24 migrations; updated to explicitly require the 25th index migration, then 82/82 passed. No security assertion was weakened.
- Focused native cookbook/component tests: 8/8 passed. Focused UI correction run: 4/5 passed; the remaining issue was the platform-normalized cancellation label, corrected with an explicit dirty-discard alert. Subsequent three affected editor tests passed, including background/Keep Editing, Next-key entry/save retry and all move/delete controls.
- Earlier UI failures exposed an inherited accessibility identifier and oversized photo accessibility bounds; both were corrected. A caret-position assumption was replaced with exact before/after draft equality. App save/detach/navigation had succeeded; no meaningful assertion was removed.
- Final selected regression: **95/95 passed, zero failures/unexpected failures/skips**: 80 native tests across 11 selected suites plus 15 UI tests (Food Bible 6, product/navigation 2, Recipes/links 6, logged-out account entry 1). Result bundle: `/private/tmp/bible2-final-authorized-regression.xcresult`. Debug compile/launch passed through this run. Standalone optimized Release simulator build passed (`/private/tmp/bible2-release-build.log`); no archive/upload/signing configuration change. Binary inspection finds none of `--ui-test-store`, `--social-review`, `--recipe-save-failure`, `--development-library`, `--test-large-type`. The first final invocation stopped before tests because sandbox denied Xcode caches; the authorized retry passed. Final narrow chooser enhancement: **1/1 UI test passed**, zero failures, confirming representative thumbnail display, Course search/clear and new Recipe entry (`/private/tmp/bible2-chooser-photo.xcresult`). The exported thumbnail screenshot was inspected; no application changes followed the final regression.
- Website: seven static tests passed; actual local routing engine and live direct-status checks passed. AASA remains direct JSON; fallback is private/minimal, with no fabricated TestFlight destination.
- Privileged-secret/local-artifact scan: zero findings. Whitespace checks required before each checkpoint. Build products, dependency caches, `.local-backups`, Wrangler runtime state and credentials remain ignored/uncommitted.
- Hosted security advisor: no ERROR; existing RPC-only-table INFO and unused password-protection warning predate this cycle. No expanded anonymous access.

## Simulator and accessibility inspection

Strategically inspected isolated fixture screenshots: dark populated grid with photo pipeline/fallback; active ingredient/cuisine/source searches; light empty cookbook; Choose Dish default/search; prefilled simple editor; reader hero and multi-section ingredients; simple fallback reader; multiline keyboard entry; dark independent move controls; preserved draft after app switch; large-text reader/section editor with Reduce Motion. Fixtures include a deliberately synthetic blue image to verify photo plumbing/layout; this is not a new representative production photo.

The final chooser screenshot also confirms its synthetic-photo thumbnail retains the intended 70×78 layout alongside title/course/context, with no caption clipping in fallback rows. Visual review found large-type quantity clipping and crowded summary columns. Accessibility quantities now expand, summary metrics use one column, and metadata fields stack; compact chooser fallbacks remove the clipped decorative caption. These corrections are compiled and included in final UI verification.

VoiceOver: decorative photos hidden inside labeled card buttons; contextual action labels, separate quantity/unit/name fields, header traits, explicit continuous step labels, large save/cancel/reorder targets. Automated accessibility hierarchy/large-type coverage is not a substitute for an owner VoiceOver listening pass. Native text selection is retained; no row drag intercepts it. Reduce Motion uses native interactions with no added animation dependency.

## Owner physical acceptance checklist and release recommendation

1. Browse a real photo/fallback cookbook in light/dark; search title/ingredient/cuisine/source, clear, Course/Cuisine and both sorts. Existing Recipes only; no scores/Tickets leak.
2. Choose Dish: title/cuisine/Course search, clear, photo/fallback, existing Recipe opens without duplication; new Dish context prefills the editor.
3. Create/edit a simple Recipe: qty → unit → name → next row; preparation/note; multiline Method; source and tips; one Save. Reopen/relaunch and confirm same Dish/link/revision persist.
4. Multi-section Recipe: add/rename/reorder/delete section, move/reorder/delete ingredients and steps. Verify quantities/fractions, line breaks and continuous step numbering. Text-selection gestures must remain normal.
5. Background/app switch while editing; Keep Editing retains the exact draft, Discard leaves saved Recipe unchanged. Simulate offline failure without deleting data, retain draft and retry after reconnect. Already-open owned reader remains readable offline; no cold-offline cache promise.
6. Inspect accessibility text, scrolling, keyboard dismissal, VoiceOver order/labels and Reduce Motion. Long Recipe ingredients/steps must remain readable.
7. Confirm Recipe detach/cook-again paths preserve cooking/ranking/provenance; Tickets remain absent. Do not perform account deletion/reset.
8. Perform the separate exact Universal Link test above and record warm/cold/auth-resume results.

**NOT YET for External TestFlight.** The hosted search action is now deployed and verified, so the real-account UI is ready for owner physical acceptance. Owner acceptance of the redesigned flow and physical Universal Link success remain release gates. Existing operational moderation/release requirements remain separate; the intentionally deferred real Apple deletion test is not invented as a new blocker here. No need for another unrelated giant audit. The deployed action’s authorization/index/data-fingerprint checks passed. Remaining follow-up is the affected owner physical flows.

No Intelligent Recipe Engine, AI provider, timer, scaling, hands-free or full Start Cooking system was started. No TestFlight upload occurred.
