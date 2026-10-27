# Recipe import failure investigation — October 26, 2026

> Current: v11 has **passed owner physical acceptance** with the exact canonical kale input. The next editorialization cycle is **AUTOMATED EDITORIAL ACCEPTANCE PASSED — OWNER PHYSICAL ACCEPTANCE PENDING**. [RECIPE_ENGINE_ACCEPTANCE.md](RECIPE_ENGINE_ACCEPTANCE.md) records the current contract, evidence and one final physical test; the v3–v10 investigation below remains historical evidence.

Starting state: clean `main`, HEAD and `origin/main` both `fc93143fdc63b9e662441e0eddf83ed0b356f6b2`. Single agent, existing checkout and Simulator lane. This follow-up supersedes the original Engine V1 review's timestamp gate, strict verbatim-only validation, pending-secret claim and unpublished-policy status.

## Root cause: confirmed rejection and successful correction

**Resolved live smoke, October 26 at 10:47:05 pm EDT:** v9 logged `stage=complete`, Google **HTTP 200**, function **HTTP 200**, result **success**, duration **1,544 ms**. The owner confirmed the tiny recipe opened the existing Recipe Editor and was **not saved**. The only functional provider-request change from the failing version was removing nested array-count constraints from the output grammar. The before/after evidence identifies those schema constraints as the request defect; Google did not expose its precise compiler explanation in the captured safe diagnostics. Schema-state complexity is the documented explanation, rather than a directly logged compiler message. Credentials, selected model and endpoint now work for this real account.

**Second live diagnostic retry, October 26 at 10:41:32 pm EDT:** v8 reached Google and received **400 / INVALID_ARGUMENT** at the provider stage in 835 ms. No allowlisted rejected field or structured key/restriction reason was present. This proves the current failing stage, but not a particular field, successful key/model acceptance or the old error message.

**Owner diagnostic retry, October 26 at 10:02:24 pm EDT (October 27 02:02:24 UTC):** v7 directly logged `stage=provider`, upstream **HTTP 400**, function HTTP 503, `reason=request_format`, duration 1,383 ms. The request reached Google; authentication/configuration/budget were passed, and recipe generation/source validation did not run. `request_format` was a conservative fallback for HTTP 400, not evidence identifying a particular field. Credential acceptance and model availability are not established by this status alone.

The physical iPhone requests reached `recipe-import`. Function Edge logs show v3 HTTP 503 at **2026-10-27 00:12:51 and 00:13:24 UTC** (October 26, 8:12:51 and 8:13:24 pm EDT), taking about 1,400 and 666 ms. Their two budget reservations establish that authentication/account checks and the old key/timestamp configuration guard succeeded far enough to invoke and reserve the budget RPC. The deployed v3 runtime was byte-identical to the starting local runtime. In that implementation a non-OK Gemini response returned 503; malformed output/source validation returned 422. The evidence strongly points to an upstream provider HTTP rejection, rather than source validation. This is a code-path inference: the old generic outer catch could also return 503 if the budget RPC response failed after a successful reservation, so the exact failure stage is not directly proven by the old logs. Earlier v2 503s did not establish the same stage.

**The exact Google status/reason was not recorded by v3.** It would be incorrect to claim an invalid key, unavailable model, billing problem, accepted credentials or successful inference from these logs. The owner confirms both secrets are configured and the dedicated project has no billing/card. No values were read or requested. A CLI name-inventory attempt returned an authentication error, not an empty secret list; the original review's absence claim is corrected.

The model remains `gemini-3.5-flash-lite`. Current official [model](https://ai.google.dev/gemini-api/docs/models)/[structured-output](https://ai.google.dev/gemini-api/docs/generate-content/structured-output) documentation and the public [v1beta REST discovery schema](https://generativelanguage.googleapis.com/$discovery/rest?version=v1beta) include the selected endpoint and `generationConfig.responseFormat.text` with `APPLICATION_JSON`/JSON schema. No unsupported-model/request-shape root cause has been assumed. Availability and credential acceptance for this project were subsequently confirmed by the successful v9 smoke.

Separately, the old verbatim-only validator deterministically rejected safe number-word/fraction cleanup and organization. This independent defect is fixed; it does not explain the earlier 503s.

## Exact kale acceptance failure — rule-level investigation

After rebuilding, the owner tested the **unchanged original 882-character kale source** and reported failure. The committed test fixture is byte-identical to that original source. The tiny smoke is not acceptance of this real input.

v9 logs on October 26 at 10:50:10, 10:55:53 and 10:56:09 pm EDT show **stage validation / invalid_recipe / HTTP 422**, in 2,043 /2,195 /1,694 ms. The function passed the upstream HTTP, STOP-completion and response-byte checks and reached extraction parsing/server validation. No successful extraction was returned to the client; RecipeDraft decoding, native ingredient normalization and client review did not cause these server 422s. v9's boolean validator cannot identify the exact rejecting rule, and extraction JSON parsing occurred in the same stage, so no narrower cause is assumed.

v10 ACTIVE adds bounded diagnostic structure/counts and up to 20 fixed validation rules with generated field indexes. It distinguishes extraction JSON, object fields/types/count limits, source word/number evidence, quantity/unit pairs, metadata phrase and ingredient phrase checks. No source, output, unknown property name or rejected word is logged. Runtime acceptance rules are unchanged. All **31/31** focused Edge tests, Deno typecheck, privileged-secret scan and whitespace checks pass; deployed files match local bytes. Bundle SHA-256 `b3fe9017d15793cf79ccdc3b9a910154afcd0683b541592d4c47065226df4aa1`. The owner performed that retry. v10 recorded Google 200 and five lexical/phrase failures in a 1-component/12-ingredient/9-step candidate: ingredients[7] source_word, ingredients[10–11] ingredient_phrase, steps[7–8] source_word. No shape/count failure occurred. The overnight general fix now reconciles recoverable wording to literal original source spans and re-runs the complete validator, without accepting unsupported quantities or new ingredients. See the current acceptance report; actual discarded provider word values were never logged and are not fabricated as captured fixtures.

## Changes

- Removed the recurring `STAYGRUBBY_GEMINI_FREE_TIER_UNTIL` dependency entirely. An old secret may remain unused. Only the server key is required for configuration. No billing, payment, Google project or credential configuration was changed. The owner must keep the dedicated project unbilled; an application flag cannot prevent an external administrator linking billing later.
- Preserved authenticated active-account/session checks, server-only key, consent, durable limits (3/account/minute, 20/account/day, 100/global/day, 1,000/global/month), bounded request/response sizes, fixed endpoint/model and timeouts. Failed provider calls still consume a reservation. No paid fallback or automatic retry loop.
- Added bounded lexical source evidence in Swift and TypeScript: number words/fractions, common units and limited spelling/grammar normalization; conservative ingredient phrase evidence; quantity/unit pairs cannot be newly combined. Original qualifiers, unknown quantities and uncertain ingredient names remain. No AI math, inferred times/temperatures/servings or general culinary inference. Review/original text remain mandatory: lexical checks cannot prove completeness, semantic interpretation or correct section assignment.
- Added the owner's exact kale source unchanged as a shared test-only JSON fixture, with representative multi-component output and cross-platform validation cases. No kale-specific production logic. Permanent `RecipeDraft = RecipeContent`, Recipe identity/revision/save, Dish association and ingredient parser remain unchanged.
- Added distinct user-facing configuration, session, network, quota, temporary-service and invalid-output errors. Original text/manual continuation remain available.
- Added safe server request ID, stage, status, duration and enumerated upstream reason logs/response metadata. No prompt, output, raw provider message, key or token is logged. Unknown upstream failures remain generic rather than guessing.
- Added Debug-only **Settings → Developer → Recipe Intelligence** with real Apple model availability/reason, cloud permission, last session/configuration status, selected provider, stage/result and HTTP statuses. It makes no diagnostic provider call. All diagnostics UI/state is excluded from Release; it contains no credential/recipe values.

## Deployment and live status

Existing Supabase project `lgjxbpycphhsswxoncmz`: diagnostic v4, source-evidence v5–v7, detailed safe diagnostics v8, final schema correction **v9 ACTIVE**, `verify_jwt=true`. Five runtime files: `index.ts`, `handler.ts`, `contract.ts`, `evidence.ts`, `deno.json`. Final bundle SHA-256 `4fc712c62bce3af4a9291208e884ed81dfd9579f868f86eb37945a1563a55aef`; all five deployed runtime files match local bytes. A deployment attempt inherited a stale absolute import-map path and was rejected before activation; explicitly setting `import_map_path: deno.json` succeeded. No migration/schema change or delete-account deployment.

Unauthenticated endpoint check returned **401** with no provider call. Three owner-initiated tiny authenticated attempts were used: v7/v8 returned Google 400, and v9 returned Google/function 200 with validated output and editor presentation. The owner did not Save. Available tooling has no existing user-context invocation, so no tokens were extracted, service-role impersonation used, new test account created or direct-key Google request made. The model remains `gemini-3.5-flash-lite`; no key, billing, model or endpoint switch was required.

The approved prepared policy was published to the existing `staygrubby` Cloudflare Worker with the existing official assets, routing/security configuration and domain. Deployment ID `13e83b7c298a438fa497d876132fd68f`. Live `https://staygrubby.com/privacy` returns **200 with zero redirects**, and its bytes match `Website/public/privacy.html`, including the optional Gemini disclosure. Canonical bundled policy SHA-256 remains `e9bdac28b8eb8358c45051077d33e27b1fadc5535fd53c3ea71af8d6039126d9`. No DNS, email, backend, redesign, Universal Links investigation or App Store Connect change.

## Focused verification

| Check | Result |
| --- | --- |
| Native routing/validation/import | **12/12 passed**, zero failures/skips; final Debug compilation included. |
| Directly affected import UI | **4/4 passed**, zero failures/skips: review/save/reopen, existing Recipe protection, large type/background, quota/manual/raw-text retention. UUID fixture stores/providers only. |
| Edge handler/contract | **28/28 passed**, including provider-grammar/runtime-cap separation, safe Google diagnostics, exact kale fixture, safe normalization/new-fact rejection, missing key/no timestamp, authorization, budget, input/output bounds, cancellation, provider timeout/connection/quota/status redaction. Mocked Google; no inference quota. |
| Static policy/site | **7/7 passed**, canonical parity, public allowlist and existing security invariants. |
| Debug | Build/test compilation and isolated Simulator launch passed. Final native follow-up passed after diagnostics adjustments. |
| Release | Generic iOS Simulator arm64/x86_64 build succeeded, no signing/distribution. No new source warning; standard AppIntents metadata notice only. |
| Secret/local artifact scan | Existing privileged-secret scan: **356 text files, zero findings**. Release binary has no Debug diagnostics symbols/label or Google key pattern. No values read/requested or local artifacts intended for Git. |
| Whitespace | `git diff --check` and staged whitespace checks pass. |

Local evidence (not committed): `/private/tmp/gemini-fix-focused.xcresult` (12 native +4 UI), `/private/tmp/gemini-fix-final-native.xcresult` (12 native), `/private/tmp/gemini-fix-final-edge-tests.log`, `/private/tmp/gemini-fix-release.log`, `/private/tmp/gemini-fix-website-tests.log`, `/private/tmp/gemini-fix-demo-final.json`.

## Preserved data

At the first fix checkpoint, all **35/35** baseline hosted data/Storage fingerprints matched. No real Recipe/cooking write or Storage byte upload occurred. Import usage was initially two historical reservations; after the three requested tiny attempts it is 5 for global-month/global-day/account-day and five account-minute rows of 1. Existing 26 migrations and schema reference were not changed. No ranking math, score/unlock/re-rank, sync, persistence, sharing, Tickets or official asset changes.

Simulator demo manifest remains `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`: 1 ranking, 12 Dishes, 15 attempts/items, 356 comparisons, 10 Sources, 21 tags, 48 memberships and **190 unchanged media files**. No reset, seed or test fixture leak.

## HTTP 400 diagnostic follow-up

A later read-only check during the owner retry found 19 of the earlier 35 fingerprints changed: Dishes 37→39, attempts/items 42→44, comparisons 156→165, Storage 64→69, plus cooking/media/social metadata and sync operations. **All Recipe/revision/link/ticket/cook fingerprints remain unchanged.** This follow-up performed no Recipe/cooking/social/Storage writes; its only active backend change is the import function deployment, whose data write is budget reservation only. The owner has been asked whether other features were used during the evening; attribution remains unconfirmed, and no records were reset or repaired. The earlier 35/35 result must not be misrepresented as a match to this later active-account state. A new final check after the successful v9 smoke matches **all 35/35 fingerprints against this immediate pre-correction snapshot**: no Recipe, cooking, social or Storage changes occurred during the schema correction/successful unsaved smoke. Recipe fingerprints also still match the original baseline.

The published GenerateContent REST example and discovery schema both include the current `responseFormat.text.mimeType/schema` structure, so no speculative request/model replacement was made. v8 added only allowlisted Google error status/reason and request-field names to server logs; no free-form message, field, metadata, recipe or credential value is copied. Structured key/restriction reasons are classified safely. All **26/26** Edge tests and Deno typecheck pass. The owner has been asked for one additional tiny unsaved attempt on the existing build to identify the exact rejection. No client/schema/ranking/persistence change or new Recipe save was made in this follow-up. v8 bundle SHA-256 `e2babf4ce32803f513234ff54d8994eaec3383ab96d49a17ece5d3765c3c82df`.

## Provider schema correction — v9

The second diagnostic did not identify a field. Current [GenerateContent guidance](https://ai.google.dev/gemini-api/docs/generate-content/structured-output#limitations) recommends reducing schema constraints after schema-complexity errors; the [API reference](https://ai.google.dev/api/interactions-api.md) explicitly describes nested large maxItems as a 400 INVALID_ARGUMENT risk. The existing provider grammar nested maxItems 20 and 100. v9 removes minItems/maxItems **only from the schema sent to Google**; all server/client limits, required/type/nullability/unknown-field validation, source evidence, byte bounds and timeouts remain. The next real request succeeded with the same key/model/endpoint, supporting the schema-constraint diagnosis. The precise internal compiler reason remains unlogged; no unsupported claim of a captured compiler error is made. No automatic provider retries were added.

**28/28** focused Edge tests pass, including a new assertion that the request grammar has no nested array bounds while 21 components, 101 ingredients/steps and aggregate ingredient overflow remain rejected by runtime validation. Deno typecheck, secret scan and whitespace checks pass. No native code changed in this follow-up, so the already-passing native/UI/Debug/Release checks were not repeated. Safe diagnostics also classify schema-compiler complexity and expired-key wording without copying provider messages.

Hosted v9 ACTIVE, JWT verification retained; bundle SHA-256 `4fc712c62bce3af4a9291208e884ed81dfd9579f868f86eb37945a1563a55aef`. The owner performed the tiny unsaved attempt: both Google and the function returned 200, validation completed and the existing Recipe Editor opened. No further tiny probes are needed.

## Owner acceptance and remaining boundary

The existing build successfully completed the tiny live import; no further diagnostic calls are needed. A **new Xcode build/install is required** to receive the client validator, error messages and Debug diagnostics before testing the messy kale input.

Build/install the latest app using normal signing, sign into the existing account, then **Food Bible → Add Recipe → Import Recipe**, choosing a cooked Dish without an existing Recipe. Paste the **exact original kale text**, enable the disclosed cloud permission and Format Recipe. Confirm Gemini produces the existing editor, meaningful sections/ingredients/method, preserved per-person/unknown/uncertain wording and no invented times/temperatures. Review/correct normally, explicitly Save, close/reopen and verify persistence. If it fails, the safe Debug diagnostics and server stage/status identify the remaining failure; never paste keys/tokens into chat.

The real-account Gemini smoke and editor presentation are verified. Full messy-kale import/review/Save/reopen on the rebuilt physical app remains owner acceptance; the fixture is automated contract coverage, not a claim of live model extraction quality. No TestFlight readiness/upload or next feature cycle is claimed.

## Git checkpoints

Implementation: `641acca` (13 source/test/fixture files); documentation `b8ea2ca`; safe HTTP 400 diagnostics `d54e79e`. The separate documentation checkpoint contains this review, UI_ARCHITECTURE.md, STAYGRUBBY_MASTER_ROADMAP.md and the historical Engine V1 review correction. Final HEAD and normal-push outcome are reported to the owner. No credential/configuration or history workaround is authorized.
