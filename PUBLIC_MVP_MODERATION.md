# Public MVP moderation and privacy

The moderation candidate adds object-level Recipe reports and an authenticated staff queue to the deployed post, comment, profile and block infrastructure. Migration `20261116204043_public_mvp_moderation.sql` is prepared locally. Activate it on the migrated target through the release gate in [V1_RELEASE_GATE.md](V1_RELEASE_GATE.md). The frozen source remains outside this rollout.

## Staff workflow

1. A user can report a post, comment, profile, current Recipe or a Recipe revision explicitly attached to a post. The server derives the reporter from their live session, verifies current access, deduplicates, and limits intake to 50 reports per account per day. Reports have a reason and up to 500 characters of optional context. Receipt retries do not write duplicate records.
2. A designated database operator enrolls a verified staff member's existing permanent account in `staygrubby.moderation_reviewers`. This table starts empty and is closed to API roles. Enroll only named staff with an active account. Confirm the account ID through an approved internal process and record the grant or revocation in the operational access record. A reviewer needs a live signed session and cannot act on a report about their own account.
3. Call `api.moderation_review` through the authenticated staff integration using the reviewer's **own** user session. The callable contract below can be used by a simple operations client. Review the launch gate for the staffed rehearsal and handling of reported images.
4. Use **dismiss** when no moderation action is warranted. Use **hide** to withdraw the item from its social audience. Resolution and its reviewer, decision and time are recorded atomically. A lost-response retry returns the original result. Conflicting final decisions return a refreshable `PT409`. The private audit survives removal of the reviewer identity while the case survives.
5. Revoke access by removing the staff membership. The next request checks membership and session validity. An exceptional action outside the queue is restricted to database operators and requires an incident record with actor, reason, time and affected record. The legacy service-key mutation is revoked by the migration.

| Action | Payload | Result |
| --- | --- | --- |
| `queue` | `{}`, then `{"afterTime":"<last createdAt>","afterID":"<last id>"}` | Oldest first, up to 25 pending rows. Returns only report metadata. |
| `review` | `{"reportID":"<id>"}` | Report context, the referenced subject, and any final outcome. Recipe evidence uses the exact reported revision. |
| `resolve` | `{"reportID":"<id>","decision":"hide"}` or decision `dismiss` | Final status, decision and recorded time. |

The REST entry point is `POST /rest/v1/rpc/moderation_review` with `Content-Profile: api` and a signed staff user session. Keep tokens out of commands, logs and case notes. Queue and case reads create no audit writes. The staff projection exposes the reported item and references to its images. Report image review requires approved access via the existing private Storage operator path. A case reference does not grant Storage access, and staff do not receive general access to private cooking media through the app.

## Privacy and lifecycle

- Private cooking graphs, Dishes, comparison evidence and notes stay owner-scoped. The Pass contains intentionally shared cook snapshots. Profile discovery remains opt-in and social DTOs remain bounded. The current backend exposes no anonymous Recipe content or open profile pages.
- Blocking uses the existing server-side visibility checks. New Recipe moderation uses the same visibility gate as direct reads, pinned attachments, shared links and private photo reads. The owner retains private access, and existing independent copies and personal cooking snapshots remain with their owners. A shared cook can stay visible with its hidden Recipe pointer withdrawn. An already delivered external image or screenshot cannot be recalled.
- The queue does not expose the reporter identity. Staff can see report context and the referenced shared content only. It creates no duplicate media or content snapshots. Existing report cascades continue when the reporter, target, post or comment is erased. Recipe revision erasure also removes the associated report and audit. Audit rows store one outcome per report and are retained for that case's lifetime.
- The authenticated production edge functions are `recipe-import` and `delete-account`. The migrated target returned 401 for missing/invalid tokens and 404 for `development-test-session`. The checked-in default config now excludes the development function from deploy and serve. The existing sandbox test proof flow requires an isolated explicit enablement.
- The target's capacity job remains active. Staff queue work uses a bounded indexed page, one requested case at a time and one outcome write per resolution. No cloud polling, new background work or additional Storage is required.

## Before public launch

Apply the additive migration after approval. Verify grants and RLS, role addition/removal, actual visible and blocked destinations, deletion cascades, report-to-resolution operation and private image review on a disposable staging identity before opening real-user access. Confirm the production function gateway with valid signed requests from an authorized test session and run the account-deletion smoke procedure without using a real account as a fixture. Agree on staffed response targets and escalation, publish the required policies/support channels, and complete the objectionable-content filtering and Apple privacy/age-rating requirements. See [Apple's user-generated content review guideline](https://developer.apple.com/app-store/review/guidelines/#user-generated-content).

## After launch

Consider audited restore within the staff API, case assignment, reporting trends and improved image-review tooling once there is an operating need. An automated moderation or AI system, a general admin dashboard and extra user surveillance are outside this candidate.
