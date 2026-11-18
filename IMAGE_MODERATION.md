# Image moderation — local candidate

## State and activation boundary

The migration and worker are implemented and verified with synthetic SQL and HTTP fixtures. Nothing is deployed. `moderate-images` is disabled in the default function configuration. Live provider processing, keys, billing and production scheduling require separate approval. Never use the Recipe Creator Gemini key for this service.

Applying the access migration withholds **all unapproved shared image bytes**, including existing shared objects, until their verdicts are approved. Owner access, original records and object bytes survive. Deployment requires an approved screening path, a plan to drain existing objects and a reviewed client experience for pending/flagged photos. Do not enable the read gate on the live target as an isolated change.

## Provider recommendation

| Option | Fit and tradeoff |
| --- | --- |
| **Google Cloud Vision SafeSearch — recommended initial adapter** | One synchronous REST call and no extra storage bucket or SDK. Classifies adult, violence and racy content with uncertainty levels. The adapter has a fixed host, protected header, bounded response and timeout. Google lists 1,000 free units per month and $1.50 per 1,000 SafeSearch units in the next tier. Verify the account's billing requirements and hard quota before activation. [Pricing](https://cloud.google.com/vision/pricing), [SafeSearch](https://docs.cloud.google.com/vision/docs/detecting-safe-search) |
| Amazon Rekognition `DetectModerationLabels` | More granular moderation taxonomy and a mature human-review integration. Needs AWS credentials, signing, regional and data-use decisions. It can accept image bytes without copying assets into a second bucket. Billing and free-tier eligibility depend on the account. [API](https://docs.aws.amazon.com/rekognition/latest/APIReference/API_DetectModerationLabels.html), [pricing](https://aws.amazon.com/rekognition/pricing/) |

Google says synchronous image requests are processed in memory and customer content is excluded from training its Vision models. Its contractual processing, region and retention terms still require owner review. SafeSearch labels do not establish identity, age, legality or complete policy compliance. Unknown outcomes and flagged material require staff handling. [Data usage](https://docs.cloud.google.com/vision/docs/data-usage)

**Owner activation steps.** Google documents billing enablement as a prerequisite, including projects using the monthly free units. Approve that billing prerequisite and the processing terms first. In a dedicated Vision project, the owner enables Cloud Vision API, creates a server key restricted to that API, sets an approved request quota and budget alerts, and reviews the Cloud Data Processing Addendum. Budget alerts are notifications, not a spending stop. At the published standard rate, 10,000 SafeSearch-only images in one month cost approximately $13.50 after the first 1,000 free units, before tax or other services. Retries consume additional requests. [Setup](https://docs.cloud.google.com/vision/docs/setup), [pricing](https://cloud.google.com/vision/pricing).

After approval, the owner enters the key directly into the target's Edge Function Secrets as `STAYGRUBBY_IMAGE_VISION_KEY`. Keep `STAYGRUBBY_IMAGE_SCREENING_ENABLED` disabled until synthetic staging, staff coverage and the scheduler are accepted. Enabling it permits processing of the existing shared-image backlog as well as new share-eligible uploads. Google temporarily logs request metadata, including time and size, while synchronous image bytes are processed in memory. Update the privacy disclosures and App Store data inventory before transmitting real user photos. Never send the key through chat or reuse the protected Gemini credential.

The replaceable `ImageScreener.screen(bytes)` interface returns `approved`, `review`, `rejected` or `unavailable`. The initial policy sends POSSIBLE/racy and unknown labels to review and LIKELY adult/violence to the rejected review queue. Staff may correct the outcome for the inspected generation. The adapter requests only SafeSearch and logs neither images, raw classifier payloads nor credentials.

## Data and private media boundary

- `staygrubby.image_reviews` stores at most one current row per original share-eligible Storage object, with object/account FKs, generation, lease, verdict, hash, provider and a final staff decision. No image bytes or per-request log table is added. Object/account deletion removes the operational row, and erasure of a reviewer detaches their identity while preserving the decision.
- Profile and social uploads enter the bounded worker queue. Recipe images enter only when their current Recipe or an explicit pinned attachment is shared. Private-only Recipe images and the `cooking-photos` bucket are excluded.
- Ordinary audience Storage reads still pass the prior account, audience, block, moderation and object-operation checks **and** requires an approved verdict. The original owner can inspect a pending image. A verdict grants no social access by itself. Cached or already exported images cannot be recalled.
- A changed unapproved object resets its generation and invalidates any outstanding worker receipt. Approved or human-decided paths are immutable. The client must use its existing new asset UUID/path replacement flow. No unbounded image-version archive is introduced.
- Existing profile and post cards can contain an unapproved path, and current Recipe cards can contain its photo ID. The Storage GET remains denied until approval. Clients should use their existing placeholder while pending and offer a clear review/replacement action where needed. This backend does not redesign Claude's photo UI.

## Worker contract

`POST /functions/v1/moderate-images` accepts an **empty body**, with JWT gateway verification and the platform service-role JWT matching the worker's protected server environment. A modern `sb_secret` value is not a replacement bearer JWT for this gateway. An ordinary authenticated account is denied. There is no caller-controlled owner, path or provider setting.

Only after owner-approved activation set `STAYGRUBBY_IMAGE_SCREENING_ENABLED=true` and `STAYGRUBBY_IMAGE_VISION_KEY` securely in the target Function secrets. Keep the existing platform service credential server-only. The function stays unavailable before keys and enablement are present, and claims no work in that state.

`api.claim_image_reviews()` is service-only. It takes at most five pending objects with skip-locked five-minute leases. The response array has `objectID`, `generation`, `leaseID`, `bucket`, `path` and `bytes`. Expired leases and failures have at most three attempts. The worker downloads the original JPEG with strict size limits, computes SHA-256 and submits only those bytes to the adapter. There is no publicly signed image URL.

`api.finish_image_review(object_id, generation, lease_id, outcome, sha256)` is service-only and returns a boolean. It accepts only a current, unexpired lease for an active account. A stale result writes nothing. Unknown, timeout, provider quota and network failures stop the batch, retain private access only, and wait ten minutes before a later attempt. After three attempts the item waits for staff. No automatic immediate retry is used.

Before activation configure one approved external server scheduler to call the protected function every minute, with overlap disabled and a timeout under five minutes. Store the credential in that scheduler's secret store. Alert the owner on 401/503, missed runs, sustained queue delay and provider quota. A 503 must pause subsequent calls for ten minutes. Verify synthetic healthy, failure and recovery delivery. No schedule or external alert destination was activated during this milestone.

## Human review contract

Use `POST /rest/v1/rpc/image_moderation` with `Content-Profile: api`, the publishable client key, and a named reviewer's live access token. Body is `{"action":"<action>","payload":{…}}`. The same `moderation_reviewers` membership and active-session checks gate every call. Reviewers cannot review their own objects.

| Action | Payload | Result |
| --- | --- | --- |
| `queue` | `{}` or `{"afterID":"<last objectID>"}` | `{"images":[…]}`, up to 25 flagged/review items ordered by object UUID. Each has `objectID`, `generation`, `state`, `createdAt`. |
| `inspect` | `{"objectID":"<id>"}` | Current generation, state, subject account, bucket, original private path and SHA-256. No reporter or token. Retrieve only that original with `GET /storage/v1/object/authenticated/<bucket>/<path>` using the same named reviewer token. The staff policy permits only flagged/review objects and authenticated GET, with live membership checked again. It grants no listing, signed URLs or private-only library access. |
| `resolve` | `{"objectID":"<id>","generation":"<generation>","decision":"approved"}` or `rejected` | `{"state":"approved"}` or `rejected`. Requires completed hash inspection. Replay of the final decision is idempotent. A changed generation or conflicting decision returns `PT409`. |

Staff retain the existing report → review → hide/dismiss workflow for contextual abuse and repeat offenders. Image approval never restores a hidden profile, hidden Recipe, blocked relationship or deleted post. Define primary and backup reviewers, escalation and response targets before rollout. Do not put private evidence into public support tickets.

## Ordered rollout and recovery

1. Approve processing and costs, privacy disclosure, staff operations and the pending-photo client behavior. Use the [signed local rehearsal](Backend/README.md#disposable-signed-backend-acceptance) and synthetic provider fixtures first.
2. Approve the seven pending migrations through `20261117200058_social_dish_identity` from a reviewed release checkout. Preserve their order and exact hashes. Compare existing graph, Auth identity and Storage inventory/hash fingerprints before and after and run the read-only health check.
3. Deploy only the approved worker with JWT verification retained and protected secrets configured. Drain and inspect the deliberately queued existing originals before expanded rollout. Reconcile resulting approved/review/rejected counts against originals and verify peer versus owner bytes. No image is deleted merely because screening failed.
4. Verify scheduler and capacity alert receipt with the owner. Accept signed production probes separately. Keep the release gate open until these pass.
5. For containment stop the external schedule and disable provider processing. Peer images stay fail-closed. Preserve original photos, review rows, private Food Bible access and the staff queue. Use a reviewed forward migration for classifier or access-policy corrections. Reopening unreviewed image reads requires an explicit incident decision and public publication paused.
