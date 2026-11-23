"""Build only public static assets, using the app's canonical policy and wordmark."""
import argparse
import json
from urllib.parse import urlparse
import hashlib
import html
from pathlib import Path
import re
import shutil

import home

ROOT = Path(__file__).resolve().parent.parent
POLICY = ROOT / "StayGrubby/Legal/PrivacyPolicy.md"
LOGO = ROOT / "StayGrubby/Assets.xcassets/StayGrubbyWordmark.imageset/StayGrubbyWordmark.png"


def inline(text):
    text = html.escape(text)
    text = re.sub(r"\[([^\]]+)\]\((https://[^\s)]+|mailto:[^\s)]+)\)",
                  r'<a href="\2">\1</a>', text)
    return re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)


def policy_html(text):
    blocks = []
    for block in text.strip().split("\n\n"):
        if block.startswith("# "):
            blocks.append(f"<h1>{inline(block[2:])}</h1>")
        elif block.startswith("## "):
            blocks.append(f"<h2>{inline(block[3:])}</h2>")
        else:
            blocks.append(f"<p>{inline(block)}</p>")
    return "\n".join(blocks)


DESCRIPTION = "Rank everything you cook, keep the Recipes worth making again and share your best cooks with friends. StayGrubby for iPhone."
BRAND = ROOT / "Website/media/brand"
BRAND_FILES = ["wordmark-240.png", "wordmark-480.png", "apple-touch-icon.png", "favicon-64.png"]


def page(title, route, content, extra_class="", action=None, social=None):
    """Shared semantic shell. `action` adds the homepage download pill; `social` adds a supplied link-preview image."""
    header_end = (f'<a class="pill-button" href="{action[0]}">{action[1]}</a>' if action else
                  '<nav aria-label="Main navigation"><a href="/privacy">Privacy</a><a href="/support">Support</a></nav>')
    og = (f'\n  <meta property="og:image" content="https://staygrubby.com/assets/media/{social["file"]}">'
          f'\n  <meta property="og:image:width" content="{social["width"]}"><meta property="og:image:height" content="{social["height"]}">'
          f'\n  <meta property="og:image:alt" content="{html.escape(social["alt"], quote=True)}">'
          '\n  <meta name="twitter:card" content="summary_large_image">') if social else ''
    return f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light">
  <meta name="theme-color" content="#ffffff">
  <meta name="description" content="{DESCRIPTION}">
  <title>{html.escape(title)}</title>
  <link rel="canonical" href="https://staygrubby.com{route}">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="StayGrubby">
  <meta property="og:title" content="{html.escape(title, quote=True)}">
  <meta property="og:description" content="{DESCRIPTION}">
  <meta property="og:url" content="https://staygrubby.com{route}">{og}
  <link rel="icon" type="image/png" sizes="64x64" href="/assets/brand/favicon-64.png">
  <link rel="apple-touch-icon" href="/assets/brand/apple-touch-icon.png">
  <link rel="stylesheet" href="/assets/site.css">
</head>
<body>
  <a class="skip" href="#main">Skip to content</a>
  <header class="site-header{' home-header' if action else ''}">
    <a class="brand" href="/" aria-label="StayGrubby home"><img src="/assets/brand/wordmark-480.png" srcset="/assets/brand/wordmark-240.png 240w, /assets/brand/wordmark-480.png 480w" sizes="(min-width: 641px) 168px, 128px" width="480" height="480" alt="#stayGRUBBY"></a>
    {header_end}
  </header>
  <main id="main" class="{extra_class}">{content}</main>
  <footer class="site-footer"><span>© 2026 StayGrubby</span><a href="/privacy">Privacy Policy</a><a href="/support">Support</a><a href="mailto:support@staygrubby.com">support@staygrubby.com</a></footer>
</body>
</html>
'''


def distribution_url(value):
    if not value:
        return None
    parsed = urlparse(value)
    if (parsed.scheme != 'https' or parsed.username or parsed.password or parsed.port or parsed.query or parsed.fragment
        or not ((parsed.netloc == 'testflight.apple.com' and re.fullmatch(r'/join/[A-Za-z0-9]+', parsed.path))
                or (parsed.netloc == 'apps.apple.com' and re.fullmatch(r'/[A-Za-z]{2}/app/[^/]+/id[0-9]+', parsed.path)))):
        raise ValueError('Use the actual Apple External TestFlight or App Store URL')
    return value


def build(output, distribution=None):
    output.mkdir(parents=True, exist_ok=True)
    media = home.slots()
    allowed = {"index.html", "privacy.html", "support.html", "404.html", "_headers",
               "assets/site.css", "assets/wordmark.png", "kitchen.html", "_redirects", ".well-known/apple-app-site-association"}
    allowed |= {"assets/brand/" + name for name in BRAND_FILES}
    allowed |= {"assets/media/" + spec["file"] for spec in media.values() if spec["present"]}
    unexpected = {str(p.relative_to(output)) for p in output.rglob("*") if p.is_file()} - allowed
    if unexpected:
        raise ValueError("Refusing to publish unexpected files: " + ", ".join(sorted(unexpected)))
    (output / "assets").mkdir(exist_ok=True)
    # The Worker owns acquisition configuration for canonical links and /beta.
    destination = distribution_url(distribution)
    cta = ('<a class="button" href="' + html.escape(destination, quote=True) + '">Get StayGrubby</a>') if destination else '<p>External beta access is not open yet. Ask the person who shared this link for access.</p>'
    kitchen = '<article class="policy"><p class="eyebrow">#stayGRUBBY</p><h1>A Kitchen is waiting in StayGrubby.</h1><p>Open this link on your iPhone with StayGrubby installed. Profiles are viewed only inside the app, after sign-in and privacy checks.</p>' + cta + '<p>If the app is already installed, open the original shared link from Messages or Mail. You can also press and hold it and choose Open in StayGrubby when iOS offers that action.</p></article>'
    (output / "kitchen.html").write_text(page("Open a Kitchen — StayGrubby", "/kitchen", kitchen, "reading").replace("<title>", '<meta name="robots" content="noindex,nofollow"><title>', 1), encoding="utf-8")
    (output / "_redirects").write_text('', encoding="utf-8")
    (output / ".well-known").mkdir(exist_ok=True)
    association = json.loads((ROOT / 'Website/association.json').read_text())
    (output / ".well-known/apple-app-site-association").write_text(json.dumps(association, separators=(',', ':')), encoding="utf-8")
    text = POLICY.read_text(encoding="utf-8")
    assert "Effective date: November 11, 2026" in text
    # Website V2 homepage: CTAs come from the same validated Apple destination the Worker uses for /beta.
    home_destination = distribution_url(json.loads((ROOT / "Website/distribution.json").read_text()).get("url"))
    action = home.cta(home_destination)
    social = media["social-card"] if media["social-card"]["present"] else None
    (output / "index.html").write_text(page("StayGrubby — Your food, ranked.", "/", home.home(home_destination), "home", action, social), encoding="utf-8")
    (output / "privacy.html").write_text(page("Privacy Policy — StayGrubby", "/privacy",
        '<article class="policy">\n' + policy_html(text) + '\n</article>', "reading"), encoding="utf-8")
    support = '''<article class="policy"><p class="eyebrow">Here to help</p><h1>Support</h1>
      <p>For questions about StayGrubby, email <a href="mailto:support@staygrubby.com">support@staygrubby.com</a>.</p>
      <p>Include what you were trying to do and your app and iOS version. Please do not send passwords, sign-in codes, or private keys.</p>
      <p>For privacy questions, contact <a href="mailto:privacy@staygrubby.com">privacy@staygrubby.com</a> or read our <a href="/privacy">Privacy Policy</a>.</p></article>'''
    (output / "support.html").write_text(page("Support — StayGrubby", "/support", support, "reading"), encoding="utf-8")
    (output / "404.html").write_text(page("Page not found — StayGrubby", "/",
        '<article class="policy"><h1>Page not found</h1><p><a href="/">Return to StayGrubby</a></p></article>', "reading"), encoding="utf-8")
    # /assets/wordmark.png stays at its original path and 1254 px canvas for the Worker fallbacks, as the
    # palette-optimized derivative of the official artwork (prepare_media.py brand).
    shutil.copyfile(BRAND / "wordmark.png", output / "assets/wordmark.png")
    (output / "assets/brand").mkdir(exist_ok=True)
    for name in BRAND_FILES:
        shutil.copyfile(BRAND / name, output / "assets/brand" / name)
    if any(spec["present"] for spec in media.values()):
        (output / "assets/media").mkdir(exist_ok=True)
    for spec in media.values():
        if spec["present"]:
            shutil.copyfile(home.MEDIA / spec["file"], output / "assets/media" / spec["file"])
    shutil.copyfile(ROOT / "Website/site.css", output / "assets/site.css")
    shutil.copyfile(ROOT / "Website/headers.txt", output / "_headers")
    print("Built static site; canonical policy SHA-256: " + hashlib.sha256(text.encode()).hexdigest())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "Website/public")
    build(parser.parse_args().output)
    for spec in home.missing():
        print(f"Missing website media ({spec['name']}): {spec['need']}")
