# Website preflight and Claude handoff

November 22, 2026 · **Historical pre-implementation audit.** The redesign was implemented afterwards; current behavior is in [README — Website V2](README.md#website-v2-single-page-homepage). Claude owns visuals/frontend after Build 7. Codex owns infrastructure/routing/security support. No iOS or production changes.

## Approved single-page direction

**Hero → How It Works (Cook / Rank / Remember / Share) → Feature Showcase (Grub Rank; My Kitchen / Food Bible; The Pass / Sous Chefs) → Download CTA → minimal Privacy / Terms / Support footer.**

Mobile-first, white/red, premium/playful, minimal copy, real app screenshots and approved food photography, lightweight transitions, Reduce Motion and accessible keyboard/touch use. No CMS, signup/email collection, accounts, dashboards, additional marketing pages, invented screenshots/testimonials/download counts. Legal/support and existing app-link utilities remain separate.

## Existing architecture / reuse

| Source | Responsibility |
| --- | --- |
| `build.py` | `page()` shared semantic shell; `policy_html()` renders complete canonical Privacy; `build()` generates public HTML/assets through an exact allowlist |
| `site.css` | Responsive layout, system fonts, buttons, focus-visible/skip-link styles, image dimensions, reduced-motion hook |
| `link-worker.mjs` | Stateless GET/HEAD router, `destination()` / `referral()` validation, `fallback()` acquisition/native-open HTML; no Supabase reads, cookies or private content |
| `distribution.json` / `association.json` | Approved Apple destination / shared AASA identity and paths |
| `headers.txt` / `wrangler.jsonc` | CSP/security headers, ASSETS binding, Worker-first routes, disabled HTML canonicalization |
| `deploy-production.sh`, `test_site.py`, `test_links.mjs`, `verify_live_links.py` | Full Worker/assets deploy and local/live regression gates |

`Website/public/` is ignored build output. Edit sources, not generated HTML. Keep vanilla static HTML/CSS: five small section functions or one clear homepage template, shared shell/download markup, optional tiny self-hosted JS. No framework migration needed.

**Protected URLs:** `/privacy`, `/support`, `/beta`, legacy `/kitchen`, `/@username` (including escaped `%40`), `/p/<UUID>`, `/r/<UUID>`, `/p/<UUID>/recipe`, both AASA endpoints and branded 404s. Preserve generic noindex/no-store/no-transform app-link fallbacks, explicit native Open action, privacy checks and AASA identity. Never replace these with a homepage catch-all. They are utilities, not new marketing sections.

## Download behavior

Single source: `distribution.json` → **https://testflight.apple.com/join/JWckxC4r**. Its public page returns 200 without a full/closed-beta marker; installation eligibility remains Apple's responsibility.

Home currently links to `/beta`; the Worker reads the JSON, but the static Home builder does not yet consume it. For the redesign, render both homepage CTAs from this same validated config. Clearly label beta/TestFlight availability; use the actual App Store listing/badge only when released. Retain `/beta` for existing links. Test both modes and strict Apple-host/path rejection; never accept a visitor-supplied redirect target.

Existing bounded `ref` metadata travels only to the native Open link, not TestFlight. No referral counting, signup attribution or deferred-install attribution exists or is needed.

## Verified audit / remaining work

| Area | Current evidence and action |
| --- | --- |
| HTTPS / routing | Active apex Worker/custom domain, ASSETS present, valid TLS. HTTP → HTTPS and www → apex redirects work. No DNS or hosting migration needed. |
| Legal / contact | Privacy and Support are HTML 200; Privacy exactly matches the canonical app document, effective Nov 11. **`/terms` is 404; no canonical Terms supplied.** Obtain owner-approved Terms/safety/community coverage; do not invent copy or use Privacy for non-privacy disclaimers. Email Routing is ready, with enabled support@, privacy@ and feedback@ forwarding; private destinations were not exposed. Owner should verify receipt/reply once; no test email was sent. |
| Beta / links | **30 live GET/HEAD checks pass:** correct HTML/content type, no download disposition, redirects or private-content exposure; correct Apple CTA, malformed-link/404 behavior and both AASA files. Browser Home → Beta works at narrow width; keyboard skip link works. |
| Performance | HTML/CSS sample transfers ~926/1,197 compressed bytes; **wordmark is 537,040 bytes** for a 112–136 CSS-pixel display. Generate sized derivatives from official artwork, responsive media, lazy below-fold images and explicit dimensions. Aim for ≤1 MB initial mobile transfer, then measure. Cached HTML/CSS TTFB ~52–90 ms from this Mac is not mobile Core Web Vitals. No Lighthouse/field LCP/INP/CLS score is claimed. |
| SEO / branding | Canonical/title/description/viewport exist; Home copy describes the older private-journal/image-sharing product. No supplied marketing OG/Twitter image or sitemap (`/sitemap.xml` 404). Live robots is Cloudflare-managed content signals, not a repo file; preserve that policy deliberately. Sitemap only public marketing/legal URLs. Use official **#F10607**; current CSS still uses conceptual #FF2D1F. |
| JS / analytics | CSP currently blocks scripts, so scroll enhancements need narrowly scoped `script-src 'self'` for marketing pages. Keep content/CTAs usable without JS and retain strict script-free app-link fallbacks. Cloudflare Web Analytics auto-install is enabled, but the browser observed its injected script **blocked by CSP**. Do not claim conversion analytics works. Resolve injection/CSP deliberately; never disable CSP. |
| Operations | No explicit Logs/Traces config is supplied; Logpush false. Consider sampled/redacted status/error diagnostics within existing free quotas, not a tracking database or full tracing project. Avoid raw private-pointer/referral URLs in logs. |

For animations, default content stays visible; optional IntersectionObserver enhancement respects Reduce Motion. Do not add unsafe-inline/eval or wildcard CSP sources. Add only reviewed public files to the builder allowlist: new screenshot variants, Terms, social artwork and JS are currently rejected. Update tests precisely; marketing JS must not weaken private-fallback no-script/no-content assertions.

**Analytics recommendation:** existing aggregate edge traffic is sufficient initially (bots included). Optional [free Cloudflare Web Analytics](https://developers.cloudflare.com/web-analytics/about/) requires its [documented CSP allowances](https://developers.cloudflare.com/web-analytics/faq/) and accurate disclosures. Pageviews do not prove CTA clicks, installs or signup attribution. Use Apple acquisition reports when available; defer custom conversion events and all email capture.

## Cloudflare and deployment handoff

- Existing account `a53a5efe17232f5b9d3e5cd62cceba15`, Worker `staygrubby`; compatibility date `2026-10-19`. Latest observed production version `e14694db-c226-4f03-b634-317415fa7635` at 100%, Nov 21. workers.dev/version-preview access disabled; an isolated accessible preview was not verified. Use local output/tests for design work.
- **Only production path:** `sh Website/deploy-production.sh` — build → tests → Wrangler dry run → full Worker + assets → live gate. Never run it as a local-preview command. Assets-only deployment has repeatedly broken beta/sharing and is forbidden.
- **Every main push currently deploys:** verified Workers Builds watches `main`, all paths, auto-build enabled. Build: `python3 Website/build.py`; deploy: `npx --yes --package wrangler@4.154.0 -c 'sh Website/deploy-production.sh'`. Even docs can redeploy. No push/merge/deployment is authorized here; get approval or separately control the trigger first.
- No database/email/provider additions needed. Zone is Free Website; this does not establish Workers account billing tier. [Static assets are free/unlimited; Worker-first routes consume allowance](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/). [Free Workers currently allow 100,000 requests/day](https://developers.cloudflare.com/workers/platform/limits/); do not call this Worker-first homepage unlimited. No upgrade proposed.

## Missing assets and shortest launch path

Reuse `StayGrubby/Assets.xcassets/StayGrubbyWordmark.imageset/StayGrubbyWordmark.png` and official light/dark/tinted AppIcon assets. No approved app screenshot/food-photo marketing pack is checked into Website. Owner supplies current safe screenshots for the three showcase areas, a real hero screen, owned/licensed food photos, short approved copy and Terms. Do not use private libraries/debug fixtures or unrelated rendered documents.

1. Claude builds the five-section page after Build 7; config-driven CTAs, optimized approved media, public metadata and approved legal links.
2. Focused acceptance: local build/tests, mobile/desktop/keyboard/Reduce Motion, media weight, no-JS CTAs, both acquisition modes, allowlist/security and protected routes. Marketing wording tests may change; HTML/no-download/privacy guarantees remain.
3. After owner approval, capture the current full deployment for recovery; publish through the canonical script, run live checks and one real iPhone Safari/TestFlight check. Recover only with a known full Worker/assets version, never assets alone.

**Rough remaining effort once media/legal are ready:** one frontend checkpoint + one technical acceptance pass, about **1–2 developer days**, excluding owner asset/legal turnaround. No infrastructure migration or signup system on the critical path.

## Evidence and integration state

Audited accepted main/origin `ec20d8c`; Website bytes equal clean Codex baseline `2be24aa`. Explicit no-merge scope overrides routine fast-forward for this audit: inspected latest accepted files read-only, tested a temporary main archive. Claude's active Swift/canonical-document edits are untouched; root roadmap statuses remain unchanged by this planning-only task. Reconcile the handoff reference during authorized integration.

**8 Python + 20 Node tests passed**, zero failures/skips; **30 live GET/HEAD checks passed**, plus read-only redirect/legal/asset/Apple probes. Browser verified Home/Beta, narrow reflow and CSP failure; temporary viewport cleared. No iOS tests, email submissions, paid services, production mutations, deployment, merge or push.
