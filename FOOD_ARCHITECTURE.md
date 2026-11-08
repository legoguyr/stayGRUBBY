# StayGrubby food architecture — one Dish, separate records

**Canonical domain document — November 8, 2026, revised for the one-Dish identity decision.** It combines the Unified Food Architecture checkpoint (`6214900`), the accepted Codex data-foundation work (`a6de6b8`), the D1/D2 stages and the later owner decision that **Dish and Recipe are two views of one Dish identity** (§1 decision 11), which replaces the earlier multi-Recipe/Main Recipe relationship model. It owns:

- how Dishes, Recipes and Cooking Attempts relate (one Dish identity, exact cook provenance)
- the final user-facing wording for Cooking Attempts (renameable cooks) and Recipe History
- which data describes the Recipe *as written* and which describes the cook *as made*
- what Grub Rank and Food Bible each show and filter
- the contextual Add Recipe, Cook Again and Rank My Version flows
- the reusable Dish UI parts

Current implementation lives in [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md), the implementation order in the [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md#next--unified-dish-foundation-then-ui-overhaul), design-system rules in [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md), and long-term signals in [PERSONAL_COOKING_INTELLIGENCE.md](PERSONAL_COOKING_INTELLIGENCE.md). Supporting evidence: [V1_DATA_FOUNDATION_AUDIT.md](V1_DATA_FOUNDATION_AUDIT.md#november-8-follow-up).

Status words: **Implemented** · **Implemented, pending deployment** · **Decided** (approved, not built) · **Post-V1** · **Transitional** (kept for data safety and older builds; not part of the V1 model). Current state: §3 one-Dish identity is **Implemented and deployed** (`20261108221250_dish_recipe_identity`, November 8); §4 cook naming, the §5 Recipe Diet content key and the D1/D2 server structures are deployed. Protected ranking math and Recipe Creator are unchanged.

## 1. Owner decisions (November 8, 2026)

| # | Decision | Where specified |
| --- | --- | --- |
| 1 | **Dish** is the user-facing name for the combined food identity | §2 |
| 2 | ~~A Dish may have several Recipes and a user-selectable Main Recipe~~ — **superseded by decision 11.** Existing multi-Recipe data is preserved (§3.3), but V1 has one Recipe per Dish and no Main Recipe workflow | §3 |
| 3 | **Food Bible stays the Recipe lens**: it lists Dishes that have Recipe content; a cooked Dish without a Recipe does not appear there | §6 |
| 4 | Recipe revisions are **Recipe History**, never "versions" | §4 |
| 5 | Each Cooking Attempt has a user **Cook Name** ("Original", "Spicy Version", "Thanksgiving 2026"), edited in Edit Cook. Without one it falls back to "Version N". No identity or ranking evidence depends on the name | §4 |
| 6 | **All Cooks** replaces the All Versions control (validated in §4.3) | §4.3 |
| 7 | **Cook Again** is the action for making the Dish again | §7.2 |
| 8 | ~~Explicit provenance associates automatically; loose matches are suggested~~ — **superseded by decision 11:** a Recipe belongs to its Dish by identity, so there is no relationship for the user to manage | §3 |
| 9 | Recipe data is **as written**, Cooking Attempt data is **as made**. This now applies to Dietary as well as Contains | §5 |
| 10 | Codex's exact Recipe-revision provenance, link-integrity and dated-reaction work is preserved. Protected ranking math is unchanged | §2.1, §9 |
| 11 | **Dish and Recipe are two views of the same Dish identity** (like one post surfacing in different feeds). The user never manages a Dish↔Recipe relationship. Creating a Recipe in Food Bible creates its Dish; adding a Recipe from a Dish writes that Dish's Recipe side; Grub Rank and Food Bible show the same Dish. Dish Detail shows "View Recipe", not a second copy of the Dish. No standalone Rename; no Main Recipe workflow in V1. Grub List shows Dish/cook activity only | §2, §3, §6, §8 |

## 2. One Dish, separate records

Users see **one Dish**. A Dish can have cooks, a Recipe, or both. A Dish with only a Recipe reads as *not cooked yet*. The schema stays normalized (no merged table), but one canonical **Dish identity** — the Dish UUID — connects Recipe content and revisions, cooks, ranking evidence, photos and future sharing/intelligence:

| Layer | Record | Lives in | Owns |
| --- | --- | --- | --- |
| Dish identity | The Dish UUID: `dishes.id` (client-synced) and `recipes.dish_id` | SwiftData + private sync; Supabase | One identity for both views (§3) |
| Cooked side | `Dish` → `CookingAttempt` → `RankedItem` + `Comparison` | SwiftData + private sync | Food identity fields; each cook *as made*; frozen ranking evidence |
| Recipe side | `Recipe` (`dish_id`) → `recipe_revisions` | Supabase (online only) | Instructions *as written*, audience, revisions, attribution |
| Provenance | `recipe_cooks` (exact revision a cook used), `recipe_forks`, `post_recipes` | Supabase | Historical claims; never rewritten |
| Transitional | `dish_recipes`, `dish_recipe_links`, `recipe_cook_links` | Supabase | Pre-identity associations kept for data safety and older builds (§3.3) |

In user-facing copy, everything is "Dish". **No `foods` table:** the Dish UUID already identifies a Recipe-only Dish and a cooked Dish uniformly, so Want to Cook, Collections and sharing can target a Dish ID directly (§10).

### 2.1 Accepted provenance and integrity (Codex `a6de6b8`)

These are **implemented and deployed** (`20261108171024_recipe_cook_lifecycle`, November 8). The architecture depends on them:

- **Exact use.** A cook's sync completes its matching owner/ranked-item Recipe reservation in the same transaction, freezing the revision, content and creator credit in `recipe_cooks`. Existing provable matches are repaired, with the repair time marked as reconciliation time. Cooks without a matching reservation keep unknown Recipe use.
- **Current link.** A new Recipe-origin cook fills a vacant exact link automatically. Deleting a cook retires its exact link but leaves its snapshot intact. Completion retries never recreate a removed association.
- **Dated reactions.** Each completed rank or re-rank appends `{id, time, reaction, kind}` to private ranked-item diagnostics in the same transaction. These entries are never model inputs and never shared.

This document builds on those rules. It never redefines exact use from links, titles or Dish identity.

## 3. One Dish identity (owner decision 11)

### 3.1 Model

- **`recipes.dish_id`** is the owner's Dish identity for that Recipe. Unique per owner: a Dish has at most one owned Recipe. It is an owner-scoped UUID rather than a foreign key, because the `dishes` row is client-synced and may arrive after the Recipe (or not exist yet for a never-cooked Recipe created on another device). A removed (tombstoned) Dish is never shown as a Recipe's Dish.
- **Exact provenance is unchanged:** `recipe_cooks` freezes the revision each cook was made from (Codex lifecycle). A Dish's Recipe is "how I make this Dish"; "Recipe used" is "what this cook was made from". They can differ (an older revision, or a Sous Chef's Recipe) and both stay visible.
- **Foreign Recipes** (a Sous Chef's, or post-V1 Saved) never get the viewer's Dish identity; cooking one records provenance only. "Save a Private Copy" makes an owned Recipe that gets a Dish when first created or cooked.

### 3.2 Behavior

| Action | Result |
| --- | --- |
| Create or import a Recipe in Food Bible | The app picks a new Dish UUID, saves the Recipe with it (`recipeDishID`), and once the server confirms creates the local Dish (no cooks) and syncs it. The Dish appears in Food Bible as *not cooked yet*, never in Grub Rank |
| Add Recipe on a Dish (Dish Detail) | The Recipe is created with that Dish's identity: it becomes the Dish's Recipe side |
| Rank My Version on an owned Recipe | The cook goes into the Recipe's own Dish; a Dish row is created with the Recipe's Dish UUID if it does not exist yet |
| Completing a cook of an owned Recipe without a live Dish | The cook's Dish becomes the Recipe's Dish (server trigger) |
| 86 the last cook of a Dish with a Recipe | The Dish identity stays (Recipe-only Dish, *not cooked yet*) |
| 86 a Recipe | An uncooked Dish that only existed for it is removed; a cooked Dish stays in Grub Rank |
| Edit a Recipe | Never moves it to another Dish |

Server actions: `save` accepts `recipeDishID` (new Recipe, or filling a missing/removed Dish); `set_dish` claims explicitly; `dish` returns the Dish's own Recipe first; `library_index` reports each owned Recipe's live Dish and `cooked`; Recipe cards carry `dishID` for the owner only. Assigning a Dish is not a Recipe revision (the Recipe History archive fires only on revision/content changes).

### 3.3 Transitional structures (kept, not the V1 model)

- `dish_recipes` (legacy family link), `dish_recipe_links` (D1 multi-Recipe + Main) and `recipe_cook_links` (current cook link) stay with their triggers and RLS so no data is lost and older builds keep working. The app no longer offers Link a Dish, Unlink, Set as Main or multiple Recipes per Dish.
- The identity backfill used the D2 resolution (Main-Recipe Dish, exact-linked cook's Dish, related Dish, legacy link). If two Recipes resolved to one Dish, the Dish's Main kept it and the others stayed unassigned until cooked (production had none: 5 Recipes, 5 distinct Dishes).
- Retire these structures only in a later, explicitly authorized cleanup once no supported build reads them.

## 4. Cooking Attempts: final terminology and naming

### 4.1 Words

| Concept | Code / docs | User-facing (final) | Retired user-facing wording |
| --- | --- | --- | --- |
| One cook of a Dish | `CookingAttempt` (Cooking Attempt) | **cook** (singular); counts read "3 cooks" | "version" as the noun for the thing |
| Its user-chosen name | stored `versionTitle` / `version_title` | **Cook Name** (field label); shown as the cook's name | "Version Title" |
| Fallback when unnamed | `sequenceNumber` | **Version N** (e.g. "Version 2") | — (deliberately kept as the fallback *name*) |
| Making the Dish again | New Version flow | **Cook Again** | "New Version" |
| Cooking from a Recipe | Recipe-origin cook | **Rank My Version** (approved vocabulary; your cook is your version *of the Recipe*) | — |
| Grub Rank projection | `RankingsDisplayMode.topVersion` / `.allVersions` | Off: one row per Dish (its top cook). On: **All Cooks** | "All Versions", "Top Version" |
| Recipe revisions | `recipe_revisions` | **Recipe History** (overflow item and screen title); a single entry is a "revision" | "Version History" |
| Changing a cook's name | — | The **Cook Name** field in Edit Cook (no separate Rename action) | "Rename" |

"Version" remains only inside the fallback name "Version N" and the Rank My Version action.

### 4.2 Naming behavior (Decided; for the rebranding stage)

- **Storage is unchanged.** The name *is* the existing `versionTitle` (SwiftData) / `version_title` (Supabase, ≤200 characters, synced). Don't rename the stored property: renaming a SwiftData attribute is a migration with no benefit. Add a `cookName` accessor if it helps readability.
- **Normalization:** `CookName.normalized` trims, collapses internal whitespace runs and bounds the name at 200 characters (`CookingDraft.cleanTitle` uses it). An empty name becomes nil and returns to the fallback. Names are not unique: two "Spicy" cooks are allowed, because identity is the UUID.
- **Display name** = custom name, else "Version N", where N = the stored `sequenceNumber`. That number is stable, so it is never renumbered after deletion, and a gap such as "Version 1, Version 3" is acceptable and honest. A lone unnamed cook shows **no** label (existing meaningful-label rule). Once a second cook exists, an unnamed first cook shows "Version 1". Legacy imports follow the same rule.
- **Ranking independence:**
  - Comparisons, assessments, reactions, unlock eligibility, Recipe-used snapshots and links all key on `CookingAttempt.id` / `RankedItem.id`, never on the name.
  - `RankedItem.name` is a display cache of `displayName`. `CookingStore.rename` refreshes it for that cook; creating or deleting a cook refreshes siblings whose fallback visibility changes (a lone first cook caches "Dish", then "Dish — Version 1" once a second cook exists). Strengths, uncertainty and evidence are never touched (`CookNameTests`).
  - Editing the Cook Name is an ordinary Edit Cook change staged as `editCook` through the outbox. It never starts a re-rank and never posts.
- **Snapshots stay snapshots:** published posts and rank-at-sharing records keep the name they were shared with. Recipe-used content is untouched. Search matches the current display name (custom or fallback).
- **Where names appear:** Grub Rank rows, Dish Detail cook list, the comparison screen (Dish + name), the result screen, the Cook Again chooser, the Dish picker, share cards and the composer (per their existing snapshot rules), and accessibility labels ("Spicy Version, cook of Chili").
- **Suggested names:** none. The field is labelled "Cook Name (optional)"; when the cook would show a fallback, a hint below reads "Leave blank to show Version 3."  No date- or Recipe-derived automatic names, because they would read as the user's choice.

### 4.3 All Cooks — validation and placement

- **Placement:** keep the Stage B slot (Grub Rank row 3, `SGBrowseToggle`, after Sort). Off = one row per Dish showing its top cook. On = every cook at its true global rank. Dish Detail shows a **Cooks** section listing all of the Dish's cooks with rank, gated score, date and name, so the toggle mainly serves cross-Dish browsing.
- **Validation:** "All Cooks" matches "Cooks" on Dish Detail, the "3 cooks" counts and "Cook Again", which together make a single vocabulary. **Risk:** "cooks" can be read as people. In context (a Dish ranking whose people are "Sous Chefs") it reads as attempts, but the spoken label must remove the ambiguity: **"Show All Cooks of Each Dish"**. If owner acceptance still finds it ambiguous, the fallback is "Every Cook". No other alternative is kept open.
- **Other copy changed in D1:** Dish Detail section "Cooks" with a Cook Again button; the creation menu's Cook Again ("Make a saved Dish again"); navigation titles Cook Again / Rank My Version; Recipe History with "Revision N" entries; score-unlock copy counts cooks ("6 / 10 cooks ranked"); the share achievement reads "BEST COOK YET".
- **Storage:** `RankingsDisplayMode` raw values ("Top Version" / "All Versions") are persisted in UserDefaults under `StayGrubby.rankingsDisplayMode.v1`. Change only the display labels, never the raw values, so existing preferences survive.

## 5. As written vs as made

Recipe fields describe the Recipe **as written**. Cooking Attempt fields describe what the user **actually made**. Dish fields describe the food identity. Storage placement of existing values does not move, and nothing is backfilled or inferred.

| Field | Dish (food) | Recipe (as written) | Cooking Attempt (as made) | Notes |
| --- | --- | --- | --- | --- |
| Name / title | Dish name | Recipe title | Cook Name (§4) | Displayed independently; never auto-synced |
| Course | default | Recipe Course | snapshot | Unchanged |
| Cuisine | ✅ | ✅ | — | Unchanged |
| Source / inspiration | manual Source | source / original creator | — | Different meanings, kept apart |
| Description / notes | Public Description, Private Notes | description, tips | cook notes | Private notes never public |
| **Contains** | — | Contains / Possible (reviewed assessment) | Contains | Shown per side with labels; never merged into one claim |
| **Dietary — Diet** (Dairy-Free, Gluten-Free, Vegan, Vegetarian) | — | **Decided new field** `dietary` in `RecipeContent`: author-selected only | ✅ existing | The Recipe value says the Recipe *as written* fits that diet; the cook value says what was actually made |
| **Dietary — Certification** (Halal, Kosher) | — | **Never** on a Recipe | ✅ existing | Certification depends on products, supervision and kitchen. It is a fact about the cook, so it is never inferred and never attached to written instructions |
| Photos | — | Recipe photo | cook photos | Ownership unchanged |

**Recipe Diet field rules:**

- It is an additive optional key in the Recipe content JSON. It is part of revisions and post pinning like every other content field.
- The author sets it in the Recipe editor. **Gemini does not propose it.** Recipe Creator contract 4 is frozen, and Diet suitability depends on product choices (stock, cheese rennet, Worcestershire). Unknown stays unknown.
- D1 confirmed the server previously **dropped unknown content keys silently**; `20261108171120_dish_recipe_links` adds `dietary` additively (unique codes from `dairyFree`, `glutenFree`, `vegan`, `vegetarian`; stored sorted; Halal/Kosher rejected). `RecipeContent.dietary` round-trips it so edits never drop it. The editor control ships in F (3b).

**Cooking from a Recipe (prefill, user-confirmed):**

- The cook's Diet and Contains may be *preselected* from the Recipe's author-selected Diet and reviewed Contains. The user sees and confirms them. Possible is never prefilled, and Certification is never prefilled.
- After a cook is saved, editing the Recipe never changes it, and editing the cook never changes the Recipe.

## 6. Two lenses over one library

| | Grub Rank | Food Bible |
| --- | --- | --- |
| Question | What have I cooked, and how did it rank? | How do I make things? |
| Rows | Ranked **cooks**: by default one per Dish (top cook), or every cook with All Cooks | **Dishes with Recipe content**: one card per Dish (its name, the Recipe title when different) |
| Includes | Dishes with ≥1 ranked cook | Owned Dishes with a Recipe (cooked or not cooked yet) and authorized Sous Chef Recipes; post-V1 Saved Recipes and Want to Cook |
| Excludes | Recipe-only Dishes | Cooked Dishes without a Recipe (owner decision 3) |
| Order | Global Bradley–Terry order (frozen) plus read-only Sort | Recently Updated / Newest / Oldest / A–Z / Z–A |
| Opens | Dish Detail, with the tapped cook selected (its cook face) | The same Dish's Recipe face: the Recipe reader for that Recipe, carrying the Dish's Cooks section; a Recipe-only Dish shows "Not cooked yet" (§8.1) |

Both lenses show the same Dish identity: a Dish with cooks and a Recipe appears in both, and 86ing in one view never orphans the other (§3.2).

### 6.1 Filters per lens

Filters read the record the lens lists, use the Stage B chip/sheet grammar, and never write data, renumber or create another ranking.

| Filter | Grub Rank (as made) | Food Bible (as written) |
| --- | --- | --- |
| Search | ✅ (Dish, cook display name, Course, Dietary, Contains) | ✅ Recipe text |
| Course | ✅ cook snapshot | ✅ |
| Cuisine | ✅ Dish | ✅ |
| Dietary | ✅ Diet + Certification (cook) | **Decided:** Diet only, once the Recipe Diet field exists (§5). No Certification |
| Avoid | ✅ cook Contains | ✅ Contains + Possible |
| Contains | — (Avoid covers it) | ✅ |
| Source | — | ✅ |
| Cooked / Not cooked yet | — | **Implemented (D2):** a "Cooked" group in the Filters sheet (Cooked, Not cooked yet), derived from relationships with no new data |
| Photo | ✗ removed | ✗ removed |

Grub Rank keeps its four direct chips. Food Bible has six groups and keeps the single Filters sheet (UI_ARCHITECTURE 5.4 rule).

## 7. Contextual flows

### 7.1 Add Recipe — `AddRecipeFlow` (Stage F, implemented)

One flow (`AddRecipeFlow(context:)`), two sources everywhere: **Paste Recipe** (outside text → Gemini contract 4 → editable `RecipeDraft` → review → explicit Save; Scan and Share Sheet are post-V1 sources of the same pipeline) and **Add Manually** (empty draft → the same editor). Every path ends with the Recipe on exactly one Dish (§3).

| Started from | Choices | Result |
| --- | --- | --- |
| Food Bible + | **New Dish + Recipe** (Paste / Add Manually on the same compact screen) | A new Dish with this Recipe; then **Rank Now** (Rank My Version into that Dish) or **Not Now** (stays *not cooked yet*) |
| Food Bible + | **Add to a Ranked Dish** → choose a ranked Dish without a Recipe → Paste / Add Manually | That Dish's Recipe side |
| Dish Detail "Add Recipe" | Paste / Add Manually / **Use a Food Bible Recipe** | This Dish's Recipe side |
| Ranking result of a Dish with no Recipe | **Add a Recipe?** → Add Recipe (this flow, Dish context) / Not Now | Offered for a brand-new Dish, and for Cook Again from Dish Detail when the Dish has no Recipe; never blocks Done |

**Use a Food Bible Recipe** reconciles two identities safely: only an owned Recipe whose Dish has **no cooks** is offered. `set_dish` moves the Recipe's Dish identity to this Dish (content and Recipe History unchanged), then the now-empty uncooked Dish is removed through sync. A cooked Dish's Recipe is never moved (that would orphan its cooks), and a Dish that already has a Recipe offers View Recipe, not Add Recipe.

External-AI consent, the burst guard, cooldown-to-manual, the 40 KB bound and Recipe Creator behavior are unchanged.

### 7.2 Cook Again and Rank My Version

- **Cook Again** (Dish Detail or Grub Rank) starts a new cook of *this* Dish. Offering "Cook from this Dish's Recipe" as a first step (exact revision reservation) is an F option; nothing is preselected or recorded as used unless chosen.
- **Rank My Version** (from a Recipe) starts a Recipe-origin cook that goes into the Recipe's own Dish (§3.2). A Sous Chef's Recipe starts a new Dish of the viewer's.
- Both end in the unchanged protected flow: Initial Reaction → comparisons → result.

### 7.3 Editors

`CookEditor` (New Dish, Cook Again, Rank My Version, Edit Cook) groups fields by owner so scope is visible without moving data:

- **About this Dish:** name, Cuisine, Source, Public Description, Private Notes, default Course. The editor states that changes apply to every cook.
- **This cook:** Cook Name, date, photos, cook notes, Course, Diet, Certification, Contains, Tag a Sous Chef.

## 8. Reusable Dish UI parts

Each part owns one record and is built by generalizing existing components (AGENTS Reuse Before Reinvention). An empty side renders as one quiet action, never as an empty section.

| Part | Built from | Used by |
| --- | --- | --- |
| `DishIdentityHeader` — name, cook name, score, rank | `SGEyebrow`, `ScoreBadge` | Dish Detail |
| `DishCooksSection` — cooks with name, rank, gated score, date; Cook Again | `CookVersionIdentity`, `sgPhotoFrame(.compactThumbnail)` | Dish Detail, the Recipe face |
| `DishRecipeRow` — "View Recipe" (or Add Recipe: Paste / Add Manually) plus the cook's "Recipe used" revision when it differs | `RecipeInlineAction`, `RecipeSnapshotView` | Dish Detail |
| `CookName` — display-name resolver; the name is edited in Edit Cook | `CookingAttempt.meaningfulVersionLabel` | Every place in §4.2 |
| `DishActions` — overflow: Edit Cook, Re-rank, Share with Sous Chefs, Dish text, 86 | overflow menus | Dish Detail; the Stage C sharing model plugs in here |
| Food Bible card — the Dish name, the Recipe title when it differs | `CookbookCard` | Food Bible |
| `AddRecipeFlow(context:)` (F) | `RecipeCreationChoice`, `RecipeImportView`, `RecipeEditor` | §7.1 |
| `CookEditor` (F) | `CookingMetadataForm`, `CookingDetailsSheet`, `SGOptionSheet`, `SGFormSection` | §7.3 |

### 8.1 Dish Detail and the Recipe face (current)

- **Dish Detail** (Grub Rank → `AttemptDetailView`): hero, `DishIdentityHeader`, cook metadata, Dish text, `DishRecipeRow`, cook provenance (tagged Sous Chefs named: "Cooked with Alex and Sam"), Source, Personal Notes, `DishCooksSection`. The Recipe is one row — the Dish photo and text are not repeated.
- **Recipe face** (Food Bible card or View Recipe → `RecipeDetailView`): the Recipe reader for the Dish, with the Dish's cooks ("Your cooks of [Dish]") or a "Not cooked yet" eyebrow. The Dish shown is the Recipe's own Dish identity. No Link a Dish / Unlink actions.
- **Grub List** shows Dish/cook activity only. Recipe-only activity (`recipe_created`) is not shown; a cook post can still offer its Recipe.
- History: D2 (`9b28a33`) shipped a multi-Recipe Recipes section with Main Recipe; it was replaced the same day by this model. `20261108210256_food_bible_dish_resolution` (deployed) remains the fallback resolution for Recipes without a Dish identity.

## 9. Evidence preserved for Personal Cooking Intelligence

- **Cooked, known and intended stay separate:** cooks, Recipes, and post-V1 Saved / Want to Cook. A Recipe-only Dish is never counted as cooked.
- **As written vs as made** (Diet and Contains on both sides) is stored separately. The difference itself shows substitutions.
- **Used vs the Dish's Recipe:** only `recipe_cooks` means "cooked from this revision". A Dish's Recipe (`recipes.dish_id`) is how the user makes the Dish now; the difference over time is cooking history (remake counts, substitutions). Transitional associations are not evidence.
- **Dated reactions** (Codex) record *when* evaluations happened. Cook names are user labels, not evidence, and are never interpreted.
- **Food-level fields are current state.** Renaming a Dish or changing its Cuisine applies to every cook (known limit). Capture an "as cooked" value going forward only if a real feature needs it.
- **Context** (Collection, shared cook, Recipe origin) stays an explicit relationship.

## 10. Future compatibility (post-V1; nothing here is authorized)

| Feature | Fit |
| --- | --- |
| **Saved Recipes** | An owner-private, revocable bookmark to a Sous Chef's Recipe, shown in a Food Bible "Saved" segment. Rank My Version on it creates an owned cook with creator credit, never a copy or an owned link. Save a Private Copy stays a separate explicit action |
| **Want to Cook** | An intention targeting a Dish ID (cooked or Recipe-only), resolved by a later cook. No separate Food identity is needed: the Dish UUID covers both. The dormant `recipe_tickets` covers Recipes only |
| **Collections** | Collection ↔ Dish ID many-to-many; members may be Recipe-only Dishes |
| **Contextual rank boards** | A filtered projection of the **one** global ranking (Collection, Cuisine, shared cooking). Never a separate fit, evidence set or manual order. Whether a board shows board-relative positions is an owner decision for that feature |
| **Scan Recipe / Share Sheet** | Extra Import Recipe sources (on-device text recognition; an authenticated app-group handoff). Same Gemini → review → Save path; disclosure covers photo-derived text |
| **Discover / statistics / remake counts** | Count explicit cooks per Dish ID and used snapshots per the audit's definitions |
| **Dish sharing** | Shares one Dish ID: its cooks (per existing post rules) and, when shared, its Recipe |
| **Aggregate score and "made by N people"** (owner idea, not built) | A shared Recipe/Dish page may later show an aggregate score and how many people have made it. Dish IDs are private per account, so cross-person aggregation keys on the **shared Recipe UUID** and exact-use provenance (`recipe_cooks`), counting each person once, and only from cooks whose owners' sharing/consent allows it, with a minimum-count threshold. The score input is each person's displayed (gated) score for their best cook of that Recipe, never raw strengths or comparisons across people (rankings are personal and not comparable). Gated behind the `dish_aggregate_scores` feature flag (off); needs privacy/disclosure review before any UI |

## 11. Per-cycle architecture check (one-Dish identity)

- **A. Requirements:** one user-facing Dish across Grub Rank and Food Bible; no relationship management; exact cook provenance kept.
- **B. Reuse:** existing `dishes` rows and sync, `recipes`, `recipe_cooks`; one added column. No merged table.
- **C. Intelligence value:** a stable Dish ID ties Recipe revisions, cooks, remake counts and photos together.
- **D. New data justified:** `recipes.dish_id` (+ unique per owner). Nothing speculative.
- **E. Privacy:** Dish IDs are owner-private (cards expose `dishID` only to the owner); Grub List no longer shows Recipe-only activity.
- **F. Scalability:** one indexed column; per-entry lookups bounded by `library_index` pages.
- **G. Docs/tests:** this document, the architecture overview, roadmap, UI architecture, release gate; backend `dish-recipe-identity` test; app unit/UI tests.

## 12. Still open (decide in the named stage, not blocking)

- Board-relative positions on future contextual rank boards (post-V1 feature).
- ~~Whether to also show the Recipe on Grub Rank rows~~ — **decided: no.** Grub Rank rows stay cook-focused; View Recipe lives on Dish Detail.
- When to retire the transitional association tables (§3.3) — a later authorized cleanup.
- Recipe reservation expiry and snapshot retention after explicit cook deletion (privacy decision, carried from the audit; V1 release gate).
