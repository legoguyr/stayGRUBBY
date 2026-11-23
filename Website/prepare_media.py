"""Offline media preparation for the public website (requires Pillow; never run by the deploy build).

Brand derivatives are resized/palette-optimized copies of the official app artwork; the wordmark is never
redrawn. Owner-supplied screenshots and food photos are resized into the slots listed in media.json.
Outputs are committed under Website/media so `build.py` stays standard-library only.

    python3 Website/prepare_media.py brand
    python3 Website/prepare_media.py slot hero-screen ~/Desktop/rank.png
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MEDIA = ROOT / "Website/media"
ASSETS = ROOT / "StayGrubby/Assets.xcassets"
WORDMARK = ASSETS / "StayGrubbyWordmark.imageset/StayGrubbyWordmark.png"
ICON = ASSETS / "AppIcon.appiconset/AppIcon-Light.png"


def save_palette_png(image, path, colors=48):
    # The wordmark is one red on transparency: an adaptive palette keeps edges and drops ~90% of bytes.
    image.convert("RGBA").quantize(colors=colors, method=Image.Quantize.FASTOCTREE).save(path, optimize=True)


def brand():
    out = MEDIA / "brand"
    out.mkdir(parents=True, exist_ok=True)
    mark = Image.open(WORDMARK).convert("RGBA")
    # Same 1254 px canvas as the source, so existing width/height attributes and the Worker fallback stay valid.
    save_palette_png(mark, out / "wordmark.png")
    for size in (240, 480):
        save_palette_png(mark.resize((size, size), Image.LANCZOS), out / f"wordmark-{size}.png")
    icon = Image.open(ICON).convert("RGB")
    icon.resize((180, 180), Image.LANCZOS).save(out / "apple-touch-icon.png", optimize=True)
    icon.resize((64, 64), Image.LANCZOS).save(out / "favicon-64.png", optimize=True)


def slot(name, source):
    slots = {s["name"]: s for s in json.loads((MEDIA / "media.json").read_text())["slots"]}
    spec = slots[name]
    image = Image.open(source).convert("RGB")
    width = spec["width"]
    height = round(image.height * width / image.width)
    if spec.get("height") and height != spec["height"]:
        raise SystemExit(f"{name}: expected {spec['width']}x{spec['height']} aspect, got {image.width}x{image.height}")
    image = image.resize((width, height), Image.LANCZOS)
    image.save(MEDIA / spec["file"], "JPEG", quality=80, optimize=True, progressive=True)
    print(f"Wrote {spec['file']} ({width}x{height})")


if __name__ == "__main__":
    if sys.argv[1:] == ["brand"]:
        brand()
    elif len(sys.argv) == 4 and sys.argv[1] == "slot":
        slot(sys.argv[2], sys.argv[3])
    else:
        raise SystemExit(__doc__)
