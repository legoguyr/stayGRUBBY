# StayGrubby food architecture — one food identity, separate records

**Canonical domain document — established November 8, 2026 (Unified Food Architecture Checkpoint, before UI overhaul Stage C).** It owns how Dishes, Recipes and cooks relate, which lens shows what, the contextual Add Recipe flow and the reusable food UI parts. Current implementation is described in [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md); sequencing in the [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md); design-system rules in [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md); long-term signals in [PERSONAL_COOKING_INTELLIGENCE.md](PERSONAL_COOKING_INTELLIGENCE.md). Evidence base: [V1_DATA_FOUNDATION_AUDIT.md](V1_DATA_FOUNDATION_AUDIT.md) and the Build 4 source.

Status words follow the architecture file: **Implemented** · **Decided** (approved direction, not built) · **Proposed** (recommended here, needs owner confirmation) · **Post-V1**. This checkpoint changes **no schema, ranking, Recipe Creator or UI code**.

## 1. Decision

**Approved direction (owner):** a Dish and its Recipe become **one user-facing food identity**. The user should never have to understand that "the thing I cook and rank" and "how I make it" are stored differently.

**Architecture decision (this checkpoint):** unify in **presentation and navigation**, not in storage. The food identity is a **composed read model** over records that keep their own IDs, owners, sync paths and deletion rules:

| Layer | Record | Lives in | Why it stays separate |
| --- | --- | --- | --- |
| Food (composed) | *none stored* — `Food` read model | app, derived per view | One identity for the user without migrating offline cooking data into the online Recipe store or the reverse |
| Cooked side | `Dish` → `CookingAttempt` → `RankedItem` | SwiftData + private sync | Offline, account-scoped, owns frozen ranking evidence |
| Knowledge side | `Recipe` → `recipe_revisions` | Supabase (online only) | Server-owned UUID, audience, revisions, attribution, Sous Chef sharing |
| Bridges | `recipe_cook_links`, `recipe_cooks`, `dish_recipes` (legacy), `recipe_forks`, `post_recipes` | Supabase | Each records a *different* claim (current association, exact use, family, copy, publication); none may be merged into another |

**No `foods` table or root entity is created now.** Promote the composed Food to a stored identity only when a shipped feature must reference Recipe-only and cooked foods *uniformly and durably* — the first candidates are Collections and Want to Cook (section 8). That decision gets its own per-cycle architecture check, an additive migration and fingerprints.

**User-facing noun (Proposed):** keep **Dish** for the food identity ("New Dish", "86 Dish" stay valid). A Dish may have cooks, a Recipe, or both; a Recipe-only Dish reads as *not cooked yet*. "Food" is the internal term for the composed model so it never collides with the `Dish` entity in code or docs. Owner confirms the noun before Stage D copy.

## 2. Ownership — who owns what

| Owner | Owns | Never owns |
| --- | --- | --- |
| **Dish** (cooked-side identity) | Durable name, default Course, Cuisine, manual Source (inspiration), Public Description, Private Notes, the family of cooks | Score, instructions, Recipe audience |
| **CookingAttempt** (a cook; UI "version") | Cooked date, version title, per-cook notes, Course snapshot, Dietary/Certification and Contains *as actually made*, ordered photos, sequence, its RankedItem | Recipe content (only an immutable used-snapshot via `recipe_cooks`) |
| **RankedItem + Comparisons** | BT strength, uncertainty, evidence (frozen) | Anything food- or Recipe-shaped |
| **Recipe** | Title, description, components/ingredients/steps, exact quantities, yield/times with origins, Recipe Course/Cuisine, source/original creator, tips, Contains/Possible assessment, Recipe photo, audience, revisions | Cooks, scores, ranking, private cooking photos |

**Relationship rules (Implemented; restated as the contract the Food model reads):**

- One current exact link per cook and per Recipe (`recipe_cook_links`, owner-private, compare-and-swap). A link is a **deliberate association, not proof of use**.
- **Recipe used** = `recipe_cooks` immutable snapshot, created only by Rank My Version or the explicit association API. Never inferred from today's link, title, photo or fuzzy match.
- Legacy `dish_recipes` family links remain readable and display as "Linked Recipe", never as "used".
- Ordinary New Version never carries a Recipe origin; treating it as a Recipe cook would fabricate evidence.

### 2.1 Composing a Food

A `Food` is resolved, in this order, from authorized data only:

1. **Cooked food:** a `Dish` (with ≥1 active cook) plus its *related Recipes* — Recipes with a current exact link to any of its cooks, then legacy family links. Deduplicate by Recipe UUID.
2. **Recipe-only food:** an owned Recipe with no current link to an active cook and no family Dish.
3. A Recipe linked to cooks of **two different Dishes** appears as a related Recipe of both Foods (it is not split or copied). The Food Bible card resolves to the Dish of its exact-linked cook, else the family Dish, else Recipe-only — consistent with the `linkedAttemptID` / `dishID` that `library_index` already returns.

**Primary Recipe (Proposed, owner decision listed in section 10):** when a Dish has more than one related Recipe, derive the primary as the Recipe exact-linked to the Dish's highest-ranked cook, else the most recently updated related Recipe. Store no "default Recipe" field until users ask to choose one; a later explicit choice would be an additive Dish → Recipe preference, not a change to links.

**Display field resolution** (presentation only; never writes back, never overwrites the other record):

| Field | Food shows | Fallback |
| --- | --- | --- |
| Title | Dish name | Recipe title (Recipe-only) |
| Cover photo | Top cook's cover photo | Primary Recipe photo → `SGPhotoPlaceholder` |
| Description | Dish Public Description | Recipe description |
| Course / Cuisine | Dish values | Recipe values |
| Contains | Shown **per side** — cook "Contains" (as made) and Recipe "Contains/Possible" (as written) are labelled separately and never merged into one claim | — |
| Score / rank | Top cook (Top Version projection) | None for Recipe-only — never a placeholder score |

### 2.2 Metadata placement — resolves the Stage B ownership question

Stage B owner review asked whether metadata edited while ranking a cook belongs to the food or the cook. **Decision: storage placement is unchanged; editors must make the scope visible.**

| Field | Belongs to | Editor treatment (Stage F) |
| --- | --- | --- |
| Name, Cuisine, Source, Public Description, Private Notes | **Food** (Dish; already shared by every version) | "About this Dish" group; editing from any cook states that it applies to all cooks |
| Default Course | Food default | Same group; the cook keeps its own Course snapshot (unchanged) |
| Date, Version Title, Cook Notes, Photos, Sous Chef tags | **This cook** | "This cook" group |
| Dietary / Certification | **This cook** — what was actually made (a vegan version, a non-kosher kitchen) | "This cook". Never inferred; never promoted to the Recipe |
| Contains | **Both, separately** — cook = as made, Recipe = as written | "This cook". When cooking *from* a Recipe, the cook's Contains may be **pre-selected from the Recipe's reviewed Contains** for the user to confirm (presentation prefill, user-confirmed, no inference). Possible is never prefilled |
| Recipe Course / Cuisine / Source / creator | Recipe | Recipe editor only. When a Recipe-only food gets its first cook, the new Dish may be prefilled from the Recipe's Course/Cuisine (user-visible, editable) |

No new fields, no backfill and no relocation of stored values. Grub Rank keeps filtering cooks by cook values; Food Bible keeps filtering Recipes by Recipe values.

## 3. Two lenses, one library

Grub Rank and Food Bible are **lenses over the same Foods**. A Food with both cooks and a Recipe appears in both, and either lens opens the **same Food Detail** (Stage D).

| | Grub Rank | Food Bible |
| --- | --- | --- |
| Question it answers | What have I cooked, and how good was it? | How do I make things / what do I want to keep? |
| Unit of a row | A ranked **cook** (Top Version projection by default) | A **Food with a Recipe** (one card per Recipe UUID) |
| Includes | Foods with ≥1 ranked cook | Foods with a Recipe; post-V1 Saved Recipes and Want to Cook (section 8) |
| Excludes | Recipe-only foods (nothing to rank yet) | Cooked foods without a Recipe |
| Order | Global BT order (frozen) + read-only Sort | Recently Updated / Newest / Oldest / A–Z / Z–A |
| Destination | Food Detail, focused on the cook | Food Detail, focused on the Recipe |

**Decision:** Food Bible does **not** list every cooked Dish. "Everything I've cooked" is Grub Rank; showing Recipe-less Dishes in Food Bible would duplicate it and blur the lens. A cooked food enters Food Bible the moment a Recipe is added or linked (the contextual Add Recipe flow makes that one tap from Food Detail).

### 3.1 Filters per lens

Filters belong to the record the lens lists. Same `SGFilterChip` / `SGFilterSheet` grammar in both (UI_ARCHITECTURE 5.4).

| Filter | Grub Rank (cooks) | Food Bible (Recipes) | Note |
| --- | --- | --- | --- |
| Search | Dish name, version, Course, Dietary, Contains | Recipe text index | Implemented |
| Course | ✅ cook snapshot | ✅ Recipe Course | Implemented, multi-select |
| Cuisine | ✅ Dish Cuisine | ✅ Recipe Cuisine | Implemented, multi-select |
| Dietary / Certification | ✅ cook | — (Recipes have no Dietary field; do not add one) | Implemented |
| Avoid | ✅ cook Contains | ✅ Recipe Contains + Possible | Implemented; informational, never a guarantee |
| Contains | — (Avoid covers it for cooks) | ✅ | Implemented |
| Source | — (Proposed later as a fifth chip only if requested; it would move Grub Rank to the Filters-sheet rule) | ✅ | Implemented in Food Bible |
| Cooked / Not cooked yet | — | **Proposed (Stage D/E)**: a Food Bible toggle enabled by the Food model; reads existing links, adds no data | First filter that needs the unified view |
| Collection | Post-V1 contextual board (section 8) | Post-V1 | — |
| Photo | ✗ removed (owner decision Nov 7) | ✗ | — |

All filters stay presentation-only: they never write, never renumber Grub Rank and never create another ranking.

## 4. Versions, cooks and revisions

Three different "versions" exist and must stop sharing one word:

| Concept | Today's wording | Direction |
| --- | --- | --- |
| A ranked cook of a Dish | Version, New Version, Version Title, Top Version / All Versions, "Version N" | **Keep the model.** Every cook is its own ranked entry in the one global ranking (frozen). Food Detail lists them as the Dish's cooks with true global rank and gated score |
| Recipe revisions | "Version History" (Recipe overflow) | **Proposed:** rename to **Recipe History** (or "Edit History") so revisions never read as cooks. Restore still creates a new revision |
| Cooking from a Recipe | Rank My Version | **Keep** (approved vocabulary). Into an existing Food it adds a cook to that Dish; into a Recipe-only food it creates the Dish — see 4.1 |

The **Top Version / All Versions** projection stays (Stage B toggle, same stored preference). Proposed copy refinement for Stage D/G, owner decision: "All Versions" → "All Cooks" and "New Version" → "Cook Again" from Food Detail, while "New Version" remains valid utility wording until the owner decides. No stored title, sequence number or preference key changes.

### 4.1 Rank My Version in the unified model

| Recipe state | Result (Decided target; current behavior noted) |
| --- | --- |
| Exact-linked to a cook of Dish D | New cook of **D** with an exact Recipe-used snapshot. Current Build 4 can reuse the linked Dish; Stage F makes this the only path and explains it |
| Family-linked to Dish D only | Ask once: add to D, or start a new Dish. Never assume |
| Recipe-only | Creates the Dish (prefilled from the Recipe, editable), then the normal cook/rank flow; the Food keeps the same identity on screen before and after |
| Foreign Recipe (Sous Chef's or, post-V1, Saved) | New owned Dish/cook with pinned creator credit; the foreign Recipe is never copied or linked as owned |

This closes the queued UI defect "Rank My Version does not explain … that it creates a new Dish" by making the destination explicit, not by changing ranking.

## 5. One contextual Add Recipe flow

Today three entry points diverge: Food Bible **+** (Paste Recipe / Add Manually), Dish Detail Recipe section (Add Recipe / Link Existing Recipe) and Recipe Detail overflow (Link a Dish). **Decided:** one reusable flow, `AddRecipeFlow(context:)`, with the same three choices everywhere they make sense.

| Choice | Meaning | Shown when |
| --- | --- | --- |
| **Import Recipe** | Bring outside text in → Gemini (contract 4) → editable `RecipeDraft` → review → explicit Save. *Paste* is the V1 source; Scan and Share Sheet are post-V1 sources of the same pipeline | Always |
| **Create Manually** | Empty `RecipeDraft` → same editor → Save | Always |
| **Link Existing** | Choose an owned Recipe from Food Bible (same photographic picker style as the Dish/cook selector) | Only with a food/cook context |

| Context | Entry | After Save / Link |
| --- | --- | --- |
| `.library` | Food Bible + | Recipe-only Food |
| `.food(dishID)` | Food Detail "Add Recipe" | New Recipe + exact link to the Dish's chosen cook in one atomic call (existing API) |
| `.cook(attemptID)` | Cook detail | Same, to that cook |

The reverse **Link a Dish** (from a Recipe) stays and reuses the existing photographic Dish/cook selector (`DishSelectionView` / `CookVersionSelectionView`). External-AI first-use consent, the 3/min burst guard, provider cooldown → manual fallback and the 40 KB draft bound are unchanged. "Paste Recipe" → "Import Recipe" is a label/grouping change; the Edge Function contract and Recipe Creator behavior are frozen.

## 6. Reusable LEGO UI architecture

Build Food screens from parts that each own one record, composed by context — not per-screen copies. Candidates (names provisional; reuse existing components first per AGENTS Reuse Before Reinvention):

| Part | Built from (existing) | Used by |
| --- | --- | --- |
| `FoodIdentityHeader` — hero, title, food metadata, primary score | `SGHeroMedia`, `SGScore`, `TagChip`, `SourceSummary` | Food Detail (both lenses), Sous Chef views of shared food |
| `FoodCooksSection` — cooks with rank/score/date, Top/All | `RankedDishRow`, `CookVersionIdentity`, `sgPhotoFrame(.compactThumbnail)` | Food Detail |
| `FoodRecipeSection` — primary Recipe preview, "Recipe used" vs "Linked Recipe", other related Recipes, Add Recipe | `DishRecipeSection` (generalized), `RecipePhoto`, `RecipeReadingBody` | Food Detail, Cook detail |
| `FoodRow` / `FoodCard` | `RankedDishRow`, Food Bible card (`.cookbook`) | Grub Rank, Food Bible, pickers, post-V1 Saved/Collections |
| `FoodPicker` | `DishSelectionView`, `CookVersionSelectionView`, `SGSearchField` | Link Existing, Link a Dish, New Version, post-V1 Collections |
| `AddRecipeFlow(context:)` | `RecipeCreationChoice`, `RecipeImportView`, `RecipeEditor` | Section 5 |
| `CookEditor` with "About this Dish" / "This cook" groups | `CookingMetadataForm`, `CookingDetailsSheet`, `SGOptionSheet`, `SGFormSection` | New Dish, New Version, Edit Cook, Rank My Version |
| `FoodActions` — one action model (Share / Post to Grub List / Cook Again / Rank My Version / overflow 86) | `SocialLinkShareAction`, overflow menus | Food Detail, Recipe reader (Stage C share model plugs in here) |

Rules: a part reads only the record it owns plus the `Food` read model; parts never fetch each other's data; empty sides render as a single quiet action ("Add Recipe", "Rank My Version"), never as an empty section.

## 7. Preserved evidence for Personal Cooking Intelligence

The unified view must not erase the distinctions intelligence will need ([PCI §2](PERSONAL_COOKING_INTELLIGENCE.md#2-one-intelligence-layer-distinct-signals)):

- **Cooked vs known vs intended** stay separate records: cooks (Grub Rank), Recipes (Food Bible), post-V1 Saved and Want to Cook. A Recipe-only food is never counted as cooked; saving is never cooking.
- **As made vs as written:** cook Dietary/Contains and the Recipe assessment stay separately stored and labelled — the difference is itself signal (substitutions).
- **Used vs linked:** `recipe_cooks` snapshots remain the only "cooked from this revision" evidence; Food Detail labels them distinctly.
- **Food-level fields are current state.** Renaming a Dish or changing its Cuisine rewrites history for every cook (existing, known limit). If an "as cooked" history is ever needed, capture the smallest owner-confirmed value at cook time going forward ([audit](V1_DATA_FOUNDATION_AUDIT.md#post-v1-use-of-existing-evidence)); do not add it speculatively now.
- **Context** (Collection, shared cook, Recipe origin) stays an explicit relationship, so twelve egg Dishes in an egg project remain distinguishable from twelve independent choices.

Pre-V1 integrity items from the audit become the **Food Foundation** stage's backend scope, because Food Detail trusts links: (1) Recipe-used completion after cook sync + app loss before `recipes/complete`; (2) stale current links held by a deleted cook (delete → restore → relink / Rank My Version). Both reuse existing keys and guards; any migration or function change needs current-cycle Supabase authorization.

## 8. Future compatibility (all Post-V1 unless the roadmap says otherwise)

| Feature | How it fits | Trigger for new storage |
| --- | --- | --- |
| **Saved Recipes** | An owner-private, revocable bookmark to a Sous Chef's Recipe, shown in a Food Bible "Saved" segment as a foreign Food card. Cooking it = Rank My Version (foreign row in 4.1). Never a copy; Save a Private Copy stays a separate explicit action | Bookmark relation (account → Recipe) when built; respects revocation/deletion |
| **Want to Cook** | An intention targeting a Food (Dish *or* Recipe), resolved by a later cook | Needs a Dish-or-Recipe target. The dormant `recipe_tickets` covers Recipe targets only — this is the first candidate to justify a stored Food identity |
| **Collections / Cooking Series** | Collection ↔ Food many-to-many; members can be cooked or Recipe-only | Same target question; decide stored Food vs tagged (dishID / recipeID) membership in that cycle |
| **Contextual rank boards** | A Collection, Cuisine or shared-cooking context shown as a board: a filtered projection of the **one global ranking**. Never a separate fit, evidence set or manual order. Whether a board shows board-relative positions (1…n) or global ranks is an owner decision for that feature | None (projection) |
| **Scan Recipe** | Another Import Recipe source: on-device text recognition → the same Gemini pipeline → review. Disclosure must say photo-derived text is sent | None |
| **Share Sheet import** | Share Extension delivering text/URL into Import Recipe with the context `.library`; requires an authenticated app-group handoff, never a second auth path | None in the Recipe model |
| **Discover / Recipe statistics** | Reads Foods across lenses; counts only explicit cooks/snapshots per the audit definitions | Separate cycle |

Nothing here authorizes building these. They constrain today's work: keep Dish and Recipe identities independent and stable, keep the Food read model free of stored assumptions, and keep Add Recipe a context-parameterized flow.

## 9. Per-cycle architecture check (this checkpoint)

**A** Reconcile the approved one-food direction before Stage C. **B** Fully representable by existing Dish/Recipe/link records; composed, not stored. **C** Preserves cooked/known/intended, as-made/as-written and used/linked signals. **D** No new fields, tables or indexes justified now; stored Food deferred to Collections/Want to Cook. **E** No change to collection, visibility or consent; Food Detail must apply the same authorization as today's Dish and Recipe readers (a foreign Recipe never becomes owned data). **F** Composition is bounded by existing `library_index` pages plus the local store; no new aggregate. **G** This document plus architecture, roadmap, UI architecture, PCI, README and AGENTS doc roles updated; no tests change.

## 10. Owner decisions requested

1. User-facing noun for the unified identity stays **Dish** (recommended) — or a new word.
2. Primary Recipe when a Dish has several: derived rule in 2.1 (recommended) vs explicit user choice.
3. Food Bible excludes Recipe-less cooked Dishes (recommended) vs lists all foods.
4. Recipe "Version History" → **Recipe History**; "All Versions" → "All Cooks"; "New Version" → "Cook Again" (Proposed copy; can wait for Stage G).
5. Family-linked Rank My Version: ask each time (recommended) vs always add to the family Dish.
6. Contains prefill from a Recipe when cooking from it (user-confirmed) — accept for Stage F?
