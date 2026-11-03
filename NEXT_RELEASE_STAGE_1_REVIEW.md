# Next Release Stage 1 — UI Foundation + Dish Data Architecture

November 3, 2026. **AUTOMATED ACCEPTANCE PASSED — ready for owner review and the separately scoped Stage 2.** No Stage 2 implementation was performed.

## Baseline and scope

Started on clean `main` at expected `b9871df88930699f22ed80b2c586996e4775ebd8`, aligned with origin/main. One agent/current checkout/one Simulator lane. The owner accepts the previous cycle sufficiently to proceed; physical profile sharing works. Recipe browser/download-like behavior and unhelpful Ranking/Dish copy/share remain mandatory later Social + Sharing defects, not Stage 1 fixes. Two-device social acceptance remains pending/nonblocking. No next stage, physical test, provider call, distribution, reset, credential or billing change.

## Architecture audit and decisions

- **No legacy Dish description exists.** `CookingAttempt.notes` are private version-specific notes; `social_posts.post_description` is separately authored; Recipe descriptions are independent. Migration never promotes/reclassifies any of them.
- Dish gains optional **Public Description** (2,000 Unicode scalars) and **Private Notes** (8,000), independently of existing cook notes. Owner edits go through the normal local atomic journal. Empty text becomes nil; corrupt NUL/over-limit input is rejected, not truncated. Owner sync/hydration preserves fields; older omitted keys preserve server values, explicit null clears them.
- A small Dish Details menu/editor proves owner save/cancel/relaunch. Existing cook notes remain visible in their original section. Only Public Description can prefill a manual, explicitly reviewed post composer; it cannot overwrite an existing authored post. Automatic publishing remains unchanged. Share-card/Recipe/Run It Back projections do not gain private fields.
- Existing **CookingAttempt → CookingMedia[]** already has stable media identity, order and private backup. Extend it, not another Dish/photo ownership store. **Six photos per cook/version**, not six across all historical cooks of a Dish. At existing 1,200/360-pixel preparation and 2 MiB per variant this bounds one collection to 24 MiB of optimized JPEG variants at the validation ceiling, normally much less.
- First ordered image is the cover; timestamp/UUID resolve legacy order ties. Dish groups remain version-specific, newest sequence first. No historical media is moved/copied and consumers still get their actual cook's cover. Append/reorder/set-cover/remove use existing structured operations/tombstones and immutable byte paths. Single-photo editing now replaces/removes only the cover, preserving secondaries.
- The new gallery API exposed two concrete test problems: repeated fixture imports reused one prepared UUID, and the photo-cloud test double did not implement the server's existing predecessor-chain receipt behavior. Fixtures now represent independent imports; the double honors unchanged server semantics. Production rejects duplicate/retired photo IDs and existing target files before they can overwrite immutable records. These are scoped photo-foundation safety dependencies, not a transport/conflict redesign.
- New change payloads advertise `photoCollectionVersion: 1`. Older queued payloads still decode. Old partial replace-all edits on established galleries are rejected instead of erasing extra photos; ordinary whole-cook deletion remains supported. Backend account serialization is unchanged; an active-attempt/order index and deferred six-photo constraint enforce the bound. Existing media ownership/RLS/manifests/Storage remain authoritative.

## UI/specification foundation

[NEXT_RELEASE_SPEC.md](NEXT_RELEASE_SPEC.md) records the complete staged release scope, optional native context-menu/haptics/crop evaluation, deferred future features and formal post-beta/pre-App-Store Trust & Safety gate. Roadmap/current architecture/domain docs link to it. The compliance cycle itself is not implemented.

[UI_ARCHITECTURE.md](UI_ARCHITECTURE.md) maps shared type/spacing/surfaces/buttons/profile rows/filter/menu/sheet/state/image/corner/color patterns to accepted components. Existing primitives are retained; secondary destructive `SGButtonStyle` labels now respect native button role with adaptive text while prominent backgrounds retain contrast-safe tokens. No general redesign or global string deletion.

`SGPrimaryBrandTitle(page:)` uses the existing cropped official wordmark in the native principal toolbar, with navigation/accessibility context and no second safe-area/header bar. Food Bible is the deliberately scoped first adoption; Add Recipe/search and secondary titles remain native. Light/dark/large-text/Reduce Motion screenshots inspected. Other primary screens adopt in later stages. Public/private editor copy remains because it explains actual privacy/scope ambiguity.

## Verification

- Focused native photo/text tests and isolated previous-schema verifier: **28 tests /4 suites passed**. The temporary verifier opened only a UUID-path copy of the pre-change development SQLite/WAL, then was removed. All **14 domain tables retain every original column value**, not merely counts. New Dish fields start nil; no private cook text was copied. No private fixture/store is committed.
- Final broader Stage 1 native integration: **82 tests /11 suites passed** — Dish text/gallery, legacy cook/model/media, multi-photo private backup/restore and reorder without re-upload, sync/journal, re-ranking wrapper, adjacent Recipe/social/share/config/Cuisine contracts. **No live Gemini request.**
- Backend: **399 assertions /9 disposable PostgreSQL programs passed**, including **23 focused Stage 1 checks**, schema/RLS, structured/photo sync, posts/descriptions, Recipe/social/link/privacy and sharing defaults. Tests prove friend table/RPC reads cannot retrieve Dish/cook private notes; social/recreation payloads exclude them; old descriptions/fields survive migration; older-client omission preserves text; six-photo ordering/limit/removal and legacy-editor protection work; foreign-attempt media is rejected; no Storage objects are created by metadata architecture.
- Scoped UI: **2 tests passed**, zero final failures/skips: owner text save/cancel/relaunch and compact brand header in light/dark/accessibility/Reduce Motion. Real app data is not a fixture.
- Debug build passes. No full UI suite, physical-device test or Release build was required for this foundation stage.
- Existing 33 migrations remain unedited; the reference schema is the ordered byte concatenation including the new append-only migration. Final secret, file/link and whitespace/staged checks accompany checkpoint closeout.

## Hosted deployment / data safety — verified

The task's section 8 authorized the contained deployment. Automatic approval review initially rejected it because it did not recognize fresh authorization from the attachment. The owner then explicitly approved Stage 1 hosted migration deployment in chat. No workaround was used. The tested migration deployed successfully to the existing project as **20261103201153**; local filename alignment was byte-identical, not a behavioral edit.

`20261103201153_dish_text_photo_foundation.sql`: SHA-256 `ae1dc2413af560848b2906c86faf7c2005bd3eefb84c273511e2a7c42afc3529`, hosted/local MD5 `4dde0ab71ddab42330077e634601d5be`. All **34 hosted/local migration hashes match**. The ordered first-install reference schema is byte-identical to the complete local chain. Existing applied migrations were not modified.

All **40 protected application-table/Storage count+row-hash groups match** cycle start, pre-deploy and post-deploy. Only the two additive null Dish columns are excluded from the legacy-row comparison. No hosted test fixtures, account writes or Storage changes: **42 Dishes /47 attempts and items /185 comparisons /4 rankings /3 Recipes /6 revisions /4 Recipe-cook snapshots /78 Storage objects** remain, with all other original rows/relationships/timestamps intact. Both new columns exist and every existing row has null values; no descriptions or notes were backfilled.

Hosted checks confirm **39/39 application +2/2 development tables have RLS**, no anonymous table access, no raw authenticated write grants, the deferred six-photo trigger and active-attempt/order index exist, and the trigger helper is not client executable. Owner-private Dish RLS and public projection whitelists are unchanged; tested SQL hashes match the deployed source.

Read-only final audits of the preserved normal development stores match the pre-change **14 complete original domain-table value sets**: **1 ranking /12 Dishes /15 attempts and items /356 comparisons /10 Sources**, plus **190/190 original media SHA-256 hashes**. The pre-change migration clone also preserves all original values. UUID fixture stores/media remain isolated; the temporary clone-audit source was removed and no private fixture files enter the checkpoint.

No Edge Function, Storage policy/bucket, website, secret, credential, paid/provider/billing, version/build or distribution change. Gemini v27 and independent Recipe/ranking/social semantics are untouched. Normal main checkpoint/push follows the final staged audit; Git history is the authoritative checkpoint identity.

## Owner review after hosted closeout

No autonomous physical testing. One optional short review with existing data: open a Dish → More → Edit Dish Description & Notes; save distinct harmless public/private text, reopen/relaunch, and cancel an unsaved edit. Confirm original per-cook notes remain separate. Check the compact Food Bible wordmark and Add Recipe/search in light/dark or larger text. Gallery controls are intentionally deferred, so do not seed real photos merely to test them; the data/restore tests cover this stage.

Later stages retain full New Dish/metadata/tagging/profile/feed/Comments/Order Up!/Food Bible/Recipe/secondary-screen redesigns, gallery controls and optional crop, both known sharing defects, and two-device social acceptance. Ranking/calibration/unlock/evidence, Recipe history/snapshots/Creator, auth/social semantics and existing byte-sync protocol remain frozen. **Do not begin Stage 2 automatically.**
