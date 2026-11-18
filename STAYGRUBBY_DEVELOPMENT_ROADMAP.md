# StayGrubby Development Roadmap

**Roadmap B — how we build it.** This document tracks foundations, contracts, gates, sequencing and delivery risk. **Roadmap A**, [STAYGRUBBY_MASTER_ROADMAP.md](STAYGRUBBY_MASTER_ROADMAP.md), tracks *what* we build, why, and when users receive it. The two are kept in sync (see [AGENTS.md — Two roadmaps](AGENTS.md#two-roadmaps)); specialized documents (architecture, UI, food, sync, moderation, release gate) stay the detailed references. Established November 18, 2026.

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
| `RecipeShareChoice` / `RecipeAttachmentModel` | Social/RecipeSocial.swift | Composer Recipe consent with status line |
| `SGContentState`, `SGLoadingState`, `SGSectionHeader`, `SGBrowseSortMenu` | DesignSystem | Every empty/loading/error state and sort |

## 3. Feature status (build view)

Product priority lives in Roadmap A; this is the implementation view. "Released" requires owner iPhone acceptance.

| Feature | Status | Notes / dependency |
| --- | --- | --- |
| The Pass card, comments sheet, Dish Details, Previous Cooks | Verified (pending integration and iPhone) | Exact `dishKey` integrated by Codex (d26b56c) |
| One Public Description (Dish ↔ caption) | Verified client sync | Backend: derive caption server-side from the Dish row (§4) |
| Standard Delete wording | Verified | Replaces "86" in actions and confirmations |
| Tab icon system | Verified (Simulator) | iPhone visual acceptance pending |
| Cook history marks (Latest / Top cook) | Verified | Presentation only; ranking unchanged |
| Locked Kitchen for non–Sous Chefs | Verified | Skips an empty profile-posts read |
| Saved Recipes / My Recipes | Enabled (Connected UI Phase 1) | Bookmarks only; no copy, no cook |
| Make This (cook another Sous Chef's Recipe) | Enabled as **Rank My Version** | Creates the user's own Dish/cook; creator attribution preserved |
| Public / private follow model | Foundation, gated | Backend contract (§4) |
| Multiple-photo galleries | Planned | Reuse photo infrastructure; no new Storage writes until designed |
| Shop This Dish | Planned (post-V1) | `DishDetailsSection.shop` + engagement accessory slot; needs privacy/legal review |
| Discover | Planned (post-V1) | — |

## 4. Backend contracts for Codex

| Contract | Why | Client boundary today |
| --- | --- | --- |
| Caption derived from `dishes.public_description` (or an `editDishDescription` action that updates the Dish row and all its posts in one transaction) | One canonical Public Description across devices, atomic | `PublicDescriptionSync` updates posts after explicit saves; reports failures |
| Follow model: `account_visibility` (`public`/`private`), `follows` with `pending/accepted`, searchable private accounts with a minimal locked card, RLS so only accepted followers read audience-scoped content | Public/private accounts (owner decision, Nov 18) | Current model stays: mutual Sous Chefs + discoverable flag; `account_privacy_follows` off |
| Cooked-at snapshot on posts | Dish Details cooking date | Shows the shared date |
| Optional comment Hands | Hands on comments | Not shown |

Contract rules: authenticated RPC/Edge action, DTO documented in the owning domain doc, PT409 for conflicts (never 40001/40P01), RLS on every read, backward compatible with the shipped client, migration header with growth/retention.

## 5. Sequencing and parallel work

1. Integrate the November 18 UI milestone (`agent/claude`) with Codex's instant image publishing (`d475257`, not yet on `main`). Expected overlap: canonical docs only.
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
| Three stale UI tests (Edit Cook in the actions menu, `hero-photo`) | Noise in regression runs | Update with the next Dish page cycle (UI_ARCHITECTURE §10) |
| Add Manually nested navigation (`RecipeEditor` owns a `NavigationStack`) | Back + Cancel | Embedded editor mode, coordinated with the Recipe editor owner |
| Per-post caption copies | Cross-device drift possible | Server contract (§4) |
