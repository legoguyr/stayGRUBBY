# StayGrubby Development Roadmap

**Roadmap B — how we build it.** This document tracks foundations, contracts, gates, sequencing and delivery risk. **Roadmap A**, [STAYGRUBBY_MASTER_ROADMAP.md](STAYGRUBBY_MASTER_ROADMAP.md), tracks *what* we build, why, and when users receive it. The two are kept in sync (see [AGENTS.md — Two roadmaps](AGENTS.md#two-roadmaps)); specialized documents (architecture, UI, food, sync, moderation, release gate) stay the detailed references. Established November 18, 2026.

**V1 feature freeze (owner, November 18, 2026):** until the first App Store release only corrections, data organization, launch polish and release work are built; new feature ideas are recorded as Post-launch in Roadmap A.

## 1. Lifecycle (LEGO: build ahead, activate later)

Every feature carries one status. These are separate states; reaching one never implies the next.

| # | State | Meaning |
| --- | --- | --- |
| 1 | Planned | Decided and scoped; no code |
| 2 | Foundation | Reusable components, models or contracts exist; no user-facing flow |
| 3 | Implemented | The flow works end to end in code |
| 4 | Verified | Focused automated tests pass (and Simulator review for UI) |
| 5 | Integrated | On `main` |
| 6 | Deployed | Backend parts live on the hosted project (where applicable) |
| 7 | Enabled | Reachable by users (no gate, or gate on) |
| 8 | Released | In a TestFlight/App Store build users have, and owner-accepted on iPhone |

**Hidden features.** Built-ahead code stays unreachable through normal navigation, including the owner's TestFlight builds, until it is enabled. Hiding UI is not security: the server enforces privacy and access on every operation, and unsafe or incomplete server functionality is never deployed because its UI is hidden. A hidden feature makes no writes, runs no background work, adds no polling and does not touch ranking or persistence.

**Gates.** Use the single server-managed `FeatureFlag` set (`StayGrubby/Social/FeatureFlags.swift`, `api.feature_flags`): off unless the server enables it for the account; offline, older servers and errors mean off. Debug review fixtures stay compile-time excluded from Release. Don't scatter one-off booleans; a gate is a `FeatureFlag` case with a comment saying what it waits for.

| Gate | State | Waits for |
| --- | --- | --- |
| `dish_aggregate_scores` | Planned (reserved) | Aggregate score/make-count backend (FOOD_ARCHITECTURE §10) |
| `account_privacy_follows` | Foundation (`SGLockedKitchenNotice`) | Follow model backend contract, RLS and client follow flow (§4) |
| `dish_collections` (Dish Variations) | **Deployed + Enabled** (owner-authorized, November 20, 2026; audience `everyone`); client on `agent/claude`, not yet in a TestFlight build; owner iPhone acceptance pending | Migration deployed November 20, 2026 as `20261120150047_dish_collections` (local `20261118160100`, renamed byte-identically); flag row inserted. Turn off with `enabled = false`. Debug review: `--feature-flag dish_collections` |

## 2. Reusable components (LEGO inventory)

Reuse before building (AGENTS.md "Reuse Before Reinvention"). Current shared pieces worth knowing:

| Component | Where | Used by / ready for |
| --- | --- | --- |
| `SGScore` (`standard`, `outOfTen`, `medallion`, `pill`) | DesignSystem/SGScore.swift | Rows, results, Dish Details, The Pass card |
| `SGTabLabel` + tab icon assets (`TabPassFill`, `TabRankFill`, `TabKitchenFill`, `SousChefs`) | DesignSystem/SGTabIcons.swift | Tab bar; `SGToolbarIcon(asset:)` for the Sous Chefs toolbar |
| `SocialPostAuthor`, `SocialCompactScore`, `SocialPostCaption`, `SocialRecipeChip` | Social/SocialFeedView.swift, DishPostDetails.swift | The Pass card; ready for profiles and Discover cards |
| `SocialEngagementView<Accessory>` | Social/SocialCommentsView.swift | Card and Dish Details; trailing accessory slot (Recipe today, Shop This Dish later) |
| `DishDetailsSection` | Social/DishPostDetails.swift | Ordered Dish Details sections; `.shop` slots after `.recipe` |
| `SharedCookLookup` / `SharedCooksModel` | Social/SharedCookLookup.swift | Previous Cooks by exact `dishKey`, paginated, cached |
| `PublicDescriptionSync` | Social/PublicDescriptionSync.swift | One Public Description across Dish and its posts |
| `DishCooksSection` + `CookMarks` / `CookTags` | Views/Cooking/DishParts.swift | Cook history (Latest / Top cook); ready for My Kitchen journal views |
| `SGLockedKitchenNotice` | Social/KitchenPrivacy.swift | Non–Sous Chef Kitchens now; private accounts later |
| `DishCollectionPolicy` / `DishCollectionStore` / `DishCollectionSummary` | Cooking/DishCollections.swift | Smart Collections: labels on Dishes, derived membership and best-cook ranking |
| `DishCollectionsField`, `KitchenCollectionsSection`, `DishCollectionView`, `MoveCookSheet` | Views/Cooking/DishOrganization.swift | Add to Collection in every Dish editor; My Kitchen; cook separation |
| `DishIdentityStore.move` | Cooking/DishIdentityStore.swift | Lossless cook separation (companion of `combine`) |
| `AuthorizedRemoteImage` + `ImageAccessCheck` | Social/AuthorizedRemoteImage.swift | One image pipeline; degrades safely without `api.image_access` |
| `SGLibraryHeader`, `SGCreateButton`, `SGFilterRail`, `sgTabHeader`, `sgHeaderAction` | DesignSystem/SGBrowseBar.swift | Every tab root (UI_ARCHITECTURE §13) |
| `SGPhotoViewer`, `SGLaunchView` | DesignSystem/SGPhotoViewer.swift | Full-screen photos; account restore |
| `SeparateCooksSheet`, `FolderGrid`, `DishFolderCallout`, `VariationEditorSheet` | Views/Cooking/DishOrganization.swift | Dish separation and Dish Variations (cards, Create/Edit Variation) |
| `DishVariationCopy` | Cooking/DishCollections.swift | The one place the user-facing feature name is set |
| `RecipeShareChoice` / `RecipeAttachmentModel` | Social/RecipeSocial.swift | Composer Recipe consent with status line |
| `SGContentState`, `SGLoadingState`, `SGSectionHeader`, `SGBrowseSortMenu` | DesignSystem | Every empty/loading/error state and sort |

## 3. Feature status (build view)

Product priority lives in Roadmap A; this is the implementation view. "Released" requires owner iPhone acceptance.

| Feature | Status | Notes / dependency |
| --- | --- | --- |
| The Pass card, comments sheet, Dish Details, Previous Cooks | Integrated (pending iPhone) | Exact `dishKey` integrated by Codex (d26b56c) |
| One Public Description (Dish ↔ caption) | Verified client sync | Backend: derive caption server-side from the Dish row (§4) |
| Standard Delete wording | Verified | Replaces "86" in actions and confirmations |
| Tab icon system | Verified (Simulator) | iPhone visual acceptance pending |
| Cook history marks (Latest / Top cook) | Verified | Presentation only; ranking unchanged |
| Locked Kitchen for non–Sous Chefs | Verified | Skips an empty profile-posts read |
| Saved Recipes / My Recipes | Enabled (Connected UI Phase 1) | Bookmarks only; no copy, no cook |
| Make This (cook another Sous Chef's Recipe) | Enabled as **Rank My Version** | Creates the user's own Dish/cook; creator attribution preserved |
| Public / private follow model | Foundation, gated | Backend contract (§4) |
| P0 The Pass / avatar photos on hosted | Verified (unit), iPhone pending | Client-only; works before and after `api.image_access` is deployed |
| Dish/Recipe integrity — separate a cook | Verified (unit + UI) | Client; server hardening `20261120171728` deployed Nov 20; share-option half `20261118160050` pending with Codex's chain |
| Rank a Dish / Add a Recipe + menu | Verified (UI) | Replaces New Dish / Cook Again choices |
| Dish Variations (Smart Collections) | Deployed + Enabled Nov 20; Create/Edit Variation, Remove from Variation | Owner iPhone acceptance; reaches users only with the next build |
| App-wide UI consistency / design system v2 | Implemented, Verified (focused UI), iPhone pending | UI_ARCHITECTURE §13; remaining exceptions §13.5 |
| Separate Cooks; Recipe → Dish details; All Dishes / Dish Variations tabs; contextual + | Implemented, Verified (UI) | Dish Variations tab behind `dish_collections` |
| Full-screen photo viewer | Implemented (Dish and post heroes) | Recipe photos and avatars next |
| Multiple-photo galleries | Planned | Reuse photo infrastructure; no new Storage writes until designed |
| Shop This Dish | Planned (post-V1) | `DishDetailsSection.shop` + engagement accessory slot; needs privacy/legal review |
| Discover | Planned (post-V1) | — |

## 4. Backend contracts for Codex

| Contract | Why | Client boundary today |
| --- | --- | --- |
| Caption derived from `dishes.public_description` (or an `editDishDescription` action that updates the Dish row and all its posts in one transaction) | One canonical Public Description across devices, atomic | `PublicDescriptionSync` updates posts after explicit saves; reports failures |
| Follow model: `account_visibility` (`public`/`private`), `follows` with `pending/accepted`, searchable private accounts with a minimal locked card, RLS so only accepted followers read audience-scoped content | Public/private accounts (owner decision, Nov 18) | Current model stays: mutual Sous Chefs + discoverable flag; `account_privacy_follows` off |
| Cooked-at snapshot on posts | Dish Details cooking date | Shows the shared date |
| `20261120171728_dish_recipe_integrity` (owner-authorized, **deployed** November 20 ahead of the other pending files; local `20261118160000`, renamed byte-identically) | `recipes dish` returns only a Recipe whose `dish_id` is that Dish (fallback patched in place in `recipe_api_before_diet_index`); new legacy links that disagree with identity are skipped; provable legacy-only Recipes get their Dish (none in production) | `Backend/tests/hosted-order-rehearsal.test.mjs` proves Codex's pending chain still applies afterwards |
| `20261118160050_recipe_share_option_integrity` (split from the above, not deployed) | `share_options` drops the legacy family-link step | Needs `20261117063020`; deploy with Codex's chain |
| `20261120150047_dish_collections` (deployed November 20, 2026 as `20261120150047_dish_collections` (local `20261118160100`, renamed byte-identically); applied alone on hosted head `20261115154948`, independent of the other ten pending migrations) | `dishes.collections text[]` (≤20 labels, ≤40 chars), accepted by the cooking outbox only when sent, restored as `collections` (null when empty) | Client always sends the key; older servers ignore it |
| `api.image_access` (Codex, pending) | Permission read before reusing cached photos | Client falls back to fresh Storage downloads while it is missing |
| Optional comment Hands | Hands on comments | Not shown |

Contract rules: authenticated RPC/Edge action, DTO documented in the owning domain doc, PT409 for conflicts (never 40001/40P01), RLS on every read, backward compatible with the shipped client, migration header with growth/retention.

## 5. Sequencing and parallel work

1. ~~Integrate the November 18 UI milestone with Codex's instant image publishing (`d475257`)~~ — done locally on `main` November 18 (one UI_ARCHITECTURE conflict, both sides kept).
1a. Integrate the P0 photo fix + Dish integrity milestone (`agent/claude`); owner iPhone check of Pass photos first.
1b. Deploy (owner-authorized) Codex's migrations with `20261118160050`. ~~`20261118160000` integrity core~~ — deployed November 20. ~~Dish Variations migration and `dish_collections` flag~~ — deployed and enabled November 20.
1c. P2 app-wide UI consistency pass (UI_ARCHITECTURE §10.1).
2. Physical iPhone acceptance of the UI milestone → next TestFlight candidate (owner authorizes upload).
3. Codex: Public Description server contract, then follow model; Claude builds the gated client flows against the documented DTOs in parallel.
4. Enable gates one at a time after hosted acceptance.

Ownership: Claude owns SwiftUI presentation, design system and client flows; Codex owns Supabase schema, functions, RLS, sync contracts and client transport changes that alter a contract. Shared files are reconciled at authorized integration.

## 6. Testing and release gates

- Focused tests for changed behavior plus narrow regression where shared code changed (AGENTS.md verification table). Don't rerun frozen ranking/photo-sync suites when untouched.
- Every new reusable component gets a unit or UI assertion where it carries logic (e.g. `SharedCookOrder`, `PublicDescriptionSync.needsUpdate`).
- TestFlight candidate: Debug + Release builds, focused suites, secret scan, whitespace, Simulator visual review (light/dark/large type), then owner iPhone acceptance. Upload only with explicit authorization.
- Release-state tracking: code implemented → integrated → locally verified → backend deployed → iPhone accepted → TestFlight-ready → distributed (mirrors §1).

## 7. Capacity and safety

- No writes from navigation; post caption updates happen only after an explicit Save and only when the text differs (bounded to 20 cooks per Dish).
- Read caches stay bounded (`AccountContentCache`, 120 s freshness; media cache 120 MB / 24 MB low-space).
- Locked Kitchens skip a request; Dish Details refreshes on return only when stale.
- Hidden features add no polling, background work or Storage objects.

## 8. Technical debt that affects delivery

| Debt | Impact | Plan |
| --- | --- | --- |
| Stale UI tests (Edit Cook in the actions menu, `hero-photo`/`hero-placeholder`, SocialUX share-default switch tap) | Noise in regression runs | Update with the next Dish page cycle (UI_ARCHITECTURE §10) |
| Add Manually nested navigation (`RecipeEditor` owns a `NavigationStack`) | Back + Cancel | Embedded editor mode, coordinated with the Recipe editor owner |
| Per-post caption copies | Cross-device drift possible | Server contract (§4) |
| Client features that silently depend on pending migrations | The Pass photo P0 (Nov 18) | Every client call to a pending function must degrade (missing-function → fallback) and be listed in §4 until deployed |
| Two search entry patterns, fixed filter rows, text Sort menus | Inconsistent library chrome | P2 pass (UI_ARCHITECTURE §10.1) |
