# StayGrubby

Native iPhone cooking journal with comparison ranking, personal Recipes (Food Bible) and intentionally shared social activity. Official identity: **#stayGRUBBY**.

**Current state (November 7, 2026):** Build 1.0 (4) is uploaded to TestFlight (`c09c18e`). November 8: `agent/claude` integrated into local `main`; D1 Unified Dish Foundation implemented; the lifecycle and Dish Recipe links migrations are deployed. D2 Unified Dish Detail implemented and its Food Bible index migration deployed. One Dish identity (Dish and Recipe as two views of one Dish) implemented and deployed. Stage F creation/linking implemented (feature flag migration awaits authorized deployment). Next: rest of F (deferrable) → C → E → G → V1 Release Gate → Release Candidate → App Store V1.

## Read first

| Document | Answers |
| --- | --- |
| [AGENTS.md](AGENTS.md) | How to work: rules, vocabulary, protected systems, verification, Git/deployment |
| [PARALLEL_DEVELOPMENT.md](PARALLEL_DEVELOPMENT.md) | Where to open Claude and Codex, refresh branches, and integrate accepted work |
| [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md) | What exists now: product, Build 4 state, system map, ranking, Recipes, sync/photos, Supabase, social, links/website, privacy, fixtures |
| [STAYGRUBBY_MASTER_ROADMAP.md](STAYGRUBBY_MASTER_ROADMAP.md) | What comes next: NOW / NEXT / THEN / post-V1 / long term / rejected |

## Then, by task

| Document | Purpose |
| --- | --- |
| [FOOD_ARCHITECTURE.md](FOOD_ARCHITECTURE.md) | One Dish over separate Dish/Recipe/cook records: relationships, Main Recipe, renameable cooks and final terminology, as written vs as made, lenses and filters, Add Recipe / Cook Again flows, reusable Dish UI parts |
| [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md) | Current design-system spec, known UI defects, overhaul stages and their run order |
| [V1_RELEASE_GATE.md](V1_RELEASE_GATE.md) | V1 release requirements and state |
| [PERSONAL_COOKING_INTELLIGENCE.md](PERSONAL_COOKING_INTELLIGENCE.md) | Long-term intelligence direction, per-cycle data check, verified data inventory, Want to Cook / Collections concepts |
| [Website/README.md](Website/README.md) | Cloudflare Worker, Universal Link fallbacks, safe production deployment |
| [Backend/README.md](Backend/README.md), [supabase/README.md](supabase/README.md), [DevelopmentTools/README.md](DevelopmentTools/README.md) | Backend tooling, hosted deployment history, development tools |
| Domain specs | [COOKING_MODEL.md](COOKING_MODEL.md), [RANKING_MODEL.md](RANKING_MODEL.md), [ACCOUNT_ARCHITECTURE.md](ACCOUNT_ARCHITECTURE.md), [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md), [MEDIA_SYNC_ARCHITECTURE.md](MEDIA_SYNC_ARCHITECTURE.md), [SOCIAL_ARCHITECTURE.md](SOCIAL_ARCHITECTURE.md), [V1_SHARING_ARCHITECTURE.md](V1_SHARING_ARCHITECTURE.md), [RECIPE_STYLE_GUIDE.md](RECIPE_STYLE_GUIDE.md) |

All other `*_REVIEW.md` files, [NEXT_RELEASE_SPEC.md](NEXT_RELEASE_SPEC.md) and [UI_ARCHITECTURE_HISTORY.md](UI_ARCHITECTURE_HISTORY.md) are dated evidence. They are not a competing roadmap or instruction system, and their pending gates/counts are not current. Future prompts need only name the cycle, its unique requirements and acceptance criteria.

## Build

Open `StayGrubby.xcodeproj`, scheme `StayGrubby`. iOS 17.0 minimum, iPhone upright portrait only. Do not reset data to build or review; Debug review fixtures require an isolated `--ui-test-store <UUID>` (see [fixture rules](STAYGRUBBY_ARCHITECTURE.md#debug-fixtures-and-test-safety)).

Recipe Creator uses the [Gemini-first boundary](STAYGRUBBY_ARCHITECTURE.md#recipe-creator--gemini-first-contract-4): Gemini is the only V1 AI provider; the app validates structure and the user reviews before Save. The production website is deployed only with `sh Website/deploy-production.sh`; assets-only publishing is invalid. No distribution is authorized by a development checkpoint.
