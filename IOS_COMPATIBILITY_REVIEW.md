# iOS compatibility expansion — November 6, 2026

Baseline: clean `main`, aligned with `origin/main`, `7b2724e8c82231b0999958bc69929217258392e8`. Owner scope: iOS 17 if practical, no architecture/UI overhaul or distribution. The subsequent owner steer explicitly makes Gemini the only active V1 AI Recipe provider. One primary agent, existing checkout and one Simulator lane.

## Decision and audit

**Minimum iOS: 26.5 → 17.0**, for the app, native tests and UI-test targets in Debug/Release. iOS 18 was unnecessary: the accepted SwiftData/Observation architecture starts at 17, and the blockers were contained availability issues rather than structural dependencies. No support below 17 is attempted.

| Audited area | Finding / final handling |
| --- | --- |
| Deployment settings | All six iOS target/configuration settings now use 17.0. No version/build-number, signing, entitlement, bundle or orientation changes. |
| SwiftUI toolbar | `sharedBackgroundVisibility` requires 26. `sgIndependentToolbarBackground` keeps it on 26+, returning standard native toolbar content below 26. Existing views/actions are reused. |
| Tab presentation | iOS 18 `toolbarBackgroundVisibility` replaced by the equivalent iOS 16+ `toolbarBackground(.visible, for: .tabBar)`. |
| Recipe generation | Unguarded Foundation Models / Generable APIs required 26. Removed obsolete Apple provider, generation annotations/types, suitability routing and availability diagnostics from the compiled app. Gemini-only request path, original Gemini instructions and Codable wire fields remain. No Apple framework is linked in either built binary. Manual creation, deterministic ingredients, validation, explicit review/Save and quota handling remain. Old Apple work stays in Git history, not V1 runtime. |
| Authentication test rendering | Test-only `scene.effectiveGeometry.coordinateSpace` required 26; use `scene.coordinateSpace` instead. Gate rendering test passes. |
| Data/state | SwiftData and Observation are available in 17; no model/schema/store rewrite. |
| Supabase/networking | Locked Swift SDK 2.55.3 declares iOS 16 minimum. Dependencies and lockfile unchanged; existing URLSession/CryptoKit/auth transport compiles for 17. |
| Photos/media | PhotosPicker/Transferable and existing UIKit/ImageIO photo infrastructure support the target. Import/thumbnails, persistence, replacement/removal and deletion tests pass in isolated stores. |
| Navigation/sheets/search/animations | Whole-app compiler availability checking passes at 17. Existing NavigationStack, detents, native search, sensory feedback and state handling remain. No duplicate screens or gesture workarounds. |
| Sharing/links | Native sharing, privacy/access checks, URL routes and association entitlements unchanged. Native Dish Copy/share smoke passes. No website/link redeployment. |
| Ranking/social/Recipe UI | Compile and focused smoke pass. Ranking implementation, calibration/unlock code and Recipe content mathematics are unchanged. |

Supported hardware: iPhone XS / XS Max / XR generation onward, including iPhone 11 and newer families, and iPhone SE second/third generation, when running iOS 17 or newer. Newer phones use their shipping/newer OS; this is not a claim they can downgrade to 17. iPhone 8, X and first-generation SE do not qualify. See [Apple's iOS 17 announcement and requirements](https://www.apple.com/uk/newsroom/2023/09/ios-17-is-available-today/).

Older supported systems use their native toolbar/tab appearance and normal app icon where newer dark/tinted icon variants are unsupported. No V1 functional feature is intentionally removed on older iOS. Apple generation is absent on **all** V1 systems; Gemini availability is independent of Apple Intelligence hardware. Upright portrait, light/dark, accessibility and touch targets remain required.

## Ranking-client protection — approved and deployed

A new app alone cannot prevent an already installed older client from recomputing/writing incompatible cached strengths. The owner explicitly approved hosted guard deployment after local tests passed.

Migration **`20261106141231_ranking_assessment_client_guard`**, MD5 **`dbc14d5ed7bafe85cc6c8a657b600c5d`**, is deployed. Supabase assigned the timestamp; the CLI-generated filename was aligned without changing SQL bytes. All **39 local/hosted hashes match**. Original applied migrations are untouched; the first-install reference is the exact concatenation of the chain.

New immutable structured operations include `rankingAssessmentVersion: 1`. The guarded writer uses the existing account lock/live-session/owner boundary and rejects incompatible writers with `0A000` when current, deleted or incoming item diagnostics contain assessment assignments. The original writer is renamed to a private core with no client EXECUTE; the exposed API stays security-invoker. No direct/anonymous bypass, new table, backfill, score fit or evidence rewrite. Already accepted old-operation retries retain the original receipt and do not mutate later data. Legacy stationary accounts remain compatible before adoption; another account is unaffected.

The new client maps rejection to a fixed review/update state, keeps local records and the original queued operation UUID/payload/hash, and stops automatic retries. It never silently claims support by relabeling old queued payloads. If unsynced older-format work is encountered, retain it for deliberate review rather than resetting/discarding it. Older offline apps can still modify their own local files; the guard prevents cloud overwrite. Update every ranking-writing device, and retire incompatible historical TestFlight builds during separately approved distribution preparation. No App Store Connect action was performed here.

Future writer migrations must retain this guard/private-core boundary. The ranking algorithm/assessment assignments from `7b2724e` are unchanged and their deterministic regression/persistence coverage passes.

## Verification

- **Debug Simulator build passed** with minimum 17.0. **Unsigned Release iPhone device build passed**, using the current iOS 27.2 SDK with deployment target 17.0; no archive/upload/signing changes. Both binaries' Info.plist and Mach-O report minimum 17.0, iPhone-only/portrait configuration, and no Foundation Models dependency.
- **52 native test methods / 77 expanded cases passed, zero failures/skips**, across compatibility wire, structured sync, Recipe intelligence/acceptance, media, ranking integrity, account sessions and the separate gate-presentation check. The main run is 51 methods / 76 cases; the gate rendering test adds one. Existing Apple-selection tests were replaced by Gemini-only single-request/cancellation/manual-fallback assertions per the owner's steer.
- **Five UI tests passed, zero failures/skips**, on the existing iPhone 17e / iOS 26.5 lane: four tabs/Grub List/Food Bible/My Kitchen/Settings; re-ranking/result/Profile/unlock; native Dish share/Copy; mocked Recipe import/review/explicit Save/reopen; isolated development-library exit to native Apple onboarding. No real Apple authorization or Gemini request.
- Installed runtimes are 26.5 and 27.2 variants; **no iOS 17 runtime is installed**. No old-runtime download or infrastructure troubleshooting was attempted. Compilation is not represented as an iOS 17 runtime/physical acceptance test.
- **177 local PostgreSQL/PGlite assertions passed**: 17 guard/security/idempotency/preservation, 75 structured-sync interoperability and 85 schema/RLS/reference checks. The schema test's expected migration count was updated from 38 to 39 and now explicitly requires the guard; no assertion was weakened. SQL fixtures use isolated identities, not hosted users.
- Hosted function configuration confirms fixed empty search paths, invoker API, anonymous denial and non-executable private core. Before/after security advisories are unchanged: existing closed-table RLS informational notices and existing [password-protection advisory](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). No Auth configuration was changed to suppress them.
- **42 hosted data/Storage fingerprint groups match**, including scores, evidence and assessment metadata; Storage remains **83 objects**. No real users, accounts or records were created/deleted/reset. Both original development-store copies retain 1 ranking / 12 Dishes / 15 attempts/items / 356 Comparisons / 10 Sources / 21 tags / 48 memberships, with all 190 original JPEG hashes matching.
- Privileged-secret/local-artifact scan, documentation links and whitespace checks pass. Dependency/build/local Supabase state, signing material, test media and backups are excluded. No privileged credentials, keys, billing/provider configuration, Recipe Edge Function, ranking source, share system or photo-sync changes.

Evidence bundles: native `test_sim_2026-11-06T14-14-42-299Z_pid41859_aa35ad5d.xcresult`; gate `test_sim_2026-11-06T15-21-49-573Z_pid41859_c875b1ec.xcresult`; UI `test_sim_2026-11-06T14-20-35-252Z_pid41859_81a6cbcb.xcresult` and `test_sim_2026-11-06T14-24-30-282Z_pid41859_dffa44a3.xcresult`. Unsigned Release build log is retained locally at `/private/tmp/sg-ios17-release-device.log`.

## Remaining physical / preparation steps

On one iPhone actually running iOS 17, install the new build before making ranking changes. Confirm native Apple sign-in/account restore, all four tabs/Settings and existing Recipes, photo selection, sharing/Copy/Messages and HTTPS link opening. Re-rank an intended version and relaunch to verify persistence; preserve all existing data. A smaller SE-sized device is useful for navigation/keyboard/sheet layout. No new live AI acceptance call is required for this unchanged Gemini contract.

The project is ready to prepare the next functional TestFlight candidate, with this older-OS physical smoke clearly outstanding. Select a unique build number/signing/archive/upload only under a separately authorized distribution step; this cycle changed none of those and did not start the Release Gate.

**STAYGRUBBY iOS COMPATIBILITY EXPANSION PASSED — READY FOR TESTFLIGHT PREPARATION**
