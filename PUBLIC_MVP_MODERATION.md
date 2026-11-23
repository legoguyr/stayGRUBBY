# Public MVP moderation and privacy

The local V1 candidate includes reporting, audited review, owner-private Recipe authorization, idempotent post descriptions and outbound text screening. Refer to [V1_RELEASE_GATE.md](V1_RELEASE_GATE.md) for rollout authority and [the milestone check](BACKEND_MVP_READINESS.md#completion-follow-up) for verification.

## Technical safeguards

- Personal Food Bible operations use a live session mapped to an active permanent account via the existing private-media owner resolver. A moderation-hidden profile can continue to read its own Recipes, revisions and photos, save privately, and cook from its Recipes. Social actions and explicit `friends` saves still require social eligibility. Older clients that omit visibility get a private save when the actor is restricted. Other accounts still pass the existing friendship, block, Recipe visibility and media checks. Deleting accounts and expired or revoked sessions remain denied.
- Text screening rejects a narrow set of high-confidence English patterns for direct violent threats, encouragement of self-harm, identity-targeted violence and solicitations for child sexual abuse material. It normalizes compatibility forms, common zero-width characters and separators. Ordinary cooking vocabulary, multilingual Recipe text and common photo-sharing phrasing remain valid. Review and reporting cover context, ambiguity, unsupported languages and evasions outside these rules.
- The database screens active profiles visible to peers, comments, published post text and explicitly shared Recipe fields, including nested components. It checks the actual pinned revision when attaching it, restoring visible Recipe content, or exposing an earlier retained attachment through an audience change. New text is checked before a photo draft can stage an upload. Final publish rechecks earlier drafts. The trigger does not backfill legacy content or scan private Recipes, notes, or private cook history; rejected text generates no review event or additional persisted copy.
- For rejected text return `PT422`. The Recipe editor preserves the draft and offers editing or saving privately. An automatic post rejected for text is held in the existing device outbox for review, including after relaunch. Legacy clients retain their existing failure path. The Pass, profile and comment UI should map `PT422` to a clear edit-and-retry message without repeating unsafe text, and avoid automatic retries of unchanged rejected submissions. This is a shared client contract for the next integration with Claude's lane.

### Report-based images — immediate publishing

Photos publish immediately under their original audience rules. There is no mandatory image review or automatic image screening. Existing Report actions cover image-bearing posts, Recipes/revisions and profiles. Named staff inspect only the actual reported original, then use the existing hide/dismiss workflow. Private cooking photos remain excluded. File checks are structural, never objectionable-content detection. [Policy, limitations, community rules and App Review considerations](IMAGE_MODERATION.md)

## Owner-operated moderation

At public launch the owner’s existing account is the **only** intended staff account; no backup moderator or new account is required (owner decision, November 22, 2026). Enrollment is not authorized yet. Approve response targets and escalation for urgent safety threats and repeated abuse, and test the advertised Support path. Review only the reported case and its authorized image evidence. Correlate repeated upheld reports using the stable subject account ID in staff case detail, never the reporter. Escalate credible safety threats immediately to the owner and use an audited profile restriction after authorized review when appropriate. Avoid exporting or copying private content into operational notes. Record decision, time and necessary escalation using the existing case audit and restricted operational access record. Review role grants regularly and revoke departed reviewers. Terms, Community Guidelines and privacy disclosures require owner approval. [Apple’s user-generated content guideline](https://developer.apple.com/app-store/review/guidelines/#user-generated-content)

## Staff workflow

1. A user can report a post, comment, profile, current Recipe or a Recipe revision explicitly attached to a post. The server derives the reporter from their live session, verifies current access, deduplicates, and limits intake to 50 reports per account per day. Reports have a reason and up to 500 characters of optional context. Receipt retries do not write duplicate records.
2. A designated database operator enrolls a verified staff member's existing permanent account in `staygrubby.moderation_reviewers`. This table starts empty and is closed to API roles. Enroll only named staff with an active account. Confirm the account ID through an approved internal process and record the grant or revocation in the operational access record. A reviewer needs a live signed session and cannot act on a report about their own account.
3. Call `api.moderation_review` through the authenticated staff integration using the reviewer's **own** user session. The callable contract below can be used by a simple operations client. Review the launch gate for the staffed rehearsal and handling of reported images.
4. Use **dismiss** when no moderation action is warranted. Use **hide** to withdraw the item from its social audience. Resolution and its reviewer, decision and time are recorded atomically. A lost-response retry returns the original result. Conflicting final decisions return a refreshable `PT409`. The private audit survives removal of the reviewer identity while the case survives.
5. Revoke access by removing the staff membership. The next request checks membership and session validity. An exceptional action outside the queue is restricted to database operators and requires an incident record with actor, reason, time and affected record. The legacy service-key mutation is revoked by the migration.

## In-app staff interface (Settings → Moderation)

Claude, November 23, 2026; built ahead, **inactive**. A thin client over `moderation_review`; no role management in the app for V1 (owner decision: the operator procedure is sufficient).

- **Visibility:** a "Moderation" row under a Staff section in Settings appears only when the server flag `staff_moderation` is on for the account **and** `api.staff_status` returns `admin` or `moderator`. With the flag off the app makes no staff request at all; ordinary users never probe the report queue. The row is convenience only: the server authorizes every queue, review and resolve call, so a removed role fails on its next request.
- **Queue:** pending reports oldest first, 25 per page with Load More (cursor = the last row's `id` and its `createdAt` text unchanged). Pull to refresh. Reports about the reviewer's own content are never returned (server rule; admins included). The owner accepts that, while `@grubwithguy` is the only staff member, reports about the owner's content wait for a second moderator.
- **Report:** type, reason, date, the reporter's note and the reported content (profile name and photo, post title, description and photo, comment text, or the reported Recipe revision read-only). Reported photos download fresh through Storage (`review_image_allowed`) and are never written to the device photo cache. Deleted content says so and can only be dismissed.
- **Decisions:** Dismiss Report or Hide Content, each behind a confirmation. Retries are idempotent on the server; `PT409` shows "Already handled" and removes the report from the queue; `42501` explains that staff access may have changed.
- **Tests:** `ModerationTests` (contracts, cursor, decoding, errors) and `ModerationUITests` (hidden for non-staff and without the flag; pagination, dismiss, hide, deleted content, concurrent handling) against synthetic Debug-only reports. Nothing touches production reports.

**Backend dependency implemented locally:** `20261123210229_staff_status.sql` supplies the exact `api.staff_status` contract below. It is not deployed. Invalid actions/nonempty payloads return `22023`; missing/revoked sessions or inactive accounts fail authorization. Active ordinary accounts receive role null. The endpoint is stable/read-only and creates no audit or provisioning writes.

| Item | Contract |
| --- | --- |
| Call | `staff_status` with action `me`, empty payload, authenticated user session |
| Response | `{"role":"admin"}`, `{"role":"moderator"}` or `{"role":null}` |
| Rules | Read-only, own role only (from `staygrubby.social_actor()`; active account and current `moderation_reviewers` row). Never errors for an ordinary signed-in user (returns null). No audit row, no other account's data. Granted to `authenticated` only |

**Codex verification:** 28 focused status/flag/activation assertions, five actual signed local HTTP cases and 101 schema/RLS assertions pass. Claude’s exact Swift role DTO independently decodes admin/moderator/null. Earlier role/erasure and UI evidence is reused; no broad app suite or production probe was run.

**Activation:** integrate the reviewed Codex backend and Claude `005a178` after approval; deploy photo correction → staff roles → staff status; enroll only the pinned `@grubwithguy` account; install an approved build containing the UI; then separately enable `staff_moderation`. The flag reader now filters this key to current staff, so ordinary accounts receive no key and make no staff request. A global metadata audience alone was insufficient before this correction. [Exact ordered activation](DevelopmentTools/operations/README.md#staff-status-and-claude-005a178-integration).

## API contracts

All calls use `POST /rest/v1/rpc/<function>` with `Content-Type: application/json`, `Content-Profile: api`, the project publishable key in `apikey` and an active Supabase user access token in `Authorization: Bearer …`. The JSON body is `{"action":"<action>","payload":{…}}`. The server derives the actor from the signed session. IDs refer to the permanent StayGrubby account or object, never the Apple subject or Auth user ID. The block operations require a social profile with a username. The staff operations also require a current operator-granted reviewer membership.

### Submit a report

Call `social_report` with action `report`.

| Payload field | Type and meaning |
| --- | --- |
| `targetType` | One of `post`, `comment`, `profile`, `recipe` |
| `targetID` | UUID of the post, comment, permanent profile account or Recipe, respectively |
| `reason` | One of `harassment`, `hate`, `spam`, `inappropriate`, `impersonation`, `other` |
| `context` | Optional string. The server trims and collapses whitespace, stores empty as null, and accepts up to 500 characters after normalization. |
| `postID` | Optional post UUID for a Recipe read through the post's pinned attachment. Send it only when reporting from that context. |
| `sourceRevision` | Optional positive integer for a Recipe. New clients should send the revision shown in the reader. The server checks it against the current revision for a direct Recipe or the pinned revision for a post. |

The full payload is limited to 4,096 bytes. The success response is `{"reported":true}` for an accepted submission or a duplicate whose target is still accessible. Use it to confirm receipt. No user-facing report ID, case status or reporter identity is returned. Dedupe is per reporter and target. A Recipe revision is a separate report target. The limit is 50 new reports in a rolling 24 hours per account. The server checks access on every submission, including replays, and prevents self-reports. Omit `postID` for a direct Recipe read. Omitting `sourceRevision` preserves the existing client contract and lets the server select the revision.

### Block, unblock and list blocked profiles

| Function and action | Payload | Result |
| --- | --- | --- |
| `social_people` / `block` | `{"peerID":"<account UUID>"}` | `{"people":[]}`. Creates the caller's block and removes the Sous Chef relationship or request. First block requires a visible peer. |
| `social_people` / `unblock` | Same peer ID | `{"people":[]}`. Removes only the caller's block. The prior relationship stays removed. |
| `social_people` / `blocked` | `{}` | `{"people":[…]}`. Each entry contains `id`, `displayName`, `username` and `relationship: "blocked"`. The collection contains the caller's blocks against still-active profiles. |

The block is stored in the caller's direction and enforced on both sides for social content. Purge affected social cache entries and reauthorize a destination when opening it. Owner-private Dishes, Recipes and independently owned cooking history remain accessible to their owners.

### Review and resolve reports

Call `moderation_review` as an enrolled staff user. An authenticated app user, a role in JWT metadata and the service API key each lack staff authority on their own.

| Action | Payload | Result |
| --- | --- | --- |
| `queue` | `{}` on first request. Subsequent payload carries both `afterTime` (the exact last `createdAt` string) and `afterID` (last report UUID). | `{"reports":[…]}`. Up to 25 pending cases ordered by `createdAt`, then `id`, each with `id`, `kind`, `reason`, `createdAt`, `status`. |
| `review` | `{"reportID":"<report UUID>"}` | `id`, `kind`, `reason`, `createdAt`, `status`, `context`, `decision`, `resolvedAt`, `subject`. The last four fields may be null. |
| `resolve` | `{"reportID":"<report UUID>","decision":"hide"}` or decision `dismiss` | `status`, `decision`, `resolvedAt`. Hide transitions `pending` to `reviewed`. Dismiss transitions it to `dismissed`. Repeating the same decision returns its original receipt. |

A non-null staff subject includes `accountID` for correlating reviewed cases. The triage queue and normal report receipts omit it. Subject fields also depend on `kind`. Profiles return `displayName`, `username`, `state`, `photoPath`. Posts return `title`, `description`, `state`, `photoPath`. Comments return `body`, `state`. Recipes return `content`, `revision`, `state`, `photoPath`, with `content` drawn from the reported revision. Image paths are nullable private references. Use approved operator access for case image review. The case supplies no signed URL. The live staff role permits only authenticated GET of that reported original, not unrelated private media; dismissed cases lose this extra access. Queue and case reads create no audit writes.

### Client errors and version compatibility

| Code | Meaning and handling |
| --- | --- |
| HTTP 401 | Missing or rejected authentication. Check the session and reauthenticate if needed. |
| `42501` | Authenticated caller lacks access, the session is no longer valid on the server, or the target is unavailable. Use the normal unavailable state without disclosing why the object cannot be seen. |
| `22023`, `22P02` | Unsupported or invalid fields, invalid IDs or prohibited self-actions. Keep entered context and avoid automatic retries. |
| `PT409` (HTTP 409) | Recipe revision changed or the staff decision conflicts. Reload. The Recipe readers capture the displayed revision when opening the report. A conflict stops submission and offers Reload Recipe. A new report requires reviewing the refreshed content and opening a new report sheet. |
| `PT422` (HTTP 422) | Outbound text needs changes. Preserve the entry, offer edit-and-retry, and stop automatic replay of identical content. Private Recipe save remains available. |
| `54000` | The report allowance is exhausted. Handle by SQLSTATE because PostgREST maps the class to HTTP 500. Show a short retry-later message. |
| Network error | Keep unsent report context. If the user retries a report, send the same target and revision. |

Keep native post, comment and profile reports and block calls unchanged. The pre-migration server rejects `targetType: "recipe"` as an invalid target and has no `moderation_review` RPC. Deploy the migration before enabling Recipe reporting or staff access. On newer servers, older clients still receive `{"reported":true}` for their original report flows. See [PostgREST error mapping](https://docs.postgrest.org/en/stable/references/errors.html).

When moderation hides a Recipe, reauthorization fails for foreign Recipe reads, pinned attachments, shared links and photo reads based on that share. Refresh the social Recipe lists and show the existing unavailable state for stale links. The owner retains private Recipe and history access. A cook can remain visible with its Recipe attachment withdrawn. A separately authorized photo reference retains access under its own rules.

## Owner/admin roles — locally implemented, activation pending

Owner decision November 23: only the existing `@grubwithguy` account is intended for initial admin enrollment. No backup/new staff account. `20261123171953_moderation_staff_roles.sql` extends existing membership with `admin`/`moderator`, a private auditable role-change API and serialized last-admin protection. Admins manage existing users; moderators handle reports only. **Neither can review their own content.** Role removal is immediate; no JWT-metadata authority or public bootstrap. Deliberate last-admin erasure uses the existing Storage-cleared job and preserves nonpersonal audit outcomes; secure recovery is an explicitly approved authenticated operator action, never account resurrection.

Twenty focused SQL assertions pass, including permissions, audit/idempotency, self-case denial, demotion/revocation, direct last-admin removal prevention, deliberate erasure/retry and operator recovery. Real concurrent HTTP demotions preserve one admin; encrypted Auth/application/catalog/photo restoration passes. These are disposable results, not production grants. [Exact enrollment, role contracts, monitoring, backup and recovery procedure](DevelopmentTools/operations/README.md). Production remains flat/unenrolled until approved deployment and the separately pinned owner enrollment.

## Privacy and lifecycle

- Private cooking graphs, Dishes, comparison evidence and notes stay owner-scoped. The Pass contains intentionally shared cook snapshots. Profile discovery remains opt-in and social DTOs remain bounded. The current backend exposes no anonymous Recipe content or open profile pages.
- Blocking uses the existing server-side visibility checks. New Recipe moderation uses the same visibility gate as direct reads, pinned attachments, shared links and private photo reads. The owner retains private access, and existing independent copies and personal cooking snapshots remain with their owners. A shared cook can stay visible with its hidden Recipe pointer withdrawn. An already delivered external image or screenshot cannot be recalled.
- The queue does not expose the reporter identity. Staff can see report context and the referenced shared content only. It creates no duplicate media or content snapshots. Existing report cascades continue when the reporter, target, post or comment is erased. Recipe revision erasure also removes the associated report and audit. Audit rows store one outcome per report and are retained for that case's lifetime.
- The authenticated production edge functions are `recipe-import` and `delete-account`. The migrated target returned 401 for missing/invalid tokens and 404 for `development-test-session`. The checked-in default config now excludes the development function from deploy and serve. The existing sandbox test proof flow requires an isolated explicit enablement.
- The target's capacity job remains active. Staff queue work uses a bounded indexed page, one requested case at a time and one outcome write per resolution. No cloud polling, new background work or additional Storage is required.

## Rehearsal and deployment

**November 22 public-launch review:** all 65 hosted migrations match accepted main. The Docker-free local runtime now passes 34 actual signed Auth/Storage/moderation/erasure checks with the single pending staff-photo correction; 22 new SQL assertions cover that correction. It is not deployed. Do not confuse local signed transport with a live target-user probe. The local harness now checks the retired approval queue is absent, checks current APIs, removes bytes before advancing the cleanup job, and checks actual owner media/manifest cleanup. Production has zero reviewer memberships and no demonstrated staff client; enrollment and staffed end-to-end rehearsal remain required. [Review evidence](PUBLIC_LAUNCH_SECURITY_REVIEW.md).

**Disposable database rehearsal.** The connected projects are the production target and frozen source, with no staging branch. Use the local PostgreSQL rehearsal from a checkout containing the candidate.

```sh
cd Backend/tests
npm ci --ignore-scripts
npm run test:public-mvp
```

The suite applies the real migrations, role grants, RLS and procedures over isolated PostgreSQL fixtures. It reproduces the hidden-profile defect before the correction, verifies private owner access afterward, and exercises Recipe revocation, pinned media catalog authorization, erasure, screening, dispatch and write idempotency. The roles and Storage policies are real SQL. JWT claim mapping and Storage byte transport are simulated. The unchanged Recipe and deletion handlers retain their prior focused evidence; no Gemini or real Apple requests are needed. For signed and byte-level tests, use a fresh unlinked [disposable Supabase CLI stack](https://supabase.com/docs/guides/local-development/cli/getting-started) or an approved isolated hosted staging project. Assign separate fixture owner, peer, outsider and reviewer accounts and seed synthetic images. Verify accepted signed RPCs and GET/HEAD, denial of absent/malformed/expired and foreign tokens, signed-out/deleting actor behavior, hide/block transitions, and erasure/retry of disposable account assets. Confirm isolated endpoints before any fixture write.

The exact pending file set is pinned by [PUBLIC_MVP_MIGRATIONS.sha256](Backend/PUBLIC_MVP_MIGRATIONS.sha256). From the release root run `shasum -a 256 -c Backend/PUBLIC_MVP_MIGRATIONS.sha256` before the CLI dry run. The November 17 integration checked all 51 predecessor versions and ordered SQL statement hashes against the hosted ledger. The first 49 target ledger rows store CLI-split statements; compare their ordered statement content, with only statement delimiters and boundary whitespace removed. Hashing their empty-string concatenation as a whole file produces a false mismatch. The two later rows retain their whole SQL files.

**Deployed November 21, 2026** (owner-authorized; all 11 files as `20261121161421`…`20261121161925`; [deployment record](supabase/README.md)). Signed Gateway/Storage/staff rehearsal and reviewer enrollment below remain open public-release gates.

**Historical pre-deployment sequence (completed November 21; do not redeploy).** The November 20 read-only preflight confirmed 54 applied migrations: 51 through `20261115154948`, then `20261120150047`, `20261120171728` and `20261121023911`. All ordered SQL statements match local files; there was then no deployed moderation review RPC; it is now deployed. The disposable production-order rehearsal includes all three independent predecessors, existing shared-photo metadata/captions and Recently Deleted history before applying the 11 pending files.

1. Rehearse the signed RPCs, private Storage, immediate publishing and a reported image through resolution using authorized disposable staging actors. Check ordinary users cannot review, revoked staff lose access, blocks and hidden Recipe shares fail closed, and old client reporting still works.
2. Confirm the linked project is the migrated production target. Compare local and hosted migration history and hashes through the predecessor. Run `supabase migration list --linked` and `supabase db push --linked --include-all --skip-vault --dry-run` from a release checkout with the exact approved set pending. The eleven pending candidates below form the reviewed local sequence, subject to a fresh hosted-ledger check. The manifest also contains the independently deployed Variations, integrity and Recipe recovery files; those must not be reapplied. Complete report-response handling, immediate-photo client acceptance and the signed fixture rehearsal before public rollout. If the preview differs, stop and resolve the history first.
3. Capture relevant counts and hashes for accounts, Dishes, cooks, ranks and comparisons, Recipes and revisions, social objects, reports and the Storage inventory. Take the same ordered aggregate fingerprints before and after, excluding only the documented new moderation columns from the old-row comparisons. Compare Storage inventory and known manifest hashes with [the Storage inventory query](DevelopmentTools/supabase_clean_migration_storage.sql). Capture the function/RLS/grant catalog using [the catalog query](DevelopmentTools/supabase_clean_migration_catalog.sql). Run `DevelopmentTools/database_health.sql` and check the Dashboard disk view and capacity Cron. The transaction makes bounded schema changes to existing tables. Use a quiet window to minimize lock contention.
4. Apply these candidates in order through the approved migration path once the release gates are satisfied. With a verified migration-history-aware CLI dry run, use the approved deployment path (`supabase db push --linked --include-all --skip-vault`; pinned CLI 2.120.0 help confirms both flags). `--include-all` includes only missing older versions; `--skip-vault` prevents unrelated secret updates. Do not include seed or roles; confirm the exact dry-run set first. A normal per-file push is not atomic across files. Obtain approval for a contained rollout window, or separately review an atomic executor, because steps 6–8 temporarily hold shared images until step 9; never activate or leave that partial chain as the finished deployment.
   1. `20261121161421_public_mvp_moderation.sql` adds the moderation states and audited review.
   2. `20261121161446_dish_owned_recipe_share_options.sql` uses the moderation state when suggesting or attaching a Recipe. The existing lookup keeps its historical, cook-specific and legacy associations before the indexed `recipes.dish_id` fallback. The attachment still requires explicit consent.
   3. `20261121161457_idempotent_post_descriptions.sql` reuses the same authenticated publication contract and avoids unchanged description writes. No backfill or new table.
   4. `20261121161512_private_recipe_authorization.sql` isolates private ownership. Its predecessor guards stop the transaction if the expected Recipe signatures have drifted.
   5. `20261121161536_public_text_screening.sql` adds prospective screening and staff-only subject correlation.
   6. `20261121161723_image_moderation_foundation.sql` queues share-eligible originals, adds the worker/staff contract and restricts peer image bytes until approved. This historical gate is superseded by candidate 9; do not activate a partial rollout.
   7. `20261121161724_social_dish_identity.sql` adds the authorized exact-Dish key and paginated cook lookup without data writes.
   8. `20261121161725_free_manual_image_moderation.sql` adds direct pending-image approval, decision audit, later hide, fresh cache authorization and Recipe signing restrictions. Its prepublication workflow is superseded by candidate 9; its cache/URL protections are retained.

   9. `20261121161726_report_based_image_publishing.sql` restores immediate audience access, removes the approval queue/triggers/worker RPCs, and limits staff photo evidence to actual reports. Original bytes/content and historical decisions are preserved. Apply the complete sequence through this correction before acceptance.

   10. `20261121161847_recipe_share_option_integrity.sql` preserves the already deployed strict Dish/Recipe identity when the older sharing chain lands. Its independent integrity core is already deployed; do not reapply it.
   11. `20261121161925_canonical_cook_descriptions.sql` adds exact-Cook public descriptions, read-time captions, owner-only legacy context and an account-receipt durability capability. It requires the text/moderation prerequisites, preserves original captions and creates no posts/backfill. Deploy before distributing Cook-description editing; the Option A client leaves blank new Cooks nil and stops retry loops for intentional unsupported descriptions until deployment plus Retry. [Compatibility, evidence and forward rollback](COOK_DESCRIPTION_INTEGRITY.md).

   Reconcile the approved migration hashes, verify grants/RLS, and compare the captured records and Storage inventory. The report reviewer/audit tables start empty. Historical image audit is closed and receives no new writes; no image approval queue remains after the full sequence. Verify that Gateway exposes Recipe reporting before distributing the new UI.
5. Confirm the Gateway exposes the expected authenticated RPC and rejects unauthenticated access. On an authorized live session, use `POST {}` with JSON for `recipe-import` and expect `400 invalid_request` after authentication. Use signed `GET` for `delete-account` and expect `405 method_not_allowed` after gateway verification. Keep the Apple authorization code and Gemini input absent. Both probes must reject an absent or invalid token. For the byte-level acceptance use the disposable actors above. Verify lookup by cook and owned post ID, explicit private Recipe consent and rejection of hidden Recipe attachments. Verify the operator workflow and enroll only named production staff once it is ready. Keep staff sessions and credentials out of command arguments and logs.
6. If review access must be withdrawn, remove reviewer memberships. If the API itself requires containment, use an authorized, forward-only change to revoke authenticated execution on both `api.moderation_review(text,jsonb)` and `staygrubby.moderation_review(text,jsonb)`. Preserve reports, audits and visibility decisions. Keep the hidden-Recipe attachment guard if reverting lookup behavior with a forward migration. The description write optimization can be reverted independently by restoring its predecessor body in a new migration. Keep the private owner authorization correction during containment. If screening misclassifies a legitimate pattern, pause rollout and repair the detector in a forward migration. Disabling screening is an explicit emergency decision with public publication paused. For image incidents use existing report-based hide and role revocation as necessary; retain originals/audits. Do not restore an image approval hold as an implicit rollback. No image provider schedule is part of the MVP. Apply only approved forward corrections. [Image recovery](IMAGE_MODERATION.md#operating-workload-and-rollout). Pause the client rollout and repair forward. Avoid truncating tables, dropping constraints, restoring the frozen project or reopening hidden content as a rollback.

## Before public launch

- Finish the signed `recipe-import` and `delete-account` production Gateway probes with appropriate authorized sessions and non-mutating requests. Read-only function inventory confirms both require JWT and the development test function is absent. The prior negative probes and the local handler tests cover different parts of the flow.
- Complete the staff procedure, including reported-image evidence access, response targets, coverage and escalation. Accept the text behavior, complete report-based image acceptance and the App Review filtering-policy disposition and review the Terms, Community Guidelines, privacy disclosures, age rating and reachable support. [Apple's user-generated content review guideline](https://developer.apple.com/app-store/review/guidelines/#user-generated-content)
- Verify actual Auth and Storage cleanup on authorized disposable infrastructure. Repeat relevant account, block and visibility checks through the real client/Gateway as part of the release gate.
- Establish a staffed capacity alert destination and confirm delivery. The five-minute production Cron reported no active signals in the read-only preflight. Alerts currently go to database logs. See [capacity monitoring](supabase/README.md#automatic-target-monitoring) and the [public release checklist](V1_RELEASE_GATE.md).

## After launch

Consider audited restore within the staff API, case assignment, reporting trends and optional automated image moderation once separately approved and justified. It is not a public MVP requirement. A general admin dashboard, paid providers and extra user surveillance are outside this candidate.
