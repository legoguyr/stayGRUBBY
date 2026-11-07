# StayGrubby Master Roadmap

**Canonical roadmap — reconciled November 7, 2026 at Build 4 (`c09c18e`).** This is the only future-sequencing document. [AGENTS.md](AGENTS.md) governs how work proceeds; [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md) describes what is implemented; [PERSONAL_COOKING_INTELLIGENCE.md](PERSONAL_COOKING_INTELLIGENCE.md) holds the long-term intelligence direction and data inventory. Planned items are not implementation, deployment or distribution authorization. Post-V1 order is not final: sequence by dependencies, tester feedback and capacity.

**DISCOVER → SAVE → COOK → RANK → REMEMBER → SHARE → INSPIRE.** Personal cooking and comparison ranking stay central. Recipes, engagement, recommendations, sponsorship and commerce never change personal ranking evidence or scores.

When proposing work classify it as **required before V1**, **desirable but deferrable**, or **post-V1**. Only product coherence, safety/privacy/platform compliance, data integrity and a credible first public release justify moving something ahead of V1.

## NOW — Build 4 / TestFlight

**Complete.** StayGrubby 1.0 (4) is uploaded and processing; owner controls tester groups, notes and notifications. Owner physical acceptance passed for ranking, Already Shared, Recipe navigation/sharing, Edit Cook tagging and Universal Links. The November 7 production website regression (assets-only publish) is recovered and guarded by `Website/deploy-production.sh`. Tester feedback continues; Build 4 functionality reopens only for genuine regressions. [Architecture: Build 4](STAYGRUBBY_ARCHITECTURE.md#current-state--build-4).

## NEXT — System-wide UI overhaul (Stages A–G)

A true consolidation of shared components and patterns, not per-screen polish, and no unrelated major functionality. Plan, component candidates and the queued defect list: [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md#9-system-wide-ui-overhaul--plan-planned-not-started).

| Stage | Scope |
| --- | --- |
| A — Foundations | Shared photo/score/state/section/toolbar foundations, spacing tokens, low-risk confirmed defects |
| B — Pickers / Search / Filtering | Selectors, filter bars, search |
| C — Sharing | Post to Grub List vs external Share; one Share action with image + short `#stayGRUBBY` message + exact link |
| D — Detail screens | Dish / Recipe Detail |
| E — Social / Kitchens | Grub List, Tickets relocated to Grub List, My Kitchen stats (Dishes Ranked → Grub Rank · Recipes → Food Bible · Sous Chefs → Sous Chefs), Sous Chef Kitchen, Requests; tagged collaborators on cards |
| F — Forms / Editors | New Dish, New Version, Edit Cook, Recipe editor |
| G — Copy / Celebrations / Final consolidation | Copy purge, ranking results and celebrations, accessibility/consistency |

**Required pre-V1 investigation — Grub Rank score/order semantic consistency.** Displayed score is reaction-banded while order is Bradley–Terry strength, so a lower-ranked entry can show a higher score (observed #9 · 2.6 above #11 · 7.6). Investigate how to keep score and order understandable while preserving all evidence, history, re-rank behavior, calibration and uncertainty. Investigation first; any math/calibration change needs explicit owner reopening. It must conclude before Stage G finalizes result/celebration presentation. [Mechanism](STAYGRUBBY_ARCHITECTURE.md#ranking--protected).

Each stage: implement → focused verification → owner acceptance where needed → update canonical docs as decisions become durable.

## THEN — V1 Release Gate

Moderation (UGC filtering, report → review → resolution, block enforcement), privacy/security review, account deletion and UGC cleanup review, Terms, Community Guidelines, Privacy Policy, Recipe/allergen/serving disclaimers, support/contact, Apple App Privacy, age rating, App Review access/sign-in, production configuration, advisories (leaked-password warning, production `development-test-session` function), incompatible-build retirement. Checklist: [V1_RELEASE_GATE.md](V1_RELEASE_GATE.md). Privacy/moderation dependencies may move earlier.

## THEN — Release Candidate

Final TestFlight release candidate, one proportionate broader regression and Release verification, physical acceptance (including two-device Universal Links and real-device photos/auth/sync/sharing). Archive, build-number change, upload and distribution each need explicit owner approval.

## THEN — App Store V1

Metadata, screenshots, reviewer instructions, switch `Website/distribution.json` to the App Store listing and redeploy the full Worker, submission with explicit owner approval.

**V1 scope:** reliable cooking records, Grub Rank, Food Bible/Recipe workflows, My Kitchen, Sous Chefs, chronological Grub List, sharing, authentication/sync, privacy/account controls, moderation/compliance and polished dependable UX. **Not V1:** Discover, Personal Cooking Intelligence, Want to Cook, Collections, advanced recommendations.

## POST-V1 — near / medium term (approved or established; order not final)

- **Want to Cook** — cooking intention distinct from cooking; bookmark + attributed cooking workflow. [Concept](PERSONAL_COOKING_INTELLIGENCE.md#5-approved-future-concepts-not-implemented)
- **Saved Recipes** refinement — bookmarks to a Sous Chef's original, attribution preserved; depends on access-control maturity
- **Recipe Social History / recreation statistics** — precise, privacy-safe "Made X times"
- **Privacy/access-control evolution** — account maximum audience Public / Sous Chefs Only / Private with per-item visibility bounded by it; new items private by default
- **Collections / Cooking Series** (name not final) — Collection ↔ Dish many-to-many thematic context, distinct from Versions
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

Hidden but retained (not rejected): Custom Tags, Halal Dietary option, Run It Back entry points, unit-conversion controls, dormant Want to Cook storage.

## Evidence and document ownership

Future planning lives **here** only. Historical stage plans and reviews ([NEXT_RELEASE_SPEC.md](NEXT_RELEASE_SPEC.md), stage reviews, [V1_PRODUCT_CLOSEOUT_REVIEW.md](V1_PRODUCT_CLOSEOUT_REVIEW.md), [V1_RANKING_INTEGRITY_REVIEW.md](V1_RANKING_INTEGRITY_REVIEW.md), [NEXT_TESTFLIGHT_IMPROVEMENTS_REVIEW.md](NEXT_TESTFLIGHT_IMPROVEMENTS_REVIEW.md) and earlier milestone reviews) retain dated decisions, commands, tests and deployments; their pending gates and sequences are not current instructions. Owner acceptance is never inferred from automated tests.

### Required first App Store release milestone

**Build 4 → UI overhaul (A–G, with the score/order investigation) → V1 Release Gate → Release Candidate → App Store V1 → post-V1.** App Store V1 is a concrete milestone that optional ideas must not keep postponing. No submission or distribution is authorized by a development checkpoint.
