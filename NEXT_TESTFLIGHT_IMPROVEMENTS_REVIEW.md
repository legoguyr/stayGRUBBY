# StayGrubby functional beta improvements

Baseline `afa8ec3`, marketing version 1.0, build 3. The next beta is owner physical acceptance pending. Website changes were separately authorized and deployed. Build-number assignment and iOS distribution are separate release actions.

## Publication and participants

For the reported #16 cook at 8.1, build 3 accepted structured cooking at 9:11:08 p.m. Eastern and the automatic intent published at 9:11:15 p.m. with the social photo. Its Recipe association was present and its post contained no Recipe attachment. The old readiness predicate returned early before observing sync status. The new gate observes the accepted snapshot of the exact cook and reads existing authorized publication by cook. Cancel retires only an unpublished draft requested by the manual composer. Revision and one-post-per-cook checks still guard the publish transaction. The exact-cook Recipe panel observes availability and distinguishes transport, decoding and unavailable-link failures.

The migrations append owner-only source/draft actions and optional snapshot fields, and add owner-only participant selection/read/search/update with optimistic conflict detection. Older clients must declare snapshot support in the prepare payload; existing posts are untouched. Publication still uses the server's accepted revision, score lock and author/global eligibility. No private content is added to the post card. Participant edits preserve completed independent cooks, use existing invitation Ticket deduplication, and never republish.

## Ranking benchmark

150 synthetic sessions use the unmodified production model and context apart from the candidate acquisition change, with five seeded trials for each of six scenarios at each library size. The harness stops at 64 answers. Two close-match sessions reached that limit on the baseline. The retained rule permits two observations of a pair before looking elsewhere in corrective acquisition after a Too Tough answer. Regular acquisition and every recorded observation remain intact. When informative corrective candidates run out the existing provisional stop applies.

| Existing items | Mean comparisons before → after | Max before → after | Absolute mean rank error before → after | Within three before → after | Mean rank SD before → after |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 10 | 5.60 → 4.13 | 64* → 20 | 0.37 → 0.37 | 29/30 → 29/30 | 1.69 → 1.69 |
| 25 | 5.20 → 5.20 | 8 → 8 | 1.73 → 1.73 | 26/30 → 26/30 | 3.45 → 3.45 |
| 50 | 8.63 → 8.03 | 64* → 46 | 0.97 → 0.97 | 27/30 → 27/30 | 5.65 → 5.65 |
| 100 | 9.27 → 9.27 | 27 → 27 | 0.73 → 0.73 | 28/30 → 28/30 | 9.40 → 9.40 |
| 250 | 14.10 → 14.10 | 40 → 40 | 2.07 → 2.07 | 27/30 → 27/30 | 17.27 → 17.27 |

Close-match repeats fell 115 → 33, with rank error unchanged at 1.20 and within-three unchanged at 23/25. Both formerly capped sessions stopped naturally. Sparse placement remained 0.16 mean error and 10.08 mean comparisons. Contradictory placement remained 5.24 mean error and 16/25 within three, with mean comparisons unchanged at 9.48. All 50 strong up/down trials remained exact, mean 7 and max 10 comparisons. Score calibration, assessment boundaries, optimizer and historical evidence are unchanged.

## Owner physical acceptance

1. Rank a new photo Dish with no Recipe. Open the composer before its receipt, leave it open and publish. Open the same composer after an automatically shared cook and confirm Already Shared opens its single post.
2. As an eligible Sous Chef, check the author’s rank/count snapshot on the post. Verify it stays historical after the creator reranks. Open Recipe activity, then tap Share deliberately once.
3. Edit a cook, search and add/change/remove a Sous Chef. Reopen after save and verify the selection and absence of duplicate posts or Tickets. Compare owner/visitor Kitchen and check a representative Tickets and 86 confirmation.
4. Try one close comparison session. Check a shared Recipe, post and Kitchen link on an installed iPhone. Open the same links and /beta on a device without the app, check the official TestFlight CTA, then reopen the original link after installing.

## Verification and deployment state

Focused checks cover the exact receipt observation and unrelated queued work, manual publication and existing-post reconciliation, loss of a reply, real social photo failure/retry, optional Recipe and pinned revisions, score locking, exact routes and optional referral input, and rank/participant security. The first ranking candidate was narrowed after the dense-history check exposed a regression in decisive movement. The retained tie-only rule passed that check, both close-match regressions and the full 150-session matrix. Native verification passed 28 distinct test methods (48 cases with parameterization) across focused runs. The iPhone Debug and unsigned Release targets compiled with iOS 17.0 minimum. All five affected UI flows passed across the same lane, including the absent native share sheet before explicit Share, Edit Cook tags, visitor Kitchen at large type, and Tickets read-all.

Local disposable PostgreSQL checks passed 257 assertions (36 new, 85 schema/RLS, 25 posting, 46 Shared Cooking, 48 Recipe sharing, 17 ranking-client compatibility). The existing hosted ranking guard still matches its approved hash. Owner-approved hosted deployment completed November 7. Supabase assigned `20261107074843_cook_publication_snapshot.sql` and `20261107074901_edit_cook_participants.sql`. The local filenames match hosted history and their SQL bytes are unchanged. All 41 migration hashes match. All 42 data fingerprints, including 99 Storage objects, were unchanged, and existing posts retained null rank snapshots. Table grants, RLS policies, private buckets and ranking compatibility guard were unchanged. Anonymous RPC access and direct client execution of the replaced private cores remain denied. Hosted physical acceptance can now proceed from the new app code in Xcode.

The supplied Apple invitation resolves to the official StayGrubby public beta page. The previous App Store Connect check showed 1.0 (3) assigned to Grub Group Alpha. External Testing status and the version actually offered to a fresh device remain owner verification. The published Worker passed 28 public HTTPS GET/HEAD checks, including /beta, canonical profile/post/Recipe fallbacks, malformed referral input, Privacy/Support and both AASA paths. The website suite passed 27 checks. Physical Universal Link association and the TestFlight install handoff are separate acceptance checks.
