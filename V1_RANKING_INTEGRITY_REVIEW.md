# V1 Ranking Integrity & Final UX Corrections — November 6, 2026

Baseline: clean `main`, aligned with `origin/main`, `094c178750673b8f016606f7b869fe48ec5bd051`. The owner explicitly reopened the ranking freeze for the reported re-ranking defect. One primary agent, existing checkout and one iPhone 17e / iOS 26.5 Simulator lane were used. No release-gate execution or distribution.

## Finding and correction

The old re-ranking session acquired/stopped using a fresh conditional insertion posterior, then committed ordinary unit-weight observations into a stationary BT fit containing the entire prior assessment. These are different inference contracts. The optimizer was correct, but session confidence could disagree sharply with the saved position. No wrong-version mapping, lost comparisons, stale strength cache or calibration-driven sorting was found.

Read-only hosted inspection identified the second Lamb Chops version in a 30-entry / 162-comparison active graph. Its stored rank is 8 and strength is `1.24899544388498`; replay of all retained evidence matches every stored strength within `4.45e-15`, with maximum gradient `2.84e-8`. The recent fourteen target-first answers include seven wins and seven losses, including wins over lower-ranked opponents. Retained-history replay moves it roughly 4 → 5 → 6 → 8. This does not establish every historical screen/session boundary (those were not recorded), nor does it support claiming that every saved answer was a loss. The latest saved semantic reaction is Liked it; this influences calibrated score, never ordering.

**Explicit Re-rank now starts a fresh current assessment of the same RankedItem.** Prior Comparison records retain their UUIDs, endpoints, outcomes and timestamps. Additive `rankingAssessments` JSON assigns previous incident observations to a historical latent strength, with the same N(0,4) prior and full unit-weight BT likelihood. Historical parameters still inform the graph, but do not add versions, entries, unlock counts or visible ranks. Ordinary incremental refinement does not create a boundary. No arbitrary penalty, forced ordinal, evidence decay, score-calibration change or optimizer change is introduced.

New Dish/New Version and Re-rank supply the same immutable `RankingContext` to acquisition. Conditional confidence additionally requires agreement with the converged global MAP inside the conditional 95% slot interval. Otherwise, useful corrective comparisons can repeat a pair, using disagreement weighted by existing information gain. Skip excludes locally, Undo replays exactly, and low-information/exhausted outcomes remain provisional. Historical covariance is marginalized before visible-item analysis; precision is not simply sliced.

Boundary metadata, fresh evidence, strengths and synchronization journal save atomically. Cancellation writes nothing; Skip-only completion creates no boundary. Stale snapshots/corrupt known metadata fail safely. Existing libraries are not passively recomputed, reset or backfilled. Normal target/opponent deletion removes incident observations and recomputes without phantom parameters. Restore preserves the existing opaque metadata/strength transport; no schema migration is required.

**Compatibility:** all devices performing ranking mutations on an assessment-aware library must use this updated build. Older binaries cannot interpret the new assignments and must not recompute that library. Existing data without boundaries retains the old fit exactly. This is a model-policy correction within the owner's authorized ranking investigation.

## Deterministic evidence

All-pair, consistently ordered fifteen-entry fixtures; the target starts fourth:

| Retained observations | Old result after four losses | Corrected downward result | Corrected upward result | Fresh questions |
| --- | --- | --- | --- | --- |
| 105 | 4 → 7 | 4 → 15 | 14 → 1 | 4 |
| 315 | 4 → 5 | 4 → 15 | 14 → 1 | 6 |
| 840 | 4 → 4 | 4 → 15 | 14 → 1 | 7 |

The old session reported conditional last-slot confidence in each case. Corrected fits converge and retain every observation. A separate read-only copy of the real retained graph moves the second Lamb Chops version from 4 → 30 after five all-loss answers, calibrated score approximately 1.5 with Didn't Like it. This experiment never writes the actual account or Simulator library and is not recipe-specific code.

Initial-ranking simulations cover 15/40/100 existing items, two observations per pair, excellent/poor/middle placement, alternating contradictions, Too Tough, Skip and Undo. Good/poor targets reach the corresponding ends; middle targets remain near their supported region. Pure contradictions/ties stay finite, and skipped evidence is never fabricated. Persistence/version regressions cover the non-first cook, displayed global rank, current calibrated score, immutable original comparisons, repeated assessments, journal/restore/reopen, cancellation, stale sessions, malformed metadata, covariance marginalization and both target/opponent deletion. The historical October 2 500-item conditional-only matrix was not rerun or represented as current-policy evidence.

## Final UX

- New Dish/New Version requires trimmed Dish name, known cooked date, valid Course (Main default), bounded optional text and a completed ranking session. Name/date are marked required, unknown new dates have an explicit recovery action, and Continue respects shared validity. Version title/photos/description/Private Notes/tags/Source remain optional; legacy unknown dates remain editable.
- Kitchen Recipes uses native search over authorized returned title/Cuisine/Source metadata, shared Food Bible literal matching and generalized bounded index pagination. Search includes later authorized pages; no keystroke requests or private-body projection. Existing sheet/navigation/reauthorization remain.
- Active Recipe Share/overflow use the same adaptive accent red, visually checked in light/dark. Private inactive Share stays secondary. Working HTTPS/native-sharing behavior is unchanged.
- Dish Recipe actions share one compact Add Recipe / Link Existing Recipe row, adapting vertically to narrow/accessibility layouts. The shared inline action style supplies actual 44-point targets. Existing Recipe identity/link/provenance semantics remain.
- Send reuses the canonical person row with multi-selection, search, selected count and explicit Send. Per-recipient stable origin keys survive ambiguous outcomes/backgrounding within the sheet; confirmed successes do not resend. Partial failures use Retry Unsent. Existing server relationship/block/access authorization remains authoritative. Current-versus-pinned Recipe wording remains explicit, now plural. No chat, new permission grant or backend endpoint.
- Generic import-review paragraphs move out of the opening content into a collapsed Draft review below content; original pasted text remains separately available. The repeated suggested-serving/time paragraph is removed. Actual data, Contains/Possible, ingredient-specific review, provenance and explicit Save remain. Sharing stays in Edit Recipe; defaults/audiences are unchanged. Appropriate Terms/safety disclosure remains a required [release-gate obligation](V1_RELEASE_GATE.md), not solely Privacy Policy text.

## Verification and integrity

- **59 distinct native tests / 108 expanded executions passed across focused runs**, covering RankingIntegrityTests, CookingReRankingWorkflowTests, V1FinalUXTests, StayGrubbyTests, ScoreUnlockPolicyTests and ShareCardModelTests. Parameter expansions are 15, 3, 18, 13, 3 and 3 cases. The added opponent-deletion test passed separately.
- **8 distinct UI tests passed**, covering two-recipient search/partial failure/retry, light/dark Kitchen search and Recipe toolbar, live re-ranking/result/unlock/Profile, required cooking fields/metadata/persistence, exact-version Recipe linking/photo ownership, native shared/pinned Recipe authorization/copy, compact relationship-row geometry/touch targets and imported draft review/original text/explicit Save/reopen. Debug builds succeed through the focused builds/test runs. No Release/full UI/backend suite or live AI calls were needed.
- Initial development failures were corrected: test fixture initializer/required fields and Skip stopping assumptions; malformed new assessment JSON handling; stale pre-calibration singleton assertion; disclosure lookup using its native label; compact action touch-target placement. The old singleton test now separately verifies zero strength, the unchanged reaction-calibrated score and neutral diagnostic transform. No meaningful test was weakened; no failure or skip remains in the affected checks.
- Final native evidence: main integration `test_sim_2026-11-06T05-55-01-959Z_pid9245_540e28ca.xcresult` (57/58 before the stale singleton assertion correction); subsequent full StayGrubbyTests class `test_sim_2026-11-06T06-03-58-258Z_pid9245_0479407a.xcresult` (11/11), and opponent-deletion `test_sim_2026-11-06T06-10-26-799Z_pid9245_762c714e.xcresult` (1/1). No ranking code changed after the main integration pass.
- UI evidence: `test_sim_2026-11-06T05-56-56-363Z_pid9245_d006f7a2.xcresult` (3/3), `test_sim_2026-11-06T06-00-40-971Z_pid9245_1ba041ae.xcresult` (2/2), pinned Recipe test in `test_sim_2026-11-06T06-05-28-046Z_pid9245_a49e9104.xcresult` (1 passed; two new UI assertions corrected), then `test_sim_2026-11-06T06-08-36-146Z_pid9245_a73c046a.xcresult` (2/2). Screenshots were exported/inspected locally.
- Both original development-store copies remain byte-equivalent for original recorded table columns: 1 ranking, 12 Dishes, 15 attempts/items, 356 Comparisons, 10 Sources, 21 tags, 48 memberships; all 190 original JPEG hashes match. UI fixtures use isolated UUID stores/media; the additional two-recipient fixture is Debug-only.
- All **41 hosted data/Storage fingerprint groups** match before/after read-only investigation; Storage remains **83 objects**. No schema, RLS, migrations, hosted functions, media, credentials, protected keys, billing or account configuration changed. No private Recipe/body/notes were used as test input or committed. Privileged-secret/local-artifact and whitespace checks pass.

## Owner recheck and remaining gate

Install this updated development build on any device used for ranking. Re-rank the intended non-first Lamb Chops version once, choose the truthful initial reaction and answer consistently against its actual quality. Confirm meaningful placement, current score, the other version's identity, and the same result after relaunch. Also check Kitchen Recipe search, matching red actions, compact Recipe relationship row, content-first reader/import review, and a deliberate multi-recipient Send to appropriate Sous Chefs (one Order Up! delivery each). New Dish should require only valid name/date/default Course plus ranking; cancel if no new cook is intended.

Owner physical acceptance of the ranking-policy correction remains pending. No known automated blocker remains. After owner acceptance, proceed to the separately requested V1 Release Gate and its existing legal/safety/privacy/moderation/release obligations. Do not start that gate or post-V1 features automatically.

**STAYGRUBBY V1 RANKING INTEGRITY + FINAL UX CORRECTIONS PASSED — OWNER PHYSICAL ACCEPTANCE PENDING**
