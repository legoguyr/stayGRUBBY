"""Website V2 single-page home: Hero → How It Works → Features → Download → footer.

Copy and examples reuse the owner-approved first-run tutorial (StayGrubby/Tutorial/TutorialContent.swift,
TutorialIllustration.swift). Screenshot/photo slots come from media/media.json; a missing slot falls back to
the tutorial example card or a text-only layout, never an invented screenshot or stock image.
"""
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MEDIA = ROOT / "Website/media"
ASSETS = ROOT / "StayGrubby/Assets.xcassets"


def slots():
    """Every slot with `present` set when its prepared file exists."""
    result = {}
    for spec in json.loads((MEDIA / "media.json").read_text())["slots"]:
        spec = dict(spec, present=(MEDIA / spec["file"]).is_file())
        if spec["present"] and not spec["alt"].strip():
            raise ValueError(f"Add alt text for {spec['name']} in Website/media/media.json")
        result[spec["name"]] = spec
    return result


def icon(name):
    """Official tab glyph from the app asset catalog, inlined (no extra request, CSP-safe)."""
    svg = (ASSETS / f"{name}.imageset/{name}.svg").read_text().strip()
    svg = svg.replace('stroke="#000"', 'stroke="currentColor"')
    return re.sub(r'<svg [^>]*viewBox="([^"]+)"[^>]*>',
                  r'<svg class="glyph" viewBox="\1" fill="currentColor" aria-hidden="true" focusable="false">', svg, count=1)


def cta(destination):
    """Homepage acquisition from Website/distribution.json; /beta stays available for existing links."""
    if destination and destination.startswith("https://apps.apple.com/"):
        return destination, "Download on the App Store", "Free for iPhone"
    if destination:
        return destination, "Join the Beta", "iPhone beta · via Apple TestFlight"
    return "/beta", "Join the Beta", "iPhone beta"


def phone(spec, eager=False):
    loading = 'fetchpriority="high"' if eager else 'loading="lazy" decoding="async"'
    return (f'<figure class="phone"><img src="/assets/media/{spec["file"]}" width="{spec["width"]}" '
            f'height="{spec["height"]}" alt="{html.escape(spec["alt"], quote=True)}" {loading}></figure>')


# Tutorial examples (illustrative names/scores; shown as labelled example cards, never as screenshots).
def rank_card():
    rows = [("Rack of Lamb", "9.4"), ("Mushroom Risotto", "8.8"), ("Pan-Seared Duck Breast", "8.1"), ("Chicken Piccata", "6.9")]
    items = "".join(
        f'<li><span class="rank-no">{i}</span><span class="rank-name">{name}'
        + ('<small>Signature Dish</small>' if i <= 3 else '') + f'</span><span class="score">{score}</span></li>'
        for i, (name, score) in enumerate(rows, 1))
    return (f'<div class="card example" role="img" aria-label="Example Grub Rank: Rack of Lamb 9.4, Mushroom Risotto 8.8, '
            f'Pan-Seared Duck Breast 8.1 and Chicken Piccata 6.9; the top three are Signature Dishes.">'
            f'<p class="card-head">{icon("TabRankFill")}Grub Rank</p><ol class="rank-list">{items}</ol></div>')


def kitchen_card():
    cooks = [("Grilled Rack of Lamb", "Oct 2"), ("Sous Vide Rack of Lamb", "Oct 19"), ("Herb-Crusted Rack of Lamb", "Nov 8")]
    rows = "".join(f'<li><span>{name}</span><time>{date}</time></li>' for name, date in cooks)
    return ('<div class="card example" role="img" aria-label="Example Dish Rack of Lamb with three cooks: Grilled, Sous Vide and '
            'Herb-Crusted; the Herb-Crusted Rack of Lamb Recipe is saved in Food Bible.">'
            '<p class="eyebrow">Dish</p><p class="card-title">Rack of Lamb</p><p class="muted">3 cooks</p>'
            f'<ul class="cook-list">{rows}</ul>'
            '<div class="recipe-chip"><p class="eyebrow">Food Bible</p><p class="card-title small">Herb-Crusted Rack of Lamb</p>'
            '<p class="muted">Serves 4 · 1 hr</p></div></div>')


def pass_card():
    return ('<div class="card example" role="img" aria-label="Example post on The Pass: Herb-Crusted Rack of Lamb, scored 9.4, '
            'with 4 Hands from Sous Chefs.">'
            f'<p class="card-head">{icon("TabPassFill")}The Pass<span class="pill">9.4</span></p>'
            '<p class="card-title">Herb-Crusted Rack of Lamb</p><p>Herb-crusted rack of lamb for Sunday dinner.</p>'
            '<p class="hands"><span aria-hidden="true">🙌</span> 4 Hands</p></div>')


def versus_card():
    return ('<div class="card example versus" role="img" aria-label="Example comparison: Mushroom Risotto or Pan-Seared Duck Breast. '
            'Mushroom Risotto is chosen."><p class="card-title">This or that?</p>'
            '<div class="picks"><p class="pick chosen">Mushroom Risotto<span class="check" aria-hidden="true">✓</span></p>'
            '<p class="or" aria-hidden="true">or</p><p class="pick">Pan-Seared Duck Breast</p></div></div>')


STEPS = [
    ("cook", "Cook", "One Dish. Every cook, with photos."),
    ("rank", "Rank", "This or that? Pick between two things you made."),
    ("remember", "Remember", "Your Grub Rank and Recipes, always with you."),
    ("share", "Share", "Post your best cooks to The Pass."),
]

FEATURES = [
    ("rank-screen", versus_card, "TabRankFill", "Grub Rank", "This or that?",
     "No stars, no sliders. Quick picks build your Grub Rank, and your top three are your Signature Dishes."),
    ("kitchen-screen", kitchen_card, "TabKitchenFill", "My Kitchen · Food Bible", "One Dish. Every cook.",
     "Every cook of a Dish in one place. Recipes worth making again live in Food Bible."),
    ("pass-screen", pass_card, "TabPassFill", "The Pass", "Save it. Show it off.",
     "Post a cook to The Pass and your Sous Chefs Give Hands 🙌."),
]


def home(destination):
    media = slots()
    href, label, note = cta(html.escape(destination, quote=True) if destination else None)
    button = f'<a class="button" href="{href}">{label}</a>'

    hero_visual = phone(media["hero-screen"], eager=True) if media["hero-screen"]["present"] else (
        '<div class="stack">' + rank_card() + '</div>')

    steps = []
    for n, (slot, verb, line) in enumerate(STEPS, 1):
        spec = media["photo-" + slot]
        photo = (f'<img class="step-photo" src="/assets/media/{spec["file"]}" width="{spec["width"]}" height="{spec["height"]}" '
                 f'alt="{html.escape(spec["alt"], quote=True)}" loading="lazy" decoding="async">') if spec["present"] else ''
        steps.append(f'<li class="step reveal{" has-photo" if photo else ""}">{photo}<span class="step-no" aria-hidden="true">0{n}</span>'
                     f'<h3>{verb}</h3><p>{line}</p></li>')

    features = []
    for slot, card, glyph, name, title, line in FEATURES:
        visual = phone(media[slot]) if media[slot]["present"] else card()
        features.append(f'<article class="feature reveal"><div class="feature-visual">{visual}</div><div class="feature-copy">'
                        f'<p class="feature-name">{icon(glyph)}{name}</p><h3>{title}</h3><p>{line}</p></div></article>')

    return f'''<section class="hero" aria-labelledby="hero-title">
      <div class="hero-copy">
        <h1 id="hero-title">Your food, <em>ranked.</em></h1>
        <p class="lede">Rank everything you cook. Keep the Recipes worth making again. Share the best with friends.</p>
        <div class="cta">{button}<p class="cta-note">{note}</p></div>
      </div>
      <div class="hero-visual">{hero_visual}</div>
    </section>
    <section class="how" aria-labelledby="how-title">
      <h2 id="how-title" class="section-title reveal">How it works</h2>
      <ol class="steps">{"".join(steps)}</ol>
    </section>
    <section class="features" aria-labelledby="features-title">
      <h2 id="features-title" class="section-title reveal">Everything you cook, in one place.</h2>
      {"".join(features)}
    </section>
    <section class="download" aria-labelledby="download-title">
      <div class="download-inner reveal">
        <h2 id="download-title">Start your Grub Rank.</h2>
        <div class="cta">{button}<p class="cta-note">{note}</p></div>
      </div>
    </section>'''


def missing():
    return [s for s in slots().values() if not s["present"]]
