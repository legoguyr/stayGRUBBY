# StayGrubby parallel development

[AGENTS.md](AGENTS.md) is the authority for scope, testing, data protection and deployment. This guide describes how to use the permanent checkouts.

## Permanent checkouts

| Use | Branch | Folder on this Mac |
| --- | --- | --- |
| Integration and release | `main` | `/Users/guyrettig/Documents/Grub Rankings/Grub Ranked` |
| Claude development | `agent/claude` | `/Users/guyrettig/Documents/Grub Rankings/StayGrubby-Claude` |
| Codex development | `agent/codex` | `/Users/guyrettig/Documents/Grub Rankings/StayGrubby-Codex` |

Each checkout has separate files, staging and HEAD. Git history, branch references and remote configuration are shared. Keep build outputs, local test stores and ignored machine-local files within the appropriate checkout or isolated test location. One agent uses the Simulator/UI-test lane at a time.

## Open the right folder

**Claude Desktop.** In the **Code** tab, start a new session, choose **Local**, and select the `StayGrubby-Claude` folder as the project folder. Leave the **Worktree** toggle off so Claude uses that folder. If you have the Claude Code CLI on your PATH, the equivalent is:

```sh
cd "/Users/guyrettig/Documents/Grub Rankings/StayGrubby-Claude"
claude
```

**Codex desktop.** Add or open `StayGrubby-Codex` as a local project with that folder as its primary workspace. Start a new **Local** chat in the project. Leave the app's **Worktree** mode off to keep the session in the permanent folder. If the app cannot select the folder as its project root, use the CLI:

```sh
codex -C "/Users/guyrettig/Documents/Grub Rankings/StayGrubby-Codex"
```

Start the prompt with the agent, task, branch and worktree path. Have the agent confirm `git rev-parse --show-toplevel` and `git branch --show-current` before editing. If either differs, switch the session to the correct folder before proceeding. The original checkout remains available for owner integration and release.

## Refresh before each task and after integration

Run these commands in your own agent checkout. Confirm the reported branch matches the table and the checkout is clean before proceeding past status.

```sh
git status --short --branch
git fetch origin
git log --oneline origin/main..HEAD
git merge --ff-only origin/main
```

The log lists any commits that have yet to be integrated. Keep pending work with its original task. If the branch is dirty, has unrelated pending commits or cannot fast-forward, stop and coordinate with the owner. To continue an existing task on a diverged branch, an approved merge of `origin/main` into that agent's clean worktree can preserve both histories. Avoid rebasing or resetting these permanent branches. A finished branch whose reviewed commits were merged into `main` should fast-forward normally.

If the owner has explicitly designated a clean, unpublished local `main` as the accepted baseline, verify its exact SHA and use `git merge --ff-only main` in the assigned checkout. Use that same ref when checking for unintegrated commits. If local and remote `main` have diverged, resolve that in the integration checkout first.

## Integrate accepted work

1. The agent commits only its task and reports the exact reviewed SHA, verification, and any dependency or conflict. Its branch stays in its own worktree. The owner approves the reviewed SHA and decides integration order.
2. In the original `main` checkout, verify the branch and clean status. Run `git fetch origin` and `git merge --ff-only origin/main`. Confirm any local-only commits are approved before proceeding. Review `git log --oneline HEAD..REVIEWED_SHA` and `git diff HEAD...REVIEWED_SHA`, substituting the approved SHA.
3. Run `git merge --no-ff --no-commit REVIEWED_SHA` for one reviewed branch tip at a time. Preserve the actual agent commits so its branch can fast-forward later. Resolve any conflicts in the integration checkout, including canonical docs. Verify the combined result and run `git diff --cached --check` before committing. Use `git merge --abort` from the integration checkout if it cannot be completed safely.
4. Push `main` normally when authorized. After publication, each agent runs the refresh steps in its own checkout. A push authentication failure leaves the integration committed locally. Use **GitHub Desktop → Push Origin**, then refresh the agent branches.

**Interrupted fast-forward or checkout (seen November 8, 2026).** These checkouts live under `~/Documents`, which macOS can sync as an iCloud file-provider folder. A `git merge --ff-only` was interrupted partway and left the `main` working tree with some files already updated and some written empty, which the next attempt reported as "local changes". Never discard such changes on assumption. Instead:

1. Compare every modified or untracked file against both the old `HEAD` and the target commit (`git show TARGET:path | md5`).
2. Proceed only if each file equals the target, equals the old version, or is an empty or truncated copy. Anything else is independent work: stop and ask the owner.
3. Write the target content for the remaining files (`git show TARGET:path > path`) and confirm the whole changed set matches the target.
4. Fast-forward with a compare-and-swap ref update, `git update-ref refs/heads/main TARGET OLD_HEAD`, then `git read-tree HEAD`. Confirm `git status` is clean and the tree matches `HEAD`.
5. Drop any stash only after verifying it holds only copies of the target, then build and test from the integration checkout.

An agent branch can remain local for review on this Mac. A remote backup or PR may use the same agent branch if authorized. For PR integration, retain the actual commits with a merge commit so the same refresh procedure works.

## Historical worktrees

The release checkpoint `067c7b69b223ea60067297132a765a0ccd352238` follows V1 checkpoint `9968390465658c2a118d2668ee44a0958ea1ec1b`. All three workers branched from `97b1bc3b0f041cc2bbf38b19bde1b1354f7c9953` (Establish StayGrubby parallel development contract).

| Workstream | Branch | Completed commit | Retained checkout |
| --- | --- | --- | --- |
| Onboarding | `feature/onboarding` | `4d6b60d02bc24ef36efeb3a6687864e1ff0cba84` | `/Users/guyrettig/Documents/StayGrubby-Worktrees/onboarding` |
| Profile | `feature/profile` | `778615ab6a9f5f57f6e141e6b1b0ed57b5761cb0` | `/Users/guyrettig/Documents/StayGrubby-Worktrees/profile` |
| Sharing | `feature/sharing` | `79792a6e7fe9d50d6b196b7e507f5cbc998ba57e` | `/Users/guyrettig/Documents/StayGrubby-Worktrees/sharing` |

Integration preserves the three worker commits as ancestors. [V1_INTEGRATION_REVIEW.md](V1_INTEGRATION_REVIEW.md) records combined verification and the physical-review gate. Independent worker reports do not approve the combined product. Historical ownership rules remain available with `git show 97b1bc3:PARALLEL_DEVELOPMENT.md`.

Do **not** delete worker branches/worktrees during integration. They are eligible for later cleanup only after their exact commits are confirmed ancestors of main and their checkouts are clean; preserve any subsequent work.

The retained worktrees above remain outside the permanent Claude/Codex workflow. Preserve any subsequent owner work and obtain scoped authorization before cleanup.
