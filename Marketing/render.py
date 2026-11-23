"""#stayGRUBBY marketing kit renderer: campaign.json → HTML pages → PNG (and a print PDF for the flyer).

    python3 Marketing/render.py              # every design
    python3 Marketing/render.py feed-03      # designs whose id starts with this

Requires Google Chrome (headless) on macOS for system fonts and Apple Color Emoji. Standard library only.
Copy lives in campaign.json, styles in kit.css. Example cards are reused from the website (Website/home.py) and
always carry an "Illustrative preview" caption; a supplied screenshot or photo slot replaces them automatically.
"""
import html
import json
import subprocess
import sys
from pathlib import Path

KIT = Path(__file__).resolve().parent
ROOT = KIT.parent
sys.path.insert(0, str(ROOT / "Website"))
import home  # noqa: E402  (website example cards and official tab glyphs)

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PAGES, EXPORT = KIT / "build", KIT / "export"
SIZES = {"feed": (1080, 1350, 1), "story": (1080, 1920, 1), "link": (1200, 630, 1), "flyer": (816, 1056, 2)}


def media():
    """Website slots plus marketing-only slots, each with an absolute file URL when the file exists."""
    found = {}
    for folder in (ROOT / "Website/media", KIT / "media"):
        for spec in json.loads((folder / "media.json").read_text())["slots"]:
            path = folder / spec["file"]
            found[spec["name"]] = path.as_uri() if path.is_file() else None
    return found


def esc(text):
    return html.escape(text, quote=True)


def wordmark(theme, cls="wordmark"):
    color = "white" if theme == "red" else "red"
    return f'<img class="{cls}" src="{(KIT / "brand" / f"wordmark-{color}.png").as_uri()}" alt="#stayGRUBBY">'


def recipe_card():
    items = ["1 rack of lamb, frenched", "2 tbsp Dijon mustard", "½ cup panko", "2 tbsp chopped rosemary & parsley"]
    rows = "".join(f"<li><span>{esc(i)}</span></li>" for i in items)
    return ('<div class="card example" role="img" aria-label="Illustrative example of a Recipe in Food Bible.">'
            '<p class="eyebrow">Food Bible</p><p class="card-title">Herb-Crusted Rack of Lamb</p>'
            '<p class="muted">Serves 4 · 1 hr</p><ul class="cook-list">' + rows + '</ul></div>')


CARDS = {"rank": home.rank_card, "versus": home.versus_card, "dish": home.kitchen_card, "pass": home.pass_card,
         "recipe": recipe_card}


def visual(design, slots):
    """Real screenshot in a plain device outline when supplied; otherwise captioned illustrative cards."""
    screen = slots.get(design.get("screen", ""))
    if screen:
        return f'<figure class="phone"><img src="{screen}" alt=""></figure>'
    if design.get("template"):
        return '<div class="slot-placeholder"><p>Screenshot slot</p><p class="muted">announce-screen · portrait iPhone capture</p></div>'
    cards = "".join(f'<div class="layer layer-{n}">{CARDS[c]()}</div>' for n, c in enumerate(design["cards"]))
    return (f'<figure class="preview-kit"><div class="cards n{len(design["cards"])}" style="zoom:{design.get("zoom", 1.6)}">{cards}</div>'
            '<figcaption>Illustrative preview</figcaption></figure>')


def topbar(d, theme):
    counter = f'<span class="counter">{esc(d["counter"])}</span>' if d.get("counter") else ""
    return f'<header class="topbar">{wordmark(theme, "wordmark small")}{counter}</header>'


def bottombar(footer):
    return (f'<footer class="bottombar"><span class="url">{esc(footer["url"])}</span>'
            f'<span class="cta-chip">{esc(footer["cta"])}<span aria-hidden="true">→</span></span></footer>')


def eyebrow(d):
    glyph = home.icon(d["glyph"]) if d.get("glyph") else ""
    return f'<p class="eyebrow-kit">{glyph}{esc(d["eyebrow"])}</p>' if d.get("eyebrow") else ""


def intro(d, slots, footer):
    photo = slots.get(d.get("photo", ""))
    if photo:
        return (f'<div class="photo-top" style="background-image:url(\'{photo}\')"></div>'
                f'<div class="photo-panel">{wordmark("red", "wordmark mid")}<h1>{esc(d["headline"])}</h1></div>{bottombar(footer)}')
    return (f'<header class="topbar"><span></span><span class="counter">{esc(d["counter"])}</span></header>'
            f'<div class="intro-body">{wordmark("red", "wordmark hero")}'
            f'<h1>{esc(d["headline"])}</h1><p class="body">{esc(d["body"])}</p></div>{bottombar(footer)}')


def steps(d, slots, footer):
    photos = [slots.get(s.get("photo", "")) for s in d["steps"]]
    if all(photos):
        tiles = "".join(f'<li class="tile" style="background-image:url(\'{p}\')"><span>{esc(s["verb"])}</span></li>'
                        for s, p in zip(d["steps"], photos))
        return f'{topbar(d, "cream")}<p class="eyebrow-kit">{esc(d["eyebrow"])}</p><ol class="tiles">{tiles}</ol>{bottombar(footer)}'
    rows = "".join(f'<li><span class="no">0{n}</span><span class="verb">{esc(s["verb"])}</span><span class="line">{esc(s["line"])}</span></li>'
                   for n, s in enumerate(d["steps"], 1))
    return f'{topbar(d, "cream")}<p class="eyebrow-kit">{esc(d["eyebrow"])}</p><ol class="step-rows">{rows}</ol>{bottombar(footer)}'


def feature(d, slots, footer):
    return (f'{topbar(d, d["theme"])}<div class="copy">{eyebrow(d)}<h1>{esc(d["headline"])}</h1>'
            f'<p class="body">{esc(d["body"])}</p></div><div class="visual">{visual(d, slots)}</div>{bottombar(footer)}')


def story_intro(d, slots, footer):
    photo = slots.get(d.get("photo", ""))
    head = (f'<div class="photo-top" style="background-image:url(\'{photo}\')"></div>' if photo else "")
    return (f'{head}<div class="story-body">{wordmark("red", "wordmark hero")}<p class="eyebrow-kit">{esc(d["eyebrow"])}</p>'
            f'<h1>{esc(d["headline"])}</h1><p class="body">{esc(d["body"])}</p></div>'
            f'<div class="link-zone"><p>{esc(d["link"])}</p><span class="arrow" aria-hidden="true">↓</span>'
            f'<p class="url">{esc(footer["url"])}</p></div>')


def story_feature(d, slots, footer):
    return (f'<header class="topbar">{wordmark(d["theme"], "wordmark small")}</header>'
            f'<div class="copy">{eyebrow(d)}<h1>{esc(d["headline"])}</h1><p class="body">{esc(d["body"])}</p></div>'
            f'<div class="visual">{visual(d, slots)}</div>'
            f'<div class="link-zone"><p>{esc(d["link"])}</p><span class="arrow" aria-hidden="true">↓</span>'
            f'<p class="url">{esc(footer["url"])}</p></div>')


def flyer(d, slots, footer):
    steps_html = "".join(f'<li><span class="no">0{n}</span>{esc(s)}</li>' for n, s in enumerate(d["steps"], 1))
    qr = (KIT / "brand" / d["qr"]).as_uri()
    return (f'<section class="flyer-top">{wordmark("red", "wordmark hero")}<h1>{esc(d["headline"])}</h1>'
            f'<p class="body">{esc(d["body"])}</p></section>'
            f'<section class="flyer-bottom"><ol class="flyer-steps">{steps_html}</ol>'
            f'<div class="flyer-cta"><div><p class="cta-title">{esc(d["cta"])}</p><p class="url">{esc(footer["url"])}</p>'
            f'<p class="note">{esc(d["note"])}</p></div><img class="qr" src="{qr}" alt="QR code for {esc(footer["url"])}"></div></section>')


def link(d, slots, footer):
    return (f'<div class="link-mark">{wordmark("red", "wordmark")}</div><div class="link-copy"><h1>{esc(d["headline"])}</h1>'
            f'<p class="body">{esc(d["body"])}</p><p class="url">{esc(footer["url"])}</p></div>')


def announce(d, slots, footer):
    if d["format"] == "story":
        return story_feature(dict(d, theme=d["theme"]), slots, footer)
    return feature(d, slots, footer)


LAYOUTS = {"intro": intro, "steps": steps, "feature": feature, "story-intro": story_intro,
           "story-feature": story_feature, "flyer": flyer, "link": link, "announce": announce}


def page(d, slots, footer):
    width, height, _ = SIZES[d["format"]]
    site_css, kit_css = (ROOT / "Website/site.css").as_uri(), (KIT / "kit.css").as_uri()
    body = LAYOUTS[d["layout"]](d, slots, footer)
    return (f'<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{esc(d["id"])}</title>'
            f'<link rel="stylesheet" href="{site_css}"><link rel="stylesheet" href="{kit_css}">'
            f'<style>@page {{ size: {width}px {height}px; margin: 0; }}</style></head>'
            f'<body><main class="canvas {d["format"]} theme-{d["theme"]} layout-{d["layout"]}" '
            f'style="width:{width}px;height:{height}px">{body}</main></body></html>')


def render(d, slots, footer):
    width, height, scale = SIZES[d["format"]]
    source = PAGES / f'{d["id"]}.html'
    source.write_text(page(d, slots, footer))
    base = [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
            "--virtual-time-budget=1500", f"--force-device-scale-factor={scale}"]
    png = EXPORT / f'{d["id"]}.png'
    subprocess.run(base + [f"--window-size={width},{height}", f"--screenshot={png}", source.as_uri()],
                   check=True, capture_output=True)
    outputs = [png.name]
    if d["format"] == "flyer":
        pdf = EXPORT / f'{d["id"]}.pdf'
        subprocess.run(base + ["--no-pdf-header-footer", f"--print-to-pdf={pdf}", source.as_uri()], check=True, capture_output=True)
        outputs.append(pdf.name)
    return outputs


def main(prefix=""):
    campaign = json.loads((KIT / "campaign.json").read_text())
    slots = media()
    PAGES.mkdir(exist_ok=True)
    EXPORT.mkdir(exist_ok=True)
    for d in campaign["designs"]:
        if d["id"].startswith(prefix):
            print("Rendered", ", ".join(render(d, slots, campaign["footer"])))
    missing = sorted(name for name, uri in slots.items() if not uri and name != "social-card")
    print("Missing media (illustrative/typographic fallbacks used):", ", ".join(missing) or "none")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "")
