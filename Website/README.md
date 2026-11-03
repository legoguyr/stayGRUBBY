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

Without the app, the website explains beta access and privacy, and keeps Support/Privacy available. `distribution.json` intentionally has no beta/App Store URL; never invent one. iOS Universal Links depend on installation/provisioning, Apple association caching and the recipient's browser preference. Same-domain Safari navigation may stay in Safari; use the explicit Open button or long-press from Messages/Mail. Automatic installed-app behavior still requires two-iPhone physical acceptance.

## Source, verification and deployment

The canonical policy is `StayGrubby/Legal/PrivacyPolicy.md`, currently effective November 2, 2026. It is bundled offline and rendered completely by `build.py`. Official artwork comes from the app asset catalog.

```sh
python3 Website/build.py
python3 -m unittest discover -s Website -p 'test_*.py'
node --test Website/test_links.mjs
wrangler deploy --config Website/wrangler.jsonc --dry-run
wrangler deploy --config Website/wrangler.jsonc
```

Use only existing normal authentication; never paste tokens into Codex. Publish the tested Worker and exact `public` asset allowlist. Build output/cache/CLI state stay ignored. Config keeps the existing identity/domain, compatibility date, disabled workers.dev/previews, no backend bindings and no paid setup.

The authenticated connector deployed tested bundle version **e392a755-ffe1-4261-b0f3-f4f39d2bbba4** during this cycle. A first `keep_assets` deployment retained old routing configuration; verification caught it. The routing correction reattached the byte-identical existing asset manifest using a short-lived completion capability internally, and applied the tested routing settings. No capability was printed, persisted or added to the repository; no static asset bytes changed. Source AASA is served by the handler ahead of the retained older asset copy. A normal future Wrangler deployment rebuilds/replaces that asset too. Final configuration verification also caught default workers.dev/preview exposure from the API upload and restored both to false, confirmed by read-back.

Verify direct responses for all pointer forms, both AASA paths, `/`, `/privacy`, `/support`, unknown/malformed paths and official assets. Check identity/security headers, destination retention, no redirect loops and no private-content fetch. Current hosted routing, all 14 public path responses and the exact hosted canonical policy were verified. Apple’s public association CDN also returned the same current JSON; this is not a claim of physical iOS acceptance.
