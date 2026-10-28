# StayGrubby — current product and architecture

**Canonical current-state overview — October 28, 2026.** Read [AGENTS.md](AGENTS.md) for development rules and the [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md) for planned work. This overview reconciles the implementation and owner decisions; dated domain/review sections remain evidence for their checkpoints, not claims that their old counts, gates or future boundaries still apply.

## Product and navigation

StayGrubby is a food/cooking platform centered on comparison-based ranking of things people actually cook, a personal cookbook/Recipe experience and explicit social sharing.

**Cook → Rank → Remember → Share → Interact**

**DISCOVER → SAVE → COOK → RANK → REMEMBER → SHARE → INSPIRE**

Cooking, saving a Recipe and publishing a social post are separate actions. Saving/discovering does not mean something was cooked/ranked. Popularity never changes personal ranking.

The native SwiftUI/SwiftData iPhone application targets iOS 26.5 and supports **upright portrait only**, with light/dark appearance and accessibility within portrait. Project/target/scheme/module is `StayGrubby`; bundle ID is `com.guyrettig.StayGrubby`.

The four authenticated tabs are **Grub List / Grub Rank / Food Bible / My Kitchen**; Grub Rank is initial. My Kitchen contains authorized own social posts, identity, Signature Dishes, Sous Chefs and Settings. Tickets are deliberately hidden from normal V1 navigation; their underlying implementation/data remain preserved.

## Domain boundaries

| Domain | Current implementation and ownership |
| --- | --- |
| Dish | Stable personal cooking identity/name, default Course, optional primary Cuisine and optional DishSource; no independent score |
| CookingAttempt | An actual cook/version of a Dish: date, optional version title, private notes, Course snapshot, tags and cook-owned media |
| RankedItem | Unique ranking identity per attempt; holds estimated strength/uncertainty and display diagnostics |
| Ranking evidence | One global cooking RankingList with individual immutable-ID Comparison observations; evidence is authoritative |
| Recipe | Server-owned UUID, owner/visibility, structured content, current revision; Dish links are separate relationships |
| Recipe history/provenance | Immutable revision archive and existing RecipeCook/social-origin snapshots; not a universal local CookingAttempt-to-revision model |
| Social | Optional profile, mutual friendship, explicit posts/safe snapshots, Hands/comments, invitations/recreations and notifications |
| Account/media | Apple/Supabase identity maps to permanent account; account-isolated working store, structured outbox and private photo backup |

### Cooking library

New Dish and New Version both create an independent attempt/item in the same global ranking. Edit and re-rank preserve existing attempt/item identities. Top Version / All Versions are projections, preserving true global ranks; filters do not create another ranking.

Course uses the controlled existing options. Dietary, Contains, custom tags and legacy free-label compatibility remain distinct. Avoid is a presentation/filter selection over existing metadata, not a medical guarantee. Cuisine uses stable canonical IDs plus account-owned custom values; no inference/backfill into existing Dishes is implied. DishSource is optional manual inspiration/attribution with My Own, Cookbook, Online, Restaurant, Friend / Family and Other UI choices; legacy storage codes remain compatible. It is separate from Recipe creator/source attribution.

All personal cooking mutations go through the existing cooking/ranking services so references, evidence cleanup and durable synchronization remain consistent. Do not directly delete domain rows as a shortcut.

### Ranking — accepted and frozen

Initial Liked / Fine / Didn't Like assessment, adaptive comparisons, Too Tough ties, Skip and Undo feed the established ranking workflow. Bradley–Terry uses retained individual evidence, including repeated observations; re-rank adds evidence to the same item. The engine uses Foundation/Accelerate independently of SwiftUI, SwiftData, Recipes and social services.

**Order and displayed score are related but distinct.** Order comes from fitted strengths. The accepted reaction-conditioned `ScoreCalibration` supplies the current displayed score; the older relative diagnostic transform in the technical specification is not the current UI mapping. Reactions do not rewrite the Bradley–Terry objective. See [RANKING_MODEL.md](RANKING_MODEL.md) and [calibration details](STAYGRUBBY_PRODUCT_STRUCTURE_SCORE_REVIEW.md), rather than duplicating formulas here.

Numerical scores unlock at ten eligible saved ranked attempts/versions. Re-rank does not increment eligibility; deleting below ten relocks presentation without destroying evidence. UI, accessibility, previews and exports obey the gate. Native numerical colors are muted coral 1.0–4.9, orange 5.0–7.5, gold 7.6–10.0; exported card scores always use brand red. Recipe/social work must preserve all ranking, calibration, evidence and visibility behavior.

## Food Bible and Recipes — what exists today

The normal Food Bible is still a **derived cookbook of cooked Dishes with eligible linked Recipes**, not the upcoming standalone Recipe library. Creation currently selects an existing cooked Dish. An existing Saved Recipes surface preserves unlinked Recipes and supports attaching them; backend UUID identity and nullable/independent links already exist. This infrastructure does **not** mean the general standalone creation/browsing product is implemented.

Recipes use authenticated online APIs with ownership/visibility checks and revision concurrency protection; they are not a second offline SwiftData cookbook. Existing personal cooking remains locally usable offline. Cookbook search is paginated and authorized, with compact summaries, title/ingredient/cuisine/source/creator search, Course/Cuisine filters and recent/alphabetical sorting. Current Recipe imagery comes from linked cook photos; Recipe-owned photos are not implemented.

`RecipeContent`/editable `RecipeDraft` preserve stable component/ingredient/step IDs, order, legacy flat content compatibility and exact rational ingredient quantities. Optional fields include description, yield, prep/cook/elapsed minutes, metadata origins, Course/Cuisine, source/link/original creator, tips and ingredient-derived allergen assessment. An unnamed single component stays simple. Explicit Save persists through the existing revision API; cancellation/dirty-draft protection remains. Unsaved force-quit draft recovery is not claimed.

Server Recipe identity/current revision, immutable `recipe_revisions`, explicit `dish_recipes` links and exact snapshots for existing Recipe-based cooking/provenance flows are implemented. Detaching/deleting a Recipe must preserve independent personal cooking and retained historical snapshots according to the existing lifecycle. General revision-history UI, Save as New Recipe, universal exact-revision binding for actual CookingAttempts and deterministic serving scaling remain **planned Food Bible Architecture V2**. Existing exact rational parsing alone is not a scaling feature.

Ingredient entry/paste works deterministically offline, including natural lines, fractions and bulk entry into the selected component. Original source text remains available during import review; legacy rows are not silently reparsed. Native ingredient/method ordering supports moves within/between components, stable IDs, Save/reopen/relaunch and accessible move controls.

### Recipe Creator V1 + refinement — OWNER PHYSICALLY ACCEPTED

The owner confirms acceptance in the October 28 workflow re-tool request. This closes the earlier pending physical gate in [refinement evidence](RECIPE_CREATOR_REFINEMENT_REVIEW.md). Accepted mechanics are stable unless actual regression/evidence or explicit new scope reopens them.

**Messy input → culinary interpretation → components → ingredient consolidation → chronology → professional cookbook writing → supportable useful metadata → editable RecipeDraft → explicit Save.** This serves people who know how they cook but do not write formal recipes; it is more than transcription formatting.

Gemini-backed consented **Cloud Formatting / Paste Recipe** is the standard intelligent path, behind authenticated `recipe-import`. The current native contract is version 3; older contracts retain compatibility. One provider response is guarded and normalized; there is no second automatic polish inference. Apple Foundation Models infrastructure remains dormant for normal creation because complex-Recipe quality was inadequate.

Semantic/factual guards preserve supplied ingredients, quantities, options and procedural facts while permitting bounded culinary interpretation/editorial cleanup. They do not formally prove arbitrary model output. Metadata distinguishes provided/derived/estimated/unknown; useful conservative yield/time suggestions remain editable, and guesses must not become fabricated precise procedural facts. Read the [Recipe Style Guide](RECIPE_STYLE_GUIDE.md) for cookbook writing rules and the [Creator ownership audit](RECIPE_CREATOR_REVIEW.md) for existing field boundaries.

Recipe allergens use the established ingredient taxonomy, possible/label-review distinctions and shared checklist interaction. User corrections survive pure reordering. Actual cook tags/Contains remain independently owned today; Recipe-primary metadata ownership migration has **not** happened. No religious compliance or allergen/cross-contact guarantee is inferred.

**No StayGrubby daily usage allowance, 30-day expiration, date-based disablement, free-tier-date secret renewal or paid billing.** The existing authenticated 3/account/minute burst protection, request/output/time bounds and server-only key remain. Provider 429/cooldown produces friendly Cloud AI guidance, manual/deterministic fallback and later retry; no automatic retry loop. The current explicit permission/settings UX still exists; simplifying it to just-in-time disclosure without a redundant global toggle is planned, not completed.

## Accounts, private sync and media

Production flow is onboarding → native Sign in with Apple → Supabase authentication → permanent account resolution → verified account-store readiness → authenticated app. New real accounts start empty; sign-out returns to onboarding. Session restoration is implemented; brief cold-start transition polish remains separate. No production guest mode. Debug development-library access is compile-time excluded from Release, isolated and unable to authenticate/provision/upload as a real account. Physical device-local development storage is separate from the Simulator library.

SwiftData is the local working cooking store. Mutations atomically persist domain changes plus durable outbox operations; authenticated owner-derived RPCs provide receipts, expected revisions, retries, snapshots and restoration. Hydration preserves identities/numeric evidence without refitting/reranking or creating upload intent. Existing conservative conflict rejection is deliberate; new conflict merging is not implemented. Tombstones/causal history prevent deleted cooks from resurrecting; raw server row counts need not become zero after deletion.

Local cook photos use account-scoped file roots and metadata, with optimized display/thumbnail variants privately backed up/restored using immutable account/media/hash paths and validated bytes. Profile reports pending/current state and retry. Social and avatar media have separate private buckets, permissions and cleanup. Test UUID stores/media roots must never write into the normal account/guest/demo roots.

Private application tables have RLS and least-privilege grants; narrow server APIs derive permanent ownership from a verified live session. Client-safe Supabase configuration is distinct from privileged server credentials. Store readiness and generation/cancellation guards prevent account-switch/stale-response leakage.

Coordinated account deletion is implemented: deliberate native confirmation/fresh Apple verification, server-side Apple verification/revocation and idempotent staged private/social media, database, Auth and local cleanup. The real physical Apple revocation/deletion test is intentionally deferred, **not a blocker to ongoing development**. Never perform it against the owner's account as routine verification.

## Social — implemented, with release hardening still needed

Optional display name, editable @username, discoverability off by default, private avatar and permanent anti-recycling profile routes are implemented. Mutual Sous Chef requests/accept/decline/remove and authoritative blocks exist. There is no public/private follower model, creator following system or public web profile product.

Grub List is a paginated chronological current-friends feed of explicit cooking posts/safe snapshots, with separately consented private social photos, Hands/comments and reporting/moderation states. Sharing defaults start OFF and can be overridden per new cook. Edit/re-rank/restore does not silently create a new post. Private Personal Notes never become public/shareable Post Descriptions. Social engagement, saves or friends' scores never alter the cooking graph/ranking. Visibility is reauthorized for friendship, blocks, moderation and deletion; a deep link/notification grants no access by itself.

Shared Cooking supports invitations, consent, joining/declining/cancellation and independent personal cooks. Run It Back carries eligible safe metadata/Recipe provenance through existing snapshots and normal cook/rank flows, never another person's evidence or score. In-app **Order Up!** notifications and read state exist; APNs/push does not. The observed Tag a Sous Chef notification issue belongs to the planned broader social/notification cycle, not a claimed fix.

Recipe visibility/provenance infrastructure is not a dedicated Recipe-only feed or combined Recipe/rank post product. Those post types, filters and update-sharing policy remain planned. Blocking/reporting/closed APIs are implemented; comprehensive UGC filtering and operational moderation response remain external-release work.

## Design, sharing, privacy and distribution

Reuse `StayGrubby/DesignSystem` (`SGTheme`, existing controls/header/editorial components) and canonical asset-catalog artwork. Supplied logo red is **#F10607**, cream **#FAF3EC**, charcoal **#1F1F1F**; adaptive app controls use existing contrast-adjusted tokens. Food imagery/type/whitespace lead; decoration and motion remain restrained. [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md) provides detailed contracts; [design review](STAYGRUBBY_DESIGN_SYSTEM_REVIEW.md) retains evidence.

Native local share images remain separate from social publishing: existing photo cards 1080 × 1350, no-photo fallback 1080 × 1080 and Top 3 1080 × 1350. Approved typography/layout, score-lock protection and evidence-backed achievements remain. Exports/embedded rendered previews always use brand-red scores; native results use semantic score colors. Private global rank/movement does not export. Future Stars is distinct from existing factual share achievements.

The canonical policy is [StayGrubby/Legal/PrivacyPolicy.md](StayGrubby/Legal/PrivacyPolicy.md), bundled offline and rendered by the existing static website. `staygrubby.com`, `/privacy`, `privacy@staygrubby.com` and `support@staygrubby.com` foundations are established. Latest local policy is effective October 27; its latest clarification is **not recorded as publicly published** in the accepted refinement checkpoint. Do not mistake source/render tests for publication. App Privacy answers completed for older releases require review for subsequent social/AI practices before wider distribution.

Owner-confirmed **1.0 (1) Internal Only TestFlight upload succeeded historically**, before later features; it is not evidence that current HEAD was uploaded or externally approved. External TestFlight, release candidate/App Store 1.0, updated policy publication, UGC operations, physical Universal Links correction/verification and current privacy/reviewer metadata remain separate authorized release work. Profile route/AASA/fallback infrastructure exists, but physical Universal Links are owner-reported broken/deferred. No new distribution is authorized by this document.

## Task-specific source map

| Task | Read next |
| --- | --- |
| Cooking/ranking/calibration | [COOKING_MODEL.md](COOKING_MODEL.md), [RANKING_MODEL.md](RANKING_MODEL.md), [score review](STAYGRUBBY_PRODUCT_STRUCTURE_SCORE_REVIEW.md) |
| Auth/account/structured sync | [ACCOUNT_ARCHITECTURE.md](ACCOUNT_ARCHITECTURE.md), [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md) |
| Photos | [MEDIA_SYNC_ARCHITECTURE.md](MEDIA_SYNC_ARCHITECTURE.md) |
| Social | [SOCIAL_ARCHITECTURE.md](SOCIAL_ARCHITECTURE.md), relevant Shared/Social UX review only as needed |
| Food Bible/Recipe | Current Recipe section above, [Food Bible UX 2 review](STAYGRUBBY_FOOD_BIBLE_UX_2_REVIEW.md), [Creator ownership audit](RECIPE_CREATOR_REVIEW.md), [Recipe Style Guide](RECIPE_STYLE_GUIDE.md), [refinement evidence](RECIPE_CREATOR_REFINEMENT_REVIEW.md) |
| UI/share images | [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md), [V1_SHARING_ARCHITECTURE.md](V1_SHARING_ARCHITECTURE.md) |
| Backend/tooling | [Backend/README.md](Backend/README.md), [supabase/README.md](supabase/README.md), [DevelopmentTools/README.md](DevelopmentTools/README.md) |
| Release/privacy/website | [release evidence](STAYGRUBBY_V1_RELEASE_READINESS_REVIEW.md), [Website/README.md](Website/README.md), canonical policy, current release stage in the Master Roadmap |

Repository evidence is the source of implementation detail. Hosted counts/hashes and past test totals in review files are dated observations, not live guarantees or instructions to rerun everything. No app, hosted, data or release changes were performed in this documentation re-tool.
