# Image moderation — immediate posting and report-based response

## Current product decision

Users publish food photos immediately through the existing explicit Post to The Pass, avatar or Recipe-sharing workflow. There is no image approval, pending-image hold, classifier, image-review Settings page or recurring image job. Normal upload integrity checks and automatic text moderation remain. File validation does not recognize inappropriate content. This November 18, 2026 owner decision supersedes the manual prepublication system at `0f3c820`.

No paid image service, API, billing account, card, provider key or heavy local model is introduced. Optional automated image moderation is a **future enhancement**, not an MVP prerequisite. Existing publication, reporting, visibility and staff-resolution boundaries remain replaceable; unused classifier adapters and worker code are removed rather than kept as runtime infrastructure.

## Reporting and moderator intervention

- Report an inappropriate photo through its post, Recipe/revision or profile using the existing Report action and `inappropriate` reason. Comments retain their report action. Reports are permission-checked and deduplicated. Block continues to remove the relationship and enforce bilateral social restrictions.
- Named staff use the existing authenticated `api.moderation_review` queue, review and hide/dismiss actions. Membership lives in the closed `moderation_reviewers` table and is checked on every request. Ordinary accounts and a service key alone have no staff authority. There is no prepublication reviewer enrollment requirement for posting. [Exact contracts and owner procedure](PUBLIC_MVP_MODERATION.md#staff-workflow)
- A staff case returns only its reported subject/revision and nullable original photo pointer. Authenticated Storage GET permits enrolled staff to inspect that reported original; it does not open other cooks, private-only Recipe photos or the private cooking bucket. Dismissal ends this extra case-image access. Hidden cases retain scoped evidence until the case or owner is erased; role revocation takes effect on the next request.
- Hide withdraws the reported post, Recipe or profile and its dependent image access. It does not delete an owner's original, destroy private cooking or unnecessarily hide unrelated posts. Existing content audits record one actual case resolution, with idempotent retries. Exceptional operator intervention on independently identified violations follows the existing incident-record procedure.

## Privacy, URLs and caches

Photo audience is determined by existing owner, relationship, public/private profile, Recipe attachment, block, active-account and content moderation rules. Public-discovery avatars retain their existing public-in-app audience; a private profile does not become public. No anonymous image access or publicly browsable Recipe site is added.

Authenticated original GET/HEAD/info and existing upload/delete operations remain supported. Signing, public-object, list and unsupported transformation operations cannot be used to create a moderation/privacy bypass. Internal Recipe photo descriptor calls continue to work.

The read-only `api.image_access(bucket,path)` still authorizes normal cache reuse, including sharing/export. Reads create no audit or queue rows; concurrent checks coalesce without storing permission results. Denial evicts cached bytes/decoded images. Re-entry, foreground and relevant content changes refresh permission. Cached remote photos require online authorization and show placeholders offline; private local cook photos keep their existing local behavior. No polling or new permanent image copies are added.

Previously delivered copies/screenshots cannot be recalled. Previously issued signed URLs can remain valid until expiry; the official app does not create image signing URLs and new signing is denied. Resolve any known external legacy signed URL exposure separately before public activation. A fresh server denial cannot erase bytes already obtained by a recipient or prevent an old unsupported client from displaying its own downloaded copy.

## Data, migration and cost

`20261118050952_report_based_image_publishing.sql` is a local forward correction. Earlier migration SQL remains byte-identical. It restores audience-only read checks, replaces broad preapproval staff inspection with report-scoped inspection, removes image-review triggers/leases/RPCs and drops only the disposable `image_reviews` technical queue. The closed `image_review_actions` table remains solely as historical evidence if any prior decisions exist; no active path writes it. Original objects, photo manifests, Auth/accounts, Recipes, cooks, ranking evidence and report audits are not rewritten. Historical image evidence retains its original object/account erasure cascades.

An ordinary upload/share makes only its existing durable writes. No approval row, classifier receipt, permanent duplicate image or image audit is created. Existing free database/Storage/egress quotas and capacity safeguards still apply; no plan upgrade is made.

The complete nine-file [rollout manifest](Backend/PUBLIC_MVP_MIGRATIONS.sha256) includes superseded intermediate migrations for history continuity. Do not activate a partial sequence that stops at either old approval gate. Complete the approved sequence through this correction before client/public acceptance. Deployment remains separately authorized; this cycle makes no hosted changes.

## Operations, community rules and App Store considerations

The owner must check the report queue regularly, name coverage/backup, establish response targets and escalate credible safety threats promptly. Workload is per reported or otherwise identified violation, not every image. There is no claim of automatic image detection: objectionable images may be visible before a report or staff discovery, and both people and text filtering can miss violations. Queue size and response time need operational ownership, not another recurring Codex task.

Community Guidelines should clearly restrict sexual/illegal content, exploitation, threats, hate, harassment, impersonation, spam and privacy/IP violations, explain Report/Block and removal, and provide a reachable support/contact path. Keep legal text and enforcement practice aligned; owner approval/publication of those policies remains a release gate. No policy publication or website change occurs here.

[Apple guideline 1.2](https://developer.apple.com/app-store/review/guidelines/#user-generated-content) requires objectionable-content filtering, reporting with timely responses, blocking and published contact information. Immediate image posting plus reactive reporting is the owner's product choice, not a guarantee of App Review acceptance. Existing text filtering and file validation must not be represented as visual-content filtering. Document the actual safeguards and obtain the release-policy disposition before submission; do not quietly restore an approval system or activate a provider.

## Verification and rollout acceptance

The disposable database regression upgrades a populated old queue with pending/rejected originals, preserves content/Storage fingerprints and historical audit, verifies immediate existing/new sharing, public/private avatars, report-based removal, staff-only evidence, role revocation, blocking, URL/cache restrictions and isolated erasure/retry. Native cache tests and targeted photo-posting/Settings UI checks cover the client seam. Full signed Auth/Gateway/Storage service acceptance remains separate from SQL catalog fixtures. [Executable local procedure](Backend/README.md#disposable-signed-backend-acceptance)

After an approved deployment, one owner acceptance: publish a food photo and view it immediately from an eligible peer, report it, hide the case as enrolled staff, then reopen/foreground the peer app and confirm the image is unavailable while the owner's private cook/photo remains. Do not use real-account deletion as an acceptance fixture. No production deployment, GitHub push or TestFlight is authorized by this document.
