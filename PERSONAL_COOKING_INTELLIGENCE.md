# Personal Cooking Intelligence — long-term direction and data inventory

**Canonical planning document — created November 7, 2026 at Build 4 (`c09c18e`).** Owner-approved **long-term direction**. **Nothing in this document is implemented except where the inventory below says so.** It does not authorize schema, AI, analytics or recommendation work. Sequencing lives in the [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md); current implementation in [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md).

## 1. Direction

StayGrubby should gradually become an intelligent, personalized cooking ecosystem that understands each user's cooking experiences, preferences, interests, abilities and relationships — grown from normal use, not a disconnected AI subsystem. Eventually it may help users understand their food preferences; find Recipes/Dishes they are likely to enjoy; discover ingredients, cuisines and techniques; see how their cooking changes; find inspiration from Sous Chefs; separate what they enjoy cooking from what they enjoy eating; find Recipes suited to their experience; revisit and improve past creations; plan shared cooking; and keep a meaningful history of everything they cook.

The core identity does not change: record, rank, remember, keep Recipes, share intentionally.

## 2. One intelligence layer, distinct signals

A future unified layer may draw on five dimensions. **They feed one recommendation ecosystem but are never interchangeable.**

| Dimension | Example signals |
| --- | --- |
| Cooking History | Dishes, cooks/versions, frequency, recency, repeat cooking, techniques, Recipe modifications, progression |
| Taste Preferences | Personal rankings, pairwise evidence, reactions, cuisine/ingredient/flavor/texture/method patterns, explicit likes/dislikes, inferred preferences with confidence |
| Cooking Interests | Saved Recipes, Want to Cook, explored Dishes, cuisines/ingredients/techniques to try, Sous Chef inspiration |
| Cooking Ability / Experience | Technique experience, ingredient familiarity, Recipe complexity, demonstrated experience, optional self-report |
| Social Intelligence | Sous Chef relationships, shared interests, Recipe interactions, recreations, voluntarily shared group preferences |

Non-equivalences to preserve: liking a Dish ≠ enjoying cooking it; skill at making something ≠ liking it; saving a Recipe ≠ cooking it; a high Dish rank ≠ every ingredient preferred; cooking frequently ≠ favorite; **frequency ≠ skill**; personal Dish score ≠ community Recipe quality.

Every future signal should be classifiable as **explicit preference**, **observed behavior**, **inferred preference**, with **confidence/uncertainty** and the **context** of the observation (e.g. a Collection/project, a shared cook, a Recipe-origin cook). Users should eventually be able to inspect and correct inaccurate assumptions.

## 3. Per-cycle architecture checklist (permanent)

Personal Cooking Intelligence is **not** one giant future project. During every meaningful development cycle, briefly evaluate (also in AGENTS.md):

- **A. Current requirements** — what are we actually building or fixing?
- **B. Existing data reuse** — can existing structures represent it?
- **C. Future intelligence value** — does normal use naturally create a useful signal?
- **D. Data architecture** — are new fields/relationships/indexes/history genuinely justified now?
- **E. Privacy/legal** — does it change collection, processing, visibility, retention or consent?
- **F. Scalability** — will it stay maintainable as usage grows?
- **G. Documentation** — which canonical docs/tests change?

Principles: working functionality before speculative infrastructure; capture structured data naturally without extra user effort; preserve useful history where justified; modular and backward compatible; reuse existing infrastructure; incremental, migration-tested schema evolution; no expensive AI without demonstrated value; privacy and integrity first; never delay release-critical work. **Do not create speculative tables or fields because they might be useful someday.**

## 4. Verified existing-data inventory (Build 4)

Grounded in SwiftData models, `RecipeContent`, and the 41 `staygrubby` tables (local migrations match hosted). A UI concept alone does not count.

**Classifications:** ✅ Implemented and verified · 🟡 Partially implemented · 📝 Available but unstructured · 🗺️ Approved/planned · ⛔ Not currently captured.

| Signal | Status | Where / notes |
| --- | --- | --- |
| Dish records | ✅ | `Dish` / `dishes`: name, default Course, Cuisine (canonical ID or custom), Public Description, Private Notes, createdAt |
| Cooks / versions | ✅ | `CookingAttempt` / `cooking_attempts`: cookedAt, version title, sequence number, Course snapshot, notes, created/updated |
| Grub Rank order | ✅ | BT `strength` on `RankedItem` / `ranked_items`; global `RankingList` |
| Displayed score | ✅ | Derived at read time by `ScoreCalibration` (strength + reaction); not stored as truth. Score/order semantics under pre-V1 investigation |
| Pairwise evidence | ✅ | `Comparison` / `comparisons`: immutable UUID observations, winner or tie, timestamp; repeats retained |
| Ranking uncertainty | ✅ | `RankedItem.uncertainty`; session diagnostics include position mean/SD and max slot probability |
| Explicit reaction | 🟡 | Three-level initial and latest reaction (Liked / Fine / Didn't like) in session diagnostics, per cook. No ingredient/flavor-level explicit preferences |
| Timestamps | ✅ | Cook date, created/updated on cooks, comparisons, Recipes, revisions, posts, comments |
| Cooking frequency / repetition | 📝 | Derivable from cook dates and versions per Dish; no stored aggregate (none needed yet) |
| Recipe ingredients | 🟡 | Components with ingredient lines and parsed fields; no canonical ingredient identity across Recipes |
| Ingredient quantities | ✅ | Exact rational quantities, units, preparation via deterministic IngredientParser |
| Recipe instructions | ✅ | Ordered steps per component with optional explicit dependencies |
| Techniques | 📝 | Only inside step text; no technique taxonomy |
| Recipe metadata | ✅ | Yield, prep/cook/elapsed minutes with origins, Course, Cuisine, Contains/Possible allergens, tips |
| Recipe revision history | ✅ | `recipe_revisions` immutable; restore-as-new; owner-only history |
| Dish ↔ Recipe relationships | ✅ | `recipe_cook_links` (exact current), `dish_recipes` (legacy family), `recipe_cooks` (immutable used-snapshot) |
| Recipe ownership | ✅ | `recipes.owner`, visibility `private` / Sous Chefs |
| Creator attribution | ✅ | `originalCreator`/source fields; pinned foreign creator credit on Recipe-origin cooks; `recipe_forks` provenance |
| Recipe recreations | 🟡 | Run It Back / Shared Cooking provenance in `cooking_origins`, `recreated` Ticket kind, `recipe_cooks`; Run It Back entry points hidden; no recreation statistics |
| Cooking photos | ✅ | Up to six ordered `CookingMedia` per cook; private backup in `media`/`media_backups` |
| Posts | ✅ | `social_posts` with safe snapshot (title, version, score text, achievement) |
| Rank-at-sharing snapshots | ✅ | `rank_at_sharing`, `ranked_count_at_sharing` (Build 4 clients; older posts score-only) — automated verification; Already Shared owner-accepted |
| Hands | ✅ | `social_likes` |
| Comments | ✅ | `social_comments` |
| Tickets | ✅ | `social_notifications` (nine kinds) with read state |
| Sous Chef relationships | ✅ | `friendships` (mutual), `social_blocks` |
| Tagged collaborators | ✅ | `shared_cooks` / `shared_participants`; editable on existing cooks (Build 4); not yet shown on cards |
| Recipe activity | ✅ | `recipe_activity` (creation/first-share event) |
| Saved Recipes (bookmarks) | ⛔ / 🗺️ | Not captured. Private copies (`recipe_forks`) exist but are independent copies, not bookmarks. Approved post-V1 |
| Want to Cook | 🟡 / 🗺️ | Dormant `recipe_tickets(account_id, recipe_id, created_at)` and dormant view; no V1 surface. Approved post-V1 feature |
| Cuisines/ingredients/techniques to try | ⛔ / 🗺️ | Not captured |
| Inferred preferences | ⛔ | None stored or computed |
| Difficulty / ability signals | ⛔ | No Recipe difficulty field, no technique or ability data |
| Collections / Series | ⛔ / 🗺️ | Not captured. Approved post-V1 |
| Source / inspiration | ✅ | `dish_sources` (manual Source choice) |
| Privacy / visibility | ✅ | Recipe visibility, post publication/moderation/deletion, sharing preferences, discoverability, blocks |

## 5. Approved future concepts (not implemented)

**Want to Cook (post-V1).** Captures cooking *intention* separately from cooking. Save Dishes or Recipes to make later, organize inspiration, connect a saved intention to the eventual cook, capture cuisines/techniques to explore. Keep distinct: My Recipes · Saved Recipes from Sous Chefs · Want to Cook · Dishes actually cooked · personal rankings. Preserve creator attribution; prefer bookmarking plus attributed cooking over duplicating another creator's Recipe into an editable personal copy. The dormant `recipe_tickets` storage may be reused if it fits; evaluate against section 3 first.

**Saved Recipes (post-V1).** Food Bible distinguishes My Recipes from Saved Recipes: bookmarks/references to a Sous Chef's original that preserve attribution and respect revocation/deletion. Never silently duplicate creator content. Depends on privacy/access-control maturity. Name not final ("Recipe Box" not confirmed).

**Collections / Cooking Series (post-V1; name not final).** Thematic context across Dishes — e.g. *Every Way to Cook an Egg*, *My Risotto Experiments*, *Cooking Through a Cookbook*, *Perfecting the Burger*, *Cooking Through Italy*. Distinct from Versions (repeated iterations of one Dish). Conceptual model: **Collection ↔ Dish many-to-many**, Collection → Dishes → Cooks/Versions. Never duplicate Dish, Recipe, cook or ranking evidence for membership. Intelligence value: explicit context distinguishes exploration, challenge/project, preference, repetition and deliberate learning (twelve egg Dishes inside an egg project ≠ twelve independent egg choices). Current architecture already keeps Dish identity independent; keep it that way so a join relationship can be added later.

**Personal Flavor Profiles (long term, private).** Cuisine and ingredient preferences, flavor combinations, sweetness, acidity, bitterness, richness, spice, textures, methods, Dish categories, evolution over time. Use ranking evidence where appropriate; do not overinterpret single Dishes; separate strong from weak evidence; retain uncertainty; adapt over time; allow correction; private by default; never present inference as fact; never infer allergens or flavor with certainty from images.

**Cooking Ability / Experience Profiles (long term, private).** Frequency, Recipes completed, techniques used, ingredient familiarity, complexity, repeated attempts, progression, explicit feedback, optional self-report. Observed experience and inferred ability stay distinct. Uses: difficulty and technique suggestions, progression insights, discovery, personal challenges, improving existing Dishes. **No public skill rating.**

**Social intelligence and shared cooking (long term).** Shared Recipe inspiration, overlapping interests, collaborative ideas, dinner-party planning, group suggestions, voluntarily shared dietary information, overlapping Want to Cook items. Never automatically expose private rankings, notes, Flavor or Ability Profiles, dietary restrictions, allergies or cooking history. Dietary/allergy information is never inferred as a substitute for direct confirmation when cooking for someone.

**Intelligent Discover (major post-V1 update).** Connected but distinct areas — *Dishes & Rankings* (public posts, scores, positions, photos, creators) and *Recipes* (public Recipes, attribution, saves, recreations, statistics) — not one feed. Signals may include relevance, interests, flavor fit, saves, unique recreations, repeat cooking, meaningful engagement, freshness, creator diversity, new-creator exposure, quality and safety. A high personal score is not universal Recipe quality. Start interpretable and cost-efficient. Privacy, blocking, eligibility and moderation run **before** ranking candidates. Never expose private or Sous-Chef-only content. Grub List stays chronological and is not Discover.

**Recipe recreation and community statistics (post-V1).** Total recorded cooks, unique cooks, repeat cooking, recreations, saves, activity over time, revisions, associated re-ranks. Definitions must be precise: repeated taps do not inflate counts; copies are not attributed recreations; private activity never leaks; deleted/revoked content is removed from counts. Personal Grub Rank stays independent of popularity.

**Achievements, challenges and insights — Stars ⭐ (post-V1, private).** Monthly goals, annual milestones, streaks, new-Recipe/cuisine/technique challenges, revisit-and-improve, yearly recap, consistency insights. Thresholds undecided. Reward actual cooking, not app taps; no pressure mechanics. Distinct from existing factual share achievements.

**Meal planning — distant/dormant.** Do not prioritize, design, implement or raise it in normal development. Revisit only when the owner explicitly asks. It must not shape current architecture beyond ordinary extensibility.

## 6. Privacy and data governance

Private by default; user-controlled sharing; future account-wide audience as the upper bound with per-item visibility; Private Notes always private; blocking and access controls; Supabase RLS and least privilege. Long-term architecture should support disclosure and explanation of collected data and its use; separating operational from personalization data where appropriate; user access and deletion; retention policies; privacy-safe analytics and aggregation; consent for sensitive information; accurate Apple App Privacy answers; AI-provider disclosure; Privacy Policy and Terms updates; creator attribution; moderation; legal review. Never sell, share or repurpose data beyond disclosed purposes; never silently expand data use.

## 7. Cost, performance and scalability

Each future decision weighs database growth, query performance and indexing, network traffic, Storage/photo growth, AI inference cost, background processing, recommendation computation, privacy/security overhead, testing and maintenance complexity. Prefer simple, measurable, interpretable, cost-efficient approaches before expensive ML, large analytics pipelines, speculative event collection or redundant materialized data. Decide per aggregate whether to query on demand, cache, or maintain incrementally — when the feature exists, not before.

## 8. Legal / IP workstream (ongoing, risk-driven)

`#stayGRUBBY` brand/trademark; source-code ownership; creative assets; third-party dependency licenses; Recipe creator attribution/ownership and copyright; UGC terms; Privacy Policy; Terms; Community Guidelines; moderation; documentation of original technical work and any potentially protectable innovation. Items needing qualified legal review must be flagged as such. Do not claim broad product concepts, standard ranking mathematics (Bradley–Terry) or existing techniques are patentable. Legal work follows actual risk and release requirements; V1-blocking items are in [V1_RELEASE_GATE.md](V1_RELEASE_GATE.md).
