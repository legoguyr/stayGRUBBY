# StayGrubby development workflow — retained integration history

> Permanent development instructions now live in [AGENTS.md](AGENTS.md). Current product state is [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md); future scope is [STAYGRUBBY_MASTER_ROADMAP.md](STAYGRUBBY_MASTER_ROADMAP.md). This file preserves the completed parallel experiment and its checkout-safety evidence, not a competing instruction system.

## Default: one primary Codex workflow on main

The temporary Onboarding / Profile / Sharing experiment is complete. Parallel feature worktrees are **not** the default. Implementation, testing and integration normally stay together with one primary agent in the original checkout, on `main`:

`/Users/guyrettig/Documents/Grub Rankings/Grub Ranked`

Use **one Simulator/UI-test lane at a time**. Do not create new feature worktrees or parallel workers unless the user explicitly requests them. Future genuinely independent social/backend/moderation work may justify parallelization, with shared contracts and Simulator ownership agreed first. Inspect branch/status before work; never reset, clean, discard or overwrite unexpected changes. Physical approval and distribution remain separate gates.

The repository is now `legoguyr/StayGrubby`. The historical local checkout path is unchanged.

## Completed experiment and retained history

The release checkpoint `067c7b69b223ea60067297132a765a0ccd352238` follows V1 checkpoint `9968390465658c2a118d2668ee44a0958ea1ec1b`. All three workers branched from `97b1bc3b0f041cc2bbf38b19bde1b1354f7c9953` (Establish StayGrubby parallel development contract).

| Workstream | Branch | Completed commit | Retained checkout |
| --- | --- | --- | --- |
| Onboarding | `feature/onboarding` | `4d6b60d02bc24ef36efeb3a6687864e1ff0cba84` | `/Users/guyrettig/Documents/StayGrubby-Worktrees/onboarding` |
| Profile | `feature/profile` | `778615ab6a9f5f57f6e141e6b1b0ed57b5761cb0` | `/Users/guyrettig/Documents/StayGrubby-Worktrees/profile` |
| Sharing | `feature/sharing` | `79792a6e7fe9d50d6b196b7e507f5cbc998ba57e` | `/Users/guyrettig/Documents/StayGrubby-Worktrees/sharing` |

Integration preserves the three worker commits as ancestors. [V1_INTEGRATION_REVIEW.md](V1_INTEGRATION_REVIEW.md) records combined verification and the physical-review gate. Independent worker reports do not approve the combined product. Historical ownership rules remain available with `git show 97b1bc3:PARALLEL_DEVELOPMENT.md`.

Do **not** delete worker branches/worktrees during integration. They are eligible for later cleanup only after their exact commits are confirmed ancestors of main and their checkouts are clean; preserve any subsequent work.

## Continuing authority

Use AGENTS.md for scope, data safety, protected systems, isolated fixtures, risk-based testing, commits and distribution permissions. A combined verification pass is justified by actual cross-surface risk, not required for every unrelated change. The retained worktrees above must not be deleted automatically; preserve subsequent owner work and obtain scoped cleanup authorization.
