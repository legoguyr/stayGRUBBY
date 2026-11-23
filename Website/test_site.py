"""Public-output and canonical-policy regression checks; no live services."""
from html.parser import HTMLParser
from pathlib import Path
import tempfile
import unittest
from urllib.parse import urlparse

from build import build, POLICY, LOGO, BRAND_FILES, distribution_url
import home

DISTRIBUTION = __import__("json").loads((Path(__file__).parent / "distribution.json").read_text())["url"]


def png_size(path):
    data = Path(path).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")


class Document(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.tags = []
        self.article_text = []
        self.in_policy = False
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.tags.append((tag, attrs))
        if tag == "article" and attrs.get("class") == "policy":
            self.in_policy = True

    def handle_endtag(self, tag):
        if tag == "article":
            self.in_policy = False

    def handle_data(self, data):
        if self.in_policy:
            self.article_text.append(data)


class SiteTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.output = Path(self.temp.name)
        build(self.output)

    def test_worker_deployment_remains_static_without_backend_or_dns_bindings(self):
        import json
        config = json.loads((Path(__file__).parent / 'wrangler.jsonc').read_text())
        self.assertEqual(config['name'], 'staygrubby')
        self.assertEqual(config['assets']['directory'], './public')
        self.assertEqual(config['assets']['run_worker_first'], ['/', '/@*', '/%40*', '/p/*', '/r/*', '/kitchen', '/beta', '/privacy', '/support', '/.well-known/apple-app-site-association', '/apple-app-site-association'])
        self.assertEqual(config['main'],'link-worker.mjs')
        self.assertEqual(config['assets']['binding'],'ASSETS')
        self.assertEqual(config['assets']['html_handling'], 'none')
        self.assertFalse(config['workers_dev'])
        self.assertFalse(config['preview_urls'])
        self.assertTrue(set(config).isdisjoint({'routes', 'route', 'vars', 'kv_namespaces', 'r2_buckets', 'd1_databases', 'services', 'analytics_engine_datasets'}))

    def test_publish_directory_is_an_exact_public_allowlist(self):
        present = {"assets/media/" + s["file"] for s in home.slots().values() if s["present"]}
        self.assertEqual({str(p.relative_to(self.output)) for p in self.output.rglob("*") if p.is_file()},
            {"index.html", "privacy.html", "support.html", "404.html", "assets/site.css", "assets/wordmark.png", "_headers", "kitchen.html", "_redirects", ".well-known/apple-app-site-association"}
            | {"assets/brand/" + name for name in BRAND_FILES} | present)
        # The Worker fallbacks keep /assets/wordmark.png: the official artwork's optimized derivative on the same canvas.
        self.assertEqual(png_size(self.output / "assets/wordmark.png"), png_size(LOGO))
        self.assertLess((self.output / "assets/wordmark.png").stat().st_size, 80_000)
        total = sum(p.stat().st_size for p in self.output.rglob("*") if p.is_file() and p.name != "privacy.html")
        self.assertLess(total, 1_000_000)

    def test_policy_is_rendered_from_the_complete_canonical_document(self):
        doc = Document((self.output / "privacy.html").read_text())
        canonical = POLICY.read_text()
        import re
        expected = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", canonical)
        expected = expected.replace("**", "").replace("#", "")
        self.assertEqual(" ".join("".join(doc.article_text).split()), " ".join(expected.split()))
        self.assertIn("November 11, 2026", " ".join(doc.article_text))

    def test_build_refuses_unexpected_files_in_publish_directory(self):
        (self.output / "internal-notes.md").write_text("Synthetic internal fixture")
        with self.assertRaises(ValueError):
            build(self.output)

    def test_links_assets_and_semantic_accessibility(self):
        for name in ["index.html", "privacy.html", "support.html", "404.html"]:
            doc = Document((self.output / name).read_text())
            self.assertEqual(sum(tag == "h1" for tag, _ in doc.tags), 1)
            self.assertIn(("html", {"lang": "en"}), doc.tags)
            self.assertTrue(any(tag == "main" and attrs.get("id") == "main" for tag, attrs in doc.tags))
            self.assertFalse(any(tag in {"script", "iframe", "form"} for tag, _ in doc.tags))
            for tag, attrs in doc.tags:
                if tag == "img":
                    self.assertTrue(attrs.get("alt"))
                for key in ["href", "src"]:
                    value = attrs.get(key, "")
                    if not value or value.startswith("#"):
                        continue
                    url = urlparse(value)
                    if url.scheme == "mailto":
                        self.assertIn(url.path, ["privacy@staygrubby.com", "support@staygrubby.com"])
                    elif url.scheme:
                        self.assertEqual(url.scheme, "https")
                        if name == "index.html" and value == DISTRIBUTION:
                            continue
                        if url.netloc != "staygrubby.com":
                            self.assertEqual(name, "privacy.html")
                            self.assertEqual(key, "href")
                            self.assertIn(value, ["https://ai.google.dev/gemini-api/terms", "https://policies.google.com/privacy"])
                        else:
                            self.assertEqual(url.netloc, "staygrubby.com")
                    elif value == "/beta":
                        self.assertEqual(name, "index.html")
                    else:
                        path = "index.html" if value == "/" else value.lstrip("/")
                        if "." not in Path(path).name:
                            path += ".html"
                        self.assertTrue((self.output / path).is_file(), value)

    def test_homepage_download_ctas_come_from_distribution_config(self):
        html = (self.output / "index.html").read_text()
        self.assertTrue(DISTRIBUTION.startswith("https://testflight.apple.com/join/"))
        self.assertEqual(html.count(f'<a class="button" href="{DISTRIBUTION}">Join the Beta</a>'), 2)
        self.assertIn(f'<a class="pill-button" href="{DISTRIBUTION}">Join the Beta</a>', html)
        self.assertIn("iPhone beta · via Apple TestFlight", html)
        store = "https://apps.apple.com/us/app/staygrubby/id1234567890"
        self.assertEqual(home.cta(distribution_url(store)), (store, "Download on the App Store", "Free for iPhone"))
        self.assertEqual(home.cta(None), ("/beta", "Join the Beta", "iPhone beta"))

    def test_homepage_sections_and_honest_media_fallbacks(self):
        html = (self.output / "index.html").read_text()
        for section in ['id="hero-title"', 'id="how-title"', 'id="features-title"', 'id="download-title"']:
            self.assertIn(section, html)
        for verb in ["Cook", "Rank", "Remember", "Share", "Grub Rank", "My Kitchen · Food Bible", "The Pass"]:
            self.assertIn(verb, html)
        for spec in home.slots().values():
            self.assertEqual(spec["present"], f'/assets/media/{spec["file"]}' in html, spec["name"])
        # Missing screenshots fall back to labelled tutorial example cards, never an invented screen.
        examples = html.count('class="card example')
        self.assertEqual(examples, sum(not home.slots()[s]["present"] for s in ["hero-screen", "rank-screen", "kitchen-screen", "pass-screen"]))
        self.assertEqual(html.count('aria-label="Illustrative example'), examples)
        self.assertEqual(html.count('<figcaption>Illustrative preview</figcaption>'), examples)

    def test_supplied_media_slot_is_published_and_allowlisted(self):
        import json, shutil
        with tempfile.TemporaryDirectory() as media_dir, tempfile.TemporaryDirectory() as out:
            media = Path(media_dir)
            manifest = json.loads((home.MEDIA / "media.json").read_text())
            (media / "media.json").write_text(json.dumps(manifest))
            (media / "rank-screen.jpg").write_bytes(b"synthetic fixture")
            original, home.MEDIA = home.MEDIA, media
            try:
                build(Path(out))
            finally:
                home.MEDIA = original
            page_html = (Path(out) / "index.html").read_text()
            self.assertTrue((Path(out) / "assets/media/rank-screen.jpg").is_file())
            self.assertIn('<img src="/assets/media/rank-screen.jpg" width="590" height="1279" alt="Grub Rank on iPhone" loading="lazy"', page_html)
            for spec in manifest["slots"]:
                if spec["kind"] == "photo":
                    (media / spec["file"]).write_bytes(b"fixture without alt text")
                    with self.assertRaises(ValueError):
                        home.MEDIA = media
                        try:
                            home.slots()
                        finally:
                            home.MEDIA = original
                    break

    def test_profile_landing_and_association_are_static_and_private(self):
        import json
        association = json.loads((self.output / '.well-known/apple-app-site-association').read_text())
        self.assertEqual(association['applinks']['details'][0]['appIDs'], ['5DSB36G7LZ.com.guyrettig.StayGrubby'])
        self.assertEqual((self.output / '_redirects').read_text(), '')
        landing = (self.output / 'kitchen.html').read_text()
        for forbidden in ['supabase', '<script', '<form', 'testflight.apple.com/join/', 'apps.apple.com']:
            self.assertNotIn(forbidden, landing)
        self.assertIn('after sign-in and privacy checks', landing)
        self.assertIn('not open yet', landing)
        self.assertIn('name="robots" content="noindex,nofollow"', landing)
        self.assertEqual(distribution_url('https://testflight.apple.com/join/EXAMPLE1'), 'https://testflight.apple.com/join/EXAMPLE1')
        for bad in ['http://testflight.apple.com/join/A', 'https://testflight.apple.com.evil/join/A', 'https://user@testflight.apple.com/join/A', 'javascript:bad', 'https://example.com']:
            with self.assertRaises(ValueError): distribution_url(bad)

    def test_security_headers_and_no_remote_dependencies(self):
        headers = (self.output / "_headers").read_text()
        for directive in ["default-src 'none'", "style-src 'self'", "img-src 'self'",
                          "frame-ancestors 'none'", "form-action 'none'", "base-uri 'none'",
                          "X-Content-Type-Options: nosniff", "Referrer-Policy: no-referrer"]:
            self.assertIn(directive, headers)
        css = (self.output / "assets/site.css").read_text()
        for prohibited in ["@import", "url(", "@font-face"]:
            self.assertNotIn(prohibited, css)
        self.assertIn(":focus-visible", css)
        self.assertIn("min-width: 641px", css)
        self.assertIn("#f10607", css)
        self.assertNotIn("#ff2d1f", css)
        # Scroll motion is CSS-only, opt-in and disabled under Reduce Motion; no script-src is needed.
        self.assertIn("@media (prefers-reduced-motion: no-preference)", css)
        self.assertIn("@media (prefers-reduced-motion: reduce)", css)
        self.assertNotIn("script-src", headers)


if __name__ == "__main__":
    unittest.main()
