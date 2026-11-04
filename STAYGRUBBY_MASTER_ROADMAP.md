# StayGrubby Master Roadmap

**Canonical roadmap — reconciled November 3, 2026.** This is the existing Master Roadmap, consolidated rather than duplicated as PRODUCT_ROADMAP.md. [AGENTS.md](AGENTS.md) governs how work proceeds; [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md) describes actual current implementation. Planned items are not implementation or deployment authorization.

**DISCOVER → SAVE → COOK → RANK → REMEMBER → SHARE → INSPIRE**

Personal cooking/comparison ranking stays central. Saving, cooking, ranking and publishing are separate actions. Recipes, engagement, recommendations, sponsorship and commercial relationships never change personal ranking evidence or scores.

## CURRENT — implemented foundation

| Area | Current status / important boundary |
| --- | --- |
| Core/V1 | Actual Dish/cooks/versions, photos, Course, Dietary/Contains/Avoid, preserved hidden custom tags, Sources, search/filter, global comparison ranking, re-rank, Top Version / All Versions and numerical score unlock implemented |
| Ranking/calibration | Owner-accepted and frozen: Bradley–Terry evidence/order and reaction-conditioned displayed calibration; no manual ordering |
| Accounts/cloud/privacy | Required Apple/Supabase permanent account; isolated offline working cooking store, structured/photo sync, restore, tombstones and coordinated account deletion implemented |
| Release foundation | Static public website/policy foundation and prior App Privacy entries exist; historical 1.0 (1) Internal Only TestFlight upload succeeded; current release gates are separate below |
| Post-TestFlight Cuisine | Optional primary Dish Cuisine/custom values, selection/search/filter and hosted migration complete |
| Social foundation | Optional identity/avatar, mutual Sous Chefs/requests, explicit friends-only chronological Grub List, Hands/comments, blocks/reports, sharing preferences, Shared Cooking/Run It Back and in-app Order Up! implemented |
| V1 product correction | Four tabs, cooking/Recipe separation, My Kitchen/Settings hierarchy and accepted score calibration implemented; ranking remains independent of social |
| Food Bible foundation | Derived cooked-Dish cookbook, structured Recipe content, components, stable Recipe IDs, revision archive/link/provenance infrastructure and explicit manual Save implemented |
| Food Bible UX 2.0 | Earlier cookbook/editor/reader/search foundation implemented; Architecture V2 now supplies independent Recipe membership |
| Food Bible Architecture V2 | Independent Recipes/optional links, private Recipe photos, living revisions/history/restore/fork, exact associated-cook snapshots, deterministic serving projection and first-use Paste Recipe disclosure implemented; OWNER ACCEPTED at the Recipe + Social Integration kickoff |
| Natural/bulk ingredient entry | Deterministic offline ingredient parsing/paste, exact rational quantities and component-aware bulk entry implemented |
| Recipe Creator V1 + refinement | **OWNER PHYSICALLY ACCEPTED**, confirmed in the October 28 workflow re-tool request; accepted content/metadata/allergen/native-ordering mechanics are stable |

Recipe Creator is an intelligent cookbook editor for messy input, not merely transcription formatting. Gemini is the standard consented intelligent path; Apple infrastructure is dormant for normal creation. No daily StayGrubby cap, recurring 30-day/date expiration, secret renewal or paid billing; burst abuse protection, friendly provider cooldown and manual/deterministic fallback remain. See [current architecture](STAYGRUBBY_ARCHITECTURE.md), [Recipe Style Guide](RECIPE_STYLE_GUIDE.md) and [accepted refinement evidence](RECIPE_CREATOR_REFINEMENT_REVIEW.md).

Food Bible now includes linked and standalone Recipes exactly once. Existing Recipe identity/revisions/provenance were extended rather than replaced; no cooking/ranking data was migrated or retuned. Recipe allergens are primary for ingredient information while actual cook assertions remain intact. Tickets remain dormant; share achievements are not the future Stars system. [Architecture V2 evidence and one owner procedure](FOOD_BIBLE_ARCHITECTURE_V2_REVIEW.md).

Physical Apple account-deletion/revocation verification is intentionally deferred, not a development blocker. Owner acceptance is never inferred from automated tests. Default work is single-agent/main/one Simulator lane, with risk-based verification under AGENTS.md.

## ACCEPTED BASELINE — Recipe + Social Integration

Owner acceptance of Gemini-first v27 and Food Bible Architecture V2 (independent Dish/Recipe identities, revisions, photos, deterministic scaling and review-before-Save) was confirmed in the November 2 integration request. Those mechanics remain frozen; no more live AI calls are authorized under the exhausted grants.

The completed Recipe + Social checkpoint implements deliberate friends-visible Recipe attachments on existing cook posts, pinned historical reading, Recipe descriptions throughout sharing/history, independent private forks and Run It Back/Shared Cooking snapshot integration. Existing chronological Grub List/Hands/comments remain post-centered. Current architecture and [integration evidence](RECIPE_SOCIAL_INTEGRATION_REVIEW.md) specify privacy/revocation/ownership. It is the baseline for the current Next-Version acceptance cycle.

Dedicated Recipe-only post types, All/Grub Ranks/Recipes filters and automatic Recipe-update posts remain deferred. The current Next-Version cycle completes the scoped Sous Chef/notification refresh and indication work; it adds no APNs.

## CURRENT — Next Release: Stage 1 foundation + Stage 2 core UI

The owner considers `b9871df88930699f22ed80b2c586996e4775ebd8` sufficiently accepted to continue. The [canonical next-release specification](NEXT_RELEASE_SPEC.md) owns the staged UI/UX/product scope: shared branding/primitives/copy; New Dish/metadata/text/tagging; Kitchen/profiles/Signature Dishes/discovery; social/Comments/Order Up!/sharing; Food Bible/Recipe actions; multi-photo UI and secondary-screen/accessibility polish.

Stage 1 completed reusable UI/header infrastructure, additive Dish Public Description/Private Notes and safe bounded multi-photo support. Stage 2 adopts those foundations in New Dish/edit, compact metadata/tagging, My Kitchen/authorized profiles, photographic Signature Dishes, Grub List and Grub Rank surrounding presentation. The focused Stage 2 owner-correction pass compacts entry/Details/sharing/profile controls, aligns Signature scores, stabilizes feed metadata/ages, adds read-only Grub Rank browsing sorts and improves native tab clearance. Owner visual recheck is pending. Custom Tags/Halal selection are hidden with stored compatibility preserved. Following/Followers remain a future social-product decision: only mutual Sous Chefs exist today. Existing native overflow remains preferable to duplicating long-press inventories. Stage 3 retains Comments/discovery/Order Up!/sharing corrections; later stages retain Food Bible/Recipe controls, full gallery/crop and the final system-wide pass. See [Stage 2 evidence](NEXT_RELEASE_STAGE_2_REVIEW.md). Do not begin Stage 3 automatically.

Owner findings carried forward as **mandatory Social + Sharing work**: profile sharing physically works; Recipe links behave like a download in the browser; Ranking/Dish copy/share is not useful in the tested flow. Two-device social acceptance is still pending and nonblocking. Earlier automated link evidence does not supersede those physical findings. Stage 1 does not repair these defects unless directly affected by its data changes.

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

## Previous Next-Version Integration — accepted baseline

Foreground social refresh/shared unread state, stable Comments/list refresh, direct Recipe availability, current/pinned Recipe links, actual own-Kitchen routing and contained hosted website correction are implemented. Focused checks plus one broader integration pass precede the checkpoint; owner two-account/device acceptance remains pending. [Review/checklist](NEXT_VERSION_INTEGRATION_REVIEW.md). This explicitly supersedes the earlier deferral of the small sharing-link dependency; public web browsing remains deferred.

## Pre-App-Store Trust & Safety / Compliance — formal future gate

After public-beta learning and before App Store release, separately verify objectionable-UGC filtering/moderation, complete reporting/review/resolution operations, block/privacy enforcement, account deletion/associated UGC cleanup, published support/contact, privacy/data flows/App Store disclosures, Community Guidelines/Terms, App Review access, Social Media/age-rating submission configuration. This is a planned gate, not implemented compliance or permission to distribute. See [scope and safeguards](NEXT_RELEASE_SPEC.md#formal-pre-app-store-trust--safety--compliance-gate).

## RELEASE — separate authorization and gates

Before broader external distribution, complete the relevant release work once, without treating every future idea as a release blocker:

- UGC filtering and operational moderation response: technical blocks/reports/states exist; actual safety coverage, responsible operator/cadence and response process still require release readiness.
- Two-iPhone physical Universal Links acceptance: the confirmed website redirect loop and native routing gaps are corrected; profile/post/current-Recipe/pinned-Recipe direct hosted routes and explicit app-open fallback are verified. Association caching/browser preference and recipient-device behavior still require physical acceptance.
- Launch/loading experience, including planned pasta-machine animation, under an explicit polish cycle.
- Current canonical policy (effective November 2) is published and `/privacy` works after the link-router fix. Review current App Store privacy answers, AI/social disclosures and release metadata before wider distribution. No DNS/credential workaround or distribution is authorized.
- Confirm target OS/device support, age rating, screenshots/metadata, reviewer setup/access and actual beta distribution link. Do not invent a TestFlight link.
- Explicitly approved External TestFlight preparation/Beta App Review/controlled beta; fixes as needed; Release Candidate; App Store 1.0.

Historical **1.0 (1) Internal Only upload is complete**; later feature checkpoints are not automatically uploaded. No new build number/archive/upload/App Store Connect action is authorized here. Deferred physical Apple deletion is not a reason to block unrelated development or another requirement to delete the owner's account.

Use AGENTS.md's minimum justified verification. Broader regression/Release verification belongs at an actual release checkpoint, not every documentation or feature change.

## Evidence and document ownership

Keep future planning canonical **here**. Current contracts live in [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md) and its task-specific source map. Domain specs explain implementation; historical reviews retain dated decisions, commands, tests and deployments. Old pending gates/provider preferences/counts are not current instructions.

Historical milestone evidence remains in [V1_INTEGRATION_REVIEW.md](V1_INTEGRATION_REVIEW.md), [SOCIAL_DEVELOPMENT_REVIEW.md](SOCIAL_DEVELOPMENT_REVIEW.md), [SHARED_SOCIAL_REVIEW.md](SHARED_SOCIAL_REVIEW.md), [RECIPE_TICKETS_SHARING_REVIEW.md](RECIPE_TICKETS_SHARING_REVIEW.md), [STAYGRUBBY_FOOD_BIBLE_FOUNDATION_REVIEW.md](STAYGRUBBY_FOOD_BIBLE_FOUNDATION_REVIEW.md), [STAYGRUBBY_FOOD_BIBLE_UX_2_REVIEW.md](STAYGRUBBY_FOOD_BIBLE_UX_2_REVIEW.md), [RECIPE_CREATOR_REVIEW.md](RECIPE_CREATOR_REVIEW.md), [RECIPE_CREATOR_REFINEMENT_REVIEW.md](RECIPE_CREATOR_REFINEMENT_REVIEW.md) and [release evidence](STAYGRUBBY_V1_RELEASE_READINESS_REVIEW.md). Reconciliation replaces the prior roadmap's stale launch sequence/duplicated chronology; it does not erase those historical evidence files.
