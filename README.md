# StayGrubby

Native iPhone cooking, comparison ranking, personal recipes and intentionally shared social activity. Official identity: **#stayGRUBBY**.

Start with these three sources:

1. [AGENTS.md](AGENTS.md) — permanent development rules: **how to work**.
2. [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md) — accepted current product and architecture: **what exists**.
3. [STAYGRUBBY_MASTER_ROADMAP.md](STAYGRUBBY_MASTER_ROADMAP.md) — current/next/later/release: **what comes next**.

The architecture overview indexes task-specific domain documents. Dated review files retain implementation/test/deployment evidence; they are not a competing current roadmap or instruction system. Future prompts need only name the cycle, unique requirements and acceptance criteria, referencing the three sources above.

Open `StayGrubby.xcodeproj`, scheme `StayGrubby`. Current target is iPhone, upright portrait only. Do not reset data to build or review the app. See the architecture overview for account/development isolation and existing verification tools.

Recipe Creator uses the [Gemini-first boundary](STAYGRUBBY_ARCHITECTURE.md#recipe-creator--gemini-first-contract-4): Gemini constructs content, the app validates structure, and the user reviews before Save. [Style guidance](RECIPE_STYLE_GUIDE.md) is content guidance, not a source vocabulary gate.

Current Next-Version social, notification, sharing-link and presentation integration: [evidence and owner acceptance](NEXT_VERSION_INTEGRATION_REVIEW.md).

Next release: [approved staged specification](NEXT_RELEASE_SPEC.md), [Stage 1 foundation evidence](NEXT_RELEASE_STAGE_1_REVIEW.md), [Stage 2 core UI evidence](NEXT_RELEASE_STAGE_2_REVIEW.md), [Stage 3 social/sharing evidence](NEXT_RELEASE_STAGE_3_REVIEW.md), [Stage 4 Food Bible/Recipe and owner-correction evidence](NEXT_RELEASE_STAGE_4_REVIEW.md).
