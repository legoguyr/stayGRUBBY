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
| 12 | **One canonical Dish universe** (Nov 9). Grub Rank and Food Bible are interface lenses over one set of Dishes, never separate Dish and Recipe databases. A Dish may hold Recipe data, cooks/ranking data, both, or (transiently) neither. When two identities turn out to be the same real-world Dish, they are **combined into one** (§3.4), never merely linked | §2, §3.4 |
| 13 | **Recipe Diet is suggested from ingredient evidence** when a Recipe is imported/organized (Nov 9; supersedes "author-set only"): Vegan / Vegetarian / Dairy-Free / Gluten-Free only when the ingredients clearly support it; never Kosher or Halal; always editable | §5 |
| 14 | **Grub Rank filters: Course and Cuisine** (plus Search, Sort, All Cooks). Food Bible keeps the deeper Recipe filters. Both use the same LEGO filter components and one clear X for search + filters | §6.1 |
| 11 | **Dish and Recipe are two views of the same Dish identity** (like one post surfacing in different feeds). The user never manages a Dish↔Recipe relationship. Creating a Recipe in Food Bible creates its Dish; adding a Recipe from a Dish writes that Dish's Recipe side; Grub Rank and Food Bible show the same Dish. Dish Detail shows "View Recipe", not a second copy of the Dish. No standalone Rename; no Main Recipe workflow in V1. The Pass shows Dish/cook activity only | §2, §3, §6, §8 |

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

### 3.3a Saved Recipes are references, never copies (Connected UI Phase 1)

Food Bible has **My Recipes** (owned, including any copies made before November 15, 2026) and **Saved Recipes** (another Sous Chef's Recipe bookmarked through the private `recipe_tickets` relation). A save stores only the reference: the creator keeps ownership and credit, nothing is copied, and every read rechecks access. Unsharing, blocking or leaving Sous Chefs shows *Recipe unavailable* with Remove; deletion removes the save (backend test `saved-recipes.test.mjs`). The new UI no longer offers *Save a Private Copy* (reader) or the shared-post copy; the post reader's *Open Recipe to Save* opens the current Recipe instead. The `fork`/`fork_post` RPCs and existing copies stay for compatibility with supported clients.

### 3.4 One canonical Dish universe — combining identities (owner decision 12)

**Rule.** There is one Dish universe per account. A real-world Dish has exactly one Dish identity; its Recipe (as written), cooks (as made), ranking evidence, photos and future sharing/intelligence all hang off that one identity. Grub Rank shows the Dishes that have cooks; Food Bible shows the Dishes that have Recipe content; the same Dish appears in both when it has both.

**Audit (Nov 9).** Two independent paths can create two identities for one real-world Dish: a Recipe created in Food Bible (Dish A, possibly ranked with Rank Now) and the same Dish ranked separately in Grub Rank (Dish B). The D3/F implementation already moved an *uncooked* Recipe's identity onto B (true reconciliation, not a link), but it (a) refused Recipes whose Dish A had cooks — leaving two identities — and (b) dropped A's Dish-level text. Both are fixed:

- **Combine** (Dish Detail → Add Recipe → Use a Food Bible Recipe, offered for any owned Recipe on another Dish): `set_dish` moves the Recipe to B's identity (content and Recipe History unchanged), then `DishIdentityStore.combine(A, into: B)` runs as one synced edit:
  - A's cooks move to B with their **IDs, ranked items, comparisons, assessments, photos, tags, cook notes, cooked dates and Recipe-used snapshots unchanged** (all evidence keys on cook / ranked-item / Recipe IDs, never on the Dish). They take B's next free sequence numbers, so only "Version N" fallback labels change. Global ranking order and scores never change.
  - A's Dish text fills B's empty fields (description, Cuisine, Source); conflicting Private Notes are appended; a conflicting Source is kept as an "Also from:" note. Nothing the user wrote is dropped.
  - A is deleted (synced tombstone). Nothing else referenced A: posts, shared-cooking events, reactions and provenance reference cooks, ranked items or Recipes.
- **Not combined automatically:** similar names, or two Dishes the user never said are the same. Combining is always an explicit user act.
- **Evidence for Personal Cooking Intelligence:** after combining, remake counts (cooks per Dish ID), taste/flavor preferences (ranked items + dated reactions), Course/Cuisine/ingredient preferences (Dish + cook snapshots + Recipe content), Recipe effectiveness (`recipe_cooks` revision → cook outcome), cooking improvement over time (cook dates per Dish), Discover recommendations and estimated cooking ability all read one consistent Dish identity. No merge alias table is stored: nothing outside the account graph referenced the removed identity, and the cooks themselves carry the history.

### 3.5 Integrity rules and repair (November 18, 2026)

**Root cause of "one Recipe on several risottos" (owner report).** Read-only audit of the hosted project: every owned Recipe has a Dish identity, the one legacy family link agrees with it, and no cook link or completed Recipe cook points at another Dish's Recipe. The owner's live "Risotto" Dish holds three cooks — *Butternut Squash*, *Mushroom*, *Pea and mahi mahi* — and one Recipe, *Butternut Squash Risotto*. Different dishes were logged as cooks (Cook Again) of one Dish, so that Dish's Recipe correctly appeared for all of them. Separately, three transitional server paths could attach a Recipe to the wrong Dish (`recipes dish` legacy fallback, `share_options` legacy step, legacy-link writes on `complete`/`attach`); none had affected hosted data.

**Rules (enforced).**
- A Dish shows only the owned Recipe whose `dish_id` is that Dish. Titles, tags, cuisine, source, ingredients and legacy family links never create or display an association.
- A Recipe moves to another Dish only through an explicit act (Add Recipe → Use a Food Bible Recipe, which combines the two Dishes, §3.4); `set_dish` on a Dish that already has a Recipe is refused (`PT409`).
- Composer Recipe for a cook: the cook's exact snapshot (`recipe_cooks`), its exact link, then its Dish's own Recipe.
- **Separate Cooks** (`SeparateCooksSheet`, Dish page and ⋯; Nov 18 revision): lists every cook of the Dish, marks the cook made from its Recipe, and lets the owner separate any cooks into new Dishes, rename the Dish that stays, and optionally put them all in one folder. Each move uses `DishIdentityStore.move`, the explicit repair when a cook belongs to a different Dish. The cook keeps its ID, ranked item, comparisons, photos, tags, notes, cooked date and Recipe-used provenance; the new Dish takes its course and the original Dish's Cuisine; Dish text, the Recipe and earlier posts stay with the original Dish. It can also join an existing Dish. Ranking order and scores never change. The original Dish always keeps at least one cook (an only cook is renamed in Edit Cook instead).
- Edit Cook's Dish name renames the Dish for **all** its cooks; with several cooks it now says so and points to Separate Cooks (the owner's risotto was renamed this way).
- **Grub Rank All Dishes** lists one row per Dish at its best cook, numbered by Dish position; **Folders** (gated) lists folders. Recipe → Dish navigation resolves by Dish ID and leads with the Recipe's own cook.
- Rank a Dish never merges by name: when the typed name matches a ranked Dish, the form offers *Add Another Cook of …*; otherwise a new Dish is created.
- Server migration `20261118160000_dish_recipe_integrity` (pending deployment; PGlite-tested): removes the legacy fallbacks above, skips new legacy links that disagree with identity, and gives a Dish only to a Recipe whose single legacy link proves it. Ambiguous cases stay unassigned for explicit linking. No row is deleted.

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

**Superseded November 18, 2026 (owner decision):** Grub Rank always lists every ranked cook at its true global rank; the Top / All Cooks toggle is removed and the stored `RankingsDisplayMode` preference is no longer read (raw values kept harmlessly). Dish Detail's Cooks section is unchanged. The text below is historical.


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
| **Dietary — Diet** (Dairy-Free, Gluten-Free, Vegan, Vegetarian) | — | **Implemented (Stage F)** `dietary` in `RecipeContent`: author-selected only | ✅ existing | The Recipe value says the Recipe *as written* fits that diet; the cook value says what was actually made |
| **Dietary — Certification** (Halal, Kosher) | — | **Never** on a Recipe | ✅ existing | Certification depends on products, supervision and kitchen. It is a fact about the cook, so it is never inferred and never attached to written instructions |
| Photos | — | Recipe photo | cook photos | Ownership unchanged |

**Recipe Diet field rules:**

- It is an additive optional key in the Recipe content JSON. It is part of revisions and post pinning like every other content field.
- **Suggested from ingredients (owner decision 13, supersedes "author-set only"):** when a Recipe is imported/organized, `RecipeDietInference` (deterministic, beside the allergen assessment; Recipe Creator contract 4 is unchanged) suggests Vegetarian (no meat, fish, gelatin or unclear stock/rennet cheese), Vegan (also no dairy, egg or honey), Dairy-Free (no dairy; plant milks allowed) and Gluten-Free (no gluten grains and nothing unclear such as plain flour, soy sauce, oats, stock or seasoning blends). Unknown stays unknown, Kosher/Halal are never inferred, the import review says so, and the author can change it in the editor.
- D1 found the server previously **dropped unknown content keys silently**; `20261108171120_dish_recipe_links` accepts `dietary` additively (unique codes from `dairyFree`, `glutenFree`, `vegan`, `vegetarian`; stored sorted; Halal/Kosher rejected). **Stage F:** the Recipe editor's *Details & source* has a **Diet** row (Diet-only `DietarySelector`, with a note that product labels matter and Certification belongs to the cook); the reader shows "Diet as written"; `20261109002508_food_bible_diet_index` adds `dietary` to Food Bible index entries for the Diet filter.

**Cooking from a Recipe (prefill, user-confirmed):**

- The cook's Diet and Contains may be *preselected* from the Recipe's author-selected Diet and reviewed Contains. The user sees and confirms them. Possible is never prefilled, and Certification is never prefilled.
- After a cook is saved, editing the Recipe never changes it, and editing the cook never changes the Recipe.

## 6. Two lenses over one library

| | Grub Rank | Food Bible |
| --- | --- | --- |
| Question | What have I cooked, and how did it rank? | How do I make things? |
| Rows | Every ranked **cook** at its global rank (Nov 18: no Top / All Cooks toggle) | **Dishes with Recipe content**: one card per Dish (its name, the Recipe title when different) |
| Includes | Dishes with ≥1 ranked cook | Owned Dishes with a Recipe (cooked or not cooked yet) and authorized Sous Chef Recipes; post-V1 Saved Recipes and Want to Cook |
| Excludes | Recipe-only Dishes | Cooked Dishes without a Recipe (owner decision 3) |
| Order | Global Bradley–Terry order (frozen) plus read-only Sort | Recently Updated / Newest / Oldest / A–Z / Z–A |
| Opens | Dish Detail, with the tapped cook selected (its cook face) | The same Dish's Recipe face: the Recipe reader for that Recipe, carrying the Dish's Cooks section; a Recipe-only Dish shows "Not cooked yet" (§8.1) |

Both lenses show the same Dish identity: a Dish with cooks and a Recipe appears in both, and 86ing in one view never orphans the other (§3.2).

### 6.1 Filters per lens

Filters read the record the lens lists, use the Stage B chip/sheet grammar, and never write data, renumber or create another ranking.

| Filter | Grub Rank (as made) | Food Bible (as written) |
| --- | --- | --- |
| Search | ✅ (Dish, cook display name, Course, Dietary, Contains) | ✅ Recipe text and Dish name |
| Course | ✅ cook snapshot | ✅ |
| Cuisine | ✅ Dish | ✅ |
| Dietary | — (removed Nov 9; Food Bible owns diet depth) | ✅ "Diet" group (as written; any selected diet matches). No Certification |
| Avoid | — (removed Nov 9) | ✅ Contains + Possible |
| Contains | — (Avoid covers it) | ✅ |
| Source | — | ✅ |
| Cooked / Not cooked yet | — | **Implemented (D2):** a "Cooked" group in the Filters sheet (Cooked, Not cooked yet), derived from relationships with no new data |
| Photo | ✗ removed | ✗ removed |

**Shared components (Nov 9):** both lenses use direct `SGFilterChip`s that open one group in `SGFilterGroupSheet` / `SGFilterGroupPage` (option rows `SGSelectionRow`, `DietaryChoices`, `SGAllergenChoices`), `SGBrowseSortMenu`, and one `SGIconButton` X that appears while search or any filter is active and clears both. Grub Rank: Course · Cuisine. Food Bible: Course · Cuisine · Diet · Cooked, then Contains · Avoid · Source.

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

- **Cook Again** (Dish Detail or Grub Rank, `CookAgainFlow`) starts a new cook of *this* Dish. **Implemented (Stage F):** when the Dish has a Recipe, the first step offers **Cook from the Recipe** (a Recipe-origin cook with exact revision reservation; the cook stays on this Dish and keeps its name) or **Without the Recipe**. Nothing is preselected or recorded as used unless chosen. Offline or without a Recipe, it goes straight to the cook form, which then offers "Add a Recipe?".
- **Rank My Version** (from a Recipe) starts a Recipe-origin cook that goes into the Recipe's own Dish (§3.2). A Sous Chef's Recipe starts a new Dish of the viewer's.
- Both end in the unchanged protected flow: Initial Reaction → comparisons → result.

### 7.3 Editors

**Implemented (Stage F)** in the shared cook form (`CookingMetadataForm` + `CookingDetailsSheet`, used by New Dish, Cook Again, Rank My Version and Edit Cook), grouped by owner with `SGFormSection` so scope is visible without moving data:

- **This Dish:** name, Public Description, Private Notes; in Details, Cuisine and Source. The form states these apply to every cook (inherited as read-only in Cook Again's Details).
- **This cook:** Cook Name (fallback hint), date, Details (Course, Diet, Certification, Contains — "as made"), then Tag a Sous Chef and sharing. The hero photo stays first.
- **Prefill from a Recipe:** a Recipe-origin cook preselects Diet (as written) and the Recipe's reviewed Contains, never Possible or Certification, and the form says so ("check them in Details for what you actually made").

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

### 8.1 The Dish page — Dish & Ranking and Recipe tabs (current, Connected UI Phase 1, November 15, 2026)

- **One canonical Dish page** (`DishView`; `AttemptDetailView` is the compatibility entry for every cook route). A shared header shows the hero photo, Dish name, score and global rank. The header photo is fixed for the page; switching tabs never changes it (MVP stabilization, November 16, 2026):
  - **Opened from a cook:** that cook's photo.
  - **Otherwise:** the Recipe's own photo, else the Dish's representative cook photo. This is the same rule as the Dish's Food Bible card, so the card and the page match.
  - **Recipe photo unavailable:** falls back to the Dish's cook photo, never an empty frame.

  Every option references one stored asset, never a copy. Beside score and rank, the header shows the noninteractive **Cooked N times**, the verified count of the Dish's Cooking Attempts. A native segmented control switches **Dish & Ranking** and **Recipe**. Both tabs read state the page already holds: the Dish's Recipe (`recipes dish`) is shown from the account read cache when known and refreshed in the background only when stale, on refresh or after a change, so switching is immediate and makes no request. The toolbar follows the tab: `DishActions` and Share on Dish & Ranking, Recipe sharing and owner management on Recipe.
- **Dish & Ranking:** cook metadata, Dish text, a one-row Recipe preview (*View Recipe* with the Recipe title when it differs, time, yield and ingredient count; it switches tabs. *Add Recipe* opens `AddRecipeFlow`), the exact "Recipe used for this cook · revision N" when it differs, provenance, Source, Personal Notes and every cook with Cook Again. A Recipe-only Dish shows *Not ranked yet* with Rank My Version.
- **Recipe:** the shared reader (`RecipeReaderContent`, the same component as the standalone `RecipeDetailView`) without repeating the header; ingredients, steps, serving scaling, attribution, revision and visibility, Rank My Version, and no separate Makes line: the cook count lives in the shared header. No Recipe yet: **Link a Recipe** (`AddRecipeFlow`).
- **Routes:** Grub Rank rows, My Kitchen and cook lists open the Dish page on Dish & Ranking. A Food Bible card for an owned Recipe whose Dish is on the device opens it on Recipe; otherwise the standalone reader, which offers *Open [Dish]* for an owner's Recipe with a local Dish. Other creators' Recipes, Saved Recipes, deep links and The Pass's post Recipes use the standalone reader, which checks live access.
- **The Pass** (formerly Grub List) shows intentionally posted cooks only. Recipe-only activity (`recipe_created`) is never shown and the client no longer models it (`PassPage`); a cook post can still offer its Recipe.
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
| **Collections** | **Built as Smart Collections (§10.1), gated** |
| **Contextual rank boards** | A filtered projection of the **one** global ranking (Collection, Cuisine, shared cooking). Never a separate fit, evidence set or manual order. Whether a board shows board-relative positions is an owner decision for that feature |
| **Scan Recipe / Share Sheet** | Extra Import Recipe sources (on-device text recognition; an authenticated app-group handoff). Same Gemini → review → Save path; disclosure covers photo-derived text |
| **Discover / statistics / remake counts** | Count explicit cooks per Dish ID and used snapshots per the audit's definitions |
| **Dish sharing** | Shares one Dish ID: its cooks (per existing post rules) and, when shared, its Recipe |
| **Aggregate score and "made by N people"** (owner idea, not built) | A shared Recipe/Dish page may later show an aggregate score and how many people have made it. Dish IDs are private per account, so cross-person aggregation keys on the **shared Recipe UUID** and exact-use provenance (`recipe_cooks`), counting each person once, and only from cooks whose owners' sharing/consent allows it, with a minimum-count threshold. The score input is each person's displayed (gated) score for their best cook of that Recipe, never raw strengths or comparisons across people (rankings are personal and not comparable). Gated behind the `dish_aggregate_scores` feature flag (off); needs privacy/disclosure review before any UI |

### 10.1 Smart Collections (built November 18, 2026; gated `dish_collections`)

**Dishes are identities. Collections are organization. Cooks are attempts. Recipes are instructions.**
- A collection is a label in `Dish.collections` (`dishes.collections text[]`, ≤20 labels of ≤40 characters, case/diacritic-insensitive uniqueness). No folder table: membership, counts, photos and the ranked comparison are derived from Dishes and the one global ranking.
- A Dish may be in several collections; Recipe-only Dishes may be members. Collections never create, merge or copy a Dish, cook, Recipe, photo or ranking row, and never infer Recipe links. Course and Cuisine stay separate metadata.
- Membership belongs to the Dish. Add a Recipe offers it only once the Recipe's Dish exists (Food Bible Recipes always have one, §3.2), so no Dish is created just to hold a label.
- Rename/Delete Collection rewrite only labels, as one synced edit. Unchanged saves write nothing; browsing writes nothing.
- The collection page orders Dishes by their best Grub Rank cook, names that cook when the Dish has several, shows locked scores as locked and unranked Dishes last. It is a filtered presentation, not a new ranking; personal scores are never compared across people.
- Sync: the Dish row always sends `collections`; servers without the column ignore it, and an empty list equals an absent key in graph comparisons. The gate stays off until `20261118160100_dish_collections` is deployed, because an older server would drop labels and its restored graphs would disagree with the device.

## 11. Per-cycle architecture check (one-Dish identity)

- **A. Requirements:** one user-facing Dish across Grub Rank and Food Bible; no relationship management; exact cook provenance kept.
- **B. Reuse:** existing `dishes` rows and sync, `recipes`, `recipe_cooks`; one added column. No merged table.
- **C. Intelligence value:** a stable Dish ID ties Recipe revisions, cooks, remake counts and photos together.
- **D. New data justified:** `recipes.dish_id` (+ unique per owner). Nothing speculative.
- **E. Privacy:** Dish IDs are owner-private (cards expose `dishID` only to the owner); The Pass no longer shows Recipe-only activity.
- **F. Scalability:** one indexed column; per-entry lookups bounded by `library_index` pages.
- **G. Docs/tests:** this document, the architecture overview, roadmap, UI architecture, release gate; backend `dish-recipe-identity` test; app unit/UI tests.

## 12. Still open (decide in the named stage, not blocking)

- Board-relative positions on future contextual rank boards (post-V1 feature).
- ~~Whether to also show the Recipe on Grub Rank rows~~ — **decided: no.** Grub Rank rows stay cook-focused; View Recipe lives on Dish Detail.
- When to retire the transitional association tables (§3.3) — a later authorized cleanup (after `20261118160000` they no longer influence what a Dish shows).
- Recipe reservation expiry and snapshot retention after explicit cook deletion (privacy decision, carried from the audit; V1 release gate).
