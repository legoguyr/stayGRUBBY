"""#stayGRUBBY marketing kit renderer: campaign.json (launch set) + library.json (creative library)
→ HTML pages → PNG (a print PDF for the flyer; carousels as numbered slides; Reels as frames → MP4 via reel.swift).

    python3 Marketing/render.py              # every design
    python3 Marketing/render.py lib-f1       # designs whose id starts with this

Requires Google Chrome (headless) on macOS for system fonts and Apple Color Emoji. Standard library only.
Copy lives in campaign.json, styles in kit.css. Example cards are reused from the website (Website/home.py) and
always carry an "Illustrative preview" caption; a supplied screenshot or photo slot replaces them automatically.
"""
import html
import json
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

KIT = Path(__file__).resolve().parent
ROOT = KIT.parent
sys.path.insert(0, str(ROOT / "Website"))
import home  # noqa: E402  (website example cards and official tab glyphs)
sys.path.insert(0, str(KIT))
import cards  # noqa: E402  (marketing-only illustrative cards in the same style)
import real_cards  # noqa: E402  (cards from the read-only @grubwithguy snapshot)

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PAGES, EXPORT = KIT / "build", KIT / "export"
CAMPAIGN = None  # None = launch set + library; "real-cooking" = Marketing/real-cooking (own designs, photos, exports)
SIZES = {"feed": (1080, 1350, 1), "story": (1080, 1920, 1), "link": (1200, 630, 1), "flyer": (816, 1056, 2)}


def media():
    """Website slots plus marketing-only slots, each with an absolute file URL when the file exists."""
    found = {}
    for folder in (ROOT / "Website/media", KIT / "media"):
        for spec in json.loads((folder / "media.json").read_text())["slots"]:
            path = folder / spec["file"]
            found[spec["name"]] = path.as_uri() if path.is_file() else None
    if CAMPAIGN:
        # Owner-supplied photos for this campaign: <campaign>/photos/<slot>.jpg|jpeg|png (slot names in data.json).
        for row in real_cards.DATA["top20"]:
            hits = [p for ext in ("jpg", "jpeg", "png") for p in [KIT / CAMPAIGN / "photos" / f'{row["photo"]}.{ext}'] if p.is_file()]
            found[row["photo"]] = hits[0].as_uri() if hits else None
    return found


def esc(text):
    return html.escape(text, quote=True)


def rich(text):
    """Escaped text; *word* is the highlight colour for the theme, a newline is a line break."""
    return re.sub(r"\*(.+?)\*", r"<em>\1</em>", esc(text)).replace("\n", "<br>")


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
         "recipe": recipe_card, "signature": cards.signature, "progress": cards.progress, "add-recipe": cards.add_recipe,
         "send-recipe": cards.send_recipe, "rank-my-version": cards.rank_my_version, "pass-post": cards.pass_post,
         "comments": cards.comments, "tickets": cards.tickets, "tag-chef": cards.tag_chef}


def visual(design, slots):
    """Real screenshot in a plain device outline when supplied; otherwise captioned illustrative cards."""
    screen = slots.get(design.get("screen", ""))
    if screen:
        return f'<figure class="phone"><img src="{screen}" alt=""></figure>'
    if design.get("template"):
        return '<div class="slot-placeholder"><p>Screenshot slot</p><p class="muted">announce-screen · portrait iPhone capture</p></div>'
    cards = "".join(f'<div class="layer layer-{n}">{card_html(c)}</div>' for n, c in enumerate(design["cards"]))
    real = all(c.startswith("real-") for c in design["cards"])
    caption = real_cards.caption() if real else "Illustrative preview"
    return (f'<figure class="preview-kit"><div class="cards n{len(design["cards"])}" style="zoom:{design.get("zoom", 1.6)}">{cards}</div>'
            f'<figcaption>{esc(caption)}</figcaption></figure>')


def card_html(name):
    """`name` or `name:argument` (e.g. real-top:1-10, real-recipe:Pasta alla Norma)."""
    key, _, arg = name.partition(":")
    if key in real_cards.CARDS:
        return real_cards.CARDS[key](arg) if arg else real_cards.CARDS[key]()
    return CARDS[key]()


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



# ---- Creative library layouts (library.json). Shared chrome: header, then the layout body, then a feed
# bottom bar, a carousel swipe bar or a Story link/sticker zone.
def chrome_header(d):
    right = d.get("counter") or d.get("tag") or ""
    return f'<header class="topbar">{wordmark(d["theme"], "wordmark small")}<span class="counter">{esc(right)}</span></header>'


def chrome_footer(d, footer):
    if d["format"] == "story":
        if d.get("sticker"):
            return f'<div class="sticker-zone"><p>{esc(d["sticker"])}</p></div>'
        if d.get("link"):
            return (f'<div class="link-zone"><p>{esc(d["link"])}</p><span class="arrow" aria-hidden="true">↓</span>'
                    f'<p class="url">{esc(footer["url"])}</p></div>')
        return ""
    if d.get("swipe"):
        return f'<footer class="bottombar"><span class="url">#stayGRUBBY</span><span class="swipe">{esc(d["swipe"])}<span aria-hidden="true">→</span></span></footer>'
    return bottombar(footer)


def copy_block(d):
    eyebrow_html = eyebrow(d)
    body = f'<p class="body">{rich(d["body"])}</p>' if d.get("body") else ""
    return f'<div class="copy">{eyebrow_html}<h1 class="{d.get("size", "")}">{rich(d["headline"])}</h1>{body}</div>'


def photo_block(d, slots, cls="photo-slot"):
    uri = slots.get(d["photo"])
    if uri:
        return f'<div class="{cls} filled" style="background-image:url(\'{uri}\')"></div>'
    return placeholder(d["photo"], cls, d.get("photo_need", "owned food photo"))


def placeholder(slot, cls, need=None):
    if CAMPAIGN:
        return (f'<div class="{cls} empty"><p>Photo · {esc(real_cards.photo_label(slot))}</p>'
                f'<p class="muted">add photos/{esc(slot)}.jpg</p></div>')
    return f'<div class="{cls} empty"><p>Photo slot</p><p class="muted">{esc(slot)} · {esc(need or "")}</p></div>'


def photo_tile(slots, slot, cls, inner=""):
    uri = slots.get(slot)
    if uri:
        return f'<div class="{cls} filled" style="background-image:url(\'{uri}\')">{inner}</div>'
    return placeholder(slot, cls).replace("</div>", inner + "</div>", 1) if inner else placeholder(slot, cls)


def lib_photo_score(d, slots, footer):
    """Full-bleed photo of one ranked cook with its real rank and score."""
    row = real_cards.TOP[d["rank"]]
    cook = f'<p class="ps-cook">{esc(row["cook"])}</p>' if row.get("cook") else ""
    body = f'<p class="body">{rich(d["body"])}</p>' if d.get("body") else ""
    return (f'{photo_tile(slots, row["photo"], "photo-slot hero")}{chrome_header(d)}'
            f'<div class="ps-block"><p class="ps-rank">#{row["rank"]}<span>of {real_cards.DATA["ranked_cooks"]}</span></p>'
            f'<h1 class="{d.get("size", "")}">{rich(d.get("headline") or row["dish"])}</h1>{cook}'
            f'<p class="ps-score">{row["score"]}</p>{body}<p class="ps-asof">{esc(real_cards.caption())}</p></div>{chrome_footer(d, footer)}')


def lib_photo_versus(d, slots, footer):
    """Two real cooks that were actually compared head-to-head; `winner` marks the real result."""
    tiles = []
    for side, rank in zip("ab", d["ranks"]):
        row = real_cards.TOP[rank]
        won = d.get("show_winner") and d.get("winner") == side
        mark = '<span class="check" aria-hidden="true">✓</span>' if won else ""
        score = f'<span class="score">{row["score"]}</span>' if d.get("show_scores") else ""
        inner = f'<p class="pv-name"><span>{esc(row["dish"])}</span>{score}{mark}</p>'
        tiles.append(photo_tile(slots, row["photo"], "pv-tile" + (" won" if won else ""), inner))
    return (f'{chrome_header(d)}{copy_block(d)}<div class="pv">{tiles[0]}<span class="vs-or">or</span>{tiles[1]}</div>'
            f'{chrome_footer(d, footer)}')


def lib_photo_grid(d, slots, footer):
    """Grid of ranked cooks' photos with rank badges (Top 4 / 6 / 9)."""
    first, last = (int(x) for x in d["ranks"].split("-"))
    tiles = "".join(photo_tile(slots, real_cards.TOP[r]["photo"], "pg-tile",
                               f'<span class="pg-badge">#{r} · {real_cards.TOP[r]["score"]}</span>') for r in range(first, last + 1))
    return (f'{chrome_header(d)}{copy_block(d)}<div class="pg n{last - first + 1}">{tiles}</div>'
            f'<p class="ps-asof inline">{esc(real_cards.caption())}</p>{chrome_footer(d, footer)}')


def lib_photo_card(d, slots, footer):
    """A real photo with a real card floating over it."""
    return (f'{photo_tile(slots, d["photo"], "photo-slot hero")}{chrome_header(d)}<div class="pcard">'
            f'<div class="visual">{visual(d, slots)}</div></div>{copy_block(d)}{chrome_footer(d, footer)}')


def lib_slogan(d, slots, footer):
    lines = "".join(f'<span>{rich(line)}</span>' for line in d["headline"].split("\n"))
    body = f'<p class="body">{rich(d["body"])}</p>' if d.get("body") else ""
    return (f'{chrome_header(d)}<div class="slogan {d.get("align", "")} {"alternate" if d.get("alternate") else ""}">'
            f'{eyebrow(d)}<h1 class="{d.get("size", "")}">{lines}</h1>{body}</div>{chrome_footer(d, footer)}')


def lib_feature(d, slots, footer):
    return f'{chrome_header(d)}{copy_block(d)}<div class="visual">{visual(d, slots)}</div>{chrome_footer(d, footer)}'


def lib_visual_first(d, slots, footer):
    return (f'{chrome_header(d)}<div class="panel"><div class="visual">{visual(d, slots)}</div></div>'
            f'{copy_block(d)}{chrome_footer(d, footer)}')


def lib_versus(d, slots, footer):
    tiles = []
    for side, name in zip("ab", d["choices"]):
        uri = slots.get(f'photo-versus-{side}')
        style = f' style="background-image:url(\'{uri}\')"' if uri else ""
        chosen = " chosen" if d.get("chosen") == side else ""
        mark = '<span class="check" aria-hidden="true">✓</span>' if chosen else ""
        tiles.append(f'<div class="vs-tile{" has-photo" if uri else ""}{chosen}"{style}><span>{esc(name)}</span>{mark}</div>')
    return (f'{chrome_header(d)}{copy_block(d)}<div class="vs">{tiles[0]}<span class="vs-or">or</span>{tiles[1]}</div>'
            f'{chrome_footer(d, footer)}')


def lib_photo(d, slots, footer):
    return f'{photo_block(d, slots, "photo-slot hero")}{chrome_header(d)}<div class="photo-copy">{copy_block(d)}</div>{chrome_footer(d, footer)}'


def lib_brand(d, slots, footer):
    body = f'<p class="body">{rich(d["body"])}</p>' if d.get("body") else ""
    return (f'<header class="topbar"><span></span><span class="counter">{esc(d.get("counter") or d.get("tag") or "")}</span></header>'
            f'<div class="brand-block">{wordmark(d["theme"], "wordmark hero")}<h1 class="{d.get("size", "")}">{rich(d["headline"])}</h1>{body}</div>'
            f'{chrome_footer(d, footer)}')


def lib_score(d, slots, footer):
    """One huge score with what earned it — the This or That → number payoff."""
    return (f'{chrome_header(d)}<div class="score-block"><p class="big-score">{esc(d["score"])}</p>'
            f'<p class="score-dish">{esc(d["dish"])}</p></div>{copy_block(d)}{chrome_footer(d, footer)}')

LAYOUTS = {"intro": intro, "steps": steps, "feature": feature, "story-intro": story_intro,
           "story-feature": story_feature, "flyer": flyer, "link": link, "announce": announce,
           "slogan": lib_slogan, "lib-feature": lib_feature, "visual-first": lib_visual_first, "versus": lib_versus,
           "photo": lib_photo, "brand": lib_brand, "score": lib_score, "photo-score": lib_photo_score,
           "photo-versus": lib_photo_versus, "photo-grid": lib_photo_grid, "photo-card": lib_photo_card}


# Shrinks an example card (never enlarges it) until its captioned preview fits the space the layout leaves, so
# copy edits in the JSON cannot push a card into the footer, link zone or sticker zone.
FIT = """<script>
for (const v of document.querySelectorAll('.visual')) {
  const cards = v.querySelector('.cards'), fig = v.querySelector('figure');
  if (!cards || !fig) continue;
  let zoom = parseFloat(cards.style.zoom) || 1;
  while (fig.getBoundingClientRect().height > v.getBoundingClientRect().height - 8 && zoom > 0.9) {
    zoom -= 0.05; cards.style.zoom = zoom;
  }
}
</script>"""


def page(d, slots, footer):
    width, height, _ = SIZES[d["format"]]
    site_css, kit_css = (ROOT / "Website/site.css").as_uri(), (KIT / "kit.css").as_uri()
    body = LAYOUTS[d["layout"]](d, slots, footer)
    return (f'<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{esc(d["id"])}</title>'
            f'<link rel="stylesheet" href="{site_css}"><link rel="stylesheet" href="{kit_css}">'
            f'<style>@page {{ size: {width}px {height}px; margin: 0; }}</style></head>'
            f'<body><main class="canvas {d["format"]} theme-{d["theme"]} layout-{d["layout"]} {d.get("variant", "")}" '
            f'style="width:{width}px;height:{height}px">{body}</main>{FIT}</body></html>')


def render(d, slots, footer):
    width, height, scale = SIZES[d["format"]]
    source = PAGES / f'{d["id"]}.html'
    source.write_text(page(d, slots, footer))
    png = EXPORT / d.get("out", f'{d["id"]}.png')
    png.parent.mkdir(parents=True, exist_ok=True)
    base = [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
            "--virtual-time-budget=1500", f"--force-device-scale-factor={scale}"]
    subprocess.run(base + [f"--window-size={width},{height}", f"--screenshot={png}", source.as_uri()],
                   check=True, capture_output=True)
    outputs = [str(png.relative_to(EXPORT))]
    if d["format"] == "flyer":
        pdf = EXPORT / f'{d["id"]}.pdf'
        subprocess.run(base + ["--no-pdf-header-footer", f"--print-to-pdf={pdf}", source.as_uri()], check=True, capture_output=True)
        outputs.append(pdf.name)
    return outputs


def expand(entry):
    """A carousel becomes numbered slides; a Reel becomes frames (encoded afterwards). Slides inherit the entry."""
    if "slides" in entry:
        total = len(entry["slides"])
        for n, slide in enumerate(entry["slides"], 1):
            base = {k: v for k, v in entry.items() if k not in ("slides", "id", "note")}
            yield dict(base, **slide, id=f'{entry["id"]}-{n:02d}', counter=f"{n} / {total}",
                       swipe=slide.get("swipe", "Swipe" if n < total else None),
                       out=f'carousels/{entry["id"]}/{entry["id"]}-{n:02d}.png')
    elif "reel" in entry:
        for n, frame in enumerate(entry["reel"], 1):
            base = {k: v for k, v in entry.items() if k not in ("reel", "id", "note")}
            yield dict(base, **frame, id=f'{entry["id"]}-f{n:02d}', out=f'reels/{entry["id"]}/frame-{n:02d}.png')
    else:
        yield entry


def encode_reel(entry):
    folder = EXPORT / "reels" / entry["id"]
    plan = [{"image": str(folder / f"frame-{n:02d}.png"), "seconds": f.get("seconds", 1.6)} for n, f in enumerate(entry["reel"], 1)]
    (folder / "plan.json").write_text(json.dumps(plan, indent=1))
    subprocess.run(["swift", str(KIT / "reel.swift"), str(folder / "plan.json"), str(EXPORT / "reels" / f'{entry["id"]}.mp4')],
                   check=True, capture_output=True)
    (folder / "plan.json").unlink()
    return f'reels/{entry["id"]}.mp4'


def designs():
    if CAMPAIGN:
        data = json.loads((KIT / CAMPAIGN / "designs.json").read_text())
        yield from ((entry, data["footer"]) for entry in data["designs"])
        return
    footer = None
    for name in ("campaign.json", "library.json"):
        data = json.loads((KIT / name).read_text())
        footer = footer or data["footer"]
        yield from ((entry, data["footer"]) for entry in data["designs"])


def main(prefix=""):
    slots = media()
    PAGES.mkdir(exist_ok=True)
    EXPORT.mkdir(exist_ok=True)
    chosen = [(e, f) for e, f in designs() if e["id"].startswith(prefix)]
    jobs = [(d, f) for e, f in chosen for d in expand(e)]
    with ThreadPoolExecutor(max_workers=4) as pool:
        for outputs in pool.map(lambda job: render(job[0], slots, job[1]), jobs):
            print("Rendered", ", ".join(outputs))
    for entry, _ in chosen:
        if "reel" in entry:
            print("Encoded", encode_reel(entry))
    missing = sorted(name for name, uri in slots.items() if not uri and name != "social-card")
    print("Missing media (illustrative/typographic fallbacks used):", ", ".join(missing) or "none")


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["--campaign"]:
        CAMPAIGN = args[1]
        PAGES, EXPORT = KIT / CAMPAIGN / "build", KIT / CAMPAIGN / "export"
        args = args[2:]
    main(args[0] if args else "")
