# Public launch security review — November 22, 2026

## Decision and scope

**Public launch is not yet cleared. No confirmed live cross-account exposure or data-loss vulnerability was found.** Build **1.0 (7)** has owner physical acceptance for onboarding, Recipe recovery, launch and existing data; Website V2 is live. Do not repeat that acceptance or reopen accepted product work.

Reviewed current main/origin `c6fb1c3954e0c147ff3c4b229d98819084c26832`. Codex started clean at `417ad51c4cbcb5d6a9880305ef4e5f3235dba83e`, 15 commits behind. The task's **no-merge** instruction overrides routine branch refresh: latest-main verification used an isolated `git archive`, not another worktree or a merge. Canonical status edits use that accepted main content as their basis. Main and Claude's worktree were left untouched. This checkpoint needs authorized integration/reconciliation before becoming current main guidance.

Only test-harness and documentation corrections were made. No production data, roles, settings, functions, migrations, endpoints, app code, credentials, website, build numbers or distributions changed. No Gemini call, Apple revocation, hosted fixture or real-account deletion occurred. The frozen source was not accessed.

## Passed gates and evidence

| Area | Evidence | Limit |
| --- | --- | --- |
| Migration/source parity | All **65** hosted versions and ordered SQL statements match current main. Both deployed Edge functions (v5) have JWT verification enabled and all deployed source files equal current main byte-for-byte. | No deployment was performed or needed. |
| Database authorization | **40** critical function bodies/security configuration/grants and **31** application/Storage policies match the isolated current schema. All application tables have RLS; no anonymous API execute or direct client table writes; no unvalidated FK or forbidden `40001`/`40P01` function error. | Claims in SQL fixtures do not prove Gateway behavior. |
| Private media | All four buckets are private, JPEG-only and bounded to 2 MiB; no object has an invalid account prefix. Disposable SQL tests cover owner/shared/outsider/staff visibility, blocking, hidden content and peer erasure isolation. | Actual authenticated Storage bytes/revocation need the remaining disposable HTTP rehearsal. Prior owner photo acceptance is reused. |
| Reports and staff authorization | Post/comment/profile/Recipe reporting, private review RPC, audited hide/dismiss, stale revision handling and server blocks exist; focused assertions pass. No mandatory image approval remains. | **Zero production reviewers**; staff enrollment and an operating client/procedure have not been demonstrated. |
| Account erasure | Existing manifest FK is retained. Focused SQL tests cover graph/media cleanup and peer isolation; synthetic deletion Edge tests cover authorization/Apple protocol. | Complete real Auth/Storage deletion/retry remains a disposable transport gate, not a request to delete a real Apple account. |
| Hosted negative authentication | Six safe requests: missing-user POST to each function returns **401**; foreign-signature GET to each returns **401**; missing-user delete GET returns **401**; unauthenticated Recipe GET returns **405** because of its method gate. | No successful target-user Edge probe was executed. A 405 before auth on a disallowed method exposes no content and is not a failure. |
| Auth configuration | Public Auth settings enable **Apple only**, with signup enabled. Development test function is absent from the deployed function inventory. | Do not enable password/guest providers to simplify review. |
| Release isolation | Existing signed **1.0 (7)** archive: bundle `com.guyrettig.StayGrubby`, iOS **17.0**, Release Debug-preview exclusion scan passed. | No rebuild, signing change or upload. Physical acceptance is the owner's stated result, not new automation. |
| Website/privacy | Existing live route gate: **30 GET/HEAD checks passed**, including HTML fallbacks and association endpoints. Privacy and Support return HTML; live Privacy equals the current generated canonical page byte-for-byte. Explicit external-AI consent exists before Cloud Formatting. | Terms returns **404**; App Store Connect privacy answers and reviewer access were not reviewed. |

### Focused verification totals

- `public-mvp-moderation.test.mjs`: **70 PostgreSQL assertions passed**.
- `instant-image-publishing.test.mjs`: **58 PostgreSQL assertions passed**.
- `cook-descriptions.test.mjs`: **46 PostgreSQL assertions passed**.
- **174 SQL assertions total**, real migration/RLS/function logic over isolated PGlite with synthetic Auth claims and Storage catalog. No real Storage HTTP claim.
- Synthetic Deno deletion tests: **9 passed**. Selected Recipe-handler auth/consent/cooldown/log-redaction tests: **6 passed**, **28 deliberately filtered out** (not failures or unexpected skips). No network/provider permission.
- Local acceptance guards/prerequisites: **6 focused checks passed**, including current-schema acceptance and obsolete/incomplete-schema rejection. Harness syntax check passed.
- Release archive scan and existing website live gate passed. No broad native/UI/Recipe Creator/ranking regression rerun.
- Initial test setup used an outdated dependency link; reinstalling locked dependencies in the isolated archive resolved it. This was an environment failure, not an app defect. The full HTTP acceptance runner was **not run**, because no local container runtime/stack or approved hosted staging exists.

## Smallest verified correction — plan recorded before implementation

The disposable signed-acceptance harness required `staygrubby.image_reviews`, although the accepted report-based migration removes it. It would reject a correct current schema, and its final erasure query would also reference the removed table. Correct only these rehearsal checks: require the retired queue to be absent and current authenticated image/moderation APIs to exist; check actual owner media, `media_backups` and Recipe-photo cleanup afterward. Move the fixture's `storage_cleared` transition after successful byte removal. Add schema prerequisite regression coverage; preserve loopback-only, empty-stack, owner-only file permissions, redaction, bounded timeouts and no-redirect protections.

These changes are implemented and focused checks pass. Fresh `open_account_library` was separately verified to create one ranking/library; no bootstrap change was justified. Production erasure and security code remain unchanged. Real Gateway/Storage execution remains required, rather than assuming a fixed harness is a passing end-to-end run.

## Reliability, budget and preservation

- Dashboard full disk: **0.31 GB / 2 GB (16%)**: database 33 MB, WAL 112 MB, system 177.1 MB. System/WAL are not the same as user table growth. No upgrade or intrusive maintenance is justified.
- Collector `staygrubby-capacity` is active every five minutes. Latest checked sample is fresh with **no alert signals**. Application relations occupy **3,670,016 B**; Storage **118 objects / 19,300,426 B**. Observed application rows/minute and excessive rollbacks/minute are zero; no long/idle API transactions. No current sync amplification was evidenced.
- Reuse existing operation IDs/receipts, causal outbox ordering, unchanged-state no-ops, bounded backoff, media hashes and account-scoped caches. Do not rewrite sync or prune canonical history. Keep server structured-sync throttling disabled while Build 5 remains supported.
- Read-only inventory: **13** Auth users/permanent accounts/identity links, **45** active Dishes, **46** cooks/items, **370** comparisons, **9** Recipes, **26** Recipe revisions; no deletion jobs. This is a current snapshot, not a claim that older activity counts must match. No test or production write was made by this cycle; existing normal user activity must not be misclassified as data loss.
- Existing security advisories: 35 informational RLS-without-policy tables use closed RPC-only grants; leaked-password warning is inapplicable to the currently disabled password provider. Do not weaken/change Auth merely to silence it. Performance notices (nine unindexed FKs, 23 unused indexes) are informational without an observed bottleneck; no speculative index work.
- Monitoring currently logs only. No configured external reader/delivery path or receipt test exists. The Free project has no managed backups: document a practical protected backup/recovery path; do not imply the frozen pre-cutover source protects newer target activity.

## Remaining launch requirements and exact ownership

No confirmed exploitable P0 was established. The following are **required launch gates**, not authorization for production changes or new product features:

1. **Codex + owner: signed transport acceptance.** Make a Docker-compatible local runtime available or approve a genuinely disposable staging environment. Replay current migrations and serve both JWT-protected functions; retain synthetic provider/revocation protocol tests without external calls. Run the existing loopback-guarded `local-backend-acceptance.mjs` against synthetic owner/peer/outsider/staff identities. Confirm successful signed validation without Gemini/deletion probes, foreign/expired/missing tokens, actual private bytes, hide/block/revocation, and disposable deletion/retry/peer preservation. Never extract a phone session or write fixtures to production. Existing invocation and status-file safeguards are in `Backend/README.md`.
2. **Owner + Codex: staffed moderation.** Designate primary/backup existing account identities, response targets and urgent escalation/contact coverage. Separately authorize reviewer enrollment. Exercise the existing authenticated `api.moderation_review` queue/case/resolve flow and role revocation via a minimal secure staff client/procedure; do not build a large dashboard. Text screening plus reports/blocks/staff removal must be accurately explained; file validation is not inappropriate-image detection. Resolve the App Review 1.2 filtering/operations disposition before submission.
3. **Owner + Claude: legal and review preparation.** Approve Terms/Community Guidelines and appropriate Recipe/allergen/estimate safety language, then authorize wiring/publishing existing legal/support destinations. Do not put non-privacy safety language only in Privacy. Confirm support mailbox ownership. Complete actual App Store privacy/UGC/age-rating answers and a reviewer-access procedure that permits full feature review while preserving Apple-only authentication. Do not share personal Apple credentials or add a production guest bypass. App Store metadata/submission remain separately authorized.
4. **Owner + Codex: operational P1 requirements.** Choose an alert recipient/channel and approve the existing external monitoring setup; prove one delivery. Document the protected backup/recovery method, responsibility and a disposable restore check. No paid plan change or automatic deletion is implied.
5. **Owner: integrate/release authorization.** Review this isolated checkpoint and reconcile canonical docs on current main. Do not re-deploy already aligned migrations. Final candidate/submission/distribution and the App Store CTA switch each need explicit approval. Reuse accepted Build 7 evidence; add only checks necessitated by any actual final changes.

**Estimate:** roughly one focused engineering day once disposable infrastructure and staff decisions are available; allow **1–2 working days** for coordinated operations/legal/reviewer preparation, excluding owner response and Apple's review queue. This is conditional, not a promise of Apple approval. More UI polish, AI image classification, an admin dashboard, index tuning without measured pressure, new discovery features and a sync rewrite are **not** required by this audit.

## Primary compliance references

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): 1.2 UGC filtering/report response/blocking/contact; 2.1 reviewer access; 5.1.2 third-party AI disclosure/permission. Approval is Apple's determination.
- [Apple account deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion): in-app initiation and associated data/Sign in with Apple requirements. The deferred real Apple erasure test is not newly imposed as a blocker.
- [Apple privacy disclosures](https://developer.apple.com/app-store/user-privacy-and-data-use/): complete App Store answers from actual collection/processing and SDK behavior; the bundled privacy manifest alone does not fulfill them.
- [Supabase RPC-only RLS notice](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) and [password protection advisory](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
