"""Offline brand derivatives for the marketing kit (requires Pillow). Never redraws the wordmark:
the official artwork is cropped to its ink and, for the white variant, recoloured through its own alpha mask.

    python3 Marketing/prepare_brand.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
WORDMARK = ROOT / "StayGrubby/Assets.xcassets/StayGrubbyWordmark.imageset/StayGrubbyWordmark.png"
ICON = ROOT / "StayGrubby/Assets.xcassets/AppIcon.appiconset/AppIcon-Light.png"
OUT = Path(__file__).resolve().parent / "brand"


def main():
    OUT.mkdir(exist_ok=True)
    mark = Image.open(WORDMARK).convert("RGBA")
    # Threshold the alpha so faint export noise at the canvas edge does not defeat the crop.
    mark = mark.crop(mark.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox())
    mark.save(OUT / "wordmark-red.png", optimize=True)
    white = Image.new("RGBA", mark.size, (255, 255, 255, 0))
    white.putalpha(mark.getchannel("A"))
    Image.alpha_composite(Image.new("RGBA", mark.size, (255, 255, 255, 0)), white).save(OUT / "wordmark-white.png", optimize=True)
    Image.open(ICON).convert("RGB").resize((512, 512), Image.LANCZOS).save(OUT / "app-icon.png", optimize=True)
    print("Wrote", ", ".join(sorted(p.name for p in OUT.glob("*.png"))))


if __name__ == "__main__":
    main()
