# Public MVP moderation and privacy

The local V1 candidate includes reporting, audited review, owner-private Recipe authorization, idempotent post descriptions and outbound text screening. Refer to [V1_RELEASE_GATE.md](V1_RELEASE_GATE.md) for rollout authority and [the milestone check](BACKEND_MVP_READINESS.md#completion-follow-up) for verification.

## Technical safeguards

- Personal Food Bible operations use a live session mapped to an active permanent account via the existing private-media owner resolver. A moderation-hidden profile can continue to read its own Recipes, revisions and photos, save privately, and cook from its Recipes. Social actions and explicit `friends` saves still require social eligibility. Older clients that omit visibility get a private save when the actor is restricted. Other accounts still pass the existing friendship, block, Recipe visibility and media checks. Deleting accounts and expired or revoked sessions remain denied.
- Text screening rejects a narrow set of high-confidence English patterns for direct violent threats, encouragement of self-harm, identity-targeted violence and solicitations for child sexual abuse material. It normalizes compatibility forms, common zero-width characters and separators. Ordinary cooking vocabulary, multilingual Recipe text and common photo-sharing phrasing remain valid. Review and reporting cover context, ambiguity, unsupported languages and evasions outside these rules.
- The database screens active profiles visible to peers, comments, published post text and explicitly shared Recipe fields, including nested components. It checks the actual pinned revision when attaching it, restoring visible Recipe content, or exposing an earlier retained attachment through an audience change. New text is checked before a photo draft can stage an upload. Final publish rechecks earlier drafts. The trigger does not backfill legacy content or scan private Recipes, notes, or private cook history; rejected text generates no review event or additional persisted copy.
- For rejected text return `PT422`. The Recipe editor preserves the draft and offers editing or saving privately. An automatic post rejected for text is held in the existing device outbox for review, including after relaunch. Legacy clients retain their existing failure path. The Pass, profile and comment UI should map `PT422` to a clear edit-and-retry message without repeating unsafe text, and avoid automatic retries of unchanged rejected submissions. This is a shared client contract for the next integration with Claude's lane.

### Image screening decision

Prepublication image screening is an open release gate. Existing private uploads and authorized media reads are verified in SQL. They do not classify the image. The bounded launch option is manual prepublication review by named staff. An approved screening processor is an alternative if staffed latency cannot support launch. Owner approval is needed for the operating choice, reviewer coverage or intended processor, permitted data handling and any cost.

Reuse the existing original Storage objects. For each new profile photo, social post photo or shared Recipe photo, keep the asset owner-private until the approval tied to its immutable path and byte hash is recorded. Release the approved pointer through the same profile, post and Recipe visibility paths, including pinned Recipe revisions. A replacement starts pending, a retry uses the same approval, and a revoke or account deletion withdraws external reads. Keep private cooking photos outside moderation unless a separately consented shared copy is exposed. A staff view must be scoped to the pending item and audit only the decision and responsible reviewer. The staged acceptance should prove pending, approved, rejected, replaced and revoked bytes for owner, eligible peer and unrelated account through actual Storage. No external provider, scanner, credential, endpoint or duplicate image pipeline was activated here.

## Owner-operated moderation

Before public rollout designate a primary reviewer and backup, approve response targets and escalation for urgent safety threats and repeated abuse, and test the advertised Support path. Review only the reported case and its authorized image evidence. Correlate repeated upheld reports using the stable subject account ID in staff case detail, never the reporter. Escalate credible safety threats immediately to the owner and use an audited profile restriction after authorized review when appropriate. Avoid exporting or copying private content into operational notes. Record decision, time and necessary escalation using the existing case audit and restricted operational access record. Review role grants regularly and revoke departed reviewers. Terms, Community Guidelines and privacy disclosures require owner approval. [Apple’s user-generated content guideline](https://developer.apple.com/app-store/review/guidelines/#user-generated-content)

## Staff workflow

1. A user can report a post, comment, profile, current Recipe or a Recipe revision explicitly attached to a post. The server derives the reporter from their live session, verifies current access, deduplicates, and limits intake to 50 reports per account per day. Reports have a reason and up to 500 characters of optional context. Receipt retries do not write duplicate records.
2. A designated database operator enrolls a verified staff member's existing permanent account in `staygrubby.moderation_reviewers`. This table starts empty and is closed to API roles. Enroll only named staff with an active account. Confirm the account ID through an approved internal process and record the grant or revocation in the operational access record. A reviewer needs a live signed session and cannot act on a report about their own account.
3. Call `api.moderation_review` through the authenticated staff integration using the reviewer's **own** user session. The callable contract below can be used by a simple operations client. Review the launch gate for the staffed rehearsal and handling of reported images.
4. Use **dismiss** when no moderation action is warranted. Use **hide** to withdraw the item from its social audience. Resolution and its reviewer, decision and time are recorded atomically. A lost-response retry returns the original result. Conflicting final decisions return a refreshable `PT409`. The private audit survives removal of the reviewer identity while the case survives.
5. Revoke access by removing the staff membership. The next request checks membership and session validity. An exceptional action outside the queue is restricted to database operators and requires an incident record with actor, reason, time and affected record. The legacy service-key mutation is revoked by the migration.

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

A non-null staff subject includes `accountID` for correlating reviewed cases. The triage queue and normal report receipts omit it. Subject fields also depend on `kind`. Profiles return `displayName`, `username`, `state`, `photoPath`. Posts return `title`, `description`, `state`, `photoPath`. Comments return `body`, `state`. Recipes return `content`, `revision`, `state`, `photoPath`, with `content` drawn from the reported revision. Image paths are nullable private references. Use approved operator access for case image review. The case supplies no signed URL or additional Storage grant. Queue and case reads create no audit writes.

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

## Privacy and lifecycle

- Private cooking graphs, Dishes, comparison evidence and notes stay owner-scoped. The Pass contains intentionally shared cook snapshots. Profile discovery remains opt-in and social DTOs remain bounded. The current backend exposes no anonymous Recipe content or open profile pages.
- Blocking uses the existing server-side visibility checks. New Recipe moderation uses the same visibility gate as direct reads, pinned attachments, shared links and private photo reads. The owner retains private access, and existing independent copies and personal cooking snapshots remain with their owners. A shared cook can stay visible with its hidden Recipe pointer withdrawn. An already delivered external image or screenshot cannot be recalled.
- The queue does not expose the reporter identity. Staff can see report context and the referenced shared content only. It creates no duplicate media or content snapshots. Existing report cascades continue when the reporter, target, post or comment is erased. Recipe revision erasure also removes the associated report and audit. Audit rows store one outcome per report and are retained for that case's lifetime.
- The authenticated production edge functions are `recipe-import` and `delete-account`. The migrated target returned 401 for missing/invalid tokens and 404 for `development-test-session`. The checked-in default config now excludes the development function from deploy and serve. The existing sandbox test proof flow requires an isolated explicit enablement.
- The target's capacity job remains active. Staff queue work uses a bounded indexed page, one requested case at a time and one outcome write per resolution. No cloud polling, new background work or additional Storage is required.

## Rehearsal and deployment

**Disposable database rehearsal.** The connected projects are the production target and frozen source, with no staging branch. Use the local PostgreSQL rehearsal from a checkout containing the candidate.

```sh
cd Backend/tests
npm ci --ignore-scripts
npm run test:public-mvp
```

The suite applies the real migrations, role grants, RLS and procedures over isolated PostgreSQL fixtures. It reproduces the hidden-profile defect before the correction, verifies private owner access afterward, and exercises Recipe revocation, pinned media catalog authorization, erasure, screening, dispatch and write idempotency. The roles and Storage policies are real SQL. JWT claim mapping and Storage byte transport are simulated. The Deno handlers were tested offline without Gemini, real Apple grants or account writes. For signed and byte-level tests, use a fresh unlinked [disposable Supabase CLI stack](https://supabase.com/docs/guides/local-development/cli/getting-started) or an approved isolated hosted staging project. Assign separate fixture owner, peer, outsider and reviewer accounts and seed synthetic images. Verify accepted signed RPCs and GET/HEAD, denial of absent/malformed/expired and foreign tokens, signed-out/deleting actor behavior, hide/block transitions, and erasure/retry of disposable account assets. Confirm isolated endpoints before any fixture write.

**Production sequence after explicit authorization.** The read-only preflight found 51 applied migrations through `20261115154948` and no deployed moderation review RPC.

1. Rehearse the signed RPCs, private Storage, scoped image review and a report through resolution using authorized disposable staging actors. Check ordinary users cannot review, revoked staff lose access, blocks and hidden Recipe shares fail closed, and old client reporting still works.
2. Confirm the linked project is the migrated production target. Compare local and hosted migration history and hashes through the predecessor. Run `supabase migration list --linked` and `supabase db push --linked --dry-run` from a release checkout with the exact approved set pending. The five candidates below are locally verified. Complete image screening and the signed fixture rehearsal before the public moderation rollout. If the preview differs, stop and resolve the history first.
3. Capture relevant counts and hashes for accounts, Dishes, cooks, ranks and comparisons, Recipes and revisions, social objects, reports and the Storage inventory. Take the same ordered aggregate fingerprints before and after, excluding only the documented new moderation columns from the old-row comparisons. Compare Storage inventory and known manifest hashes with [the Storage inventory query](DevelopmentTools/supabase_clean_migration_storage.sql). Capture the function/RLS/grant catalog using [the catalog query](DevelopmentTools/supabase_clean_migration_catalog.sql). Run `DevelopmentTools/database_health.sql` and check the Dashboard disk view and capacity Cron. The transaction makes bounded schema changes to existing tables. Use a quiet window to minimize lock contention.
4. Apply these candidates in order through the approved migration path once the release gates are satisfied. With a verified CLI dry run, use `supabase db push --linked`.
   1. `20261116204043_public_mvp_moderation.sql` adds the moderation states and audited review.
   2. `20261117063020_dish_owned_recipe_share_options.sql` uses the moderation state when suggesting or attaching a Recipe. The existing lookup keeps its historical, cook-specific and legacy associations before the indexed `recipes.dish_id` fallback. The attachment still requires explicit consent.
   3. `20261117140912_idempotent_post_descriptions.sql` reuses the same authenticated publication contract and avoids unchanged description writes. No backfill or new table.
   4. `20261117142805_private_recipe_authorization.sql` isolates private ownership. Its predecessor guards stop the transaction if the expected Recipe signatures have drifted.
   5. `20261117142843_public_text_screening.sql` adds prospective screening and staff-only subject correlation.

   Reconcile the approved migration hashes, verify grants/RLS, and compare the captured records and Storage inventory. The new reviewer and audit tables start empty. Verify that Gateway exposes Recipe reporting before distributing the new UI.
5. Confirm the Gateway exposes the expected authenticated RPC and rejects unauthenticated access. On an authorized live session, use `POST {}` with JSON for `recipe-import` and expect `400 invalid_request` after authentication. Use signed `GET` for `delete-account` and expect `405 method_not_allowed` after gateway verification. Keep the Apple authorization code and Gemini input absent. Both probes must reject an absent or invalid token. For the byte-level acceptance use the disposable actors above. Verify lookup by cook and owned post ID, explicit private Recipe consent and rejection of hidden Recipe attachments. Verify the operator workflow and enroll only named production staff once it is ready. Keep staff sessions and credentials out of command arguments and logs.
6. If review access must be withdrawn, remove reviewer memberships. If the API itself requires containment, use an authorized, forward-only change to revoke authenticated execution on both `api.moderation_review(text,jsonb)` and `staygrubby.moderation_review(text,jsonb)`. Preserve reports, audits and visibility decisions. Keep the hidden-Recipe attachment guard if reverting lookup behavior with a forward migration. The description write optimization can be reverted independently by restoring its predecessor body in a new migration. Keep the private owner authorization correction during containment. If screening misclassifies a legitimate pattern, pause rollout and repair the detector in a forward migration. Disabling screening is an explicit emergency decision with public publication paused. Pause the client rollout and repair forward. Avoid truncating tables, dropping constraints, restoring the frozen project or reopening hidden content as a rollback.

## Before public launch

- Finish the signed `recipe-import` and `delete-account` production Gateway probes with appropriate authorized sessions and non-mutating requests. Read-only function inventory confirms both require JWT and the development test function is absent. The prior negative probes and the local handler tests cover different parts of the flow.
- Complete the staff procedure, including approved image access, response targets, coverage and escalation. Accept the text behavior, complete the image screening gate and review the Terms, Community Guidelines, privacy disclosures, age rating and reachable support. [Apple's user-generated content review guideline](https://developer.apple.com/app-store/review/guidelines/#user-generated-content)
- Verify actual Auth and Storage cleanup on authorized disposable infrastructure. Repeat relevant account, block and visibility checks through the real client/Gateway as part of the release gate.
- Establish a staffed capacity alert destination and confirm delivery. The five-minute production Cron reported no active signals in the read-only preflight. Alerts currently go to database logs. See [capacity monitoring](supabase/README.md#automatic-target-monitoring) and the [public release checklist](V1_RELEASE_GATE.md).

## After launch

Consider audited restore within the staff API, case assignment, reporting trends and improved image-review tooling once there is an operating need. An automated moderation or AI system, a general admin dashboard and extra user surveillance are outside this candidate.
