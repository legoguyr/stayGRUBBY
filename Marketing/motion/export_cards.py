"""Exports the shared card HTML, official glyphs, brand assets, the @grubwithguy snapshot and any supplied photos to
motion/build/assets.js so the animated Reels reuse exactly what the static designs use. Standard library only.

    python3 Marketing/motion/export_cards.py
"""
import json
import sys
from pathlib import Path

MOTION = Path(__file__).resolve().parent
KIT = MOTION.parent
sys.path.insert(0, str(KIT))
sys.argv = sys.argv[:1]
import render  # noqa: E402  (card registry, cards, real_cards, home glyphs)

CARD_NAMES = ["rank", "versus", "pass-post", "send-recipe", "rank-my-version", "progress", "signature", "comments",
              "real-top:1-3", "real-top:1-5", "real-recipe:Pasta alla Norma", "real-share-recipe:Pasta alla Norma",
              "real-post:Miso Eggplant", "real-post:Tandoori Chicken with Coconut Mint Chutney", "real-moved"]


def main():
    photos = {}
    folder = KIT / "real-cooking/photos"
    for row in render.real_cards.DATA["top20"]:
        for ext in ("jpg", "jpeg", "png"):
            if (folder / f'{row["photo"]}.{ext}').is_file():
                photos[row["photo"]] = (folder / f'{row["photo"]}.{ext}').as_uri()
                break
    assets = {
        "cards": {name: render.card_html(name) for name in CARD_NAMES},
        "glyphs": {g: render.home.icon(g) for g in ("TabRankFill", "TabKitchenFill", "TabPassFill")},
        "wordmark": {c: (KIT / "brand" / f"wordmark-{c}.png").as_uri() for c in ("red", "white")},
        "data": render.real_cards.DATA,
        "photos": photos,
        "caption_real": render.real_cards.caption(),
    }
    (MOTION / "build").mkdir(exist_ok=True)
    (MOTION / "build/assets.js").write_text("window.ASSETS = " + json.dumps(assets, ensure_ascii=False) + ";\n")
    print(f"Exported {len(assets['cards'])} cards, {len(photos)} photos")


if __name__ == "__main__":
    main()
