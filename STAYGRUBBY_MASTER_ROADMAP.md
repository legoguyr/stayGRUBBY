# StayGrubby Master Roadmap

**Canonical roadmap — reconciled October 28, 2026.** This is the existing Master Roadmap, consolidated rather than duplicated as PRODUCT_ROADMAP.md. [AGENTS.md](AGENTS.md) governs how work proceeds; [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md) describes actual current implementation. Planned items are not implementation or deployment authorization.

**DISCOVER → SAVE → COOK → RANK → REMEMBER → SHARE → INSPIRE**

Personal cooking/comparison ranking stays central. Saving, cooking, ranking and publishing are separate actions. Recipes, engagement, recommendations, sponsorship and commercial relationships never change personal ranking evidence or scores.

## CURRENT — implemented foundation

| Area | Current status / important boundary |
| --- | --- |
| Core/V1 | Actual Dish/cooks/versions, photos, Course, Dietary/Contains/Avoid/custom tags, Sources, search/filter, global comparison ranking, re-rank, Top Version / All Versions and numerical score unlock implemented |
| Ranking/calibration | Owner-accepted and frozen: Bradley–Terry evidence/order and reaction-conditioned displayed calibration; no manual ordering |
| Accounts/cloud/privacy | Required Apple/Supabase permanent account; isolated offline working cooking store, structured/photo sync, restore, tombstones and coordinated account deletion implemented |
| Release foundation | Static public website/policy foundation and prior App Privacy entries exist; historical 1.0 (1) Internal Only TestFlight upload succeeded; current release gates are separate below |
| Post-TestFlight Cuisine | Optional primary Dish Cuisine/custom values, selection/search/filter and hosted migration complete |
| Social foundation | Optional identity/avatar, mutual Sous Chefs/requests, explicit friends-only chronological Grub List, Hands/comments, blocks/reports, sharing preferences, Shared Cooking/Run It Back and in-app Order Up! implemented |
| V1 product correction | Four tabs, cooking/Recipe separation, My Kitchen/Settings hierarchy and accepted score calibration implemented; ranking remains independent of social |
| Food Bible foundation | Derived cooked-Dish cookbook, structured Recipe content, components, stable Recipe IDs, revision archive/link/provenance infrastructure and explicit manual Save implemented |
| Food Bible UX 2.0 | Cookbook/Choose Dish search and photography, Recipe editor/reader and hosted cookbook search implemented; normal cookbook remains Dish-linked |
| Natural/bulk ingredient entry | Deterministic offline ingredient parsing/paste, exact rational quantities and component-aware bulk entry implemented |
| Recipe Creator V1 + refinement | **OWNER PHYSICALLY ACCEPTED**, confirmed in the October 28 workflow re-tool request; accepted content/metadata/allergen/native-ordering mechanics are stable |

Recipe Creator is an intelligent cookbook editor for messy input, not merely transcription formatting. Gemini is the standard consented intelligent path; Apple infrastructure is dormant for normal creation. No daily StayGrubby cap, recurring 30-day/date expiration, secret renewal or paid billing; burst abuse protection, friendly provider cooldown and manual/deterministic fallback remain. See [current architecture](STAYGRUBBY_ARCHITECTURE.md), [Recipe Style Guide](RECIPE_STYLE_GUIDE.md) and [accepted refinement evidence](RECIPE_CREATOR_REFINEMENT_REVIEW.md).

Current backend Recipe identity/revisions and preserved unlinked Recipes do **not** establish the standalone Recipe product planned next. Existing RecipeCook snapshots do **not** establish universal exact-revision binding for every CookingAttempt. Recipe photos and serving scaling are not implemented. Tickets/Want to Cook remain implemented infrastructure/data but dormant in normal V1 surfaces. Existing factual share achievements are not the future Stars system.

Physical Apple account-deletion/revocation verification is intentionally deferred, not a development blocker. Owner acceptance is never inferred from automated tests. Default work is single-agent/main/one Simulator lane, with risk-based verification under AGENTS.md.

## NEXT — Food Bible Architecture V2 (PLANNED, NOT IMPLEMENTED)

Goal: make Recipes independent, living cookbook objects while preserving actual cooking history, ranking, attribution and privacy. Build on the existing UUIDs, revision archive, explicit links and snapshots rather than replacing them.

Planned scope:

- Recipe and Dish can each exist without the other, with optional explicit Recipe ↔ Dish linking and standalone Recipe creation.
- Recipe-owned photo infrastructure, separate from cook-photo ownership, reusing safe private media patterns.
- Stable Recipe identity/current revision, immutable historical revisions, living revision/history UX and **Save as New Recipe** for meaningful divergence.
- An actual CookingAttempt preserves the exact Recipe revision/snapshot used; later edits do not rewrite cooking history.
- Deterministic serving/yield scaling using existing exact rational foundations; AI does not perform quantity/unit math.
- Simplified Paste Recipe with Gemini as standard intelligent implementation, just-in-time external-AI disclosure before first use, no redundant global AI toggle, and a corresponding privacy-policy update. This UX is planned; existing explicit consent must remain until replaced safely.
- Begin Recipe/Dish metadata ownership cleanup. Recipe allergens become the primary ingredient-derived surface; determine cuisine ownership/projections from architecture evidence. Do not casually remove existing cook assertions or backfill classifications.
- Short Recipe description if appropriate to the architecture, reusing the existing optional content field.

Keep accepted Creator mechanics and ranking frozen. This documentation task does not authorize implementation, schema deployment, data migration or media transport. A future cycle should explicitly scope implementation/checkpoints against these goals.

## AFTER V2 — Social Recipe Sharing + Description Improvements (PLANNED)

- Make short Dish/CookingAttempt public descriptions apparent; keep Personal Notes private.
- Recipe short descriptions, Recipe-only posts, rank-only posts and combined linked ranking + Recipe posts.
- Deliberate deduplication: no duplicate/spam posts; Recipe edits do not automatically publish. Optional update sharing is a later explicit choice.
- Grub List filters such as **All / Grub Ranks / Recipes**; Recipe posts open the Recipe.
- Preserve creator/source attribution, revision provenance and Run It Back integration without copying another person's ranking.
- Broader Sous Chef/notification overhaul, including the observed **Tag a Sous Chef notification issue**. Existing in-app notifications are not a claim that this issue is resolved.

## THEN — dedicated Food Bible / Recipe UI overhaul (PLANNED)

Design around the settled architecture: exceptionally functional, clean, fast, beautiful, photo-forward and distinctly StayGrubby.

Cover cookbook browsing, Recipe reader/create/edit, serving scaling, Recipe photos, revision/history, standalone/linking, metadata/allergens, keyboard response, reorder interaction, accessibility, restrained motion and light/dark appearance. Reuse accepted components and content mechanics. Do not redesign prematurely during the architecture task.

## LATER — deferred product development

This preserves the established broader progression after the nearer Recipe cycles. It is not a V1 backlog to implement all at once.

| Sequence | Planned scope / boundary |
| --- | --- |
| Social/notification hardening | Reliable Sous Chef and in-app notification behavior; timing depends on actual social changes/release risk |
| Personal History + Stats | Private history/activity/statistics from actual cooking/evidence; no ranking retuning |
| Recipe Engine / Food Library / Tickets expansion | Resume Want to Cook/Tickets as appropriate; saving never creates cooked/ranked history; source/creator attribution and eligible save/made counters |
| Public Web Sharing | Explicit native deep links to authorized destinations; minimal app-first fallback, not a public browsable Recipe catalog/feed or native-app replacement |
| Social + Recipe Expansion / Send to Friend | Friend-directed Recipe/dish sharing, notifications, save/cook/rank/dismiss; no full chat platform without demonstrated need |
| Social Polish / Push | APNs, preferences and privacy/tagging polish after reliable in-app behavior; no engagement spam |
| Challenges / Bigger Social / Community Discovery | Only after dependable personal/social/safety foundations; sponsorship cannot change personal scores |
| Creator / Commerce / broader discovery | Possible following/public-private follower migration, creator profiles/collections, partnerships and affiliate commerce; no conventional native display ads |
| Personalized Taste Intelligence & Discovery | **Final long-term major phase**, after social, Recipes, public sharing and discovery foundations |

Stars and a public/private follower model remain future product work. Mutual friendship is today's model. Tickets remain deferred from current user-facing V1 navigation; do not delete their records/domain because they are hidden.

Future Taste Intelligence may use permitted cooking/evidence, cuisines/ingredients/techniques, Recipes/sources, photos and explicit preferences to explain taste/discovery. Separate preference from execution, respect small-data uncertainty and never infer allergens/flavor with certainty from images. Recommendations, popularity, sponsorship and monetization never alter Bradley–Terry ranking. Personal ranking remains free; any future subscriptions must add genuine new value. **No new Taste Intelligence/AI infrastructure or paid service is authorized now.** Existing Recipe Creator is a separate accepted system.

## RELEASE — separate authorization and gates

Before broader external distribution, complete the relevant release work once, without treating every future idea as a release blocker:

- UGC filtering and operational moderation response: technical blocks/reports/states exist; actual safety coverage, responsible operator/cadence and response process still require release readiness.
- Physical Universal Links verification/fix: native profile-route/AASA/fallback infrastructure exists, but physical behavior is owner-reported broken/deferred. Do not label it verified from configuration alone.
- Launch/loading experience, including planned pasta-machine animation, under an explicit polish cycle.
- Publish the latest tested canonical policy on the existing site; review privacy/AI/social disclosures and current App Store privacy answers. Latest local clarification is effective October 27; the refinement checkpoint did not publish it.
- Confirm target OS/device support, age rating, screenshots/metadata, reviewer setup/access and actual beta distribution link. Do not invent a TestFlight link.
- Explicitly approved External TestFlight preparation/Beta App Review/controlled beta; fixes as needed; Release Candidate; App Store 1.0.

Historical **1.0 (1) Internal Only upload is complete**; later feature checkpoints are not automatically uploaded. No new build number/archive/upload/App Store Connect action is authorized here. Deferred physical Apple deletion is not a reason to block unrelated development or another requirement to delete the owner's account.

Use AGENTS.md's minimum justified verification. Broader regression/Release verification belongs at an actual release checkpoint, not every documentation or feature change.

## Evidence and document ownership

Keep future planning canonical **here**. Current contracts live in [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md) and its task-specific source map. Domain specs explain implementation; historical reviews retain dated decisions, commands, tests and deployments. Old pending gates/provider preferences/counts are not current instructions.

Historical milestone evidence remains in [V1_INTEGRATION_REVIEW.md](V1_INTEGRATION_REVIEW.md), [SOCIAL_DEVELOPMENT_REVIEW.md](SOCIAL_DEVELOPMENT_REVIEW.md), [SHARED_SOCIAL_REVIEW.md](SHARED_SOCIAL_REVIEW.md), [RECIPE_TICKETS_SHARING_REVIEW.md](RECIPE_TICKETS_SHARING_REVIEW.md), [STAYGRUBBY_FOOD_BIBLE_FOUNDATION_REVIEW.md](STAYGRUBBY_FOOD_BIBLE_FOUNDATION_REVIEW.md), [STAYGRUBBY_FOOD_BIBLE_UX_2_REVIEW.md](STAYGRUBBY_FOOD_BIBLE_UX_2_REVIEW.md), [RECIPE_CREATOR_REVIEW.md](RECIPE_CREATOR_REVIEW.md), [RECIPE_CREATOR_REFINEMENT_REVIEW.md](RECIPE_CREATOR_REFINEMENT_REVIEW.md) and [release evidence](STAYGRUBBY_V1_RELEASE_READINESS_REVIEW.md). Reconciliation replaces the prior roadmap's stale launch sequence/duplicated chronology; it does not erase those historical evidence files.
