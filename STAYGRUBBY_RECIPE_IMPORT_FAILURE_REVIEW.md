# Recipe import failure investigation — October 26, 2026

Starting state: clean `main`, HEAD and `origin/main` both `fc93143fdc63b9e662441e0eddf83ed0b356f6b2`. Single agent, existing checkout and Simulator lane. This follow-up supersedes the original Engine V1 review's timestamp gate, strict verbatim-only validation, pending-secret claim and unpublished-policy status.

## Root cause: proven stage and remaining uncertainty

**Owner diagnostic retry, October 26 at 10:02:24 pm EDT (October 27 02:02:24 UTC):** v7 directly logged `stage=provider`, upstream **HTTP 400**, function HTTP 503, `reason=request_format`, duration 1,383 ms. The request reached Google; authentication/configuration/budget were passed, and recipe generation/source validation did not run. `request_format` was a conservative fallback for HTTP 400, not evidence identifying a particular field. Credential acceptance and model availability are not established by this status alone.

The physical iPhone requests reached `recipe-import`. Function Edge logs show v3 HTTP 503 at **2026-10-27 00:12:51 and 00:13:24 UTC** (October 26, 8:12:51 and 8:13:24 pm EDT), taking about 1,400 and 666 ms. Their two budget reservations establish that authentication/account checks and the old key/timestamp configuration guard succeeded far enough to invoke and reserve the budget RPC. The deployed v3 runtime was byte-identical to the starting local runtime. In that implementation a non-OK Gemini response returned 503; malformed output/source validation returned 422. The evidence strongly points to an upstream provider HTTP rejection, rather than source validation. This is a code-path inference: the old generic outer catch could also return 503 if the budget RPC response failed after a successful reservation, so the exact failure stage is not directly proven by the old logs. Earlier v2 503s did not establish the same stage.

**The exact Google status/reason was not recorded by v3.** It would be incorrect to claim an invalid key, unavailable model, billing problem, accepted credentials or successful inference from these logs. The owner confirms both secrets are configured and the dedicated project has no billing/card. No values were read or requested. A CLI name-inventory attempt returned an authentication error, not an empty secret list; the original review's absence claim is corrected.

The model remains `gemini-3.5-flash-lite`. Current official [model](https://ai.google.dev/gemini-api/docs/models)/[structured-output](https://ai.google.dev/gemini-api/docs/generate-content/structured-output) documentation and the public [v1beta REST discovery schema](https://generativelanguage.googleapis.com/$discovery/rest?version=v1beta) include the selected endpoint and `generationConfig.responseFormat.text` with `APPLICATION_JSON`/JSON schema. No unsupported-model/request-shape root cause has been assumed. Availability and credential acceptance for this particular project remain live-unverified.

Separately, the old verbatim-only validator deterministically rejected safe number-word/fraction cleanup and organization. This independent defect is fixed; it does not explain the earlier 503s.

## Changes

- Removed the recurring `STAYGRUBBY_GEMINI_FREE_TIER_UNTIL` dependency entirely. An old secret may remain unused. Only the server key is required for configuration. No billing, payment, Google project or credential configuration was changed. The owner must keep the dedicated project unbilled; an application flag cannot prevent an external administrator linking billing later.
- Preserved authenticated active-account/session checks, server-only key, consent, durable limits (3/account/minute, 20/account/day, 100/global/day, 1,000/global/month), bounded request/response sizes, fixed endpoint/model and timeouts. Failed provider calls still consume a reservation. No paid fallback or automatic retry loop.
- Added bounded lexical source evidence in Swift and TypeScript: number words/fractions, common units and limited spelling/grammar normalization; conservative ingredient phrase evidence; quantity/unit pairs cannot be newly combined. Original qualifiers, unknown quantities and uncertain ingredient names remain. No AI math, inferred times/temperatures/servings or general culinary inference. Review/original text remain mandatory: lexical checks cannot prove completeness, semantic interpretation or correct section assignment.
- Added the owner's exact kale source unchanged as a shared test-only JSON fixture, with representative multi-component output and cross-platform validation cases. No kale-specific production logic. Permanent `RecipeDraft = RecipeContent`, Recipe identity/revision/save, Dish association and ingredient parser remain unchanged.
- Added distinct user-facing configuration, session, network, quota, temporary-service and invalid-output errors. Original text/manual continuation remain available.
- Added safe server request ID, stage, status, duration and enumerated upstream reason logs/response metadata. No prompt, output, raw provider message, key or token is logged. Unknown upstream failures remain generic rather than guessing.
- Added Debug-only **Settings → Developer → Recipe Intelligence** with real Apple model availability/reason, cloud permission, last session/configuration status, selected provider, stage/result and HTTP statuses. It makes no diagnostic provider call. All diagnostics UI/state is excluded from Release; it contains no credential/recipe values.

## Deployment and live status

Existing Supabase project `lgjxbpycphhsswxoncmz`: diagnostic v4, source-evidence v5/v6, final **v7 ACTIVE**, `verify_jwt=true`. Five runtime files: `index.ts`, `handler.ts`, `contract.ts`, `evidence.ts`, `deno.json`. Final bundle SHA-256 `67e36177171495336e15b3b5815dd34bc9ee7165755bcfcc129679dc5c6a25af`. A deployment attempt inherited a stale absolute import-map path and was rejected before activation; explicitly setting `import_map_path: deno.json` succeeded. No migration/schema change or delete-account deployment.

Unauthenticated endpoint check returned **401** with no provider call. A minimal authenticated live smoke reached Google but **failed with HTTP 400**, as recorded above. Before the owner retry, it could not be initiated by the agent: available tooling has no existing user-context function invocation. No tokens were extracted, service-role impersonation used, new test account created or direct-key Google request made. The owner has been asked for one existing-app attempt with `2 eggs`, `1 tbsp butter`, `Scramble eggs in butter.` and **not to Save**. The owner then made the single requested attempt, establishing provider HTTP 400. Specific rejected field/configuration reason, key/model acceptance and successful live formatting remain pending, rather than falsely green.

The approved prepared policy was published to the existing `staygrubby` Cloudflare Worker with the existing official assets, routing/security configuration and domain. Deployment ID `13e83b7c298a438fa497d876132fd68f`. Live `https://staygrubby.com/privacy` returns **200 with zero redirects**, and its bytes match `Website/public/privacy.html`, including the optional Gemini disclosure. Canonical bundled policy SHA-256 remains `e9bdac28b8eb8358c45051077d33e27b1fadc5535fd53c3ea71af8d6039126d9`. No DNS, email, backend, redesign, Universal Links investigation or App Store Connect change.

## Focused verification

| Check | Result |
| --- | --- |
| Native routing/validation/import | **12/12 passed**, zero failures/skips; final Debug compilation included. |
| Directly affected import UI | **4/4 passed**, zero failures/skips: review/save/reopen, existing Recipe protection, large type/background, quota/manual/raw-text retention. UUID fixture stores/providers only. |
| Edge handler/contract | **24/24 passed**, including exact kale fixture, safe normalization/new-fact rejection, missing key/no timestamp, authorization, budget, input/output bounds, cancellation, provider timeout/connection/quota/status redaction. Mocked Google; no inference quota. |
| Static policy/site | **7/7 passed**, canonical parity, public allowlist and existing security invariants. |
| Debug | Build/test compilation and isolated Simulator launch passed. Final native follow-up passed after diagnostics adjustments. |
| Release | Generic iOS Simulator arm64/x86_64 build succeeded, no signing/distribution. No new source warning; standard AppIntents metadata notice only. |
| Secret/local artifact scan | Existing privileged-secret scan: **356 text files, zero findings**. Release binary has no Debug diagnostics symbols/label or Google key pattern. No values read/requested or local artifacts intended for Git. |
| Whitespace | `git diff --check` and staged whitespace checks pass. |

Local evidence (not committed): `/private/tmp/gemini-fix-focused.xcresult` (12 native +4 UI), `/private/tmp/gemini-fix-final-native.xcresult` (12 native), `/private/tmp/gemini-fix-final-edge-tests.log`, `/private/tmp/gemini-fix-release.log`, `/private/tmp/gemini-fix-website-tests.log`, `/private/tmp/gemini-fix-demo-final.json`.

## Preserved data

At the first fix checkpoint, all **35/35** baseline hosted data/Storage fingerprints matched. No real Recipe/cooking write or Storage byte upload occurred. Import usage remains two historical reservations: global-month 2, global-day 2, account-day 2 and two account-minute rows of 1. Existing 26 migrations and schema reference were not changed. No ranking math, score/unlock/re-rank, sync, persistence, sharing, Tickets or official asset changes.

Simulator demo manifest remains `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`: 1 ranking, 12 Dishes, 15 attempts/items, 356 comparisons, 10 Sources, 21 tags, 48 memberships and **190 unchanged media files**. No reset, seed or test fixture leak.

## HTTP 400 diagnostic follow-up

A later read-only check during the owner retry found 19 of the earlier 35 fingerprints changed: Dishes 37→39, attempts/items 42→44, comparisons 156→165, Storage 64→69, plus cooking/media/social metadata and sync operations. **All Recipe/revision/link/ticket/cook fingerprints remain unchanged.** This follow-up performed no Recipe/cooking/social/Storage writes; its only active backend change is the import function deployment, whose data write is budget reservation only. The owner has been asked whether other features were used during the evening; attribution remains unconfirmed, and no records were reset or repaired. The earlier 35/35 result must not be misrepresented as a match to this later active-account state.

The published GenerateContent REST example and discovery schema both include the current `responseFormat.text.mimeType/schema` structure, so no speculative request/model replacement was made. v8 ACTIVE adds only allowlisted Google error status/reason and request-field names to server logs; no free-form message, field, metadata, recipe or credential value is copied. Structured key/restriction reasons are classified safely. All **26/26** Edge tests and Deno typecheck pass. The owner has been asked for one additional tiny unsaved attempt on the existing build to identify the exact rejection. No client/schema/ranking/persistence change or new Recipe save was made in this follow-up. v8 bundle SHA-256 `e2babf4ce32803f513234ff54d8994eaec3383ab96d49a17ece5d3765c3c82df`.

## Owner acceptance and remaining boundary

For the immediate upstream diagnosis, the existing app can make the one tiny unsaved attempt; no rebuild is needed just to obtain safe server logs. Do not repeat calls to burn quota. A **new Xcode build/install is required** to receive the client validator, error messages and Debug diagnostics.

After the upstream reason has been established/resolved, build/install the latest app using normal signing, sign into the existing account, then **Food Bible → Add Recipe → Import Recipe**, choosing a cooked Dish without an existing Recipe. Paste the **exact original kale text**, enable the disclosed cloud permission and Format Recipe. Confirm Gemini produces the existing editor, meaningful sections/ingredients/method, preserved per-person/unknown/uncertain wording and no invented times/temperatures. Review/correct normally, explicitly Save, close/reopen and verify persistence. If it fails, the safe Debug diagnostics and server stage/status identify the remaining failure; never paste keys/tokens into chat.

Live Gemini acceptance remains the outstanding verification item. No claim of physical acceptance, completed root-cause resolution, TestFlight readiness or upload is made. No further feature cycle was started.

## Git checkpoints

Implementation: `641acca` (13 source/test/fixture files). The separate documentation checkpoint contains this review, UI_ARCHITECTURE.md, STAYGRUBBY_MASTER_ROADMAP.md and the historical Engine V1 review correction. Final HEAD and normal-push outcome are reported to the owner. No credential/configuration or history workaround is authorized.
