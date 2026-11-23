"""Review sheets from export/ (requires Pillow): the Instagram profile grid as it will appear after posting 01→06
(newest first, 3 across), and an overview of stories, flyer, link preview and templates.

    python3 Marketing/contact_sheet.py
"""
from pathlib import Path

from PIL import Image

EXPORT = Path(__file__).resolve().parent / "export"
CREAM = (250, 243, 236)


def sheet(names, height, out, cols, gap=24):
    images = [Image.open(EXPORT / n).convert("RGB") for n in names]
    images = [i.resize((round(i.width * height / i.height), height), Image.LANCZOS) for i in images]
    rows = [images[r:r + cols] for r in range(0, len(images), cols)]
    width = max(sum(i.width for i in row) + gap * (len(row) + 1) for row in rows)
    canvas = Image.new("RGB", (width, len(rows) * (height + gap) + gap), CREAM)
    y = gap
    for row in rows:
        x = gap
        for image in row:
            canvas.paste(image, (x, y))
            x += image.width + gap
        y += height + gap
    canvas.save(EXPORT / out, quality=88)
    print("Wrote", out)


if __name__ == "__main__":
    feed = sorted(p.name for p in EXPORT.glob("feed-0*.png"))
    sheet(list(reversed(feed)), 450, "review-instagram-grid.jpg", 3, gap=6)
    sheet(["story-01-beta-open.png", "story-02-this-or-that.png", "template-announcement-story.png",
           "flyer-beta-letter.png", "template-announcement-feed.png"], 760, "review-other-materials.jpg", 5)
