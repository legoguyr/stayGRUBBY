# StayGrubby public website and sharing links

**Current website/Cloudflare specification — reconciled November 7, 2026.** System context: [architecture — sharing, links and the website](../STAYGRUBBY_ARCHITECTURE.md#sharing-links-and-the-website).

> **Rule: assets-only publishing is NOT a valid StayGrubby production deployment.** Every production publish must ship the link Worker together with the assets and pass the live link gate. An assets-only publish keeps Home, Privacy and the static AASA file working while `/beta` and every post, Recipe and profile fallback return empty 404s — it has happened three times (November 4, November 5, November 7).

The existing Cloudflare Worker `staygrubby` serves `staygrubby.com` in account `a53a5efe17232f5b9d3e5cd62cceba15`. Do not create another website, change DNS/email, or add a public Recipe/feed browser. The November 2 Next-Version cycle explicitly reopened the contained app-link dependency; the historical assets-only/profile-only restriction is superseded for this router.

## Single-page redesign direction

Owner direction, November 22, 2026: one visual, mobile-first landing page — Hero, Cook/Rank/Remember/Share, a short feature showcase, Download CTA and minimal Privacy/Terms/Support footer. Claude owns the frontend after Build 7. Preserve the existing beta and private app-link utilities; no CMS, email signup or extra marketing pages. Use real approved screenshots/photography and the official wordmark. Codex's [technical preflight and handoff](REDESIGN_HANDOFF.md) records the infrastructure audit, download configuration and launch gaps it found before implementation. The implemented page is described in [Website V2](#website-v2-single-page-homepage).

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

## Website V2 single-page homepage

**Deployed November 22, 2026** (owner-approved, with illustrative feature previews): commit `5395686` via the Workers Builds trigger running `deploy-production.sh` (build `61b8b067`), Worker version `e60de22b-da8d-4909-b4cd-dc45d2569ab2` at 100% with the ASSETS binding; workers.dev and previews stay disabled. The live gate passed (30 GET/HEAD checks), and desktop and 375 px mobile were verified in a browser. The previous full version, `410e31bd-c112-4b62-8d5b-cb92fa19fd28`, is the recovery target; never recover with an assets-only deploy. Known: Cloudflare Web Analytics still injects its beacon on the homepage and the CSP blocks it (no analytics data, no functional impact). `home.py` renders one page: Hero ("Your food, ranked.") → How It Works (Cook / Rank / Remember / Share) → Grub Rank, My Kitchen · Food Bible and The Pass → Download → a minimal footer. The copy and examples come from the owner-approved first-run tutorial (`StayGrubby/Tutorial/`). The shared shell in `build.py` keeps Privacy, Support, `/kitchen` and the Worker fallbacks on the same stylesheet.

- **Brand and design.** The page uses logo red `#F10607` for identity blocks, the app's accessible accent `#CB1015` for text and buttons, and cream `#FAF3EC` and charcoal `#1F1F1F`. Fonts are system fonts only. The official tab glyphs are inlined from the asset catalog. The wordmark is always the official artwork: `prepare_media.py brand` (Pillow, run offline) writes palette-optimized derivatives into `media/brand/`, and `build.py` stays standard-library only. `/assets/wordmark.png` keeps its 1,254 px canvas for the Worker fallbacks but shrinks from 537 KB to about 30 KB.
- **Media slots.** Screenshots, food photos and the link-preview image are listed in `media/media.json`. `python3 Website/prepare_media.py slot <name> <file>` resizes an owner-supplied image into its slot, and the build publishes only slots whose file exists (the allowlist is extended exactly). A missing screenshot falls back to a tutorial example card captioned "Illustrative preview" (never a real user's ranking). A missing photo leaves a text-only step. Nothing on the page is an invented screenshot or a stock image. `python3 Website/build.py` lists the missing slots.
- **Motion and security.** Scroll reveals use CSS scroll-driven animations (`animation-timeline: view()`), only under `prefers-reduced-motion: no-preference` and where the browser supports them. Without support, everything is simply visible. The headline and CTAs never wait on an animation. The page ships no JavaScript, so the CSP and every no-script guarantee are unchanged.
- **Download.** Both homepage CTAs and the header pill render from `distribution.json`: a TestFlight URL gives "Join the Beta" (iPhone beta · via Apple TestFlight), an App Store URL gives "Download on the App Store", and no URL falls back to `/beta`. The live gate checks the homepage CTA against the same configured destination.
- **Local preview.** Run `python3 Website/build.py && node Website/preview.mjs`, then open `http://127.0.0.1:8788/`. The preview runs the real Worker over `public/` with the production `/*` headers. It is never a deployment path.
- **Open before launch.** The owner needs to supply current iPhone screenshots (hero, Grub Rank, My Kitchen/Food Bible, The Pass) from a safe demo account, four owned or licensed 4:5 food photos, a 1200×630 link-preview image and approved Terms of Use. The footer has no Terms link until a canonical Terms document exists; no Terms text was written. Also open: a sitemap and a deliberate decision on Cloudflare Web Analytics and the CSP (see the [handoff](REDESIGN_HANDOFF.md)).

## Beta acquisition and referral metadata

The homepage's Join the Beta buttons link directly to the Apple destination in `distribution.json` (Website V2). The Worker still serves the branded beta page and uses the same acquisition action on generic profile, post and Recipe fallbacks. `distribution.json` controls the Apple destination. At App Store release, switch the destination to the verified listing; the homepage changes its wording to Download on the App Store automatically. AASA and canonical paths stay unchanged. No public content is fetched.

The optional `?ref=<opaque token>` is 16–64 ASCII letters, digits, underscores or hyphens. A single valid value travels in the explicit Open StayGrubby URL; invalid or duplicate values are ignored. TestFlight receives the verified invitation URL alone. After installation, reopen the original shared link to recover the intended destination and any referral metadata. Attribution at signup requires future work.

Worker version `f5164ec8-90ca-44b9-b567-697963dc1f09` shipped beta acquisition with the ASSETS binding and the existing static bytes, including the current Privacy page.

## Source, verification and deployment

**Terms of Use and Community Guidelines (November 23, drafts, unpublished).** Source text lives in `Legal/` (outside the app bundle and outside the build allowlist). Preview locally with `python3 Website/preview_legal.py <folder outside Website/public>`. Publishing is the separate branch `claude/legal-pages-activation`: it adds `/terms` and `/community-guidelines` to the Worker routes, `run_worker_first`, the allowlist, the footer and the live-link gate, and its build refuses any Legal text still marked DRAFT or containing `[placeholders]`. Merge only after owner approval of the final text; the merge push deploys.

The canonical policy is `StayGrubby/Legal/PrivacyPolicy.md`, effective November 11, 2026 (Recipes never post to The Pass). The hosted HTML matched a fresh canonical build byte-for-byte on November 12. The policy is bundled offline and rendered completely by `build.py`. Official artwork comes from the app asset catalog.

Run the production entry point from the repository root with an authenticated Wrangler:

```sh
sh Website/deploy-production.sh
```

The script builds the public asset allowlist, runs the local tests and Wrangler dry run, deploys the Worker and assets using `Website/wrangler.jsonc`, then runs `python3 Website/verify_live_links.py`. A production publish is incomplete until the live gate passes. The Cloudflare Git build trigger for `main` must call this same script. An assets-only deploy (including `wrangler deploy --assets` or an assets-only dashboard upload) is invalid even if Home, Privacy and the static AASA file respond. The Worker owns `/beta`, profile, post and Recipe browser fallbacks.

**Git publishes can deploy production.** As verified November 12, Cloudflare Workers Builds watches every path on `main` and successfully ran the canonical full deploy for `61d92ab`. If the current task does not authorize a website publish, hold the push until the owner has paused the trigger or narrowed and verified its watch paths. A narrowed trigger must cover the Worker and build scripts, static website sources, the canonical Privacy Policy and the official artwork used by `build.py`. Absence of a GitHub Actions workflow does not prove there is no deploy trigger.

Use existing authentication. If Wrangler is unavailable during an incident, the authenticated Cloudflare connector can restore a previously verified full version after confirming the active deployment and the target's `fetch` handler and `ASSETS` binding. Run the same live gate immediately and verify the active version afterward. Keep the existing domain, disabled workers.dev/previews and public asset allowlist.

The live gate requires direct, browser-renderable HTML for the beta and shared-link fallbacks, with one `text/html; charset=utf-8` type, `no-store, no-transform`, and no `Content-Disposition` header. It verifies the beta heading, the actual TestFlight anchor and the homepage CTA to that same Apple destination, along with Privacy, Support, branded 404s and both AASA endpoints. Its 30 GET/HEAD checks validate a deployed version at a point in time. Physical iPhone Safari remains a separate check.

## Deployment incident history

Dated evidence; the rule and procedure above are current.

### November 2 connector deployment

The authenticated connector deployed tested bundle version **e392a755-ffe1-4261-b0f3-f4f39d2bbba4** during this cycle. A first `keep_assets` deployment retained old routing configuration; verification caught it. The routing correction reattached the byte-identical existing asset manifest using a short-lived completion capability internally, and applied the tested routing settings. No capability was printed, persisted or added to the repository; no static asset bytes changed. Source AASA is served by the handler ahead of the retained older asset copy. A normal future Wrangler deployment rebuilds/replaces that asset too. Final configuration verification also caught default workers.dev/preview exposure from the API upload and restored both to false, confirmed by read-back.

### November 4 Stage 3 hosted regression closeout

An assets-only publish displaced the router in hosted version `26be2b2b-ae30-4503-a2d3-a5f117adcbb5`; valid Recipe/post/profile requests returned empty untyped 404s. Repository route tests alone could not detect the missing deployed handler. Stage 3 restored the tested Worker plus the byte-identical existing asset manifest, with ASSETS binding and exact `run_worker_first` settings. Active version is `1de0d408-5934-4614-8acc-71a37b62ba37`; workers.dev and preview URLs remain disabled. Link HTML explicitly uses `Content-Disposition: inline`; malformed app paths get branded HTML 404.

Always deploy with `--config Website/wrangler.jsonc`. Never publish this site as assets-only or substitute `wrangler deploy --assets`: the native URL fallback depends on the Worker. After a deployment run `python3 Website/verify_live_links.py` (22 read-only real GET/HEAD checks) and read back the active router/ASSETS configuration. If normal CLI authentication is unavailable, use only the existing authorized connector; do not change credentials. This guard checks actual hosted HTML/MIME/disposition/no redirects and exact AASA; physical association/Messages/Safari still require owner acceptance. [Stage 3 evidence](../NEXT_RELEASE_STAGE_3_REVIEW.md).

### November 5 Stage 5 hosted regression closeout

The whole-app audit found active assets-only version `a53e89dd-e0fc-4f7c-a8eb-3961e287886d` had again displaced the accepted handler/binding/Worker-first configuration, yielding empty 404s for valid shared pointers. Restored the unchanged router and byte-identical eight-file asset manifest as **`19b93d04-f64d-4aa1-988c-2877aa5d2ac9`**; no static asset bytes, private data, DNS or credentials changed. All 22 actual public GET/HEAD checks pass, with exact AASA, direct inline fallback HTML, Privacy/Support and disabled workers.dev/previews confirmed. Every future website publish must retain the router and pass the live guard; an assets-only publish is not a valid StayGrubby deployment. [Stage 5 evidence](../NEXT_RELEASE_STAGE_5_REVIEW.md).

### November 7 Build 4 production recovery

The active Wrangler deployment `b490cd5c-3d16-4ab8-9843-0d58e542ee53` contained neither a fetch handler nor an asset binding. Home, Privacy and static AASA still responded, while beta and valid shared pointers returned empty 404s. The canonical Wrangler dry run packaged the handler and binding, but the local CLI had no authenticated session. The authenticated Cloudflare connector redeployed the previously verified full version `f5164ec8-90ca-44b9-b567-697963dc1f09` to 100% in deployment `01aaf7a1-7034-4ee0-a64e-4399543644c8`. The Worker's `workers.dev` and preview access were returned to their canonical disabled settings.

All 27 local website tests and 30 hosted GET/HEAD checks passed. Verified direct browser fallbacks and the configured Apple beta invitation, malformed and unknown 404s, headers, both origin AASA endpoints and Apple's association CDN. Home, Privacy, Support, CSS and wordmark matched the canonical build before and after recovery. The production script now requires the live check and rejects deployment overrides.

### November 7 Safari beta follow-up

The Git build trigger subsequently published assets alone using `wrangler deploy --assets`. The active version had no fetch handler or ASSETS binding. Safari-style requests to `/beta` and representative shared links received an empty 404 without a media type or redirect. The earlier checks had passed against the full version before it was replaced. The original iPhone popup itself was not reproduced. The Git trigger now invokes the canonical script and its live gate, and Worker pages omit the optional disposition header.

Wrangler's local session could package the canonical build but could not publish. The authenticated Cloudflare connection deployed that full Worker and its assets as version `92c0dc95-b5dc-4347-a976-350cd920abbe`. The live gate caught a Cloudflare-injected analytics script on the first browser response. `no-transform` prevented injection on the Worker fallbacks without changing zone-wide analytics settings. All 28 local tests and 30 hosted checks passed, including the homepage CTA and the existing Apple invitation. Apple’s association CDN also matched the source.
