# Next Release Stage 4 — Food Bible + Recipe Experience

November 4, 2026. Baseline clean main `d733eff7b49117fd877f2a36e5fbf7fcddc44844`. **AUTOMATED ACCEPTANCE PASSED — OWNER PHYSICAL ACCEPTANCE PENDING.** Implementation and additive migration are complete; Stage 5/distribution are not started. Owner explicitly authorizes necessary verified additive Supabase migrations in this cycle. One primary agent/current checkout/one Simulator lane; no Stage 5 or distribution.

## Decisions established

- Strengthened AGENTS Reuse Before Reinvention / Living Documentation rules. Master Roadmap now makes App Store V1 a required milestone after Stages 4/5/6, beta, privacy/safety/compliance and Release Candidate; optional features should not indefinitely delay it. Future hybrid privacy, Saved Recipes vs independently owned copies, admin/roles/entitlements, invitations and monetization are documented, not implemented. Recipe Box is not a confirmed name; barcode cookbook indexing remains rejected.
- Recipe identity, Dish family, actual cook and immutable Recipe-used snapshot remain distinct. New private `recipe_cook_links` records one intentional current cook per Recipe/account (and one current Recipe per cook). Legacy `dish_recipes` are not migrated/deleted/reinterpreted. Changing this link does not claim the Recipe was historically used or modify `recipe_cooks` snapshots/revisions. Explicit links determine photo fallback; a deleted selected cook never falls back to an arbitrary other version.
- Recipe-owned photo always wins. While unavailable/loading it stays an owned-photo placeholder, avoiding a flash of a different cook's image. With no owned photo: explicit linked cook; legacy Dish-family fallback only for retained old links; branded placeholder otherwise. No media ownership transfer or Stage 5 gallery work.
- Food Bible uses Recipe metadata: Course/Cuisine, known Contains, conservative Avoid (known or possible), literal manual Source and Recipe-photo presence. Recipes currently have no reviewed Dietary field; no Dietary claim is invented or copied from a cook. Unknown allergens remain unknown, not free-from guarantees. Filters are within-group OR, across-group AND, composed with local search/sort and reset; Custom Tags stay hidden.
- Shared native sort menu and selection-sheet chrome reuse accepted browse tokens/rows. Grub Rank adds Highest/Lowest Score (existing score gate), Newest/Oldest Cooked and A–Z/Z–A while retaining global Grub Rank. Food Bible adds Newest/Oldest Added, A–Z/Z–A and preserves Recently Updated. These are presentation projections only.
- Reader units As Written / US / Metric use deterministic Decimal projection over existing exact quantities and serving math. US customary volume stays volume, mass stays mass; no density guesses/count-unit conversions/AI calls. Converted values marked approximate and rounded for reading; method temperatures/durations stay canonical. Original Recipes/revisions/IDs remain untouched. Reference: [NIST US customary conversions](https://www.nist.gov/pml/owm/metric-si/unit-conversion/approximate-conversions-us-customary-measures-metric).
- Native Recipe actions menu consolidates Edit/History/Save as New/link/unlink/send/delete; Cook Recipe remains primary, shared link stays compact. Removed redundant explanatory copy while retaining ownership/audience/provenance/error/destructive information. Manual Source fields are shared where semantics match; structured Dish Source and freeform Recipe attribution remain independent, with full Sous Chef/metadata taxonomy integration future work.
- Run It Back post/shared-Recipe entry points are removed; services/provenance/history remain. Historical labels describe inspiration without advertising the hidden workflow. Ordinary Cook Recipe remains an existing independent Recipe action.

## Baseline / verification ledger

- Local read-only baseline: `/private/tmp/sg-stage4-local-before.json` from the established snapshot helper; no normal-store writes.
- Hosted baseline successfully read: 35 migrations through `20261104055100` match prior checkpoint; 40 existing data/Storage fingerprint groups, 82 Storage objects. Retained in the session; no raw private row values printed or committed.
- Pinned CLI v2.120.0 created `20261105013648_stage4_recipe_cook_experience.sql` (UTC assigned filename; client date remains November 4). Current changelog notes CLI v3 local-default breaking changes; no CLI upgrade/auth/configuration change. The tested SQL was deployed as Supabase-assigned `20261105033728_stage4_recipe_cook_experience.sql`; local filename aligned byte-identically (MD5 `124b1159cf0b71a93e74d1aa182ce1b4`). All 36 hosted/local migration hashes match; reference schema exactly concatenates local migration files.
- First browse/unit presentation build passed. Existing concurrency warnings were observed in accepted services; no unrelated service refactor. A subsequent compile caught a missing picker property during integration; correction is being verified.
- Initial Recipes/links backend smoke passed 42 assertions with the additive migration loaded; final focused native/backend/UI evidence below supersedes that interim state.

## Deployment / data / security

- Additive current-link table/RPC changes only; no backfill, content rewrite, migration of old relationships, Storage mutation, Edge Function/secret change or provider request. Completing a newly explicit Recipe cook establishes an exact link only if no prior choice exists; retained actual Recipe-used snapshots are distinct from current selection and legacy family links.
- All 40 preexisting hosted full-row data/Storage fingerprint groups match before/after; Storage remains 82 objects. New `recipe_cook_links` has zero rows. All private tables have RLS, no direct authenticated/anon read/write on the new table, no direct helper execution; authenticated wrapper enabled, anonymous wrapper denied.
- Security advisor: expected INFO for deliberately RPC-only closed RLS tables (including the new table); preexisting leaked-password-protection warning unchanged, outside Apple-only Stage 4. No auth settings changed.
- Local read-only comparison remains exact for both original store copies: 1 ranking, 12 Dishes, 15 attempts/items, 356 Comparisons, 10 Sources, 21 tags, 48 memberships. All 190 original media hashes match. UUID test stores/media never use normal account/demo roots.
- Backend final focused checks: **333 assertions pass** across schema/RLS (85), exact cook links (31), Recipes/tickets/links (42), provenance (16), component/order history (7), Recipe/social (48), photo/media access (19), fork sharing (4), additive migration preservation (5), directed sharing (30), Shared Cooking (46). Multi-account PGlite identities only, no hosted test users/writes.
- First isolated UI pass: 2/4 pass; normal native Menu tap and the existing Stepper accessibility ID corrected two test assumptions. Diagnostic rerun passes accessibility Menu; subsequent integration passes all four original Stage 4 UI flows. One scoped integration finished after MCP’s 300-second timeout; direct result bundle proves **19 passed / 2 failed / 0 skipped**. The two failures were obsolete Food Bible filter-button lookup and missing wait for Add Recipe sheet; assertions are retained against current controls, and both focused reruns pass. No full frozen ranking/Creator suite or Release run is warranted in this non-release cycle.

## Final focused verification

- Scoped integration: 12 native tests + 9 UI scenarios. All 12 native and 7 UI passed immediately; the two outdated test interactions above were corrected and pass in the final focused bundle.
- Final dependency/focused bundle: **16/16 passed, zero failures/unexpected failures/skips** (13 additional native tests + the two affected UI reruns + one new exact-photo/Source-control flow). Native coverage includes exact serving math, Recipe serialization/provenance, native links/auth routing and independent copies. Across the final selected scope: **25 distinct native test methods and 10 distinct UI scenarios passed** (the directional-sort test additionally covers all seven parameter values); repeated diagnostic runs are not counted as extra distinct coverage.
- Debug build/launch and complete test-target compilation succeed. iPhone 17e's compact 390-point portrait, light/dark, accessibility-large type, native keyboard/sheets, browse/reset/empty state, exact link/change/unlink, own-photo priority/fallback/replacement, serving+unit projection, unchanged canonical yield, Recipe edit/history/restore/fork/relaunch and shared-reader ownership are covered. Actual final screenshots inspected. Unit projection leaves unsupported legacy unsplit amounts unchanged; no density or semantic-amount conversion is claimed.
- Screenshot inspection found a tinted secondary date in the new shared identity label; existing `ColorToken.subdued` now supplies the explicit adaptive text color. Both directly affected light/dark flows pass again (**2/2**, zero failures/skips); final screenshot confirms neutral readable secondary date text.
- Secret/local-artifact scan: **533 text files, zero findings**. Canonical local Markdown links resolve; whitespace checks pass. No local backups/build/dependency/signing/credential artifacts are intended for staging. Final staged inventory/whitespace checks precede the checkpoint.

The completed checkpoint contains the Stage 4 source/tests/documentation plus deployed additive migration and exact reference schema. No Stage 5, distribution, provider calls, billing, ranking math, Recipe Creator or photo-sync behavior or real-account mutation was performed.

## Owner acceptance pending

Using existing data, without resetting:

1. Food Bible: combine search with Course/Cuisine/Contains/Avoid/Source, reset; try both date/name directions. Grub Rank: try both score/date/name directions; global ranks/scores must stay unchanged.
2. Open an owned Recipe → ••• → Link/Change Cook → Dish → intended version/date. Change and unlink it; inspect Cook Detail’s current link versus any Recipe-used revision. Check an old family-only link remains clearly labeled.
3. On one Recipe with its own image and a differently photographed cook, replace/remove the Recipe image and change the linked version. Confirm own-image precedence, intended-cook fallback, no-photo placeholder and unchanged cooking gallery/history.
4. Try Units/Servings together, As Written/reset and a range/to-taste ingredient; reopen to confirm the saved Recipe is unchanged. Try ••• Edit/History/Save as New and manual Source/Cuisine. Check light/dark and your normal accessibility setting.

Stage 3 real Messages/Safari/two-device checks remain separately pending and are not fabricated as accepted here. Do not begin Stage 5/distribution automatically.


## Checkpoint closeout

Checkpoint message: `Complete Stage 4 Food Bible and Recipe experience`. Baseline `d733eff7b49117fd877f2a36e5fbf7fcddc44844`; final commit identity/push result is reported with Git closeout. Complete intended source/tests/docs/deployed migration/reference schema are included, with local-only artifacts excluded. No outstanding automated failure remains. Normal push only, no credential or history workaround.

**STAYGRUBBY NEXT-RELEASE STAGE 4 AUTOMATED ACCEPTANCE PASSED — OWNER PHYSICAL ACCEPTANCE PENDING**
