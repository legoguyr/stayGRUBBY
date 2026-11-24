# Love It production preflight — November 24, 2026

## Decision

**GO for the function-only production migration, after explicit deployment approval.** No corruption or historical rewrite blocker found. This is not client-release or owner physical acceptance. **Not a claim of exact Love It display on older builds:** builds through 1.0 (9) intentionally display the Liked fallback. If identical four-reaction scores across every supported client is mandatory, that mixed-version rollout is **NO-GO until older builds are retired/updated**; the current migration does not enforce a Love It minimum build.

Reviewed Claude `1a1af36` and accepted main `09fe8e5` (including the isolated Debug test scheme). Codex synchronization preserved both histories; its resulting tree exactly matched accepted main. Prior Codex checkpoints had been integrated under different commit IDs; three superseded migration filenames were removed only after proving their SQL byte-identical to the deployed aligned files. No independent work or history was discarded. No app/scoring implementation was changed in this review.

## Read-only hosted preflight

- Target: `ayjflxstqmnuoiphbyek`; frozen source untouched. **68** applied migration versions match local ordered SQL tokens (comments, transaction wrappers and statement separators normalized; quoted bodies/literals preserved). Local chain has **69** files; only `20261124230000_love_it_reaction.sql` is pending.
- All **12** relevant deployed sync-writer/social/scoring function bodies, arguments, security modes, volatility, search paths and ACLs match the 68-migration predecessor. The assessment-aware compatibility guard is current; helper execution remains owner-only.
- Counts: **69 Dishes, 73 cooks, 73 ranked items, 375 comparisons, 10 Recipes, 121 Storage objects**. All buckets private. **Zero Loved-it markers** in saved diagnostics.
- A read-only SELECT evaluates the proposed formula against **all 73 production items**: **0 changed scores, maximum delta 0**. It calls the old helper and computes the candidate expression inline; no function/table is changed and no diagnostics leave the server.
- Before/after audit fingerprints for ranked items, cooks, comparisons and posts are identical; counts/Storage count unchanged. Ranked-item hash `2da2fb8bd21494073110967ddee39875`; cook hash `0cd979b6ee36fb4f8bb66ffdacf9f6e7`; evidence hash `5155cbaf5cf29aa1af393949c56b982b`; posts hash `de7f0e2dcfd4e9feb04ec5b4d9774eac`.
- Database is writable; latest five-minute capacity sample has no alert signals (database 35,024,757 B; PostgreSQL-visible disk floor 157,388,631 B). This is not the full platform System disk measurement.
- All hosted operations in this review were SELECTs. No real-user fixture, Apple/Gemini call, account/media mutation or deployment.

## Four-reaction and old-client findings

- Actual order: Loved it, Liked it, It was fine, Didn't like it. Love It starts acquisition at percentile 0.05; existing percentiles 0.2/0.5/0.8 stay unchanged. The placement prior affects which comparisons are asked, not BT fitting or manual order. Existing comparison outcomes, assessment boundaries, uncertainty and unlock policy are untouched.
- Love It uses `7 + 3*sigmoid(strength/1.6 + 0.4)`. Existing Liked/Fine/Disliked/legacy transforms are unchanged. At strength zero, new Love It displays **8.8**, while old-client Liked fallback is **8.2**. Different reactions can overlap; comparisons still determine rank.
- New builds retain original three-value fields (`initialReaction`, `latestSemanticReaction`, historical `reaction`) with Liked compatibility values, and keep the distinct reaction in `initialSemanticReaction`, `semanticReaction` and per-entry semantic fields. No schema/model migration is needed; diagnostics remain opaque sync bytes.
- Actual pre-change Swift reader/writer code was exercised alongside current code: old readers decode Love It as Liked; old re-rank writes version 1 plus its latest reaction and wins over stale v2 semanticReaction; new re-rank can take over again. Unknown metadata survives; existing histories/IDs remain intact. Passive refitting changes strength/uncertainty only, not diagnostics.
- Pre-assessment writers remain blocked by the existing deployed guard once assessment data requires the newer model; accepted operation retries stay valid. Assessment-capable pre-Love-It clients remain supported via the intentional fallback. This migration neither weakens that guard nor falsely teaches old apps the new score band.

## The Pass and migration safety

Only `staygrubby.calibrated_cooking_score(double precision, bytea)` changes, in one transaction. Existing social preparation wrappers resolve this same helper at runtime and save the score only for a genuinely new snapshot. Local tests verify a new Love It snapshot uses the new band, existing snapshots keep their stored text, locked scores remain absent and publication does not mutate ranking state. Existing drafts created before deployment can retain the old fallback too; do not rewrite/delete/repost history to hide that distinction.

There is no new table/column/index, backfill, evidence refit, account change, receipt change, Storage access change or background write. The existing helper's immutable/security-invoker mode and ACL are preserved. The CREATE OR REPLACE takes a short function-definition lock; no user-table scan/update is required by the migration.

## Focused evidence

- Full current chain/schema/RLS: **101 assertions passed**.
- Four-reaction calibration, precedence, snapshot and unlock: **76 passed**.
- Full historical production-order rehearsal through all 69 files: **19 passed**.
- Assessment-client compatibility guard: **17 passed**.
- New populated 68 → 69 preservation, unchanged-score/ACL/catalog and rollback/reapply rehearsal: **8 passed**.
- **221 database assertions total**, all disposable. No broad Simulator suite repeated. Actual old/current Swift calibration code also passes independent compatibility and unchanged-band checks without a Simulator. Claude's focused engine, LoveItReactionTests, sync-restore and isolated Simulator evidence is reused; owner physical acceptance remains pending.

## Exact production sequence — after separate approval

1. Confirm the reviewed main/checkpoint, clean release checkout, target `ayjflxstqmnuoiphbyek`, current 68-entry ledger and byte/hash-approved candidate. Do not deploy a concatenated schema or reapply old migrations. Recheck relevant graph/post/Storage fingerprints and existing helper definition/ACL just before deployment; legitimate owner activity after this preflight requires a fresh baseline, not data rollback.
2. Save the **current scoring helper definition only** for forward recovery; preserve its ACL. Run the pinned supported CLI's linked migration dry run after checking the linked project ID. It must propose exactly this one file. Stop on any extra migration, drift or changed permissions.
3. Apply only `20261124230000_love_it_reaction.sql` via the approved migration path. Reviewed SHA-256: `832394332e64541581db73ee1429e451665b397207d5f9634f557eae4aafcf21`. No Edge Function, feature flag, minimum-build setting, credential, website or TestFlight change is part of this deployment. If Supabase assigns a different ledger timestamp, align the local filename/references byte-identically and verify the new ledger hash afterward; never change applied SQL behavior.
4. Verify the new ledger entry and helper definition/ACL, unchanged row/fingerprint/Storage baseline and existing-score parity. Run health checks and review capacity/API errors. Harmless read-only helper vectors may be checked through the authorized SQL operator; do not create test posts or comparisons in production.
5. Only under separate client-release approval, distribute the Love It-capable build. Keep devices installed and update in place, preserving outboxes. Complete owner physical acceptance in the isolated Debug scheme first. Decide whether the documented old-client fallback is acceptable or retire older supported builds before claiming uniform Love It scores. No TestFlight/App Store work is authorized by this review.

## Recovery

Prefer a forward repair. A local rollback rehearsal restored only the predecessor helper body and then reapplied Love It; all application/Storage rows stayed identical. If necessary after approval, append a new migration restoring that **single function**, preserving ACLs, rather than running the old semantic-score migration (which also renames/wraps social APIs), editing applied history or touching records. This causes new Love It snapshots to use Liked fallback again; already saved snapshot text and new-client display remain unchanged. It does not erase Love It metadata. There is no destructive data rollback to perform.
