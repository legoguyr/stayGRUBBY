# Food Bible Foundation, Dish-linked Recipes & Tickets

Starting checkpoint: `27707003c7edb52d8aef117edfc18e6dbab0336a`, `main`, clean and even with `origin/main`. The preceding Product Structure / Score Calibration cycle is owner accepted. This phase uses one agent, the current checkout and one Simulator lane; no reset, stash, rebase, data seeding into real stores or parallel workers.

## Final product contracts

| Destination | Meaning |
| --- | --- |
| Grub Rank | Existing cooked/ranked Dish → independent CookingAttempts/RankedItems and comparisons; initial tab |
| Food Bible | Derived personal cookbook: an existing cooked Dish with an eligible authorized saved Recipe |
| Tickets | Private Want to Cook saves; prominent separate secondary destination from Food Bible, no fifth tab |
| Saved Recipes | Preserved standalone/unlinked recipes, reached separately; not automatically cookbook entries |

Food Bible has no manually managed membership toggle, separate Dish table or duplicate cooking identity. Adding, editing, linking, unlinking or deleting a Recipe never invokes cooking creation or ranking. Food Bible membership disappears when the link, Recipe, active Dish/cook or current Recipe authorization no longer qualifies. Grub Rank/history/photos/evidence survive Recipe removal.

## Inspected architecture and minimal migration

Previously `recipes` stored owner UUID, content JSON, private/friends visibility, current revision counter and timestamps. `recipe_tickets` was a private idempotent `(account, recipe)` save. `recipe_cooks` reserved an item UUID, immutable recipe content/revision and eventual synchronized attempt ID. Make This entered the existing editable cooking/ranking flow; the durable account-bound SharedCooking outbox completed provenance only after the cook synchronized. Run It Back's social origin and Recipe origin were independent. Flat string arrays represented ingredients and instructions. No offline Recipe cache/outbox existed. Completed snapshots preserved history, but there was no general archive of all Recipe revisions or explicit Dish ↔ current Recipe relationship.

The additive `dish_linked_recipe_components` migration preserves all of that useful infrastructure:

- `dish_recipes(account_id, dish_id, recipe_id, created_at)`: one current recipe relationship per actor-owned Dish, composite FK to the existing private Dish, Recipe FK and account-erasure cascades. One Recipe may enrich several explicitly associated Dishes; neither title matching nor Recipe creation creates a Dish.
- `recipe_revisions(recipe_id, revision, content, created_at)`: immutable archive of current legacy revision plus each subsequent insert/update. Existing prior revisions that were never archived cannot be reconstructed; original completed snapshots remain untouched.
- Both tables have RLS, no direct authenticated/anonymous grants, and narrow existing authenticated `api.recipes` access. Fixed search paths, account/session readiness, ownership and live Recipe visibility remain enforced. Helper and predecessor functions are private.
- New actions: owner-scoped compact `cookbook` pages, `dish`, `attach`, `detach`, and owner-only historical `revision`. Existing save/get/list/Ticket/begin/complete/delete behavior remains, with structured validation and atomic optional save-and-link.
- Attach/save require the actor's already-synchronized active cooked Dish. Unsynced cooking produces an explicit retryable error and leaves the editor draft intact. Linking cannot overwrite another Recipe relationship silently. Removing a changed link is rejected. Existing Recipe revisions reject stale overwrites.
- Completed recipe-cook provenance links its exact synchronized Dish automatically when no primary link exists. It never replaces a manually chosen current Recipe. New migration backfill chooses the latest exact completed provenance per Dish deterministically. Ambiguous/standalone records stay safely unlinked, accessible through Saved Recipes / Use a Saved Recipe. No title guessing or destructive cleanup.
- Old flat Recipe JSON and all existing snapshots stay byte-identical. Old clients can read flattened projections of new components. Old clients attempting to overwrite an existing structured Recipe without components receive a revision/conflict error rather than flattening and losing content.

`Backend/schema.sql` remains the exact byte concatenation of ordered migration files. No already-deployed migration was edited. No SwiftData schema, private cloud graph/sync columns, Auth, Edge Function or Storage architecture changes.

## Recipe and version semantics

A Dish's link selects the current Recipe; editing it creates a Recipe revision, not a new Dish or CookingAttempt. Both Dish Detail and Food Bible open that same Recipe identity. The archive retains structured changes. No assumption is made that every past Cook used the current Recipe.

Make This explicitly captures an immutable content/revision snapshot in the existing reservation. From a known linked local Dish it opens **New Version** for that same Dish. For an uncooked Recipe it opens the existing New Dish flow. Canceling never creates cooking or evidence. Actual ranking uses the frozen engine and the normal create transaction. The existing durable outbox completes Recipe attribution after structured sync, survives relaunch, and then derives cookbook membership. Version-specific historical snapshots remain meaningful even after the current Recipe changes or access is later revoked. A normal manual cook/version without an explicit Recipe reservation is not retroactively asserted to have used a recipe.

Removing the relationship keeps the standalone Recipe. Deleting the Recipe removes its links/Tickets through existing FK semantics while nullifying cross-account Recipe references and retaining entitled historical snapshots. Private cooking and photos remain intact. Account deletion cascades the two new tables using existing ownership FKs; no real account-deletion test or Edge redeployment.

## Structured draft, editor and reader

`RecipeDraft` aliases serializable `RecipeContent`; future parsers can return this same value contract. Optional ordered components carry stable UUID, optional title, order, ingredient rows and steps. Ingredients carry UUID/order, exact quantity text, unit, name, preparation and note. Steps carry UUID/order and instruction. The server canonicalizes order from array order, validates bounded lengths/row counts, normalizes IDs, rejects duplicates and constructs explicit allowlists. Up to 20 components, 100 ingredients and 100 steps across a bounded 60 KB request. No private cooking fields are admitted.

Legacy flat arrays are read as one unnamed component with deterministic namespace IDs; quantities are not guessed from legacy prose. New rows use UUIDs. Saving deliberately upgrades that Recipe to structured content while keeping compatible flat projections. One-component recipes omit an unnecessary component heading. Optional metadata includes introduction, yield, prep/cook minutes, safely summed total, Course/Cuisine, source/HTTPS URL, original creator and explicitly shareable Recipe tips. Nothing is invented. Exact fractions, U.S. customary measurements, metric and temperature text are retained; no unit conversion/scaling engine.

The editor uses an isolated value draft with inline ingredients/steps, add/delete/rename/reorder components, up/down ingredient/step controls and cross-component move menus. Controls have 44-point targets, clear accessibility names and no drag-only interaction. Component deletion has explicit confirmation. Blank new rows prevent Save instead of being silently discarded. Save failure retains the draft; Cancel discards only the draft. Existing title/revision and privacy checks remain. Metadata stays optional; Dish title/Course/Cuisine can prefill without copying Personal Notes.

The reader uses editorial portrait spacing, legible exact quantities, component headings and numbered steps; current and immutable snapshot readers share the same component body. Source/creator and Added by identity remain distinct. Dish/version navigation connects back to cooking context. Recipe editing, unlinking and destructive deletion are separate actions with explicit confirmation.

Food Bible's adaptive grid uses existing design tokens, thumbnails and placeholders, not a second ranking list or generic admin dashboard. Search matches Dish/Recipe titles; Course and literal Cuisine filters use existing metadata. The server returns compact 50-row keyset pages, without bodies or revision history per card. One request per page, no remote N+1 queries. Existing SwiftData Dishes provide representative photography (latest available photo, fallback to the latest cook), without copying media or creating Storage objects. No ranking recomputation is used by this screen.

## Tickets, provenance and privacy

Tickets are clearly Want to Cook, separate from cookbook membership. They use existing idempotent durable Recipe saves; removing one never deletes the Recipe. Make This remains editable and normally ranked. A new uncooked Ticket creates no Dish, attempt, rank or comparison. An authorized social post's Recipe link / existing Run It Back path retain separate Recipe/source/creator and social inspiration. No fabricated social source or expanded source type was added; arbitrary non-Recipe post bookmarking remains outside the existing Recipe-based Ticket system.

Recipe visibility defaults private; friends-only sharing is explicit and checked on every read. A shared Dish does not make a Recipe public. Private/block/deleted/inaccessible Recipes are excluded from cookbook queries and returned as unavailable in Tickets. Recipe cards expose only the viewer's own linked Dish ID. Historical revision archives are owner-only. No anonymous Recipe route, URL, cache or preview payload was created.

Personal cooking notes never enter Recipe/social payloads. Recipe tips are explicitly part of entered Recipe content and share only under the Recipe visibility choice. Post Descriptions remain distinct. Source attribution is entered content, not proof of authorship; original creator, record owner and social inspiration stay separate.

## Offline, restore and future seams

Canonical links/Recipes/revisions/Tickets live in the existing account-bound cloud transport, so link identities survive relaunch/account restore and resolve against restored existing Dish IDs. No second sync engine or local persistence schema is introduced. As before, Recipe management needs connectivity; this phase does not claim offline Recipe editing or a new offline cache. Failed/conflicting saves do not silently lose the draft. Existing private cooking remains offline-capable. Recipe-backed cooking completion still uses the existing durable provenance outbox.

Future RecipeParser → RecipeDraft → editable manual editor → user-confirmed revision-checked save/link is the integration seam. Future providers: Apple Intelligence / Foundation Models on supported devices first, Google Gemini via protected Supabase Edge Function with free-tier/server limits second, manual entry final. Provider selection should be invisible. Native deterministic Swift handles future quantity/scaling math. No AI SDK, credentials, calls, scraping, OCR, model bundle, paid API or provider function is implemented. $0 paid AI/API cost unless the owner explicitly changes policy.

## Deployment, verification and data evidence

Backend checkpoint `b42c382`: additive schema, migration-preservation and authorization tests (6 files). Native checkpoint `09cff7d`: cookbook, editor/reader, Tickets and focused native/UI tests (12 files). Final HEAD is the closing documentation checkpoint reported after creation; this document does not recursively embed its own commit SHA.

Hosted deployment is currently **pending explicit approval**: automatic approval review rejected `apply_migration` because it did not recognize hosted-deployment authority in the trusted transcript. A specific approval question was sent. No alternate SQL/CLI path was used to bypass that rejection. Existing 23/23 migration hashes matched before deployment; the pending local migration is additional. Update this paragraph only with actual deployment evidence.

Fresh hosted baseline (after owner activity since the prior cycle): 3 accounts/rankings, 33 Dishes, 38 attempts/items, 137 comparisons, 14 Sources, 10 tags, 51 memberships, 35 media metadata/backups, 70 sync-operation receipts, 5 posts, 1 comment, 57 Storage objects. Recipe baseline: 1 Recipe, 0 Tickets, 3 incomplete reservations; zero eligible completed provenance for deterministic backfill. The existing unlinked Recipe must remain unlinked until explicitly associated by its owner. All 33 captured application/Storage fingerprint groups matched after local testing; no hosted fixtures/users/media were written.

Preserved demo: 1 ranking, 12 Dishes, 15 attempts/items, 356 comparisons, 10 Sources, 21 tags, 48 memberships, 190 media files. Full semantic/media manifest SHA-256 `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51` remains exact, including identities, order, strengths, uncertainty, evidence, reaction diagnostics and relationships. RankingEngine, score calibration, ranking order, unlock, private sync, share renderers, official assets, signing/configuration and project settings remain unchanged.

Hosted security advisor retains 17 intentional closed/RPC-only RLS-with-no-policy INFO findings and the pre-existing unused password-protection WARN, with no ERROR. See [RLS advisor](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) and [password advisor](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). No Auth settings changed. Local new tables are likewise deliberately closed, with all 34 application tables RLS-protected.

Focused backend: 34 Food Bible lifecycle/security assertions + 11 migration/legacy-preservation/security assertions + 42 existing Recipe/Ticket/link assertions + 16 Recipe/social provenance assertions + 82 schema/RLS assertions = **185 passing**. The old schema test had stale chain/table counts; updated explicit expected counts/closed-table allowlist for this additive migration, preserving all security assertions.

Native model verification: `/private/tmp/staygrubby-food-bible-model.xcresult`, **10 passed, 0 failed/skipped**. Covers legacy one-component read, stable identities, structured quantities/reorder/serialization, draft cancellation/blank-row protection, unchanged entire cooking graph, privacy, durable completion and existing Recipe/link behavior. Debug builds pass. Final targeted integration evidence is recorded below.

Initial UI diagnostics: a test-query compile error was corrected; saved-row accessibility labels were restored; keyboard-intercepted/coarse gestures were replaced by measured viewport scrolling; a genuine missing Done action on the pushed Dish-picker destination was added. No meaningful assertion was disabled. Earlier failing result bundles are retained, not relabeled as green.

Simulator visual evidence inspected: empty cookbook light, separate empty Tickets light, populated cookbook dark with photo/placeholder, multi-component reader dark, linked Dish photo dark, single-component and multi-component editor at accessibility text sizes with Reduce Motion. Synthetic blue media belongs only to an explicit UUID-isolated test store/media root, not real/demo photography. VoiceOver labels/headings and non-drag reorder controls are inspected through accessibility hierarchy, not claimed as a physical VoiceOver session.

## Owner review and release gates

After hosted deployment and final local verification, physically review: add Recipe from an existing Dish; same Dish appears automatically; edit from both routes; structured ingredient/step/component movement and save/cancel; representative photo/placeholder; detach/delete confirmations preserve cooking/history; Tickets → Make This (new Dish and linked New Version); private/friends authorization and source attribution; portrait light/dark/accessibility reading; relaunch/restore with connection and existing offline cooking.

External TestFlight preparation can begin only after this phase's hosted deployment and owner physical approval, plus the existing signing/Universal Link/website/policy/beta-link/App Privacy release gates. No upload, archive, version/build-number change or App Store Connect action is authorized here. The future Intelligent Recipe Engine draft/editor foundation is prepared; implementation remains a separate phase, not started. Current limits: online Recipe management, literal Cuisine filtering, no pre-existing unarchived revision reconstruction, no arbitrary non-Recipe post Tickets, and no AI/conversion/cooking-mode features.

## Final integration and closeout

- `/private/tmp/staygrubby-food-bible-integration.xcresult`: 26 selected methods/executions, 24 passed / 2 failed / 0 skipped / 0 expected failures. All 18 native tests passed. Six UI flows passed; two diagnostic failures were a confirmation query selecting the dimmed underlying button and a missed small Ticket action. This failed bundle is retained honestly.
- Scoped corrections: select the actual confirmation sheet; give reader actions 44-point hit targets; keep Dish/version navigation registered in the Recipe route; clear stale standalone Recipe results across scene/request generations. The native minimum tap target also applies to editor reorder controls.
- `/private/tmp/staygrubby-food-bible-final-targets.xcresult`: all **3 UI tests passed / 0 failed / 0 skipped / 0 expected failures**, including both previously failing flows and the saved Recipe edit path touched by the final lifecycle guards. No second broad suite was run. Latest affected coverage is **18 native + 8 distinct UI methods**, all with passing results; this is not a claim that the older 26-test bundle was green.
- Final Debug compile/test build succeeded. No full historical suite, Release build or physical-device test is claimed or required for this focused phase; project/release/signing configuration remains frozen. Owner physical review remains a separate gate.
- Final privileged-secret/local-artifact scan: 323 text files, zero findings. Both whitespace checks pass. Demo semantic/media manifest remains exact. All 33 hosted application/Storage fingerprints remain exact. No real users, cooking records, Recipe/Ticket content, comparisons, Storage objects or media bytes were created/edited by tests.
- Hosted state remains **23 applied migrations**, all 23 hashes matching; **32/32** existing application tables have RLS. Local chain has one additional tested migration: `20261022235205_dish_linked_recipe_components.sql`, MD5 `3634b481189b1f5915f530067d474999`. It is **not deployed**. The explicit approval question remains pending. Local schema tests verify **34/34** tables protected after applying it. There is no claim of hosted 24/24 alignment or live feature readiness.
- External TestFlight preparation / live-account physical testing of this feature must wait for the hosted migration and owner review. Native/manual RecipeDraft foundation for the future Intelligent Recipe Engine is ready locally; no Engine implementation began.

### Complete changed-file inventory

Backend checkpoint:

- `Backend/schema.sql`
- `Backend/tests/food-bible-migration.test.mjs`
- `Backend/tests/food-bible.test.mjs`
- `Backend/tests/schema.test.mjs`
- `Backend/tests/social-harness.mjs`
- `supabase/migrations/20261022235205_dish_linked_recipe_components.sql`

Native checkpoint:

- `StayGrubby/Social/RecipeComponents.swift`
- `StayGrubby/Social/RecipeEditor.swift`
- `StayGrubby/Social/RecipeReadingBody.swift`
- `StayGrubby/Social/RecipeViews.swift`
- `StayGrubby/Social/Recipes.swift`
- `StayGrubby/Social/SocialIdentity.swift`
- `StayGrubby/Social/SocialReview.swift`
- `StayGrubby/Views/Cooking/AttemptDetailView.swift`
- `StayGrubby/Views/Cooking/FoodBibleView.swift`
- `StayGrubbyTests/FoodBibleTests.swift`
- `StayGrubbyUITests/FoodBibleUITests.swift`
- `StayGrubbyUITests/RecipesLinksUITests.swift`

Documentation checkpoint:

- `SOCIAL_ARCHITECTURE.md`
- `STAYGRUBBY_MASTER_ROADMAP.md`
- `STAYGRUBBY_FOOD_BIBLE_FOUNDATION_REVIEW.md`
- `UI_ARCHITECTURE.md`

22 intended files total. No project settings, official assets, ranking math/calibration, persistence schema, private sync, sharing renderer, backend credentials, generated products, local backups or fixture media included. Push outcome and final commit SHA are reported after checkpoint creation; no credential/configuration workaround is authorized.
