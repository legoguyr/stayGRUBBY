# Security activation and recovery — prepared, not active

November 23, 2026. Owner confirms `@grubwithguy`; read-only production lookup found one active match. No production grants, deployment, merge or push is authorized. No new production accounts are needed.

## Exact approval package

1. Integrate the reviewed Codex checkpoint into accepted main, preserving independent work and reconciling the migration-order guard with main's already-aligned predecessor filenames. Do not reapply the 65 deployed migrations.
2. Deploy only `20261123035208_staff_reported_photo_operation.sql`, then `20261123171953_moderation_staff_roles.sql`. The first normalizes the existing staff photo operation; the second adds a role column, private role-change audit, guards and authenticated admin-only RPC. Existing memberships default to moderator (production currently has none). No enrollment or content backfill occurs in migrations. Compare hashes, grants and relevant data/Storage fingerprints, and run the existing database health check at approved deployment.
3. Resolve and privately pin the existing permanent account UUID for `grubwithguy` and its original Auth link. Obtain final enrollment approval. In an authenticated operator session set `staygrubby.approved_owner_id` to that verified UUID before running `enroll_initial_admin.sql`; the script refuses a missing/different ID, nonunique username or existing staff. It inserts **one** admin membership and its audit, creates no account, and changes no other user's role. Do not treat a reused username as proof of ownership during later recovery.
4. Verify only that account is admin, ordinary users cannot call role management, self-target reports remain unavailable even to admin, and staff can read only reported original images. Do not write synthetic reports to production.
5. Separately approve the email activation below. No automatic website/TestFlight deployment is included.

A private authenticated staff caller is still needed for owner operations: use the existing report queue/review/resolve contracts and new `api.staff_roles`. There is no new dashboard or Swift change in this checkpoint. Claude can wire a thin server-authorized Settings entry using the existing signed client; do not paste/export sessions or put service keys in an app. This usability gate is separate from backend permissions.

## Later role changes

`POST /rest/v1/rpc/staff_roles`, `Content-Profile: api`, normal client key and the admin's live user bearer session. Body:

```json
{"action":"assign","payload":{"accountID":"existing-permanent-account-UUID","role":"moderator","expectedRole":null,"reason":"Approved staff responsibility","operationID":"fresh-UUID"}}
```

`role` is `admin` or `moderator`. Use `action: remove`, omit `role`, and give the exact current `expectedRole` to revoke. Use `list` with `{}` payload for a bounded staff inventory. Responses contain `operationID` and resulting `role`. Changed operations create one audit; lost-response retries return the same result. No-op assignments create no audit/write. `PT409` means stale role, conflicting operation ID or last-admin protection: refresh, never blindly retry. `42501` means unauthorized/inactive account. Normal users/moderators cannot grant roles; all current staff can use the existing case API. No self-case override exists.

Role changes serialize across requests. Direct last-admin deletion/demotion is also guarded. Deliberate account erasure remains allowed only through the established deletion job after Storage cleanup: FK cascade removes the membership and clears private actor/subject references while retaining nonpersonal audit outcomes. No erased account is resurrected. If no active admin remains, the owner must authorize authenticated database-operator recovery to a separately verified **existing** account. The operator records a reason and inserts its admin membership; the same audit trigger runs. This is not a public bootstrap API and does not require another permanent moderator account.

## Free email monitoring — owner configuration required

Create one Healthchecks.io **Hobbyist ($0)** check, verify the owner's notification email, configure five-minute period and 15-minute grace, and enable state-change/recovery email. No card, upgrade, SMS or paid integration. Securely store its private HTTPS ping URL in Supabase Vault as `staygrubby_capacity_ping`; never put it in chat, Git or logged command arguments.

After separate approval run `activate_capacity_email.sql`: enable `pg_net`, create the closed heartbeat helper, and schedule one job two minutes after each existing five-minute capacity sample. It sends only `{}` and success/failure state. Timeout is three seconds; a pending request coalesces subsequent attempts. Keep pg_net response retention bounded (six hours or less); this is transient technical data, not product history. A missing or failed database/job leads to an external missing-heartbeat email. Full platform System disk remains a dashboard metric, not something this heartbeat invents.

Six offline delivery assertions and five existing capacity-evaluator tests pass. Actual HTTP/email delivery is **pending** the owner's free account and final activation. Use a separate synthetic check to verify healthy → failure → silence → recovery receipt; never modify production capacity signals for testing. To stop delivery, unschedule only `staygrubby-capacity-email`; preserve the existing sampler.

## Encrypted independent backups — destination required

Owner must choose an existing independent encrypted destination and an awake scheduled runner, plus where the recovery key is safely recoverable if this Mac is lost. No paid storage setup is assumed. Keep archives outside Git/iCloud working trees; only upload completed encrypted archives to an approved off-device destination.

Nightly successful recovery points: seven daily and four weekly snapshots, deduplicating overlapping points, maximum 28-day retention. No retention deletion is activated here. Target RPO is 24 hours **when the nightly job succeeds**; monitor missed backups separately and do not promise PITR. Recovery time is not yet timed for production. Document backup deletion/retention in owner-approved privacy operations.

A complete set includes consistent logical application/history/audit and Auth identities, Storage metadata, **actual bytes from all four private buckets**, ordered count/hash manifests and the matching source/migration version. Secrets/signing keys belong in a separate protected recovery store. A default CLI dump excluding Auth/Storage is insufficient; SQL dumps alone never include photos. Reconcile snapshot references and concurrent changes; a missing object/hash mismatch fails the new set, preserving the last complete set. Do not restore an old account/content snapshot to live service without reconciling known subsequent deletions/tombstones.

`DevelopmentTools/encrypted_backup.mjs seal INPUT OUTPUT RECOVERY_KEY_FILE` seals a complete archive using AES-256-GCM, a random nonce and authenticated format header. `open` authenticates before publishing output. A recovery key is 32 random bytes in an owner-only file (0600); never print/paste it or keep the only copy beside its backup. Outputs never overwrite existing files; failed decryption does not publish plaintext. Temporary plaintext stays in a private operator directory during authorized restore only. The helper performs no cloud request or retention deletion.

Disposable proof: `Backend/tests/staff-backup.local.mjs` requires `SG_LOCAL_STATUS` for the isolated `staygrubby-final-gates-*` stack and `SG_POSTGRES_BIN` (PostgreSQL 17 tools directory with trailing slash). It refuses hosted URLs and non-synthetic Auth users. It exercises concurrent demotion, dumps/restores the actual Auth/application/Storage catalog into a separate disposable database, encrypts/decrypts a complete archive and verifies every restored table plus seven real photo files across all four buckets. Tampering is rejected. No production backup was taken. Retained synthetic evidence: `/private/tmp/sg-restore-proof-JU1LBT`.

## Apple review — documentation first

Prepare review notes for Apple-only sign-in/onboarding, creation/ranking, Recipe recovery, report/block, account deletion and support. Explain server moderation, privacy and self-case rules accurately. No Apple credentials or admin role are provided to reviewers. Complete App Store privacy/age-rating fields from actual behavior. Agree full feature access with Apple; the Debug tour is not a Release demo. No new auth/demo mode is approved or implemented here. Approved Terms/Community content and their small app links remain separate owner/Claude work.

Restore-proof boundary: the separate database and decrypted photo files were verified byte-for-byte. The drill does not claim production disaster recovery, reconfigured Apple/provider secrets, restored-target Apple sign-in or an independently configured off-device backup schedule. Fresh recovery infrastructure must initialize the standard Supabase roles/extensions and validate restored Storage serving before live activation.


## Staff status and Claude 005a178 integration

`20261123210229_staff_status.sql` completes `api.staff_status(action: "me", payload: {})`: exactly one `role` key with admin/moderator/null. Authenticated ordinary **active permanent accounts** return null; no selected account ID is accepted. Current session and account readiness use `social_actor`; unprovisioned/deleting accounts and missing/revoked sessions are denied. Both functions are stable; no table/audit/provisioning writes, row locks or role changes. Existing role management and self-case protection are untouched.

Claude's actual `SocialPayload()` encodes `{}`, `StaffRole` decodes admin/moderator, and its optional role accepts JSON null. `SocialTransport` allows both staff_status and moderation_review. Feature flag off means no role request. Compatibility was checked against the actual `005a178` source and its supplied tests; standalone Swift decoding passed all three actual response shapes. No Swift files were edited and no app-wide suite was repeated.

An evidenced activation dependency is included: replace only the existing flag reader predicate so `staff_moderation` is delivered to current staff. Other flags and audiences keep their existing behavior. No flag is enabled/inserted by the migration. With one owner membership, only that owner receives the staff gate. Future admin/moderator promotion and revocation naturally change delivery without another migration.

**After explicit approval, in order:**
1. Integrate Codex reviewed commits through this endpoint checkpoint and Claude `005a178` into current main; preserve all independent work. Reconcile canonical docs, reference schema, manifest and the predecessor-order guard with main's applied timestamp alignments. No integration has been performed here.
2. Validate the integrated backend with focused staff-status/role tests and the native ModerationTests/endpoint allowlist test. Reuse Claude's accepted synthetic UI tests; run additional UI only for integration changes/failures. Do not repeat the full frozen suites.
3. Dry-run only the three genuinely pending migrations: `20261123035208_staff_reported_photo_operation.sql`, `20261123171953_moderation_staff_roles.sql`, `20261123210229_staff_status.sql`. Confirm target, 65 existing hashes and approved fingerprints; deploy these three in that order only after approval. No content reset, account creation or backfill. No Edge Function deployment is needed.
4. Recheck migration hashes, database health, unchanged user/Storage inventory and grants. Supply the privately verified permanent owner UUID and execute the prepared `enroll_initial_admin.sql` after enrollment approval. Exactly one existing admin plus its audit; zero backup/test accounts.
5. Prepare/install an approved client containing `005a178` (existing Build 7 lacks it). No archive/upload/distribution is authorized here. Then, after flag activation approval, run `enable_staff_interface.sql` with the pinned owner UUID. It aborts unless only the approved owner is enrolled. `audience=everyone` is metadata; the new server predicate filters this key to staff, not all users.
6. Owner verifies Settings → Moderation and authorized fresh photo access; never generate synthetic reports against real users. Use existing reports if any; hide/dismiss mutation requires an authorized real moderation decision. Reports about the owner remain excluded. Disable only staff_moderation for UI containment; preserve roles/audits and repair forward. Revoking a staff role immediately denies backend moderation and removes subsequent gate delivery.

Risks/dependencies: activation before the status/flag migration could hide the row or cause needless ordinary-user role probes; therefore leave the gate off until step 5. Enabling a feature flag never grants staff authority. API-only deployment does not add UI to older builds. Real staff enrollment, client rollout, flag activation, merging and pushing each remain unapproved. Monitoring/email setup and backup destination are independent existing gates, not prerequisites for this read-only endpoint.
