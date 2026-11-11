# StayGrubby development instructions

Before substantial work, read this file, [current architecture](STAYGRUBBY_ARCHITECTURE.md), [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md), and only the domain documents relevant to the task. [README](README.md) is the document index. Do not load every historical review by default.

## Authority and scope

Within repository guidance, precedence is: **explicit current task → AGENTS.md → canonical current architecture/product documents → domain documents → historical reviews**. Platform/system/developer requirements still apply. Follow a scoped prompt override and document the exception. Historical evidence must not override current product truth.

Work autonomously within the requested cycle; resolve routine engineering choices from repository evidence. Refactors, tests, safe migrations, scoped bug fixes, documentation, coherent commits and normal pushes are permitted within scope. Supabase migration/function deployment requires authorization in the current cycle. Escalate consequential ambiguity, destructive operations, security/credential issues, billing, production-user risk or material scope expansion; do not seek routine approvals.

Keep **one primary agent per task and one Simulator/UI-test lane**. Claude and Codex develop only in their permanent `agent/claude` and `agent/codex` worktrees. `main` is the integration and release source of truth. The owner or an agent with explicit integration authorization uses the `main` checkout for that work. See [opening, synchronization and integration steps](PARALLEL_DEVELOPMENT.md).

Before editing, verify the checkout path, branch, HEAD and status. Fetch and fast-forward the assigned branch from the latest accepted `main` using the documented procedure. Preserve existing work if the checkout is dirty or the branch has diverged. After integration, refresh each agent branch from the accepted `main` in its own worktree.

Assign non-overlapping implementation areas. Commit only work owned by the current task. Never edit, stash, reset, clean or revert another agent's worktree. Resolve canonical-document conflicts during authorized integration so both accepted changes survive. Keep Simulator, device and deployment activity coordinated because these resources are shared. Creating additional worktrees or delegating to subagents still requires explicit direction.

Preserve accepted/frozen systems unless the prompt reopens them or an evidenced regression/dependency requires the smallest safe fix. Explain that exception. Do not retune accepted ranking/calibration, unlocking, photo sync or Recipe Creator behavior for hypothetical improvement.

## Identity and design

- Product/brand: **StayGrubby / #stayGRUBBY**. Project, target, scheme, executable and module: `StayGrubby`; tests: `StayGrubbyTests`, `StayGrubbyUITests`; project: `StayGrubby.xcodeproj`; bundle: `com.guyrettig.StayGrubby`; repository: `legoguyr/StayGrubby`.
- Do not restore old branding. Legacy names and the historical checkout path belong only to intentional compatibility/history.
- Reuse the official asset-catalog wordmark/icons; never reconstruct the wordmark typography. Cream `#FAF3EC`, charcoal `#1F1F1F`; canonical logo red is **`#F10607`**, as recorded in `SGTheme.Brand.red`, taking precedence over conceptual `#FF2D1F`. Reuse adaptive control tokens, not literal export colors, for accessible controls.
- Design for editorial food photography, contemporary restaurant identity and polished native interaction: strong type, whitespace and restrained motion. Avoid generic gradients, excessive glass, glowing buttons, kitschy chef/fork decoration and stock controls where an accepted StayGrubby pattern exists.
- iPhone is upright portrait only. Preserve Dynamic Type, Reduce Motion, light/dark readability, contrast and appropriate touch targets (normally at least 44 points). Consult [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md) and existing design-system components.

Use established vocabulary where appropriate:

| Concept | Product wording |
| --- | --- |
| Ranking / #1 / Top 3 | Grub Rank / Signature Dish / Signature Dishes |
| Friends Feed / Profile | Grub List / My Kitchen |
| Friends / friend requests | Sous Chefs / Requests |
| Cooked Together tagging | Tag a Sous Chef 🧑‍🍳 |
| Likes / Like action | Hands 🙌 / Give Hands 🙌 |
| Notifications / new notification / Recreate | Tickets 🎟️ / New Ticket / Run It Back (entry points hidden) |
| Internal publish / external share | Post to Grub List / Share |
| Cook from a Recipe | Rank My Version |
| Cooking Attempt / its name / unnamed fallback | cook ("3 cooks") / Cook Name / Version N |
| Make the Dish again / show every cook / Recipe revisions | Cook Again / All Cooks / Recipe History |
| Delete (restrained) | 86 (Delete), 86 Dish/Recipe/Cook/Comment/Post; Delete Account stays conventional |
| Future achievements / intention list | Stars ⭐ / Want to Cook (approved post-V1) |

Keep utility wording clear: Comments, Search, Settings, Edit, Delete, Block, Report, Share, New Dish, Cook Again, View Recipe, Re-rank. Dish is the user-facing name for the combined food identity; "version" is not a user-facing noun for cooks or Recipe revisions (see [FOOD_ARCHITECTURE.md](FOOD_ARCHITECTURE.md#4-cooking-attempts-final-terminology-and-naming)). Vocabulary does not authorize future features.

## Protected ranking and reuse

Ranking is frozen unless explicitly reopened: Liked/Fine/Didn't Like initial reaction, adaptive pairwise comparisons, Too Tough tie, Skip, Undo, Bradley–Terry evidence/order, uncertainty/refinement, repeated evidence, no manual order, score unlocking and current displayed-score calibration. Recipes/social must not alter any of these. See [RANKING_MODEL.md](RANKING_MODEL.md) and its current calibration reference; do not conflate displayed score with ranking order.

### Reuse Before Reinvention

Before creating a selector, picker, sheet, popover, menu, confirmation, search/filter/sort control, metadata editor, identity/Dish/Recipe row, action family, card, toolbar or empty/loading/error state, inspect accepted StayGrubby equivalents first. Prefer **direct reuse → generalize an existing component → shared reusable component → unique implementation only for genuinely different behavior**. Apply the same language, spacing, navigation and interaction conventions across screens; location alone does not justify a different control. Avoid abstraction for its own sake. Accepted equivalents include allergen checklists, photo infrastructure, RecipeDraft/exact quantity math, design tokens, account/session boundaries, RLS and share/post renderers; justify parallel implementations.

### Living Documentation

**Repository = long-term memory. Prompt = current task.** Claude loads this same file through [CLAUDE.md](CLAUDE.md). Record durable decisions in the owning canonical document and keep task prompts focused on scope, constraints and acceptance.

Update the owning canonical document automatically when a cycle establishes a durable product, architecture, design, testing or owner decision. Keep temporary implementation/test details in dated review evidence. Future roadmap work should be classified as required before App Store V1, desirable but deferrable, or post-V1 where useful; optional features must not indefinitely delay the required first public release. Recipe estimate/quantity and ingredient-derived allergen limitations belong in appropriate Terms/disclaimer/safety coverage, not solely the Privacy Policy. Avoid repeated reader warnings; retain actionable safety, privacy and provenance information.

Canonical document roles: `AGENTS.md` rules · `STAYGRUBBY_ARCHITECTURE.md` current product/technical truth and system maps · `UI_ARCHITECTURE.md` current design-system spec, UI defect queue and overhaul stages · `STAYGRUBBY_MASTER_ROADMAP.md` sequencing, deferred and rejected work · `V1_RELEASE_GATE.md` release requirements/state · `PERSONAL_COOKING_INTELLIGENCE.md` long-term intelligence direction and data inventory · `FOOD_ARCHITECTURE.md` Dish/Recipe/Cooking Attempt relationships, Main Recipe, cook naming/terminology, as written vs as made, library lenses and Add Recipe flow · `Website/README.md` website/Cloudflare deployment. Dated reviews are evidence, not current truth. Update canonical docs **during** meaningful stages as durable decisions/state change (architecture, schema, product decisions, shared UI patterns, privacy, deployment, testing, release state, roadmap movement), not only at the end; skip trivial implementation detail. Replace superseded current-state text rather than stacking new dated sections over it.

### Per-cycle architecture check

For every meaningful cycle briefly evaluate: **A** current requirements; **B** existing data reuse; **C** future intelligence value of data normal use creates; **D** whether new fields/relationships/indexes/history are genuinely justified now; **E** privacy/legal impact on collection, processing, visibility, retention or consent; **F** scalability and cost; **G** documentation/tests to update. Working functionality before speculative infrastructure; no speculative tables or fields. See [PERSONAL_COOKING_INTELLIGENCE.md](PERSONAL_COOKING_INTELLIGENCE.md#3-per-cycle-architecture-checklist-permanent).

## Verification and owner acceptance

Use the **minimum verification that establishes confidence** in the changed scope:

| Change | Normal verification |
| --- | --- |
| Documentation only | Consistency, links, whitespace and applicable secret/file checks; no build/Simulator by default |
| Code/domain/backend | Relevant compile/typecheck and focused unit/backend tests |
| Small UI | Build, directly affected UI tests and focused inspection |
| Major navigation/flow | Targeted Simulator verification of the affected flow |
| Schema/Supabase | Migration/hash checks, focused schema/RLS/security tests and relevant data fingerprints |
| Major release/TestFlight candidate | Broader regression once and Release verification once |
| Device-specific risk | Physical iPhone where useful for auth/photos/sync/provider behavior, major UX or release acceptance |

Broaden only for concrete dependencies, failures, broad risk or release significance. Do not repeatedly rerun full UI/backend suites or frozen ranking/share/photo-sync suites when untouched. Do not weaken meaningful tests for green results.

Implement → focused self-test → fix failures → scoped integration if warranted → **one concise owner physical acceptance procedure when needed**. Avoid repeated intermediate owner tests unless the issue cannot reasonably be reproduced otherwise. Until the owner confirms, say **AUTOMATED ACCEPTANCE PASSED — OWNER PHYSICAL ACCEPTANCE PENDING**. Mocks/automation never establish live-model or physical acceptance. Owner-accepted Recipe Creator V1/refinement is recorded in the current architecture.

Fixtures must use isolated UUID stores/media roots, never normal guest/account/demo roots. Keep development/test controls compile-time excluded from Release. Diagnose resource exhaustion; do not create more Simulator lanes.

## Data, security and external services

- Protect user, demo and hosted data, stable IDs, relationships, evidence, Recipe revisions and media. No reset/wipe, real-account deletion, media destruction or destructive history/evidence operation without explicit authorization. Never use real data as disposable test fixtures.
- For risky schema/data work, capture relevant pre-change counts/fingerprints and verify preservation afterward. Prefer additive/reversible migrations. Never edit applied SQL to change behavior; append migrations and verify hosted/local alignment. Do not deploy a concatenated reference schema over a live project.
- Never raise SQLSTATE `40001`/`40P01` from a StayGrubby function: PostgREST retries them without limit (the November 11, 2026 read-only incident). Use `PT409` for conflicts. Every new persistent table documents expected growth, canonical vs operational class and retention in its migration header. Never auto-prune canonical product evidence for capacity. Automated tests never write to the production project. Run `DevelopmentTools/database_health.sql` with each deployment and release candidate ([capacity policy](supabase/README.md#database-capacity-and-health-permanent)).
- Preserve RLS, permanent-account ownership, least privilege, private Storage and authorization on every operation/destination. Never weaken security to pass tests. [Backend/README.md](Backend/README.md) and [supabase/README.md](supabase/README.md) explain tooling and historical deployment evidence.
- Do not request/expose/print privileged keys, tokens, service-role or `sb_secret` values, Apple private keys or credentials. Do not change credential/secret configuration without explicit authorization. Keep local backups, dependencies, builds, Supabase state, fixture media and signing material out of commits. Use the existing value-redacting `DevelopmentTools/check_privileged_secrets.py` check.
- Private information stays private unless explicitly shared. Personal Notes are never public descriptions. Religious compliance such as kosher/halal cannot be inferred from ingredients; allergens are informational, never medical/cross-contact guarantees. Disclose external processing appropriately.
- No paid billing, paid-provider setup or new external AI provider without explicit approval. Preserve working protected keys. Provider quota failure must degrade gracefully to manual/deterministic entry and later retry, without retry loops.
- Gemini-backed Paste Recipe/Recipe Creator is the accepted standard intelligent path. Apple Foundation Models did not meet complex-Recipe quality requirements and is not compiled or offered in V1; no availability checks or on-device provider path. Reconsideration requires an explicit future cycle. Do not reroute normal complex creation to Apple because it is on-device/free or expose unnecessary provider/model complexity. No StayGrubby daily allowance or date/30-day expiration; retain justified burst/security protections and friendly provider cooldown.

## Recipe Creator ownership boundary

The explicit November 2 Gemini-first architecture supersedes historical lexical/source-proof rules: Gemini interprets and constructs content; StayGrubby validates structure and model compatibility; the user reviews/edits before explicit Save. Source is context, never a word/phrase whitelist. Do not restore token-overlap checks, source reconstruction, method-to-ingredient recovery, a second AI judge or brittle culinary fact-checking heuristics. Keep technical/security/bounds/dependency/corrupt-quantity protections and existing ingredient parsing/serving math. Missing optional metadata may be unknown; useful imperfect drafts should reach the editor. Read the current Recipe section and Style Guide rather than reviving older review criteria.

## Git, deployment and documentation

Create coherent verified checkpoints, not knowingly broken intermediate commits unless explicitly necessary/documented. Review the complete staged inventory/diff; include intended new sources/assets/tests/docs/migrations, exclude unrelated changes and machine-local artifacts. Leave main clean after a completed cycle while preserving unrelated owner work; report any resulting dirty state honestly.

Push normally when authorized/authenticated. If HTTPS authentication fails, preserve local commits, report HEAD and tell Guy to push through **GitHub Desktop**. Do not change credentials, authentication configuration or SSH as a workaround. No force push, amend/rewrite of published history without explicit permission.

Production website publishes require authorization in the current cycle and use only `sh Website/deploy-production.sh` (full Worker + assets, then the live link gate). **Assets-only publishing is never a valid StayGrubby deployment**; see [Website/README.md](Website/README.md).

Supabase authorization does not authorize **TestFlight uploads, App Store submissions, release publication or paid services**. Those require explicit current instructions. Do not change version/build numbers or begin distribution merely because feature verification passed.

Update canonical architecture/roadmap/domain documents when permanent behavior changes. Keep historical evidence with clear dates/supersession labels; do not manufacture past acceptance. Small changes normally update an existing document rather than generating a giant review. Planned features belong in the roadmap, not current implementation claims.

Begin every agent task's final report with these fields, in order:

**Agent:** Claude or Codex\
**Task:** task name\
**Branch:** actual branch\
**Worktree:** absolute path\
**Commit:** checkpoint SHA or none

Then report the changes, tests, push status, owner verification, unresolved issues and integration requirements. Include relevant migrations, deployments and data/security results. Keep manual actions direct and sequential.
