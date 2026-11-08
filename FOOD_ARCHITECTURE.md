# StayGrubby food architecture — one Dish, separate records

**Canonical domain document — final reconciliation November 8, 2026.** This document combines the Unified Food Architecture checkpoint (`6214900`), the accepted Codex data-foundation work (`a6de6b8`) and the owner decisions recorded the same day. It owns:

- how Dishes, Recipes and Cooking Attempts relate, including Main Recipe and association rules
- the final user-facing wording for Cooking Attempts (renameable cooks) and Recipe History
- which data describes the Recipe *as written* and which describes the cook *as made*
- what Grub Rank and Food Bible each show and filter
- the contextual Add Recipe, Cook Again and Rank My Version flows
- the reusable Dish UI parts

Current implementation lives in [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md), the implementation order in the [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md#next--unified-dish-foundation-then-ui-overhaul), design-system rules in [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md), and long-term signals in [PERSONAL_COOKING_INTELLIGENCE.md](PERSONAL_COOKING_INTELLIGENCE.md). Supporting evidence: [V1_DATA_FOUNDATION_AUDIT.md](V1_DATA_FOUNDATION_AUDIT.md#november-8-follow-up).

Status words: **Implemented** · **Implemented, pending deployment** · **Decided** (approved, not built) · **Post-V1**. **D1 status (November 8):** §4 cook naming and the copy rebrand are **Implemented**; §3 Dish Recipes / Main Recipe and the §5 Recipe Diet content key are **Implemented and deployed** (`20261108171120_dish_recipe_links`); the app UI that calls them arrives in D2/F. Protected ranking math and Recipe Creator are unchanged.

## 1. Owner decisions (November 8, 2026)

| # | Decision | Where specified |
| --- | --- | --- |
| 1 | **Dish** is the user-facing name for the combined food identity | §2 |
| 2 | A Dish may have several Recipes and a **user-selectable Main Recipe**, with a deterministic default when none is chosen | §3.2 |
| 3 | **Food Bible stays the Recipe lens**; a cooked Dish without a Recipe does not appear there | §6 |
| 4 | Recipe revisions are **Recipe History**, never "versions" | §4 |
| 5 | Each Cooking Attempt can be **renamed** by the user ("Original", "Spicy Version", "Thanksgiving 2026"). Without a custom name it falls back to "Version N". No identity or ranking evidence depends on the name | §4 |
| 6 | **All Cooks** replaces the All Versions control (validated in §4.3) | §4.3 |
| 7 | **Cook Again** is the action for making the Dish again | §7.2 |
| 8 | Explicit Recipe provenance **associates automatically**; ambiguous or loose matches are **suggested for the user to confirm**, never merged silently | §3.3 |
| 9 | Recipe data is **as written**, Cooking Attempt data is **as made**. This now applies to Dietary as well as Contains | §5 |
| 10 | Codex's exact Recipe-revision provenance, link-integrity and dated-reaction work is preserved. Protected ranking math is unchanged | §2.1, §9 |

## 2. One Dish, separate records

Users see **one Dish**. A Dish can have cooks, Recipes, or both. A Dish with only a Recipe reads as *not cooked yet*. Underneath, the records stay separate and keep their own IDs, owners, sync paths and deletion rules:

| Layer | Record | Lives in | Owns |
| --- | --- | --- | --- |
| Dish (composed, internal name `Food`) | No stored table. A read model built per view | App | Nothing. It only assembles the records below |
| Cooked side | `Dish` → `CookingAttempt` → `RankedItem` + `Comparison` | SwiftData + private sync | Food identity fields; each cook *as made*; frozen ranking evidence |
| Recipe side | `Recipe` → `recipe_revisions` | Supabase (online only) | Instructions *as written*, audience, revisions, attribution |
| Relationships | Dish-level association (Decided, §3.1), `recipe_cook_links`, `recipe_cooks`, `dish_recipes` (legacy), `recipe_forks`, `post_recipes` | Supabase | Each records a different claim (§3.1). They are never merged into one another |

In code and docs, `Food` means the composed read model and `Dish` means the SwiftData/`dishes` entity. In user-facing copy, everything is "Dish". **No `foods` table now.** Store a Food identity only when a shipped feature has to reference a Recipe-only Dish and a cooked Dish uniformly. Want to Cook and Collections are the expected triggers (§10).

### 2.1 Accepted provenance and integrity (Codex `a6de6b8`)

These are **implemented and deployed** (`20261108171024_recipe_cook_lifecycle`, November 8). The architecture depends on them:

- **Exact use.** A cook's sync completes its matching owner/ranked-item Recipe reservation in the same transaction, freezing the revision, content and creator credit in `recipe_cooks`. Existing provable matches are repaired, with the repair time marked as reconciliation time. Cooks without a matching reservation keep unknown Recipe use.
- **Current link.** A new Recipe-origin cook fills a vacant exact link automatically. Deleting a cook retires its exact link but leaves its snapshot intact. Completion retries never recreate a removed association.
- **Dated reactions.** Each completed rank or re-rank appends `{id, time, reaction, kind}` to private ranked-item diagnostics in the same transaction. These entries are never model inputs and never shared.

This document builds on those rules. It never redefines exact use from links, titles or Main Recipe.

## 3. Dish ↔ Recipe relationships

### 3.1 Four kinds of relationship

| Relationship | Meaning | Storage | Cardinality |
| --- | --- | --- | --- |
| **Recipe used** | This cook was made from this exact revision | `recipe_cooks` snapshot (immutable) | ≤1 per cook |
| **Current cook link** | This cook is currently associated with this Recipe | `recipe_cook_links` | ≤1 Recipe per cook; ≤1 cook per Recipe |
| **Dish Recipe** (Implemented, deployed) | This Recipe is one of the ways I make this Dish | New owner-private relation `dish_recipe_links(account_id, dish_id, recipe_id, is_main, created_at)` | Many Recipes per Dish; one Recipe may belong to several Dishes; at most one `is_main` per Dish (partial unique index) |
| **Legacy family link** | Pre-V2 association of a Recipe with a whole Dish | `dish_recipes`, PK `(account_id, dish_id)` | ≤1 per Dish |

**Why a new relation:** a Dish can't hold several Recipes in today's structures. `dish_recipes` allows only one Recipe per Dish, and exact links are per cook. Repurposing `dish_recipes` as "main" was rejected: changing the main Recipe would delete the old association and change the meaning of historical rows. The implementation stage will:

- add the table additively, with RLS, owner-derived RPCs and a compare-and-swap guard
- read legacy `dish_recipes` rows as Dish Recipes (copied once, with fingerprints, if that keeps one source of truth; the legacy table is kept read-only)
- **not** copy exact cook links or used snapshots into it, because those are already related through the cook

Deleting the Dish or the Recipe cascades. Supabase authorization is required in that cycle.

A Dish's **related Recipes** are the union, deduplicated by Recipe UUID and restricted to Recipes the viewer may read, of:

- its Dish Recipes and legacy family link
- Recipes exact-linked to any of its active cooks
- Recipes recorded as used by any of its cooks (a revoked foreign Recipe shows only its frozen snapshot)

### 3.2 Main Recipe

- **Chosen:** the user can mark any related Recipe as Main from Dish Detail. This sets `is_main` on its Dish Recipe row, first creating the row if the Recipe was related only through a cook.
- **Default when nothing is chosen** (deterministic and independent of ranking, so it never flips when scores move):
  1. the legacy family-linked Recipe, if any
  2. otherwise, the oldest related Recipe by Recipe creation time, with Recipe UUID as the tie-break
- **Auto-main:** the first Recipe associated with a Dish that has no Recipe becomes Main.
- If the chosen Main is deleted, revoked or unlinked, the default rule applies again. The app never silently picks a different explicit Main.
- Main Recipe drives the Dish Detail Recipe section and the Cook Again suggestion (§7.2). It **never** establishes that any cook used it.

### 3.3 Automatic vs suggested association

| Situation | Behavior |
| --- | --- |
| Rank My Version / Cook Again *from a Recipe* | **Automatic:** reserves the exact revision, creates the Recipe-used snapshot, fills a vacant exact link (Codex trigger), and adds a Dish Recipe row (Main if the Dish had none) |
| Add Recipe (Import / Create Manually) from a Dish or cook | **Automatic:** creates a Dish Recipe; also creates the exact link when started from a cook. Creation and association are one atomic call |
| Link Existing from a Dish, or Link a Dish from a Recipe | **Automatic:** this is an explicit user act. It creates a Dish Recipe (plus an exact link if the user picked a cook). It never creates a Recipe-used snapshot |
| Cook Again on a Dish that has a Main Recipe | **Suggest:** "Cook from [Main Recipe]" or "Without a Recipe". Nothing is preselected and nothing is recorded as used unless the user chooses the Recipe |
| Rank My Version on a Recipe related to one Dish only through a legacy or Dish-level link | **Suggest:** add the cook to that Dish (default highlighted) or start a new Dish |
| Recipe related to several Dishes | **Ask** which Dish |
| New Dish whose name matches a Recipe-only Dish or an unlinked owned Recipe | **Suggest:** "Link [Recipe]?" Dismissing the suggestion leaves both separate |
| Two Dishes with similar names | Never merged. A Dish merge is not part of V1 |

Rules: never infer use from title, photo or fuzzy match. Never move a cook between Dishes implicitly. Foreign Recipes (a Sous Chef's, or post-V1 Saved) can be used and suggested, but are never made owned or delegated.

### 3.4 D1 implementation (deployed November 8)

- **Store:** `staygrubby.dish_recipe_links`, owner-private, RLS with no client grants, cascades from the Dish and the Recipe. Legacy `dish_recipes` rows were copied once (not marked Main) and stay unchanged. A trigger mirrors legacy attach/detach from existing app builds.
- **Automatic association:** `associate_dish_recipe` (advisory-locked per Dish) runs when an exact cook link is inserted and when a Recipe-origin reservation completes (Codex lifecycle). The first Recipe of a Dish with no other related Recipe becomes the chosen Main.
- **Actions** on `api.recipes`: `dish_recipes` (read), `link_dish_recipe`, `unlink_dish_recipe` (also removes the legacy row, never cook links or used snapshots), `set_main_recipe` (compare-and-swap on `expectedMainID`, null clears the choice). Each returns the Dish's related Recipes with `mainRecipeID`, `chosenMainRecipeID`, and per Recipe `dishLinked`, `legacy`, `linkedAttemptIDs`, `usedByAttemptIDs`. A revoked Recipe drops out of the list; its frozen snapshot remains in provenance.
- **App:** `DishRecipeSet` decodes the response; `RecipeAssociation` encodes §3.3 (explicit → automatic, one related Dish → suggest, several → ask, none → new Dish; Cook Again offers Main first and preselects nothing). D2 and F call them once the migration is deployed.

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
| Changing a cook's name | — | **Rename** (Dish Detail cook row overflow, plus the Cook Name field in Edit Cook) | — |

"Version" remains only inside the fallback name "Version N" and the Rank My Version action.

### 4.2 Naming behavior (Decided; for the rebranding stage)

- **Storage is unchanged.** The name *is* the existing `versionTitle` (SwiftData) / `version_title` (Supabase, ≤200 characters, synced). Don't rename the stored property: renaming a SwiftData attribute is a migration with no benefit. Add a `cookName` accessor if it helps readability.
- **Normalization:** `CookName.normalized` trims, collapses internal whitespace runs and bounds the name at 200 characters (`CookingDraft.cleanTitle` uses it). An empty name becomes nil and returns to the fallback. Names are not unique: two "Spicy" cooks are allowed, because identity is the UUID.
- **Display name** = custom name, else "Version N", where N = the stored `sequenceNumber`. That number is stable, so it is never renumbered after deletion, and a gap such as "Version 1, Version 3" is acceptable and honest. A lone unnamed cook shows **no** label (existing meaningful-label rule). Once a second cook exists, an unnamed first cook shows "Version 1". Legacy imports follow the same rule.
- **Ranking independence:**
  - Comparisons, assessments, reactions, unlock eligibility, Recipe-used snapshots and links all key on `CookingAttempt.id` / `RankedItem.id`, never on the name.
  - `RankedItem.name` is a display cache of `displayName`. `CookingStore.rename` refreshes it for that cook; creating or deleting a cook refreshes siblings whose fallback visibility changes (a lone first cook caches "Dish", then "Dish — Version 1" once a second cook exists). Strengths, uncertainty and evidence are never touched (`CookNameTests`).
  - Rename is an ordinary metadata edit staged as `editCook` through the outbox. It never starts a re-rank and never posts.
- **Snapshots stay snapshots:** published posts and rank-at-sharing records keep the name they were shared with. Recipe-used content is untouched. Search matches the current display name (custom or fallback).
- **Where names appear:** Grub Rank rows, Dish Detail cook list, the comparison screen (Dish + name), the result screen, the Cook Again chooser, the Link a Dish picker, share cards and the composer (per their existing snapshot rules), and accessibility labels ("Spicy Version, cook of Chili").
- **Suggested names:** none. The field is labelled "Cook Name (optional)"; when the cook would show a fallback, a hint below reads "Leave blank to show Version 3." Rename (cook overflow and a Cooks row context action) uses the fallback as its placeholder. No date- or Recipe-derived automatic names, because they would read as the user's choice.

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
| Rows | Ranked **cooks**: by default one per Dish (top cook), or every cook with All Cooks | **Recipes**: one card per Recipe UUID, showing its Dish when related |
| Includes | Dishes with ≥1 ranked cook | Owned Recipes (Recipe-only Dishes and Recipes of cooked Dishes); post-V1 Saved Recipes and Want to Cook |
| Excludes | Recipe-only Dishes | Cooked Dishes without a Recipe (owner decision 3) |
| Order | Global Bradley–Terry order (frozen) plus read-only Sort | Recently Updated / Newest / Oldest / A–Z / Z–A |
| Opens | Dish Detail, with the tapped cook selected | Dish Detail with that Recipe selected; a Recipe-only Dish opens the Dish Detail "not cooked yet" state |

A Recipe related to several Dishes appears once in Food Bible. Its card names the Main-Recipe Dish first, otherwise the Dish of its exact-linked cook, otherwise the first by name.

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
| Cooked / Not cooked yet | — | **Decided:** toggle in Food Bible, derived from relationships with no new data |
| Photo | ✗ removed | ✗ removed |

Grub Rank keeps its four direct chips. Food Bible has six groups and keeps the single Filters sheet (UI_ARCHITECTURE 5.4 rule).

## 7. Contextual flows

### 7.1 One Add Recipe flow — `AddRecipeFlow(context:)`

| Choice | Meaning | Shown |
| --- | --- | --- |
| **Import Recipe** | Outside text → Gemini (contract 4) → editable `RecipeDraft` → review → explicit Save. Paste is the V1 source; Scan and Share Sheet are post-V1 sources of the same pipeline | Always |
| **Create Manually** | Empty draft → the same editor | Always |
| **Link Existing** | Choose an owned Recipe in the photographic picker | Dish or cook context only |

| Context | Started from | Result (associations per §3.3) |
| --- | --- | --- |
| `.library` | Food Bible + | Recipe-only Dish |
| `.dish(dishID)` | Dish Detail "Add Recipe" | Dish Recipe (Main if first) |
| `.cook(attemptID)` | Cook row / Edit Cook | Dish Recipe plus an exact link to that cook |

This replaces today's three divergent entry points: Food Bible Paste/Add Manually, the Dish Recipe section Add/Link, and the Recipe overflow Link a Dish. **Link a Dish** stays as the reverse entry from a Recipe and uses the same picker. External-AI consent, the burst guard, cooldown-to-manual, the 40 KB bound and Recipe Creator behavior are unchanged; only the "Paste Recipe" label and grouping change.

### 7.2 Cook Again and Rank My Version

Both start the same new-cook flow and differ only in their starting point:

- **Cook Again** (from Dish Detail or a Grub Rank row) starts a new cook of *this* Dish. If the Dish has related Recipes, the first step offers "Cook from [Main Recipe]", "Choose another Recipe" or "Without a Recipe" (§3.3). Choosing a Recipe makes it a Recipe-origin cook with exact revision reservation.
- **Rank My Version** (from a Recipe) starts a Recipe-origin cook of *this* Recipe. The destination Dish follows §3.3: automatic when explicit, suggested when loose, asked when several Dishes are related, and a new Dish (prefilled from the Recipe, editable) for a Recipe-only Dish.
- Both end in the unchanged protected flow: Initial Reaction → comparisons → result.

### 7.3 Editors

`CookEditor` (New Dish, Cook Again, Rank My Version, Edit Cook) groups fields by owner so scope is visible without moving data:

- **About this Dish:** name, Cuisine, Source, Public Description, Private Notes, default Course. The editor states that changes apply to every cook.
- **This cook:** Cook Name, date, photos, cook notes, Course, Diet, Certification, Contains, Tag a Sous Chef.

## 8. Reusable Dish UI parts

Each part owns one record and is built by generalizing existing components (AGENTS Reuse Before Reinvention). An empty side renders as one quiet action, never as an empty section.

| Part | Built from | Used by |
| --- | --- | --- |
| `DishIdentityHeader` — hero, name, food metadata, top score | `SGHeroMedia`, `SGScore`, `TagChip`, `SourceSummary` | Dish Detail |
| `DishCooksSection` — cooks with name, rank, gated score, date; Rename; Cook Again | `RankedDishRow`, `CookVersionIdentity`, `sgPhotoFrame(.compactThumbnail)` | Dish Detail |
| `DishRecipesSection` — Main Recipe preview, other related Recipes, Set as Main, Add Recipe; "Recipe used" vs "Linked Recipe" per cook | `DishRecipeSection` (generalized), `RecipePhoto`, `RecipeReadingBody` | Dish Detail, cook detail |
| `CookName` — display-name resolver plus the Rename field | `CookingAttempt.meaningfulVersionLabel` (generalized) | Every place in §4.2 |
| `DishRow` / `RecipeCard` | `RankedDishRow`, Food Bible card (`.cookbook`) | Grub Rank, Food Bible, pickers, post-V1 Saved/Collections |
| `DishPicker` (Dish / cook / Recipe modes) | `DishSelectionView`, `CookVersionSelectionView`, `SGSearchField` | Link Existing, Link a Dish, Cook Again Recipe choice, post-V1 Collections |
| `AddRecipeFlow(context:)` | `RecipeCreationChoice`, `RecipeImportView`, `RecipeEditor` | §7.1 |
| `CookEditor` | `CookingMetadataForm`, `CookingDetailsSheet`, `SGOptionSheet`, `SGFormSection` | §7.3 |
| `DishActions` — Share / Post to Grub List / Cook Again / Rank My Version / overflow (Rename, Recipe History, 86) | `SocialLinkShareAction`, overflow menus | Dish Detail, Recipe reader; the Stage C sharing model plugs in here |

## 9. Evidence preserved for Personal Cooking Intelligence

- **Cooked, known and intended stay separate:** cooks, Recipes, and post-V1 Saved / Want to Cook. A Recipe-only Dish is never counted as cooked.
- **As written vs as made** (Diet and Contains on both sides) is stored separately. The difference itself shows substitutions.
- **Used vs linked vs Main:** only `recipe_cooks` means "cooked from this revision". Main Recipe is a preference, and a Dish Recipe is an association.
- **Dated reactions** (Codex) record *when* evaluations happened. Cook names are user labels, not evidence, and are never interpreted.
- **Food-level fields are current state.** Renaming a Dish or changing its Cuisine applies to every cook (known limit). Capture an "as cooked" value going forward only if a real feature needs it.
- **Context** (Collection, shared cook, Recipe origin) stays an explicit relationship.

## 10. Future compatibility (post-V1; nothing here is authorized)

| Feature | Fit |
| --- | --- |
| **Saved Recipes** | An owner-private, revocable bookmark to a Sous Chef's Recipe, shown in a Food Bible "Saved" segment. Rank My Version on it creates an owned cook with creator credit, never a copy or an owned link. Save a Private Copy stays a separate explicit action |
| **Want to Cook** | An intention targeting a Dish (cooked or Recipe-only) or a Recipe, resolved by a later cook. This is the first trigger to decide between a stored Food identity and a tagged `(dish_id \| recipe_id)` target. The dormant `recipe_tickets` covers Recipes only |
| **Collections** | Collection ↔ Dish many-to-many, where members may be Recipe-only. Same target decision |
| **Contextual rank boards** | A filtered projection of the **one** global ranking (Collection, Cuisine, shared cooking). Never a separate fit, evidence set or manual order. Whether a board shows board-relative positions is an owner decision for that feature |
| **Scan Recipe / Share Sheet** | Extra Import Recipe sources (on-device text recognition; an authenticated app-group handoff). Same Gemini → review → Save path; disclosure covers photo-derived text |
| **Discover / statistics** | Counts only explicit cooks and used snapshots per the audit's definitions |

## 11. Per-cycle architecture check

- **A. Requirements:** final Dish/Recipe/cook terminology, data behavior and implementation order.
- **B. Existing data reuse:** cook naming reuses `versionTitle`; the Food read model reuses existing records; Codex lifecycle triggers handle exact association.
- **C. Intelligence value:** as-written/as-made Diet and Contains plus Main-vs-used distinctions improve future signals; names stay labels, not evidence.
- **D. New data justified now:** two additions, both required by owner decisions — `dish_recipe_links` (several Recipes per Dish plus Main) and an optional Recipe Diet content key. No Food table.
- **E. Privacy:** Dish Recipe links are owner-private like current links. Recipe Diet follows Recipe audience and revision pinning. Certification never leaves the cook. Snapshots are unchanged.
- **F. Scalability:** Dish composition is bounded by `library_index` pages and the local store; relationship reads are per Dish.
- **G. Documentation and tests:** canonical docs updated here. Implementation needs migration/RLS tests, `CookingStore` rename-invariance tests (evidence, strengths and IDs unchanged) and UI tests for the copy changes.

## 12. Still open (decide in the named stage, not blocking)

- Board-relative positions on future contextual rank boards (post-V1 feature).
- Whether to also show the Main Recipe on Grub Rank rows (D2, presentation only).
- Recipe reservation expiry and snapshot retention after explicit cook deletion (privacy decision, carried from the audit; V1 release gate).
