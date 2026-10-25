# StayGrubby public website

The production site is the existing **assets-only Cloudflare Worker `staygrubby`**, attached to `staygrubby.com` in account `a53a5efe17232f5b9d3e5cd62cceba15`. It is not a Pages project. Do not create a second site or replace its custom domain/DNS setup. The release-readiness review records deployment IDs and live verification.

The website is a minimal app-first landing, privacy/support pages, generic profile fallback and AASA. No web accounts, public recipe/feed/catalog, Supabase requests, JavaScript, analytics or cookies. Preserve all email MX/TXT records; deployment must not change DNS.

## Source and local verification

`StayGrubby/Legal/PrivacyPolicy.md` is the canonical policy, bundled offline in the app and rendered completely for the public site. The current clarification is effective October 22, 2026 and describes Dish-linked Food Bible, Recipe components/tips/revisions and the current account-deletion navigation. Official artwork comes from the existing asset catalog. Never reconstruct the wordmark.

From the repository root:

```sh
python3 Website/build.py
python3 -m unittest discover -s Website -p 'test_*.py'
```

Publish **only `Website/public`**, an exact tested allowlist of HTML, CSS, the official logo, headers/redirects and extensionless AASA. Output, Python cache and CLI state are local artifacts and must not be committed. The builder refuses extra files in that directory. No credentials, app data or internal Markdown belongs in it.

## Deployment with the owner's existing authorization

`Website/wrangler.jsonc` targets the existing assets-only Worker and account, retains compatibility date `2026-10-19`, disables workers.dev/preview URLs, serves an intentional 404 and contains no routes/DNS/backend bindings. No paid features or new project are required.

After the owner has their normal Cloudflare CLI session available, from the repository root:

```sh
wrangler deploy --config Website/wrangler.jsonc --dry-run
wrangler deploy --config Website/wrangler.jsonc
```

Do not paste tokens into Codex or place credentials in configuration. If the existing authenticated connector supports the documented direct static-assets API, it can publish the same tested allowlist without changing credentials. The release review records whether publication actually succeeded; local output and dry run alone are not deployment evidence.

Verify `/`, `/privacy`, `/support`, an unknown path returning 404, and a sample `/@username` reaching the generic `/kitchen` fallback. Profile URLs must retain the original `/@username` path with a direct 200 internal rewrite; HTML canonicalization is deliberately disabled so it cannot redirect away the destination. Explicit extensionless privacy/support/kitchen rewrites remain; **AASA must return 200 JSON directly without redirect/authentication** at `/.well-known/apple-app-site-association`. Check CSP, nosniff, referrer/permissions headers, no cookies/scripts and the complete current policy. Keep the existing custom domain and email records unchanged.

## Universal Links and distribution

Only `https://staygrubby.com/@username` is enabled. AASA names `5DSB36G7LZ.com.guyrettig.StayGrubby` and `/@*`; native parsing is stricter, requires authentication/account readiness, and the server rechecks discovery, friendship/block/account state. The public fallback never interpolates/fetches personal content. No public Recipe/post route is added.

`Website/distribution.json` remains explicitly `{"url": null}`. The page honestly explains that external beta access is not open. Once the owner supplies the actual approved External TestFlight public URL, configure it, rebuild/test and publish. The builder only accepts genuine-format Apple HTTPS join/product URLs, rejects arbitrary hosts/credentials/query/fragment injection, and does not invent a destination. No public link, archive, upload or App Store Connect change is created by this workflow.

Physical association testing remains necessary: confirm Associated Domains capability/provisioning for the existing Team/bundle; install a newly signed build and open shared links from Messages/Mail with cold/warm and signed-in/signed-out states. Same-domain Safari navigation and HTTP/AASA checks alone do not prove iPhone routing. Existing Apple association caches may delay updates.
