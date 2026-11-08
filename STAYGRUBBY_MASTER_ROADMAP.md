# StayGrubby Master Roadmap

**Canonical roadmap — reconciled November 7, 2026 at Build 4 (`c09c18e`).** This is the only future-sequencing document. [AGENTS.md](AGENTS.md) governs how work proceeds; [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md) describes what is implemented; [PERSONAL_COOKING_INTELLIGENCE.md](PERSONAL_COOKING_INTELLIGENCE.md) holds the long-term intelligence direction and data inventory. Planned items are not implementation, deployment or distribution authorization. Post-V1 order is not final: sequence by dependencies, tester feedback and capacity.

**DISCOVER → SAVE → COOK → RANK → REMEMBER → SHARE → INSPIRE.** Personal cooking and comparison ranking stay central. Recipes, engagement, recommendations, sponsorship and commerce never change personal ranking evidence or scores.

When proposing work classify it as **required before V1**, **desirable but deferrable**, or **post-V1**. Only product coherence, safety/privacy/platform compliance, data integrity and a credible first public release justify moving something ahead of V1.

## NOW — Build 4 / TestFlight

**Complete.** StayGrubby 1.0 (4) is uploaded and processing; owner controls tester groups, notes and notifications. Owner physical acceptance passed for ranking, Already Shared, Recipe navigation/sharing, Edit Cook tagging and Universal Links. The November 7 production website regression (assets-only publish) is recovered and guarded by `Website/deploy-production.sh`. Tester feedback continues; Build 4 functionality reopens only for genuine regressions. [Architecture: Build 4](STAYGRUBBY_ARCHITECTURE.md#current-state--build-4).

## NEXT — Unified Dish foundation, then UI overhaul

**Final implementation sequence (Final Unified Food Architecture Reconciliation, November 8, 2026).** The old order put Stage C (Sharing) first. It is replaced, because building sharing, editors and social screens on the separate Dish Detail / Recipe Detail structure would mean building them twice. The unified Dish foundation now comes first. Specification: [FOOD_ARCHITECTURE.md](FOOD_ARCHITECTURE.md). Plan, component candidates and the queued defect list: [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md#9-system-wide-ui-overhaul--plan). The letters are kept for continuity with completed work; **run them in the order of this table.**

| Order | Stage | Scope | V1 |
| --- | --- | --- | --- |
| done | A — Foundations | **Implemented Nov 7 — owner accepted.** Shared photo/score/state/section/toolbar foundations, spacing tokens | — |
| done | B — Pickers / Search / Filtering | **Implemented Nov 7–8 — owner physical acceptance pending.** Direct Grub Rank chips, separate Sort, the projection toggle, Photo filter removed, Dietary groups | — |
| 0 | Integration + data prerequisite | **Integration done Nov 8** (`main` fast-forwarded to `7630e96`; push through GitHub Desktop pending). **Lifecycle migration deployed Nov 8** (fingerprints unchanged). The owner integrates `agent/claude` (contains Codex `a6de6b8` plus this checkpoint) into `main`. Authorize and deploy `20261108171024_recipe_cook_lifecycle` with fingerprints (release-gate item). **In parallel (other agent lane):** the score/order investigation below | Required |
| 1 | **D1 — Unified Dish Foundation** | **Implemented Nov 8; `dish_recipe_links` deployed Nov 8; owner physical acceptance pending.** Read model and association rules are app-side types; D2 wires them into Dish Detail. Data, model and terminology; no Dish Detail redesign. (a) `dish_recipe_links` additive migration (several Recipes per Dish, one Main, legacy `dish_recipes` read or copied with fingerprints, RLS, owner RPCs, compare-and-swap); needs Supabase authorization. (b) `Food` read model: related-Recipe union, deterministic Main default, Recipe-only Dishes. (c) Association policy as testable logic: automatic for explicit provenance, suggestions for loose matches. (d) `CookName` resolver plus a Rename path that leaves IDs, strengths and evidence unchanged (tests). (e) **Terminology rebrand across existing screens:** Version Title → Cook Name, New Version → Cook Again, All Versions → All Cooks (labels only; raw preference values kept), Version History → Recipe History, "N versions" → "N cooks", accessibility. (f) Confirm the Recipe content contract accepts the `dietary` key | Required |
| 2 | **D2 — Dish Detail** | One Dish Detail from Grub Rank and Food Bible: `DishIdentityHeader`, `DishCooksSection` (Rename, Cook Again), `DishRecipesSection` (Main Recipe, Set as Main, Recipe used vs Linked), `DishActions` shell; Recipe-only "not cooked yet" state; Food Bible Cooked / Not cooked yet toggle; tagged collaborators on detail; owner validation of All Cooks wording in context | Required |
| 3 | **F — Flows and editors** | `AddRecipeFlow(context:)` (Import Recipe / Create Manually / Link Existing) replacing three entry points; Cook Again and Rank My Version start screens with the §3.3 suggestions; `CookEditor` "About this Dish" / "This cook"; Recipe editor (accent overuse, Back+Cancel defect); Diet/Contains prefill from a Recipe, user-confirmed | Required |
| 3b | F — Recipe Diet (as written) | Author-selected Recipe Diet field and Food Bible Dietary (Diet) filter | Desirable, deferrable |
| 4 | **C — Sharing** | Post to Grub List vs external Share; one Share action (image + short `#stayGRUBBY` message + exact link) built into `DishActions`; composer simplification | Required |
| 5 | **E — Social / Kitchens** | Grub List, Tickets relocated to Grub List, My Kitchen stats (Dishes Ranked → Grub Rank · Recipes → Food Bible · Sous Chefs), Sous Chef Kitchen, Requests; tagged collaborators on cards; cook names on cards per snapshot rules | Required |
| 6 | **G — Copy / Celebrations / Final consolidation** | Copy purge, ranking result and celebrations (after the investigation concludes), accessibility/consistency | Required |

Why this order:

- D1 contains the only schema change. It also contains the copy rebrand, so every later stage is built on final words and data.
- D2 establishes the single screen that C, E and F attach to.
- F comes before C because the new-cook flow and the result screen that sharing starts from are reshaped in F.
- C and E are presentation work on top of that foundation.

D1 (a) and (d)/(e) touch different files and can be split across the two agent lanes. Avoid running D2 and F in parallel, because both edit Dish Detail and the cooking forms.

**Required pre-V1 investigation — Grub Rank score/order semantic consistency.** The displayed score is banded by reaction, while order follows Bradley–Terry strength, so a lower-ranked entry can show a higher score (observed: #9 · 2.6 above #11 · 7.6).

- Investigate how to keep score and order understandable while preserving all evidence, history, re-rank behavior, calibration and uncertainty.
- Investigation comes first; any math or calibration change needs the owner to explicitly reopen ranking.
- It can start now in parallel. It must conclude before D2 settles how Dish Detail presents score and rank, and before G finalizes results.

[Mechanism](STAYGRUBBY_ARCHITECTURE.md#ranking--protected).

**Unified food architecture — final, November 8, 2026 (documentation only).** The owner decided:

- Dish is the user-facing identity.
- A Dish can have several Recipes, with a selectable Main Recipe.
- Food Bible is the Recipe lens.
- Recipe revisions are Recipe History.
- Cooking Attempts can be renamed, with a "Version N" fallback.
- All Cooks and Cook Again are the new labels.
- Explicit provenance associates automatically; loose matches are suggested.
- As written vs as made applies to Diet as well as Contains.

The checkpoint `6214900` was reconciled with Codex `a6de6b8` (exact-revision provenance, link lifecycle, dated reactions — all preserved). Saved Recipes, Want to Cook, Collections, contextual rank boards, Scan Recipe and Share Sheet import remain **post-V1**: the architecture constrains them but does not authorize them.

Each stage: implement → focused verification → owner acceptance where needed → update canonical docs as decisions become durable.

## THEN — V1 Release Gate

Moderation (UGC filtering, report → review → resolution, block enforcement), privacy/security review, account deletion and UGC cleanup review, Terms, Community Guidelines, Privacy Policy, Recipe/allergen/serving disclaimers, support/contact, Apple App Privacy, age rating, App Review access/sign-in, production configuration, advisories (leaked-password warning, production `development-test-session` function), incompatible-build retirement. Checklist: [V1_RELEASE_GATE.md](V1_RELEASE_GATE.md). Privacy/moderation dependencies may move earlier.

Data integrity before V1 includes authorizing and deploying the locally verified Recipe cook lifecycle migration, confirming hosted restore and current-link retirement, and carrying forward the dated private reaction record. Personal Cooking Intelligence remains post-V1. [Data foundation follow-up](V1_DATA_FOUNDATION_AUDIT.md#november-8-follow-up).

## THEN — Release Candidate

Final TestFlight release candidate, one proportionate broader regression and Release verification, physical acceptance (including two-device Universal Links and real-device photos/auth/sync/sharing). Archive, build-number change, upload and distribution each need explicit owner approval.

## THEN — App Store V1

Metadata, screenshots, reviewer instructions, switch `Website/distribution.json` to the App Store listing and redeploy the full Worker, submission with explicit owner approval.

**V1 scope:** reliable cooking records, Grub Rank, Food Bible/Recipe workflows, My Kitchen, Sous Chefs, chronological Grub List, sharing, authentication/sync, privacy/account controls, moderation/compliance and polished dependable UX. **Not V1:** Discover, Personal Cooking Intelligence, Want to Cook, Collections, advanced recommendations.

## POST-V1 — near / medium term (approved or established; order not final)

- **Want to Cook** — cooking intention distinct from cooking; bookmark + attributed cooking workflow. Targets a Dish (cooked or Recipe-only) or a Recipe — the first candidate to justify a stored Food identity. [Concept](PERSONAL_COOKING_INTELLIGENCE.md#5-approved-future-concepts-not-implemented), [fit](FOOD_ARCHITECTURE.md#10-future-compatibility-post-v1-nothing-here-is-authorized)
- **Saved Recipes** refinement — bookmarks to a Sous Chef's original, attribution preserved; depends on access-control maturity
- **Recipe Social History / recreation statistics** — precise, privacy-safe "Made X times"
- **Privacy/access-control evolution** — account maximum audience Public / Sous Chefs Only / Private with per-item visibility bounded by it; new items private by default
- **Collections / Cooking Series** (name not final) — Collection ↔ Dish many-to-many thematic context (members may be Recipe-only Dishes), distinct from a Dish's cooks; contextual rank boards are projections of the one global ranking
- **Scan Recipe** and **Share Sheet import** — additional Import Recipe sources feeding the same Gemini → review → Save pipeline
- **Cooking insights** and private **Stars ⭐** achievements/challenges
- **Recipe unit conversion** when reliable (implementation retained, controls hidden)
- **Photography** — crop/reposition, advanced gallery, editing
- **Rich external previews** — explicit share-safe preview artifact; never public general buckets; documented cache/revocation limits
- **Discover** as a major update (distinct Dishes & Rankings / Recipes areas)
- **Early personalization** — interpretable, cost-efficient
- **Push notifications** (APNs) after reliable in-app Tickets
- **Referrals** — counts only a genuinely new attributed signup; rewards undecided; core functionality never requires recruiting
- **Run It Back redesign** (entry points hidden, provenance preserved)
- **Moderation/administration growth** — roles separate from entitlements; broader dashboards only when scale requires
- **Source taxonomy** — My Own, Online, Cookbook, Restaurant, Friend / Family, Sous Chef, Other; optional metadata later
- Dedicated Recipe-only posts, feed filters, automatic Recipe-update posts (deferred)
- Launch/loading polish (planned pasta-machine animation) under an explicit polish cycle

## LONG TERM

Personal Flavor Profiles · Cooking Ability / Experience Profiles · advanced Personal Cooking Intelligence · sophisticated recommendations · social/group intelligence and shared cooking experiences · creator/commerce exploration (possible following model, partnerships, affiliate commerce; no conventional display ads; personal ranking stays free) · other justified intelligence features. All private by default; no new AI/paid infrastructure is authorized now. [Direction](PERSONAL_COOKING_INTELLIGENCE.md).

## DISTANT / DORMANT

Intelligent meal planning — do not prioritize, design or raise it until the owner explicitly revisits it.

## EXPLICITLY REJECTED / EXCLUDED

Do not resurrect without an explicit owner decision:

- Cookbook barcode / ISBN indexing or a cookbook search database
- Apple Foundation Models as a Recipe provider (not compiled in V1; on-device quality was insufficient)
- Lexical source-vocabulary guards, token-overlap checks, source reconstruction, method-to-ingredient recovery, a second AI judge or culinary fact-checking heuristics in Recipe Creator
- A StayGrubby daily AI allowance or date/30-day expiry
- Manual ranking order
- Speculative AI/data infrastructure or event collection without a current feature
- Renaming My Kitchen (e.g. "Knife Roll")
- Making general photo buckets public for link previews
- Algorithmic ordering of the current Grub List

Hidden but retained (not rejected): Custom Tags, Run It Back entry points, unit-conversion controls, dormant Want to Cook storage.

## Evidence and document ownership

Future planning lives **here** only. Historical stage plans and reviews ([NEXT_RELEASE_SPEC.md](NEXT_RELEASE_SPEC.md), stage reviews, [V1_PRODUCT_CLOSEOUT_REVIEW.md](V1_PRODUCT_CLOSEOUT_REVIEW.md), [V1_RANKING_INTEGRITY_REVIEW.md](V1_RANKING_INTEGRITY_REVIEW.md), [NEXT_TESTFLIGHT_IMPROVEMENTS_REVIEW.md](NEXT_TESTFLIGHT_IMPROVEMENTS_REVIEW.md) and earlier milestone reviews) retain dated decisions, commands, tests and deployments; their pending gates and sequences are not current instructions. Owner acceptance is never inferred from automated tests.

### Required first App Store release milestone

**Build 4 → integration + lifecycle deployment → D1 Unified Dish Foundation → D2 Dish Detail → F → C → E → G (with the score/order investigation in parallel) → V1 Release Gate → Release Candidate → App Store V1 → post-V1.** App Store V1 is a concrete milestone that optional ideas must not keep postponing. No submission or distribution is authorized by a development checkpoint.
