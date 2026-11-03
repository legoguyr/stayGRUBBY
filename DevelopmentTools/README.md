# Development tools

## Unattended authenticated Recipe Creator validation

`recipe_live_test.mjs` is explicit development tooling, **outside every Xcode target**. It never runs at app launch or in Release/TestFlight/App Store; the app does not reference its endpoint. Production stays Apple-only, with email and anonymous sign-in disabled. Never use Guy's account/phone/SDK Keychain or extract the Gemini key.

`development-test-session` keeps JWT verification and requires an additional administrator-issued, random 256-bit proof. Only its SHA-256 hash enters SQL; it expires in five minutes and is consumed atomically before Auth operations. Clients and service_role cannot issue proofs. The helper uses supported Auth Admin create/get/generate-link APIs and `/verify`, sends no email, and issues an ordinary non-anonymous session **only** for `recipe-validation@staygrubby.invalid`. Admin-controlled app_metadata and a pinned UUID prevent real-user targets or collision adoption. Privileged keys stay inside Edge Functions. Two closed/RLS tables are in the unexposed `development` schema; constrained service-only consume/bind RPCs have fixed search paths. Migration `20261102181733_development_recipe_test_auth.sql` changes no existing app ownership or production Auth settings. This is the explicitly authorized November 2 testing exception, not a second app sign-in path.

The separately owner-authorized **v25 final-verification** campaign is also exhausted: **3/3**, French toast/Shakshuka/kale once each. `STAYGRUBBY_RECIPE_CAMPAIGN=v25-final-live-20261102` selects its independent `v25-final-budget.json` and prefixed artifacts; it cannot reset or spend the old grant, repeat a fixture or exceed three calls. Missing state fails closed. Neither exhausted campaign authorizes another call.

Future authorized workflow:

1. Inspect the task/deployment and existing private budget. **The present `77dd8c13-six-approved-calls` budget is exhausted: 6/6. Never reset it or make a seventh call.** A new campaign needs explicit live-call authorization; do not silently create another allowance.
2. Reuse `~/Library/Application Support/StayGrubbyDevelopment/recipe-validation/session.json`. Directory mode 700, files 600, outside Git. Normal Auth refresh rotation rechecks the fixed identity. Never display/copy tokens into chat or tracked files.
3. If a session is unavailable, run `node --use-system-ca DevelopmentTools/recipe_live_test.mjs prepare`. It privately stores the raw proof and prints only the UUID/hash issuance SQL. Execute that statement through the existing Supabase administrator connection, then run the CLI's `login` within five minutes. Expired/failed proofs require new issuance, never relaxed authorization or an owner phone.
4. Private `public-client.json` has only the existing project's public `anon` JWT (gateway compatibility) and `publishable` key from Supabase `get_publishable_keys`, never privileged credentials. `provision` uses the normal parameterless account RPC for this identity. It creates no cooking library/ranking, Recipe or upload. `status` verifies the test session and public provider settings without calling Gemini.
5. With a new available approved budget, `run french`, `run shakshuka` or `run kale` verifies unchanged canonical bytes, locks exclusively, and persists a reservation **before one** normal authenticated `recipe-import` invocation. No batching, automatic provider retries or direct Gemini calls. Quota/billing/configuration/authentication or ambiguous transport failures stop the campaign. Inspect each result before proceeding.
6. Private `call-N-fixture.json` files retain source, bounded candidate and result. `diagnosticReview` plus `x-staygrubby-development-review: candidate` captures successful originals too; normal app responses/logs do not. Offline replay is not another live/physical pass. Tracked regression captures contain only the owner-supplied canonical acceptance Recipes, never session/account identifiers or another user's private Recipe.

Node 24 `--use-system-ca` keeps TLS verification. The Mac's configured DNS resolver timed out during this cycle. Optional `STAYGRUBBY_TEST_ADDRESS` supplies an independently verified public IPv4 for the fixed Supabase hostname, analogous to curl `--resolve`; hostname/certificate verification remains enabled. Normally omit it and never blindly reuse a stale address. No system DNS, credential, Git or TLS configuration is changed.

Focused checks: `node --test DevelopmentTools/recipe_live_test.test.mjs`, `node Backend/tests/development-test-auth.test.mjs`, and Deno tests in `supabase/functions/development-test-session` / `recipe-import`. Hosted deployment still needs current-cycle authorization. Retire this facility later by deliberately retiring its helper/grants and dedicated test session/identity, never real accounts.

## Historical manual development cooking seed

**Historical utilities:** the Swift seed/allergen tools below retain their original module and bundle guards and must not be retargeted to the renamed app. Current project/app identity is StayGrubby, `com.guyrettig.StayGrubby`. See `PROJECT_RENAME.md` for the separate, explicit Simulator-only library transfer. Its Python tool is outside all Xcode targets and never runs at app startup. Run its isolated safety tests with `python3 -m unittest discover -s DevelopmentTools -p 'test_simulator_transfer.py' -v`.

SeededLibraryReview now uses the common UI-test teardown base. Isolated review photos resolve to the matching temporary test-store media root; copy any real clone photos there explicitly if needed. Large-type review should use `launchWithReviewOptions`, which synchronizes the UIKit/SwiftUI test choice without changing system text size. Normal guest launches keep no review flags. See `UI_ENVIRONMENT_DIAGNOSIS.md`.

These utilities are **outside all Xcode targets**. There is no reset/seed call in the app, launch flag, schema change, migration or ranking implementation change. Normal launches and the standard test suite cannot invoke them.

The requested October 5, 2026 reset targeted only the Debug app `com.guyrettig.Grub-Ranked` on iPhone 17 / iOS 26.5 Simulator `D839186C-3810-4C98-99FA-3C88230212DC`, with CloudKit disabled by the existing persistence configuration. A consistent SQLite backup and complete before snapshot were saved under the ignored `.local-backups/seed-20261005/` directory before mutation.

## One-use execution

`OneTimeDevelopmentSeed.swift` was temporarily copied into the unit-test target and compiled before any reset authorization was placed. Only its named test was invoked. It requires a manual `staygrubby-one-time-seed-request.json` in that simulator app's Application Support directory. It verifies the simulator, bundle ID, default-store path, existing ranking UUID, item/comparison/cook/dish UUIDs, tag count, absence of uninspected media/Sources, and the recorded backup fingerprint supplied by the manual preflight. It first builds and validates the whole dataset in memory, then consumes the request **before** deleting anything. A retry cannot reset the store again.

Deletion uses `CookingStore.delete` for the original 14 cooks and their incident evidence/empty Dishes. Only the five resulting unused cooking tags are explicitly removed. The existing RankingList and CookingLibrary identities remain; unrelated `Item` data is retained. Creation uses completed `RankingEngine` sessions through `CookingStore.create`, including shared Dish/Source inheritance for versions. `RankingStore.record` adds three rounds of observations for all 105 pairs. Synthetic preferences include close ties and upsets; no final rank, score, strength or uncertainty is written manually. A fresh Bradley–Terry analysis is checked against every stored estimate.

The utility is deliberately not an automatic/reusable reset script. To repeat a reset, inspect and back up the actual store again and issue a new explicit request describing its current IDs. The Swift utility and temporary copies are easy to remove; no production path depends on them.

## Representative records

The saved review library has 12 Dishes and 15 independently ranked CookingAttempts. Lamb Chops, Harissa Chicken Kabobs and Sea Bass each have two cooks. There are seven canonical Courses, short and long names, custom/default version labels, mixed notes, custom tags, Dietary selections, and optional simplified Sources: My Own, Cookbook, Online, Restaurant, Friend / Family, and no Source.

Attributions are illustrative development metadata, not verified cookbook/restaurant provenance. Online Sources use reserved `example.com` URLs, preserved verbatim. No network access or metadata retrieval is performed. The original seed included illustrative Free labels; the Phase 2C polish update below explicitly replaces those disposable labels with Contains metadata. Neither is medical verification or a cross-contact safety claim. The cake explicitly notes almonds, eggs and wheat. All 15 cooks intentionally retain the normal no-photo placeholder; no media is downloaded or added.

## Review verification

`SeededLibraryReview.swift` is likewise outside the UI-test target. A temporary copy substitutes a uniquely generated `__CLONE_TOKEN__` backed by a SQLite copy of the seeded store. The real-store test searches, filters, opens versions and exercises/cancels re-ranking. The isolated-clone test actually saves New Dish, New Version and re-rank answers, then relaunches. These test-created records never enter the review store.

After verification, temporary files inside both test targets are removed, and a normal app build/launch uses the seeded development store. Before/after source hashes verify that all existing application files, project configuration and Phase 2C documentation remain unchanged. The request marker is absent. The baseline, seeded snapshot, exact order/scores/IDs, test results and visual captures are retained in `.local-backups/seed-20261005/` for manual review and recovery. No commit or push is performed.

## Phase 2C polish: one-time presence metadata update

`OneTimeDevelopmentAllergenUpdate.swift` is another manual utility outside every target. It **does not repeat the reset**. A new consistent backup/manifest under `.local-backups/polish-20261005/` identifies the existing 12 Dishes, 15 cooks/items and 356 observations. The one-use `staygrubby-one-time-allergen-request.json` checks those identities, the selected Simulator/bundle/default store and recorded backup fingerprint, and is consumed before mutation. A temporary unit-target copy runs only its named test and is then removed.

The update replaces the reviewed disposable seed Free labels with explicit `contains` tags. Corn velouté versions contain Fish/Milk; Butter Chicken and saffron-yogurt Street Corn contain Milk; couscous contains Wheat; matzo balls contain Egg/Wheat; Tuna Crispy Rice contains Fish/Soy/Wheat/Sesame; almond cake contains Tree Nuts/Egg/Wheat. These are illustrative ingredient choices for fixtures, not medical verification. Other seed dishes have no presence marks. No photos, names, dates, notes, Sources, scores, strengths, uncertainties, diagnostics, ranking evidence or identity relationships are changed.

Ordinary saved legacy Free labels remain semantically intact in the application. The seed template now uses presence metadata for future explicitly authorized resets. SeededLibraryReview uses Avoid and the automatically saved result close action. The original seed reports remain historical evidence of that earlier reset.
