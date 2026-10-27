# Recipe Engine reliability and acceptance

Current Recipe Creator contract/status: [RECIPE_CREATOR_REVIEW.md](RECIPE_CREATOR_REVIEW.md). The editorial-only contract below is historical and superseded; its fixtures remain regression coverage. It does not add a separate owner test.

## October 27 editorialization cycle — historical

The owner **physically accepted v11** with the unchanged canonical kale text on a real iPhone. That safe baseline is preserved in implementation `9794b926a2206509c247c4c42b2e83742ceea5f5` and starting HEAD `a804628e224730947443f8e74bb1c030427baad8`. This cycle began on clean `main`, aligned with `origin/main`. The sections below headed “v11 historical acceptance” retain the earlier investigation/results, not a pending v11 gate.

### Editing architecture and factual boundaries

**Rewrite the words; never rewrite the cooking.** One provider response still returns the same transient Extraction envelope and existing RecipeDraft/editor. No second polish call, permanent Recipe fields, migration, billing change or credential access. Apple and Gemini use identical instructions (asserted by a contract test): edit the user's recipe rather than develop a recipe; improve imperative prose, grammar, punctuation, repetition, supported sections and equivalent quantities; never complete missing cooking information. Unknown/vague/optional/uncertain information stays so. No outside culinary knowledge.

Existing source grounding remains the field-level guard, extended with a closed, context-dependent editorial vocabulary. “Put in oven till crispy” can become “Bake until crispy”; “mix ... until glossy” can become “toss ... until glossy”; cooling/stirring/squeezing can use the tested editorial equivalents. Ingredient identities, varieties, numbers, units, preparation and doneness words remain evidence. A preparation descriptor cannot simply be borrowed from another ingredient. Exact rational quantity/unit equivalences and degree aliases remain; no conversions or scaling.

`RecipeEditorialEvidence` / `editorial.ts` add **transient source obligations**, not a second AI extraction pipeline or provider-authored fact claims. They retain source qualifiers (a little/some/optional/maybe/to taste/per person/about), numerical facts, preparation words and complete alternative groups. Safely recoverable missing qualifiers are restored locally into the edited ingredient/step; the same source/schema guard runs afterward. This does not discard a polished step merely because it says “5 minutes” instead of “five minutes.” Reapplication is idempotent and does not mutate provider input. A lost obligation without a safe target fails with fixed safe reason `fact_lock`.

Recovery first tries removing only a closed set of unsupported modifiers (extra-virgin/freshly/finely/roughly) **if the remaining edited field independently passes every source guard**. It never deletes numbers, negation, technique words or uncertain chile varieties this way. Otherwise v11's bounded literal-source recovery remains the conservative fallback. Hard quantity, binding, schema, count and length failures remain failures. Safe polished prose survives unchanged in editorial fixtures; scoped repair does not replace the rest of a method.

This is bounded deterministic evidence checking, **not a formal proof of arbitrary natural-language meaning, completeness, action order or section assignment**. Source text, mandatory review/manual correction and explicit Save remain essential. No model output is silently saved. An unrecognized paraphrase can still conservatively recover source wording or require manual continuation.

### Independent acceptance dimensions

- **Factual fidelity:** 18 safe/unsafe rewrite pairs cover fractions, word quantities, missing amounts/temperature, approximate duration, vague/optional ingredients, cheese identity, cold/cubed butter, cooling/draining, equipment, technique, garnishes/storage, preparation/doneness, salt type and descriptor binding. Invented extra-virgin, 3 vs 2 cloves, 400°F, 5–7 vs about 5 minutes, 12 oz pasta, 1 tsp chili oil, Parmigiano-Reggiano and kosher salt remain rejected or source-only recovered; unsupported additions do not survive.
- **Editorial quality:** nine synthetic provider examples cover run-ons, filler, repetition, fragments, capitalization, written quantities, multiple actions, vague alternatives, scoped modifier repair and local qualifier restoration. Assertions check capitalization/punctuation, bounded readable steps, removal of specified dictation artifacts and preservation of polished provider methods. Most tests do not require one exact rewrite.
- **Canonical kale:** byte-identical 882-character source, original JSON and copyable TXT unchanged; SHA-256 `774a33291a4e216bb55ce4b1d476d0b9c12a4b8aeb3faa2163f3be51da933915`. The editorial contract produces three supported sections, 13 ingredient rows and 9 method steps. Quarter cups, two cloves, tablespoon of cold/cubed butter, per-person quantity, approximate five-minute crisp instruction and original “clabbering chilies”/alternatives survive. Pasta/garnish amounts, oven temperature, total servings/prep/cook times remain unknown. This is a **synthetic contract result, not captured live Gemini output**; no kale-specific runtime branch or hardcoded rewrite exists.
- **Prior baseline:** all nine Phase 0–7 cases and twelve original adversarial cases remain. The canonical-faithful golden response now includes restored “a little” and optionality; its raw source/provider fixture was not changed. New editorial fixtures are additive. The UI contract now uses the polished canonical response, retaining exact source bytes.

### Verification and deployment

Final results: **87/87 Edge tests**, **45/45 native tests across seven suites**, and **4/4 UI tests**, **136 distinct tests total, zero failures/unexpected failures/skips**. Edge includes nine old Phase 0–7 cases, nine new editorial cases, eighteen paired tests and the original twelve adversarial cases. Native checks cover both shared server contracts and both provider semantics, parser/entry/Food Bible/cookbook behavior, editor compatibility and Codable persistence. UI covers exact canonical input/editor/Cancel, explicit synthetic Save/reopen, quota/manual/original preservation and large-type/background retention. The captured canonical editor screenshot was reviewed. Debug and generic Simulator Release builds pass. Deno typecheck, privileged-secret/local-artifact scan (**370 text files, zero findings**), Release test-resource/provider-injection isolation and whitespace checks pass.

One focused development run failed an assertion that expected “to taste” in the ingredient name; the established parser correctly keeps it in the note. The assertion now checks the correct existing field and passes; no parser behavior/test protection was weakened. Two qualifier-target/equivalent-number bugs were caught by the new tests and corrected. Counts above exclude repeated development executions. Final review also changed the 200-source-obligation bound to fail closed rather than silently truncate; all 87 Edge tests and the 8 affected native tests passed again, followed by a final Release build. v12 was the first editorial deployment; v13 includes this bounded-work correction. No intermediate owner retry was requested.

Hosted **recipe-import v13 ACTIVE**, `verify_jwt=true`, all seven runtime files byte-identical to local; bundle SHA-256 `1229a9395fa98d8ccae12a1c79e198d68675e2891b6a320b75d2744d7e1ddc1d`. Unauthenticated POST returns **401** before the provider. `index.ts`, model/endpoint/schema grammar, auth/session verification, quota reservation, timeout/size caps, logging redaction and free/unbilled policy remain. No secrets or billing settings were accessed/changed. No new migration; all 26 SQL files/schema are untouched.

**35/35 hosted data/Storage fingerprints unchanged** from this cycle’s fresh baseline (including 3 Recipes and 69 Storage objects). The development manifest is unchanged: `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`, 1 ranking / 12 Dishes / 15 attempts/items / 356 comparisons / 10 Sources / 21 tags / 48 memberships / 190 media files. No real user data was modified by this task. Security advisors retain the existing RPC-only RLS/no-policy informational notices and password-protection warning for unused password auth; no auth/RLS configuration changed. See the [Supabase advisor guidance](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) and [password advisory](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). No new security issue was introduced.

The physically accepted v11 history remains an ancestor. Implementation checkpoint: `3f4e02d39445914d6bfe524db2f844b984d5b981` (16 files). Deployment/documentation is a separate logical checkpoint. See the owner report for final SHA/normal-push outcome. Evidence remains machine-local under `/private/tmp/recipe-editorial-*`, never in Git. Automated provider responses are synthetic, Auth/budget are mocked, and UI tests use isolated UUID stores/media; no owner credentials are extracted and no real Recipe or provider quota is consumed by tests. Apple real-model inference and new live Gemini editorial quality require the single physical gate below.

### Historical editorial acceptance instructions — superseded

1. Build/install the **new Xcode Debug build** (native prompt/source/qualifier checks changed). Use the existing real account; do not reset its data.
2. Food Bible → Add Recipe → Import Recipe, selecting an existing cooked Dish without a Recipe. Enable **Cloud Formatting**. Paste all of `StayGrubbyTests/Fixtures/RecipeEngineCanonicalKale.txt` unchanged, and Format once.
3. Look for clean imperative sentences, sensible punctuation, less repetition/run-on speech, readable ingredient quantities, and supported sauce/pasta, chips and crisp organization. Exact title, section names and step count are not prescribed.
4. Verify 2 cups kale per person, ¼ cup olive oil, ¼ cup Parmesan, 2 cloves garlic, pinch salt, 1 tbsp cold/cubed butter, and about 5 minutes for the crisp. No new pasta/garnish amount, oven temperature, duration/range, servings or total prep/cook time. “A little,” optional alternatives and the original uncertain “clabbering chilies” must survive; no confident Calabrian substitution. Check original text and section assignment before Save.
5. **Save only after your review**. Close/reopen, then terminate/relaunch and reopen the Recipe to check the reviewed wording, quantities and sections persist under the same Dish. Automated tests Save only synthetic recipes into isolated stores.

**Does this now read like a real recipe while still being the exact recipe you dictated?**

No intermediate physical retry was requested. No TestFlight/App Store, independent Recipe/Dish, ranking, social, auth, photo-sync or Universal Links work was performed.

## v11 historical acceptance


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
| Editorial quality / paired factual contrasts | RecipeEditorialAcceptance.json / RecipeEditorialPairs.json |
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

No new live Gemini calls were made in the overnight harness. Apple routing/availability and the shared contract are tested with mocks; real Apple model inference was not performed. Existing tooling cannot invoke as the owner without extracting a session credential or adding an authentication bypass. Neither was done. Do not confuse deterministic provider-quality examples with a live Gemini quality test. Historical v9/v10 prove actual schema/provider access; the v11 prompt/reconciliation subsequently passed the owner’s real-iPhone canonical-kale acceptance. The new editorial cycle has its own single physical gate above.

All automated tests use synthetic responses/isolated UUID stores. No real Recipe, Dish, attempt, ranking, evidence, social record or Storage object was created/edited/deleted. The deployed endpoint can reserve its existing bounded usage counter on an owner request; tests use a mock reservation and consume no provider quota. No secrets, billing, account/session architecture or migrations changed. Final verification: all **35/35 hosted data/Storage fingerprints** match the overnight baseline. The demo manifest remains `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`: 1 ranking, 12 Dishes, 15 attempts/items, 356 comparisons, 10 Sources, 21 tags, 48 memberships and 190 unchanged media files. Hosted `recipe-import` **v11 ACTIVE**, JWT verification enabled, six runtime files byte-identical to local; bundle SHA-256 `862bc336f2fd05c522bf6c2d107bbfafe3ff392771d9cc26ec3d583f55e21d0e`. Unauthenticated endpoint check returns **401** without a provider call. No schema migration was needed; existing 26 SQL migrations/schema reference are unchanged. Release has only the standard no-AppIntents metadata warning.

## v11 physical acceptance completed

The owner confirmed the exact canonical kale fixture reached the editor through Cloud Formatting on a real iPhone before this editorialization cycle. Do not repeat the old v11 diagnostic gate. The new editorial acceptance above remains pending.

## Checkpoints

Implementation/test checkpoint: `9794b92` (18 files), including v10 diagnostics. The separate documentation checkpoint contains this report, the historical investigation update, UI_ARCHITECTURE.md and STAYGRUBBY_MASTER_ROADMAP.md. Final HEAD, clean status and normal-push outcome are reported to the owner; no credentials, Git configuration or history workaround.
