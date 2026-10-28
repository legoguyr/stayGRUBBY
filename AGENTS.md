# StayGrubby development instructions

Before substantial work, read this file, [current architecture](STAYGRUBBY_ARCHITECTURE.md), [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md), and only the domain documents relevant to the task. [README](README.md) is the document index. Do not load every historical review by default.

## Authority and scope

Within repository guidance, precedence is: **explicit current task → AGENTS.md → canonical current architecture/product documents → domain documents → historical reviews**. Platform/system/developer requirements still apply. Follow a scoped prompt override and document the exception. Historical evidence must not override current product truth.

Work autonomously within the requested cycle; resolve routine engineering choices from repository evidence. Refactors, tests, safe migrations, scoped bug fixes, documentation, coherent commits and normal pushes are permitted within scope. Supabase migration/function deployment requires authorization in the current cycle. Escalate consequential ambiguity, destructive operations, security/credential issues, billing, production-user risk or material scope expansion; do not seek routine approvals.

Default to **one primary agent, existing checkout, main, one Simulator/UI-test lane**. Do not introduce workers/worktrees unless explicitly requested. Inspect Git status/HEAD before work; preserve unexpected or unrelated changes. Never reset/clean/discard approved work. [PARALLEL_DEVELOPMENT.md](PARALLEL_DEVELOPMENT.md) retains the old parallel experiment, not a second instruction system.

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
| Cooked Together tagging | Tag a Sous Chef |
| Likes / Like action | Hands / Give Hands |
| Notifications / Recreate | Order Up! / Run It Back |
| Future achievements / deferred Want to Cook | Stars / Tickets |

Keep utility wording clear: Comments, Search, Settings, Edit, Delete, Block, Report, Share, New Dish, New Version, Re-rank. Vocabulary does not authorize future features.

## Protected ranking and reuse

Ranking is frozen unless explicitly reopened: Liked/Fine/Didn't Like initial reaction, adaptive pairwise comparisons, Too Tough tie, Skip, Undo, Bradley–Terry evidence/order, uncertainty/refinement, repeated evidence, no manual order, score unlocking and current displayed-score calibration. Recipes/social must not alter any of these. See [RANKING_MODEL.md](RANKING_MODEL.md) and its current calibration reference; do not conflate displayed score with ranking order.

Before inventing a control/system, inspect accepted equivalents: allergen checklist, photo infrastructure, RecipeDraft, exact rational parser, design tokens/components, authentication/session boundaries, RLS patterns and share/post renderers. Reuse when semantics match; justify parallel implementations.

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
- Preserve RLS, permanent-account ownership, least privilege, private Storage and authorization on every operation/destination. Never weaken security to pass tests. [Backend/README.md](Backend/README.md) and [supabase/README.md](supabase/README.md) explain tooling and historical deployment evidence.
- Do not request/expose/print privileged keys, tokens, service-role or `sb_secret` values, Apple private keys or credentials. Do not change credential/secret configuration without explicit authorization. Keep local backups, dependencies, builds, Supabase state, fixture media and signing material out of commits. Use the existing value-redacting `DevelopmentTools/check_privileged_secrets.py` check.
- Private information stays private unless explicitly shared. Personal Notes are never public descriptions. Religious compliance such as kosher/halal cannot be inferred from ingredients; allergens are informational, never medical/cross-contact guarantees. Disclose external processing appropriately.
- No paid billing, paid-provider setup or new external AI provider without explicit approval. Preserve working protected keys. Provider quota failure must degrade gracefully to manual/deterministic entry and later retry, without retry loops.
- Gemini-backed Paste Recipe/Recipe Creator is the accepted standard intelligent path. Apple Foundation Models did not meet complex-Recipe quality requirements; infrastructure may remain dormant for reevaluation. Do not reroute normal complex creation to Apple because it is on-device/free or expose unnecessary provider/model complexity. No StayGrubby daily allowance or date/30-day expiration; retain justified burst/security protections and friendly provider cooldown.

## Git, deployment and documentation

Create coherent verified checkpoints, not knowingly broken intermediate commits unless explicitly necessary/documented. Review the complete staged inventory/diff; include intended new sources/assets/tests/docs/migrations, exclude unrelated changes and machine-local artifacts. Leave main clean after a completed cycle while preserving unrelated owner work; report any resulting dirty state honestly.

Push normally when authorized/authenticated. If HTTPS authentication fails, preserve local commits, report HEAD and tell Guy to push through **GitHub Desktop**. Do not change credentials, authentication configuration or SSH as a workaround. No force push, amend/rewrite of published history without explicit permission.

Supabase authorization does not authorize **TestFlight uploads, App Store submissions, release publication or paid services**. Those require explicit current instructions. Do not change version/build numbers or begin distribution merely because feature verification passed.

Update canonical architecture/roadmap/domain documents when permanent behavior changes. Keep historical evidence with clear dates/supersession labels; do not manufacture past acceptance. Small changes normally update an existing document rather than generating a giant review. Planned features belong in the roadmap, not current implementation claims.

At substantive closeout, report concisely: changes, important decisions, migrations/deployments, verification, data/security, commits/final HEAD/push, limitations and one owner acceptance procedure if needed. Guy is learning parts of Xcode/Git: manual actions should be direct and sequential, with implementation detail only where useful.
