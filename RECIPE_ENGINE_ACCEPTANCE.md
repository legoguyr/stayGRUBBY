# Recipe Engine reliability and acceptance

Status: **AUTOMATED ACCEPTANCE PASSED — OWNER PHYSICAL ACCEPTANCE PENDING**.

Scope: the October 26 overnight reliability cycle, starting at `98c771d3be480f6761a4cd06994c4649300d9ecd` on clean `main`/`origin/main`, preserving the subsequently uncommitted v10 diagnostics. No independent Recipe/Dish work, ranking, social, photo sync, Universal Links, account deletion or distribution work.

## Proven failure and owning layers

The earlier Google 400 was corrected by removing nested array bounds from the provider grammar, with runtime bounds retained. The tiny live recipe then returned Google/function 200 and opened the editor. This did **not** establish acceptance of the real kale input.

The actual kale v10 request at **October 26, 11:05:14 pm EDT** reached Google 200, completed generation, parsed and passed structure/count checks. It returned server **422 invalid_recipe**, reason **source_word**, after 1,998 ms. The candidate contained **1 component, 12 ingredients, 9 steps**. Exact rejected fields:

| Field | Rule |
| --- | --- |
| components[0].ingredients[7] | source_word |
| components[0].ingredients[10] | ingredient_phrase |
| components[0].ingredients[11] | ingredient_phrase |
| components[0].steps[7] | source_word |
| components[0].steps[8] | source_word |

The function never returned a draft to the client. Authentication, model, endpoint, timeout, output-token stop, JSON shape and native decoding were not the cause. No transformation of provider strings occurred before these checks. Quantity canonicalization happened inside evidence comparison; ingredient parsing happened later on the client.

This identifies a **provider-contract / prompt / validator interaction**: the prompt allowed light grammatical cleanup and organizational annotations, while the validator required a narrow source vocabulary and contiguous ingredient phrase. Those rules could reject a reasonable organization; they also correctly catch an invented ingredient variety. The raw provider response was intentionally never logged or retained, so we cannot claim the actual five rejected strings said any particular word. The permanent representative response reproduces the observed shape/rules and is explicitly **synthetic**, not falsely labeled a captured Gemini response.

## General correction

Cloud pipeline: unchanged raw source → provider envelope → JSON/type/count checks → source checks → **bounded source reconciliation for recoverable wording only** → the **same full source/schema validation again** → Swift decoding → deterministic ingredient normalization → native validation → existing Recipe Editor. No second editor or permanent Recipe schema.

- Keep the minimal Google-compatible schema: nullable title/yield/source and component titles, ingredient strings and method strings. Missing amounts/times/temperatures need not be fabricated. Required structure and all runtime limits remain.
- Prompt both providers to organize source-supported preparations, retain alternatives together, prefer source wording over culinary paraphrase, and preserve uncertainty instead of guessing a variety or adding conventional amounts/times/temperatures.
- Reconcile only lexical/phrase mismatches by retrieving **literal original source substrings**. Optional unsupported labels become unknown. No new culinary word is accepted merely because it sounds plausible. Relational ingredient annotations can be removed while restoring the actual source name and vague qualifiers.
- Preserve source context/completion qualifiers in restored methods and keep preparation prose out of ingredient names. Recovery never mutates the input or the provider fixture.
- Do not repair unsupported numbers, quantity/unit pairs, malformed structure, empty fields, count/length failures or invalid quantities. Failed quantitative ingredient fields cannot be rebound to another source amount/unit. No reliable source anchor means failure/manual continuation, rather than guessed facts.
- Keep the original text and existing review warnings visible. Recovery is not a proof of section assignment, completeness or model semantics; original dictation can remain wordy. The owner must review before Save.
- Exact rational equivalences remain quarter ↔ 1/4 ↔ 0.25, half ↔ 1/2 ↔ 0.5, spoken integers and existing unit aliases. Added matching named degrees Fahrenheit/Celsius to °F/°C; **no temperature conversion**. Negative ingredient quantities and zero denominators are rejected consistently on server/client. Ranking/math and the general IngredientParser grammar are unchanged.

The first phased vocabulary/annotation mismatch occurs at **Phase 3**; deterministic degree-unit alias disagreement is exposed at **Phase 4**; unsupported confident transcription correction is exercised at **Phase 5**. Multi-preparation/source-context recovery is stressed in **Phases 6–7**. Earlier schema compilation failure could prevent even Phase 0, and remains covered by the provider-grammar test.

The test loop caught additional bugs before deployment: recovery initially copied preparation prose into an ingredient, dropped a method's subject/completion qualifier, and broad stemming could choose a different chile-related source phrase. Explicit semantic assertions now prevent those regressions; recovery uses exact normalized anchors, not that stemming.

## Permanent harness

| Layer | Artifact |
| --- | --- |
| Approved phased sources and representative provider responses | StayGrubbyTests/Fixtures/RecipeEngineAcceptance.json |
| Original canonical source | RecipeImportFailure.json `raw`; copyable RecipeEngineCanonicalKale.txt |
| Hallucination/invalid-fact cases | RecipeEngineNegative.json |
| Deterministic full production handler, mocked Auth/budget/provider only | DevelopmentTools/recipe_engine_acceptance.ts |
| Edge integration, phased/negative/source safety and contract drift | supabase/functions/recipe-import/acceptance.test.ts + handler.test.ts |
| Actual server outputs consumed by Swift | RecipeEngineServerOutputs.json |
| Swift decode → normalize → source guards → editor-valid RecipeContent → Codable round trip | RecipeEngineAcceptanceTests.swift |
| Isolated actual Import → editor → Cancel/raw preservation | RecipeImportUITests.testCanonicalKaleServerContractOpensEditorWithoutSaving |

Canonical UTF-8 SHA-256: `774a33291a4e216bb55ce4b1d476d0b9c12a4b8aeb3faa2163f3be51da933915`. The test asserts that the original JSON, copyable text and UI fixture contain the identical 882-character source. Phase 7 is never cleaned before entering the normal handler.

Server output snapshots are produced by the real handler and tested for drift. Their synthetic provider inputs are separately tested for semantic properties: unknown quantities stay unknown, uncertainty/alternatives remain, method subjects and supplied completion qualifiers survive, preparation prose is not an ingredient, no unsupported variety appears. Swift consumes exactly these outputs, including quantity/unit equivalences and genuine final-draft bounds.

The UI provider fixture is gated by **DEBUG + isolated UI-test store + social-review + recipe-import-review**. It accepts a bounded synthetic response from the test runner, still passing normal decode/source validation. It cannot authenticate, invoke Gemini, provision an account or write the normal store. Release binary/resource checks confirm no injection marker, test launch flag or Recipe Engine fixture resource in the app.

### Run the fast checks

With Deno installed (verified here with Deno 2.9.6):

```sh
deno test --allow-read supabase/functions/recipe-import/handler.test.ts supabase/functions/recipe-import/acceptance.test.ts
deno run --allow-read DevelopmentTools/recipe_engine_acceptance.ts
```

To intentionally refresh client/UI snapshots after reviewing a contract change (never as an automatic way to make a failed assertion green):

```sh
deno run --allow-read --allow-write=StayGrubbyTests/Fixtures/RecipeEngineServerOutputs.json,StayGrubbyUITests/Fixtures/RecipeEngineKaleUI.json DevelopmentTools/recipe_engine_acceptance.ts --record-contracts
```

Then run `RecipeEngineAcceptanceTests`, `RecipeIntelligenceTests` and `RecipeImportFailureTests` in the existing StayGrubby scheme. Run the canonical no-Save UI test after flow/client changes. Keep one Simulator lane; use an existing booted iPhone Simulator destination. Near a broad Recipe Engine checkpoint, include existing IngredientParser/IngredientEntry/FoodBible/Cookbook tests once. Do not routinely retest ranking/social/photo sync or run every UI test.

## Final automated results

| Verification | Result |
| --- | --- |
| Phases 0–7 | **All pass**, nine cases (two Phase 7 provider variants), unchanged source. |
| Edge/function/acceptance | **57/57 pass**, including **12 adversarial cases** plus malformed/refused/truncated/oversized/bounds/auth/timeout/log-redaction coverage. |
| Final native regression | **41/41 pass**, seven Recipe/ingredient/cookbook suites. |
| Final import UI | **3/3 pass**, canonical exact input/editor/cancel, quota/manual/original preservation, large-type/background retention. No kale Save. |
| Debug/Release | Final Debug regression/build and generic iOS Simulator Release build pass. |
| Release isolation | No test-provider injection marker, Debug diagnostic symbol, UI-test launch marker, Google key pattern or Recipe Engine fixture resources in the app. |
| Static/security | Deno typecheck, privileged-secret/local-artifact scan (**366 text files, zero findings**) and whitespace checks pass. |

Counts above are distinct final checks, not inflated by earlier repeated iterations. Earlier failed development assertions are the recovery-quality issues described above and were resolved without removing their checks.

Controlled mocked-handler phase runs take approximately **0.3–10 ms** locally after startup (first case ~33 ms), not a live-network performance promise. The previous real tiny import took 1.54 seconds; the failed real kale request completed in ~2 seconds. No brittle network timing assertion or extra retry loop was added.

Machine-local evidence, intentionally excluded from Git: `/private/tmp/recipe-overnight-regression.xcresult`, `/private/tmp/recipe-overnight-kale-ui.xcresult`, `/private/tmp/recipe-overnight-native.xcresult`, corresponding logs, `/private/tmp/recipe-overnight-release.log`, `/private/tmp/recipe-overnight-all-edge.log`, `/private/tmp/recipe-acceptance-phases.log` and data audit snapshots.

## Live-provider and data boundary

No new live Gemini calls were made in the overnight harness. Apple routing/availability and the shared contract are tested with mocks; real Apple model inference was not performed. Existing tooling cannot invoke as the owner without extracting a session credential or adding an authentication bypass. Neither was done. Do not confuse deterministic provider-quality examples with a live Gemini quality test. Historical v9/v10 prove actual schema/provider access; the newly corrected prompt/reconciliation and exact kale model output still need **one final physical acceptance**, not another diagnostic retry chain.

All automated tests use synthetic responses/isolated UUID stores. No real Recipe, Dish, attempt, ranking, evidence, social record or Storage object was created/edited/deleted. The deployed endpoint can reserve its existing bounded usage counter on an owner request; tests use a mock reservation and consume no provider quota. No secrets, billing, account/session architecture or migrations changed. Final verification: all **35/35 hosted data/Storage fingerprints** match the overnight baseline. The demo manifest remains `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`: 1 ranking, 12 Dishes, 15 attempts/items, 356 comparisons, 10 Sources, 21 tags, 48 memberships and 190 unchanged media files. Hosted `recipe-import` **v11 ACTIVE**, JWT verification enabled, six runtime files byte-identical to local; bundle SHA-256 `862bc336f2fd05c522bf6c2d107bbfafe3ff392771d9cc26ec3d583f55e21d0e`. Unauthenticated endpoint check returns **401** without a provider call. No schema migration was needed; existing 26 SQL migrations/schema reference are unchanged. Release has only the standard no-AppIntents metadata warning.

## One final owner acceptance

1. Install a **new Xcode build** for the native alias/diagnostic/prompt changes.
2. Sign into the existing account. Food Bible → Add Recipe → Import Recipe; choose an existing cooked Dish without a Recipe. Use **Cloud Formatting**.
3. Paste **all of RecipeEngineCanonicalKale.txt**, unchanged. Format once.
4. Expect the existing Recipe Editor with source-supported preparations/ingredients/method. Exact section names are not prescribed; the new prompt allows separate sauce/pasta, chips and crisp preparations. Original wording may remain where cleanup is uncertain.
5. Check known quarter-cup amounts, two cloves, tablespoon of cold butter and the per-person qualifier. Pasta/garnish amounts and missing oven temperature must remain unknown; the supplied approximate five-minute crisp instruction may remain in the method. Verify the uncertain dictated chile phrase is preserved, and alternatives are not made separate mandatory ingredients. Review section assignment, original text and any corrections before proceeding.
6. **Only after review, Save explicitly**, close/reopen the Recipe and verify corrected fields/sections persist under the same Dish. This is normal owner acceptance; the automated run did not Save the kale into the real Food Bible.

Do not mark physically accepted until the owner completes that test. No TestFlight/App Store work is part of this cycle.

## Checkpoints

Implementation/test checkpoint: `9794b92` (18 files), including v10 diagnostics. The separate documentation checkpoint contains this report, the historical investigation update, UI_ARCHITECTURE.md and STAYGRUBBY_MASTER_ROADMAP.md. Final HEAD, clean status and normal-push outcome are reported to the owner; no credentials, Git configuration or history workaround.
