# Bulk ingredient entry + Intelligent Recipe Engine V1

> Historical implementation checkpoint. The October 26 follow-up supersedes its verbatim-only validator, timestamp gate, disabled-provider status and unpublished-policy status. See [current failure investigation](STAYGRUBBY_RECIPE_IMPORT_FAILURE_REVIEW.md). Historical test totals below describe the original cycle only.

Starting HEAD: `5a5b1f0a26471eb3840696cd27a5b981785b4493`, clean `main` matching `origin/main`. Owner-accepted Food Bible UX 2.0, natural single-line entry, deterministic parsing and ranking behavior were preserved. Single agent, original checkout, one Simulator lane. The final documentation checkpoint/HEAD is identified by `git log -1 --format=%H -- STAYGRUBBY_INTELLIGENT_RECIPE_ENGINE_V1_REVIEW.md`; exact commits and push outcome are recorded in the final report.

**Implemented and deployed with Gemini deliberately disabled pending owner-only secret/free-tier setup. No live AI parsing or physical acceptance is claimed.** The owner separately approved the quota migration and authenticated function after automatic approval review initially blocked deployment. No paid provider setup, credential values, real Recipe writes, account deletion, TestFlight or App Store Connect actions occurred.

## Product paths and existing identities

- **+ Ingredient**: accepted one-line natural input → IngredientParser → formatted row. Stable native first responder/Return behavior and Edit Details remain.
- **Paste Ingredients**: action in each component → large scrollable multiline sheet → explicit Format Ingredients → same deterministic IngredientParser → append to that component only. No AI/network. Native selection/Paste works; the dedicated keyboard Paste button is removed.
- **Food Bible + / Add Recipe**: Import Recipe or Add Manually → existing cooked-Dish picker. The authoritative existing Recipe link is loaded before creating. A Dish with a Recipe opens that Recipe rather than allowing silent import replacement. Empty accounts still need a cooked Dish first.
- **Import Recipe**: pasted whole text → automatic provider routing → validated RecipeDraft → existing Recipe Editor, including original-text disclosure and review warnings → explicit Save. Formatting never persists/publishes a Recipe, creates a Dish/cook, renames the Dish or writes ranking data.

Example bulk input: `• 2 tbsp olive oil`, `1. 3 cloves garlic minced`, blank lines, `- 28 oz crushed tomatoes`, `2) salt to taste`. Only high-confidence punctuation plus whitespace is removed. `1/2 cup`, `1.5 lb`, `7 spice`, `00 flour` and `-1 pinch` retain meaningful prefixes. Editor-only per-row originals preserve list input. Quantity/unit/preparation parsing reuses the accepted exact rational implementation. Capacity is limited by the existing 100-total-ingredient contract; each line is at most 500 characters and bulk text at most 32 KB. Cancel requires confirmation for nonempty text. Normal correction happens in the existing editor, not a second review workflow.

## Contract, normalization and review

The permanent contract stays `RecipeDraft = RecipeContent`; no Recipe/Dish persistence schema changed. Both providers produce one extraction envelope: nullable `title`, `yield`, `source`, and `components` with nullable `title`, ingredient-source strings and instruction-source strings. Stable local UUIDs/orders are assigned when converting into existing RecipeComponent / RecipeIngredient / RecipeStep values. This temporary extraction contract is not a competing Recipe model or storage API.

V1 is deliberately **extractive**: every returned non-null field and ingredient/instruction must be a contiguous source excerpt after case/whitespace normalization. Creative paraphrases and unsupported quantities, timings, temperatures, servings and section names are rejected. Missing metadata stays nil; unknown/freeform ingredients retain their words. Basic quantity/fraction/unit normalization is deterministic Swift. No AI serving math, conversions or scaling. Optional prep/cook times, cuisine/course and other fields remain available for user correction; this V1 extractor does not guess them from general culinary knowledge.

The model is instructed to retain meaningful original components and their ingredients/method, and keep simple Recipes to one unnamed component. Strict schema validation rejects unknown fields, wrong types, empty/no components, invalid excerpts, excess rows/lengths, blocked or truncated provider results. Existing storage caps apply: 20 components, 100 ingredients total, 100 steps total, ingredient source ≤500 characters, step ≤2,000 characters. Normalized encoded drafts must fit a conservative 40 KB budget before review, within the existing save request limit. IngredientParser supplies existing quantity/unit/name/preparation/note fields; Recipe preparedForSave rebuilds the legacy arrays for existing clients/search.

Source-span validation prevents introducing facts absent from the source; it cannot prove correct section assignments, semantic interpretation or completeness. A model can omit information or place a real source step in the wrong section. The review notice and original-text disclosure are therefore mandatory. A single aggregate notice flags unknown quantities; absent method gets a useful warning. No warning spam for every missing time/serving field.

Only normal Save uses the existing Recipe UUID, expected revision, ownership, Dish linkage and revision history. No new AI search index. Existing cookbook title/ingredient/cuisine/source search remains in use; Dish metadata still supplies the established index fallback. Existing Recipes remain readable/compatible and unchanged unless explicitly edited/saved.

## Providers and device availability

`RecipeIntelligenceProvider` exposes availability/identity/extraction; `RecipeIntelligenceService` validates input and routes Apple first, then one Gemini fallback. Provider-specific details do not enter permanent Recipe data. Cancellation does not retry another provider; other Apple/model/validation failures may try the consented fallback once. No infinite retry loop.

**Apple**: official FoundationModels `SystemLanguageModel.default.availability`, `LanguageModelSession`, `@Generable` guided output and GenerationOptions. Deployment target remains iOS 26.5. This is implemented, Debug/Release compile verified, with mock availability/routing/contract tests. The owner’s ordinary iPhone 15 has no Apple Intelligence path and automatically uses Gemini when cloud permission and server configuration are available. No physical Apple-model inference was performed or claimed; device/region/language/system model readiness can vary independently of OS version.

**Gemini**: fixed `gemini-3.5-flash-lite`, selected from current official model/pricing/structured-output documentation on October 26, 2026 for low-latency/cost structured extraction with a published free tier. The app never holds its key or calls Google directly. A separate authenticated import transport uses the current Supabase session, guards account identity before/after the await, and invokes `recipe-import`. Ordinary development-library mode has no cloud import connection. Isolated Debug UI fixtures inject synthetic responses; the real Gemini/Apple providers are not used by normal automated tests.

Sources: [Apple generation/availability](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models), [Gemini models](https://ai.google.dev/gemini-api/docs/models), [pricing](https://ai.google.dev/gemini-api/docs/pricing), [structured GenerateContent](https://ai.google.dev/gemini-api/docs/generate-content/structured-output), [billing](https://ai.google.dev/gemini-api/docs/billing), [terms](https://ai.google.dev/gemini-api/terms), [Supabase function authorization](https://supabase.com/docs/guides/functions/auth-headers). Supabase changelog reviewed; CBC TLS deprecation and the Postgres minor-version advisory do not require changes to this modern native client/additive counter SQL.

## Hosted endpoint, authentication and cost controls

Hosted project: existing `lgjxbpycphhsswxoncmz` only.

- Migration `20261026200904_recipe_import_budget.sql` is byte-identical to CLI-created `20261026200049` before hosted timestamp alignment. MD5 `0a4906cc8b31a7b410764e877610996c`. All **26** hosted/local migration hashes match.
- `recipe-import` Edge Function **v1**, ACTIVE, `verify_jwt=true`; original delete-account function unchanged. Four deployed runtime files: index.ts, handler.ts, contract.ts, deno.json. No unpinned external runtime dependency.
- Gateway requires user JWT. Handler verifies user through Auth, rejects anonymous identities, then uses verified user/session claims for server-only budget reservation. SQL checks an active provisioned account, live matching Auth session, unexpired session and undeleted non-anonymous user. No authorization from editable metadata or caller-selected owner/model/upstream URL.
- New `staygrubby.recipe_import_usage` contains counters only, RLS enabled, no anon/authenticated table grants or policies. `api.reserve_recipe_import` is service-role-only SECURITY DEFINER with empty search_path and fully qualified references. No new client grants to existing data. Account counters cascade on account deletion; no existing deletion implementation changed.
- Atomic reservations lock fixed global-month first, then global-day/account-day/account-minute rows. Limits: **3/account/minute, 20/account/day, 100/global/day, 1,000/global/month**. Failed provider calls count; no refund/retry loophole. UTC day/month windows. Old counters older than the previous month are removed during reservations; current month ceiling remains intact.
- Input: ≤12,000 characters /32 KB text, ≤40 KB bounded streaming request body. Structured upstream response ≤128 KB; extracted JSON ≤96 KB. Fixed schema and source validation are enforced on server and client. Google request timeout 25 seconds; Auth/budget requests 8 seconds each. Cancellation suppresses stale client results and propagates to the upstream request when delivered by the transport. No arbitrary proxy, raw provider error or unrestricted CORS. No direct Recipe save/read in the import endpoint.
- Production function code intentionally logs **no prompt, response, token, secret or raw provider error**. Platform invocation/security logs remain subject to provider policies. Counters retain no recipe text. Errors return stable safe categories only.

There is **no paid mode**. Both secure secrets must be present, and the free-tier confirmation must be a future ISO timestamp no more than 30 days away, or requests fail closed before reservation/upstream. Expiration is an intentional reconfirmation gate. A key alone cannot enable the service. Quota failure never switches to a paid model/key. Application limits bound calls even across concurrent isolates/devices.

A configuration flag cannot independently prove Google billing status. To guarantee the intended zero-paid path, the owner must use a dedicated project with **no linked billing account** and keep it unbilled. If someone later attaches billing while a confirmation is valid, bounded requests could still become chargeable; no application flag can prevent an external project administrator changing billing. Google spend caps/budget alerts are not a substitute (official docs describe delayed enforcement/overages). This residual risk is disclosed, never treated as an automatic free-tier guarantee.

## Secret setup — only owner action still required for Gemini

Correction from the follow-up investigation: the CLI inventory returned an authentication error, not a successful empty inventory; the earlier absence claim was not established. The owner subsequently confirmed both settings configured, and physical requests passed the configuration guard. No secret values were read or requested. No Gemini request, free quota or paid token was consumed by this cycle.

1. In Google AI Studio, create/select a **dedicated unbilled project**, confirm it shows Free tier and has no linked Cloud Billing account. Do not upgrade, add a payment method, buy credits, or enable paid usage. Create a provider key restricted to the Generative Language API where available. Keep its value out of chat, source, screenshots, local files and logs.
2. In the existing StayGrubby Supabase Dashboard, open **Edge Functions → Secrets**. Add `STAYGRUBBY_GEMINI_API_KEY` using the key directly in that secure Dashboard field.
3. After verifying the unbilled project, add `STAYGRUBBY_GEMINI_FREE_TIER_UNTIL` as an ISO-8601 UTC timestamp in the future and within 30 days (for example, `2026-11-02T00:00:00Z` if configuring during this review week). Save. Renew only after reconfirming the project remains unbilled. No service-role key/PAT/database password/Apple private key is needed from the owner. Never paste any provider secret into Codex.
4. Publish the prepared canonical privacy-policy update through the established website workflow before enabling real cloud use, and review App Store privacy disclosures before a later distributed build. This run prepared/bundled the policy and tested the static site; it did not publish the website or modify App Store Connect.
5. Perform the physical iPhone 15 acceptance below. No app key edit, client rebuild for secrets or another schema/function deployment is required merely to configure these server settings.

## Failure, privacy and accessibility

Cloud permission defaults **off per import**, with a plain-language disclosure: on-device first where available; permission allows recipe text to go through Supabase to Google. The free-tier Google service may use prompts/responses to improve products and may involve human review. Confidential/personal data should not be pasted. Both the bundled canonical policy and prepared website rendering disclose the new practice; neither claims all processing stays on device or zero provider retention.

Format shows restrained ProgressView, disables repeated submission and offers Stop Formatting. Unavailable model/configuration, network, quota, timeout and invalid output preserve the raw text and expose retry/manual continuation. Continue Manually preserves the entire source in editable method rows (≤2,000-character chunks), plus original disclosure; it does not falsely label it parsed. Cancel of the result returns to the original import text. Nonempty import/bulk sheets require deliberate discard. Backgrounding retains in-memory text; **force-quit recovery of unsaved drafts is not implemented**, consistent with the accepted editor’s scope. Extremely oversized manual text may still require user editing to satisfy ordinary Recipe Save limits; it is never silently truncated.

Native labels/identifiers cover text editors, permission, actions, progress/error and correction UI. Body/Dynamic Type fonts, scrolling, native selection, ≥44pt actions and semantic light/dark colors are used. No new motion animation, dependency on animation, custom drag gesture or clipping workaround. Large-type/Reduce Motion and light/dark screenshots were inspected. Automated labels/layout checks are not a claim of physical VoiceOver listening acceptance.

## Verification and preservation

Final results and checkpoint inventory are recorded below. Implementation checkpoint: `55ab1a0` (28 files). Earlier development failures are preserved accurately: the broader run caught a native ingredient field still holding keyboard focus during Cancel after backgrounding; Cancel now finishes local input/dismisses focus before requesting the unchanged discard confirmation. Focused verification still requires exact original text after Keep Editing. The new existing-Recipe protection test initially selected a non-fixture Dish title; it now searches/selects the actual named fixture. Schema reference/inventory expectations were extended for the additive counter table and server-only RPC, retaining the exact pre-existing API inventory and denied client access. the initial new error-path UI test used an ambiguous Cancel locator between nested sheets; explicit intended-control identifiers fixed it without reducing assertions. A typed optional closure ternary exposed a Swift compiler diagnostic failure; an explicit conditional closure avoids it. Website tests were narrowly updated for exactly the two provider-policy links on the privacy page and the new effective date, retaining the public-file allowlist/no-script protections.

Hosted post-deployment checks: all 35 baseline existing-data/Storage fingerprints unchanged, including **64 Storage objects** in this cycle’s starting baseline. Existing table ACL/RLS, policy and function-definition/ACL aggregate hashes unchanged (excluding only the new counter objects). New counter table empty; anon/authenticated budget EXECUTE false, service_role true. Unauthenticated deployed endpoint returns **401**. Security advisor: no ERROR; existing leaked-password WARN remains, and the intentional RPC-only/no-policy INFO count increases 19→20 for the inaccessible counter table. No new user/account/cooking/Recipe/test records or photo bytes were created in the hosted project.

Preserved demo baseline is 1 global ranking /12 Dishes /15 attempts/items /356 comparisons /10 Sources /21 tags /48 memberships and 190 media files. Ranking engine/calibration/evidence/unlock/re-rank, photo/structured sync, official assets and Tickets were not changed. Original guest/demo library was never reset or seeded. Test fixtures use fresh UUID stores/media and mock providers.

## Physical iPhone 15 acceptance (pending owner setup)

1. Keep existing data; install the reviewed Debug/device build using normal signing. Open Food Bible → Add Recipe → Import Recipe → choose an existing cooked Dish **without a Recipe**.
2. Paste a simple full Recipe. Enable the disclosed cloud permission and Format Recipe. On ordinary iPhone 15 this automatically uses Gemini; there is no provider picker or Apple-unavailable dead end.
3. Confirm progress → existing Recipe Editor, original text/review notice, ingredients/method and missing quantities preserved. Correct an ingredient normally and with Edit Details; review title/source. Tap Save explicitly. Confirm same Dish, one cookbook entry, search by title/ingredient/source, reopen and normal revision behavior.
4. Repeat with Cod / Red Pesto / Gnocchi & Brussels source sections, and messy risotto notes with missing quantities/times. Check section assignments against original text; no invented servings, temperatures or precise timings. Simple Recipe should remain simple.
5. Select a Dish that already has a Recipe through Import; it must open its existing Recipe without replacing it. Cancel imports/drafts and confirm saved data unchanged.
6. While editing a Recipe, open Paste Ingredients in a specific section. Paste bullets/numbering, blank lines, fractions, units and unknown quantities. Format; confirm only that section receives rows. Correct, Save, reopen.
7. Turn cloud permission off or disconnect network; preserve raw text, retry or Continue Manually. Test Stop Formatting and background/return. For quota/config failure, use the development fixture or wait for a real service limit; do not deliberately burn quota. Review light/dark, large text and VoiceOver on device.

## Remaining boundaries / release gates

Gemini is **not physically ready until the owner configures the two server secrets against an unbilled project**; end-to-end live inference remains unverified. Apple is compile/mock verified, not physically owner-verified. No paid billing enabled. Policy publication/disclosure review and physical acceptance remain explicit gates. Universal Links remain owner-confirmed physically broken and deferred; no investigation in this cycle. Remaining external-beta UGC moderation hardening remains deferred. No Tickets restoration, OCR/photo/PDF/URL import, timers, Start Cooking, serving scaling, groceries, meal planning, Taste Intelligence, ranking changes, TestFlight upload or App Store work was performed.


## Final verification totals and artifacts

| Verification | Result |
| --- | --- |
| Native tests | **34 passed** across IngredientParserTests (6), IngredientEntryTests (11), RecipeIntelligenceTests (9), FoodBibleTests (5), CookbookUXTests (3). Parameterized parser corpus is counted as test functions, not inflated into extra executions. |
| One broader Recipe/Food Bible integration | **49 executions: 47 passed, 2 failed, 0 skipped**. Failures were the Cancel/focus path and incorrect fixture Dish title described above. Both resolved. |
| Final focused follow-up | **5/5 passed, 0 failures/unexpected failures/skips**: bulk normal, bulk large/Reduce Motion/background/cancel, partial natural line/background/Keep Editing/discard, existing Recipe protection, quota/manual fallback/raw retention. Together with the successful broader coverage, all **34 native +15 UI distinct tests** are verified. No claim of a single all-green broader rerun. |
| Edge Function | **20/20 Deno mocked tests**, no live quota. Includes authentication, consent, input/body bounds, configuration expiry, rate/budget failure, structured success, provider quota/error redaction, invalid/hallucinated/extra/truncated output, byte ceilings, timeout and cancellation. Deno check passed. |
| Focused PostgreSQL | **150 assertions passed**: schema/RLS/reference inventory 83; new import budget 16; ingredient persistence/revision/search 17; existing Food Bible 34. Disposable PGlite only. |
| Prepared public policy/site | **7/7 tests passed**; complete canonical policy parity, public-file allowlist, allowed external policy links and static accessibility/security invariants. Not published. |
| Debug | Build/test compilation and isolated launch passed on iPhone 17 Simulator, iOS 26.5. Final focused run compiles the final source. |
| Release | Final generic iOS Simulator Release build succeeded (arm64 +x86_64), no code signing/distribution. No new source warnings; standard no-AppIntents metadata notice only. |
| Release contents | No UI-test/development-library/provider-fixture launch strings; no Google API key pattern. FoundationModels framework linked. |
| Secrets / whitespace | Existing privileged/local-artifact scan extended for Google key pattern: **351 text files, zero findings**. Separate repository/provider-key and Release scans clean. Both diff whitespace checks pass. No local backups, dependencies, Supabase state, generated public output, signing material or build products included. |
| Preserved data | Original demo logical manifest and 190 media hashes unchanged; final hosted **35/35** existing-data/Storage fingerprints match this cycle's baseline. Counter rows remain **0**. No real inference, fixture leakage or hosted cooking/Recipe writes. |

Evidence (machine-local, intentionally not committed): `/private/tmp/intelligence-final-regression.xcresult`, `/private/tmp/intelligence-final-focused.xcresult`, corresponding logs/summary JSON; `/private/tmp/intelligence-release-checkpoint.log`; `/private/tmp/intelligence-{edge,budget,persistence,food-bible}-tests.log`; `/private/tmp/intelligence-schema-tests-complete.log`; `/private/tmp/intelligence-website-final.log`; `/private/tmp/intelligence-demo-{before,final}.json`. Exported screenshots reviewed under `/private/tmp/intelligence-regression-visuals`. Unsaved source text in screenshots is synthetic fixture content.

## Checkpoint inventory

The implementation checkpoint contains these 28 files; the final documentation checkpoint contains this review, UI_ARCHITECTURE.md, STAYGRUBBY_MASTER_ROADMAP.md and the historical ingredient-entry review update (**32 distinct files total**). No owner files were discarded. Origin push is a normal fast-forward attempt only; its outcome and final HEAD are reported at completion. If existing HTTPS authentication fails, push with GitHub Desktop; no credentials/configuration/SSH/history workaround.

- `Backend/schema.sql`
- `Backend/tests/recipe-import-budget.test.mjs`
- `Backend/tests/schema.test.mjs`
- `DevelopmentTools/check_privileged_secrets.py`
- `StayGrubby/Accounts/AccountApplicationRoot.swift`
- `StayGrubby/Accounts/AccountSessionCoordinator.swift`
- `StayGrubby/Legal/PrivacyPolicy.md`
- `StayGrubby/Social/BulkIngredients.swift`
- `StayGrubby/Social/IngredientEntryDraft.swift`
- `StayGrubby/Social/IngredientLineField.swift`
- `StayGrubby/Social/RecipeEditor.swift`
- `StayGrubby/Social/RecipeImportTransport.swift`
- `StayGrubby/Social/RecipeImportView.swift`
- `StayGrubby/Social/RecipeIntelligence.swift`
- `StayGrubby/Social/SocialReview.swift`
- `StayGrubby/Views/Cooking/FoodBibleView.swift`
- `StayGrubbyTests/RecipeIntelligenceTests.swift`
- `StayGrubbyUITests/FoodBibleUITests.swift`
- `StayGrubbyUITests/RecipeImportUITests.swift`
- `Website/build.py`
- `Website/test_site.py`
- `supabase/config.toml`
- `supabase/functions/recipe-import/contract.ts`
- `supabase/functions/recipe-import/deno.json`
- `supabase/functions/recipe-import/handler.test.ts`
- `supabase/functions/recipe-import/handler.ts`
- `supabase/functions/recipe-import/index.ts`
- `supabase/migrations/20261026200904_recipe_import_budget.sql`
