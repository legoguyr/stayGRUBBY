# StayGrubby Master Roadmap

**Canonical roadmap — reconciled November 4, 2026.** This is the existing Master Roadmap, consolidated rather than duplicated as PRODUCT_ROADMAP.md. [AGENTS.md](AGENTS.md) governs how work proceeds; [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md) describes actual current implementation. Planned items are not implementation or deployment authorization.

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
| Social foundation | Optional identity/avatar, mutual Sous Chefs/requests, explicit friends-only chronological Grub List, Hands/comments, blocks/reports, sharing preferences, Shared Cooking and in-app Order Up! implemented; Run It Back capability retained but its entry points hidden in Stage 4 |
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

## CURRENT — iOS compatibility expansion before functional TestFlight preparation

The owner requested iOS 17 first, falling back to 18 only for disproportionate rewrites. iOS 17.0 compiles with small native toolbar fallbacks; SwiftData/Observation and accepted ranking remain intact. Gemini is the only active V1 AI Recipe provider, with Apple generation removed from compilation. The separately approved hosted sync guard prevents incompatible older builds from overwriting assessment-aware data. [Compatibility evidence](IOS_COMPATIBILITY_REVIEW.md). Older-iOS physical smoke remains required; no Release Gate or TestFlight upload starts automatically. Post-V1 priorities are unchanged.

## PREVIOUS — V1 Ranking Integrity & Final UX Corrections

Owner physical feedback after `094c178` explicitly reopened ranking for an evidenced re-ranking acquisition/commit mismatch. This correction preserves comparisons/IDs and uses explicit assessment boundaries plus model-aware stopping, with focused Kitchen search, Recipe actions/multi-send and content-first cleanup. [Evidence](V1_RANKING_INTEGRITY_REVIEW.md). Owner physical acceptance remains pending; afterward proceed directly to the existing V1 Release Gate. No next feature stage, release-gate execution or distribution is begun here. Post-V1 priorities remain unchanged.

## PREVIOUS — V1 Product Closeout

Owner Stage 5 physical feedback reopened only the compact Kitchen Recipe sheet, meaningful version labels, consistent Recipe/Dish actions, new-Recipe Sous-Chef-default audience, editor copy, creator provenance and distinct privacy-aware Recipe-created Grub List activity. This is a contained V1 correction, not a new feature stage. [Evidence](V1_PRODUCT_CLOSEOUT_REVIEW.md). Focused automated acceptance has passed; owner physical recheck is pending. Proceed immediately to the release gate after that recheck, without another normal feature stage.

## CURRENT — Stage 5: Final Product Polish & V1 Readiness

Stages 1–4 implementation is complete through `7a2f7a3`; Stage 5 automated acceptance has passed, with owner physical acceptance pending. Stage 5 replaces the planned Photography stage and is the final normal product-development stage before the release gate. Existing photos/multi-photo ownership/sync are sufficient for V1 and frozen except evidenced regressions. Stage 5 hides conversion controls, adds authorized owned-Recipe Kitchen previews and resolves material whole-app consistency defects. No new normal feature stage begins automatically. See [Stage 5 scope/evidence](NEXT_RELEASE_STAGE_5_REVIEW.md).

## Required first App Store release milestone

**Stages 1–4 complete → Stage 5 Final Product Polish → V1 Product Closeout → Pre-App-Store Trust/Safety/Privacy/Compliance Gate → Release Candidate → APP STORE V1 → post-V1 development.** Privacy/moderation/security dependencies may move earlier. No submission/distribution is authorized by a development checkpoint.

App Store V1 is a concrete required milestone, not a horizon optional ideas may repeatedly postpone. When proposing work classify it as **required before V1**, **desirable but deferrable**, or **post-V1**. Require before V1 only what product coherence, safety/privacy/platform compliance, data integrity and a credible first public version need; strongly prefer deferring optional expansion. Adjust dependencies dynamically without casually moving release farther away.

## Confirmed future directions — not Stage 4 implementation

- **Privacy + Ownership:** account maximum audience Public / Sous Chefs Only / Private, with per-item Private / Sous Chefs / Public bounded by that maximum. New cooks/Recipes private by default; Private Notes always owner-only. Full hybrid privacy, privacy-aware sharing and revocation require their own deliberate phase; minimum release-critical safety may precede V1.
- **Post-App-Store V1 — Saved Recipes (final name TBD):** eventually distinguish owned/imported Recipes from bookmarks to another creator's original. Bookmarks preserve ownership/attribution, access revocation/deletion/unavailability and removal. Save as New is an independent owned copy with provenance, not bookmarking; cooking is separate from ownership. Naming remains open; “Recipe Box” is not confirmed. This bookmark area is explicitly after App Store V1; do not implement it in Stage 4.
- **Post-App-Store V1 — Recipe Social History:** privacy-aware “Made X times”, authorized cooking versions connected to their Recipe and creator attribution. Private cooking must never leak through counts, identities or linked versions; access changes must be respected. This is future work, not a new counter/history implementation in Stage 4.
- **Moderation + Administration:** secure roles, report review/resolution, moderation/suspension/ban/restoration, audit trail and tester management; entitlements separate from roles. Required safety/compliance operations belong before release, broader dashboards/admin growth after V1. No dashboard is implemented in Stage 4.
- **Invitations / premium exploration:** later explicit phases; no current Recipe-sharing paywall. Monetization requires explicit owner approval.
- **Source taxonomy direction:** My Own, Online, Cookbook, Restaurant, Friend / Family, Sous Chef, Other. Manual entry remains. Later URL/cookbook/restaurant metadata and Sous Chef identity integration may be evaluated; cookbook barcode recipe indexing remains rejected.
- **Run It Back:** hidden from current product surfaces in Stage 4, with provenance/backend/historical data preserved; future workflow requires deliberate redesign, not an assumed release prerequisite.

## Confirmed post-V1 deferrals and growth

- **Advanced photography:** crop/reposition, advanced gallery polish, optional editing and other nonessential media work. V1 keeps the working upload, ordered multi-photo, ownership and sync/restore architecture.
- **Recipe Unit Conversion:** retained implementation/tests, hidden in normal V1 readers after physical reliability failures. Improve post-V1; serving scaling remains V1.
- **Social Discovery & Growth:** better people discovery, privacy-authorized public content/feed, optional Contacts, referral/invite links, successful-signup attribution/analytics and abuse protection. A referral counts only after a genuinely new user successfully signs up through the attributed path, never on a sent/clicked link.
- **Referral/Entitlement exploration:** five progression tiers and approximately five successful referred signups for full progression; exact rewards undecided. Possible enhanced AI Creator/social/commenting allowances or other desirable features remain concepts, not current caps or entitlements. Core functionality must stay usable without recruiting friends.
- **Administration:** manual entitlement grants/revocation, tester access, restrictions, moderation and administrative roles. Roles and entitlements remain separate. No Stage 5 admin system, current Recipe-sharing paywall or billing configuration.
- Saved Recipes (name TBD), privacy-aware Recipe Social History, Source metadata expansion and deliberate Run It Back redesign remain post-V1 as specified above. Optional growth must not displace App Store V1.

## LATER — deferred product development

This preserves the established broader progression after the nearer Recipe cycles. It is not a V1 backlog to implement all at once.

| Sequence | Planned scope / boundary |
| --- | --- |
| Social/notification hardening | Reliable Sous Chef and in-app notification behavior; timing depends on actual social changes/release risk |
| Personal History + Stats | Private history/activity/statistics from actual cooking/evidence; no ranking retuning |
| Recipe Engine / Food Library / Tickets expansion | Resume Want to Cook/Tickets as appropriate; saving never creates cooked/ranked history; source/creator attribution and eligible save/made counters |
| Public Web Sharing expansion | Authorized native pointers/minimal private-safe fallback are implemented; any broader public web content requires explicit future scope, never an implicit browsable Recipe catalog/feed |
| Social + Recipe Expansion | Stage 3 delivers existing-access Recipe/post pointers through Order Up!; broader save/cook/rank/dismiss and Tickets integrations remain future work, without chat |
| Social Polish / Push | APNs, preferences and privacy/tagging polish after reliable in-app behavior; no engagement spam |
| Challenges / Bigger Social / Community Discovery | Only after dependable personal/social/safety foundations; sponsorship cannot change personal scores |
| Creator / Commerce / broader discovery | Possible following/public-private follower migration, creator profiles/collections, partnerships and affiliate commerce; no conventional native display ads |
| Personalized Taste Intelligence & Discovery | **Final long-term major phase**, after social, Recipes, public sharing and discovery foundations |

Stars and a public/private follower model remain future product work. Mutual friendship is today's model. Tickets remain deferred from current user-facing V1 navigation; do not delete their records/domain because they are hidden.

Future Taste Intelligence may use permitted cooking/evidence, cuisines/ingredients/techniques, Recipes/sources, photos and explicit preferences to explain taste/discovery. Separate preference from execution, respect small-data uncertainty and never infer allergens/flavor with certainty from images. Recommendations, popularity, sponsorship and monetization never alter Bradley–Terry ranking. Personal ranking remains free; any future subscriptions must add genuine new value. **No new Taste Intelligence/AI infrastructure or paid service is authorized now.** Existing Recipe Creator is a separate accepted system.

## Previous Next-Version Integration — accepted baseline

Foreground social refresh/shared unread state, stable Comments/list refresh, direct Recipe availability, current/pinned Recipe links, actual own-Kitchen routing and contained hosted website correction are implemented. Focused checks plus one broader integration pass precede the checkpoint; owner two-account/device acceptance remains pending. [Review/checklist](NEXT_VERSION_INTEGRATION_REVIEW.md). This explicitly supersedes the earlier deferral of the small sharing-link dependency; public web browsing remains deferred.

## NEXT — V1 Release Gate

After public-beta learning and before App Store release, separately verify objectionable-UGC filtering/moderation, complete reporting/review/resolution operations, block/privacy enforcement, account deletion/associated UGC cleanup, published support/contact, appropriate Terms/disclaimers covering Recipe/serving estimates and ingredient-derived allergen limitations (not solely the Privacy Policy), privacy/data flows/App Store disclosures, Community Guidelines/Terms, App Review access, Social Media/age-rating submission configuration. The canonical actionable [V1 Release Gate checklist](V1_RELEASE_GATE.md) separates hard release blockers, deferrable work and post-V1. This is a planned gate, not implemented compliance or permission to distribute. See [scope and safeguards](NEXT_RELEASE_SPEC.md#formal-pre-app-store-trust--safety--compliance-gate).

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
