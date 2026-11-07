# StayGrubby public website and sharing links

The existing Cloudflare Worker `staygrubby` serves `staygrubby.com` in account `a53a5efe17232f5b9d3e5cd62cceba15`. Do not create another website, change DNS/email, or add a public Recipe/feed browser. The November 2 Next-Version cycle explicitly reopened the contained app-link dependency; the historical assets-only/profile-only restriction is superseded for this router.

## Architecture

`link-worker.mjs` is a small stateless request handler over the existing static assets. It fetches no Supabase/account/content data, renders no private metadata, sets no cookies, runs no browser JavaScript and accepts only GET/HEAD. Ordinary pages/assets remain static. `association.json` is the shared AASA source for the build and handler. The app ID is `5DSB36G7LZ.com.guyrettig.StayGrubby`.

| Generated HTTPS pointer | Native destination after authentication and authorization |
| --- | --- |
| `/@username` (also ordinary `%40` escaping) | Current discoverable Kitchen; own Kitchen selects the actual My Kitchen tab |
| `/p/<post UUID>` | Current authorized cooking post |
| `/r/<Recipe UUID>` | Current authorized Recipe |
| `/p/<post UUID>/recipe` | The immutable Recipe revision deliberately attached to that post |

These links confer no access. Invalid/deleted/private/blocked destinations show an unavailable state; the web deliberately gives the same generic fallback for every syntactically valid pointer, without checking object existence. No credentials, signatures, account identifiers, personal notes or content appear in URLs. Profile usernames retain the existing anti-recycling route rules; UUID pointers remain stable across content edits. No redirect parameters or arbitrary destinations are supported.

Dish/cook and Signature Dishes native exports remain approved branded images, with no private cook/ranking URL. Published cooking posts can separately share their authorized post pointer. Export colors/layouts and unlock rules are unchanged.

## Confirmed failure and correction

The old `/@* → /kitchen.html` rewrite interacted with default HTML canonicalization: the live profile URL redirected to `/kitchen`, which redirected to itself. Privacy/Support suffered the same loop. It also discarded the intended profile. Native parsing rejected `%40` and supported no post/Recipe routes. Entitlements and profile AASA identity already existed; missing entitlements were not the proven cause.

The handler now returns direct 200 fallbacks retaining the validated destination, and direct JSON AASA at both `/.well-known/apple-app-site-association` and `/apple-app-site-association`. `html_handling=none`, empty `_redirects` and explicit Worker-first paths prevent the loop. The fallback offers a user-initiated `staygrubby://open/...` button, registered by the native Info.plist. There is no automatic app-open loop.

Without the app, the website explains beta access and privacy, and keeps Support/Privacy available. `distribution.json` holds the verified Apple acquisition URL. iOS Universal Links depend on installation/provisioning, Apple association caching and the recipient's browser preference. Same-domain Safari navigation may stay in Safari; use the explicit Open button or long-press from Messages/Mail.

## Source, verification and deployment

The canonical policy is `StayGrubby/Legal/PrivacyPolicy.md`, effective November 5, 2026 for Product Closeout. It is bundled offline and rendered completely by `build.py`. Official artwork comes from the app asset catalog.

Run the production entry point from the repository root with an authenticated Wrangler:

```sh
sh Website/deploy-production.sh
```

The script builds the public asset allowlist, runs the local tests and Wrangler dry run, deploys the Worker and assets using `Website/wrangler.jsonc`, then runs `python3 Website/verify_live_links.py`. A production publish is incomplete until the live gate passes. An assets-only deploy (including `wrangler deploy --assets` or an assets-only dashboard upload) is invalid even if Home, Privacy and the static AASA file respond. The Worker owns `/beta`, profile, post and Recipe browser fallbacks.

Use existing authentication. If Wrangler is unavailable during an incident, the authenticated Cloudflare connector can restore a previously verified full version after confirming the active deployment and the target's `fetch` handler and `ASSETS` binding. Run the same live gate immediately and verify the active version afterward. Keep the existing domain, disabled workers.dev/previews and public asset allowlist.

The authenticated connector deployed tested bundle version **e392a755-ffe1-4261-b0f3-f4f39d2bbba4** during this cycle. A first `keep_assets` deployment retained old routing configuration; verification caught it. The routing correction reattached the byte-identical existing asset manifest using a short-lived completion capability internally, and applied the tested routing settings. No capability was printed, persisted or added to the repository; no static asset bytes changed. Source AASA is served by the handler ahead of the retained older asset copy. A normal future Wrangler deployment rebuilds/replaces that asset too. Final configuration verification also caught default workers.dev/preview exposure from the API upload and restored both to false, confirmed by read-back.

Verify direct responses for all pointer forms, both AASA paths, `/`, `/privacy`, `/support`, unknown/malformed paths and official assets. Check identity/security headers, destination retention, no redirect loops and no private-content fetch. Current hosted routing, all 14 public path responses and the exact hosted canonical policy were verified. Apple’s public association CDN also returned the same current JSON; this is not a claim of physical iOS acceptance.

## November 4 Stage 3 hosted regression closeout

An assets-only publish displaced the router in hosted version `26be2b2b-ae30-4503-a2d3-a5f117adcbb5`; valid Recipe/post/profile requests returned empty untyped 404s. Repository route tests alone could not detect the missing deployed handler. Stage 3 restored the tested Worker plus the byte-identical existing asset manifest, with ASSETS binding and exact `run_worker_first` settings. Active version is `1de0d408-5934-4614-8acc-71a37b62ba37`; workers.dev and preview URLs remain disabled. Link HTML explicitly uses `Content-Disposition: inline`; malformed app paths get branded HTML 404.

Always deploy with `--config Website/wrangler.jsonc`. Never publish this site as assets-only or substitute `wrangler deploy --assets`: the native URL fallback depends on the Worker. After a deployment run `python3 Website/verify_live_links.py` (22 read-only real GET/HEAD checks) and read back the active router/ASSETS configuration. If normal CLI authentication is unavailable, use only the existing authorized connector; do not change credentials. This guard checks actual hosted HTML/MIME/disposition/no redirects and exact AASA; physical association/Messages/Safari still require owner acceptance. [Stage 3 evidence](../NEXT_RELEASE_STAGE_3_REVIEW.md).

## November 5 Stage 5 hosted regression closeout

The whole-app audit found active assets-only version `a53e89dd-e0fc-4f7c-a8eb-3961e287886d` had again displaced the accepted handler/binding/Worker-first configuration, yielding empty 404s for valid shared pointers. Restored the unchanged router and byte-identical eight-file asset manifest as **`19b93d04-f64d-4aa1-988c-2877aa5d2ac9`**; no static asset bytes, private data, DNS or credentials changed. All 22 actual public GET/HEAD checks pass, with exact AASA, direct inline fallback HTML, Privacy/Support and disabled workers.dev/previews confirmed. Every future website publish must retain the router and pass the live guard; an assets-only publish is not a valid StayGrubby deployment. [Stage 5 evidence](../NEXT_RELEASE_STAGE_5_REVIEW.md).

## Functional beta acquisition

The deployed Worker serves `/beta` and embeds the same acquisition action on generic profile, post and Recipe fallbacks. `distribution.json` controls the Apple destination for all of them. When the verified App Store listing is available, switch that one value and deploy the full Worker plus assets. AASA and canonical paths stay unchanged. No public content is fetched.

The optional `?ref=<opaque token>` is 16–64 ASCII letters, digits, underscores or hyphens. A single valid value travels in the explicit Open StayGrubby URL; invalid or duplicate values are ignored. TestFlight receives the verified invitation URL alone. After installation, reopen the original shared link to recover the intended destination and any referral metadata. Attribution at signup requires future work.

Worker version `f5164ec8-90ca-44b9-b567-697963dc1f09` shipped beta acquisition with the ASSETS binding and the existing static bytes, including the current Privacy page.

## November 7 Build 4 production recovery

The active Wrangler deployment `b490cd5c-3d16-4ab8-9843-0d58e542ee53` contained neither a fetch handler nor an asset binding. Home, Privacy and static AASA still responded, while beta and valid shared pointers returned empty 404s. The canonical Wrangler dry run packaged the handler and binding, but the local CLI had no authenticated session. The authenticated Cloudflare connector redeployed the previously verified full version `f5164ec8-90ca-44b9-b567-697963dc1f09` to 100% in deployment `01aaf7a1-7034-4ee0-a64e-4399543644c8`. The Worker's `workers.dev` and preview access were returned to their canonical disabled settings.

All 27 local website tests and 30 hosted GET/HEAD checks passed. Verified direct browser fallbacks and the configured Apple beta invitation, malformed and unknown 404s, headers, both origin AASA endpoints and Apple's association CDN. Home, Privacy, Support, CSS and wordmark matched the canonical build before and after recovery. The production script now requires the live check and rejects deployment overrides.
