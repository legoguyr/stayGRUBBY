# Image moderation — zero-billing MVP

## Product decision and current state

The public MVP uses **human approval before audience image access**. It requires no paid service, billing account, card, provider key, model host or scheduled classifier. This supersedes the earlier Google Vision recommendation. File validation checks format and bounds; it does not detect inappropriate content. The `ImageScreener` interface remains available for a separately approved future provider.

Implementation and disposable fixture acceptance are local. Production deployment and release distribution remain pending approval. Apply all eight candidates in [the rollout manifest](Backend/PUBLIC_MVP_MIGRATIONS.sha256), including `20261118034708_free_manual_image_moderation.sql`. Its prerequisite image foundation is unchanged. Existing shared images enter the hold on rollout and must be reviewed. Existing owners retain private access and all original bytes/records.

## Free classifier evaluation

| Option | Evidence and MVP decision |
| --- | --- |
| NSFWJS | MIT library with browser, WASM and Node backends and a small-model option. Its authors report roughly 90%/93% accuracy for their models; these are not StayGrubby food-photo benchmarks. Its sexual-content categories do not cover the full community policy. It is a credible future local review aid. We have not established safe automatic approval or measured Edge runtime fit, so it is excluded from the launch gate. [Project](https://github.com/infinitered/nsfwjs) |
| NudeNet | Local ONNX/OpenCV detector with a bundled 320-resolution model and nudity/body-part labels. The repository is AGPL-3.0 and requests maintainer help. Native Python/ONNX dependencies and license/weight review add operational work; it does not provide broad abuse screening. [Implementation](https://github.com/notAI-tech/NudeNet), [license](https://raw.githubusercontent.com/notAI-tech/NudeNet/v3/LICENSE) |
| Existing Supabase Edge infrastructure | Hosted limits include 256 MB memory, two CPU seconds per request and restrictions on native/multithreaded dependencies. No representative classifier benchmark has been run here. Installing a model would consume bundle, cold-start, CPU and invocation budgets. An always-on Mac daemon would introduce an availability dependency. Human review avoids these launch dependencies. [Runtime limits](https://supabase.com/docs/guides/functions/limits) |

Free inference tools exist. The decision is to use the supported manual fallback for this small launch while preserving a replaceable adapter. No custom AI, downloaded model, external inference request or new dependency was added.

## Owner/admin workflow

1. After approved deployment, an operator enrolls the owner's existing permanent account in `staygrubby.moderation_reviewers` using the trusted Supabase SQL editor. Use the verified account UUID and `insert ... on conflict do nothing`. The app cannot grant this membership. No service credential is entered into the app.
   ```sql
   select p.account_id, p.username from staygrubby.profiles p
   join staygrubby.accounts a on a.id=p.account_id
   where p.username='<your existing username>' and a.status='active';
   -- After verifying the returned permanent account UUID belongs to you.
   insert into staygrubby.moderation_reviewers(account_id)
   values('<verified permanent account UUID>'::uuid)
   on conflict(account_id) do nothing;
   ```

2. Sign in normally with Apple, then open **My Kitchen → Settings → Moderation → Image Review**. The entry appears only after a live server capability check. Every queue, inspection, download and decision independently rechecks current authority.
3. Pending shows up to 25 eligible shared originals per page. Open a photo. The app downloads only that original through authenticated Storage, bypasses normal caches, validates complete JPEG decoding, the 2 MiB/4,096-pixel bounds, and computes SHA-256. Inspect the visible content yourself. **Approve** grants only its existing audience; **Reject** keeps it owner-private. Invalid or unavailable files cannot be approved.
4. Approved allows review and **Hide Image**, which withdraws audience access. Rejected allows deliberate reconsideration after a fresh inspection. A conflicting decision or replaced generation requires Refresh. The original is retained.
5. Remove the membership through trusted SQL to revoke reviewer authority. The server rejects further actions immediately. Named reviewers may review their own explicitly shared originals, with the same audit, so a small launch can be operated by one owner. This role grants no access to the cooking-photo bucket or private-only Recipe library.

`api.image_moderation` accepts the existing action/payload envelope. `capabilities` returns `{"reviewer":true}` only for live enrolled staff. `queue` accepts `reviewState` (`pending`, `approved`, `rejected`) and optional `afterID`; pending includes older `review` states. `inspect {objectID}` returns the current object/generation/state/bucket/path. `resolve` requires `objectID`, `generation`, `expectedState`, `decision` (`approved` or `rejected`) and `photoHash` for approval. The app supplies the hash after inspecting fresh bytes. Replays return the existing decision without another write; mismatches return `PT409`.

Only actual decision changes append `image_review_actions` with object, generation, reviewer, prior/final state, hash and time. Queue/inspection/capability/cache authorization reads create no rows. Inspection takes no review-row write lock. The decision locks in Storage object → review order to serialize replacements. Audit is typically one approval and occasional hide/reconsideration per original, retained with it. Object/owner erasure cascades it; reviewer erasure removes only that reviewer identity.

Existing post/comment/Recipe/profile reporting, blocking and the staff report → review → resolution APIs remain active. Follow [the report queue procedure](PUBLIC_MVP_MODERATION.md#owner-operated-moderation) for contextual reports. A hidden Recipe/profile/post or block still overrides an image approval.

## Privacy, URLs and caches

- Reuse original private Storage objects. There is no quarantine copy, duplicate permanent JPEG, external image transmission or new view telemetry. Private cooking photos are excluded. Private-only Recipe photos and withdrawn, unreferenced shared originals are excluded from the staff browser and optional validation worker.
- Existing audience/owner/account/block/moderation restrictions still apply. Pending/rejected originals cannot be fetched by a peer. Public, signing, listing and unsupported transform operations are denied. The Recipe owner-read helper now restricts explicit Storage operations while preserving the existing internal photo RPC.
- The client calls authenticated `api.image_access(bucket,path)` before reusing image memory/disk caches. It is a read-only POST and returns only current permission. Concurrent checks coalesce inside the account; permission results are not cached. Denial removes cached bytes and decoded images. Views reauthorize on appearance, foreground entry and content/privacy refresh. Existing bounded byte caches still save repeat downloads, including sharing/export callers. Cached remote images require online authorization and show a placeholder offline; local cooking photos remain available through their existing local store.
- Staff originals are held in memory for the current review only. App backgrounding clears that preview and re-entry rechecks access. The client never creates signed image URLs.
- Previously received bytes, screenshots or exported copies cannot be remotely recalled. Previously issued signed URLs are stateless capabilities and can survive a later RLS change until expiry. The official app has no signed-image creation path. Before production activation, establish whether any were issued outside the app and resolve their expiry/revocation separately if necessary. New signing is denied. Server policy cannot retroactively erase a recipient's downloaded copy.

## Optional adapter and cost

`moderate-images` stays disabled. The normal manual workflow does not deploy or invoke it. Its default `manualScreener` uses bounded JPEG structural checks and returns `review` or `rejected`, never approval, with no network provider/key. The database also converts a worker `approved` result to `review`, preventing an old worker from bypassing the manual launch policy. Three-attempt leases/backoff remain available for a future scoped use.

A normal approval changes one existing review row and inserts one audit row. Reads add no durable data. No additional image Storage, recurring classifier jobs or provider charges are introduced. Normal database/Storage/egress use still consumes the existing free quotas and remains covered by capacity safeguards; this feature does not upgrade a plan.

## Operating workload and rollout

The owner must check Pending regularly and review reported content. Images remain held while the owner is absent. For planning only, 20 photos at 15–30 seconds each is about 5–10 minutes; 100 is about 25–50 minutes, before reports and uncertain cases. These are workload estimates, not measured throughput. Name a backup before availability or queue size exceeds one operator's capacity. Quota exhaustion and connection failure keep images private and allow later review. A classifier can miss policy violations; manual review can also make mistakes. Reporting/blocking and responsive staff remain necessary.

After approval, rehearse the [disposable signed stack](Backend/README.md#disposable-signed-backend-acceptance), capture existing graph/Auth/Storage fingerprints and run the exact eight-migration manifest. Deploy the matching client only after the new API is available. Enroll staff, review the existing backlog, verify pending/approved/rejected reads for owner/peer/outsider and make one owner iPhone review. The optional worker remains disabled. Compare data/Storage and health afterward. Use an authorized forward correction for containment; retain the originals and manual hold. Production migration, rollout, GitHub push and TestFlight each keep their existing approval gates.
