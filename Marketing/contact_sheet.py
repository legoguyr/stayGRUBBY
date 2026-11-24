"""Review sheets from export/ (requires Pillow). Every thumbnail is labelled with its file id so favourites can be
named back. Never post these sheets.

    python3 Marketing/contact_sheet.py

review-instagram-grid.jpg   launch posts 01→06 as the profile grid will show them (newest first)
review-feed.jpg             every feed design (launch set + library)
review-stories.jpg          every Story
review-carousels.jpg        one row per carousel, slides in order
review-reels.jpg            one row per Reel, frames in order (the MP4s are in export/reels/)
review-other-materials.jpg  flyer, link preview and announcement templates
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

EXPORT = Path(__file__).resolve().parent / "export"
CREAM, INK, RED = (250, 243, 236), (31, 31, 31), (241, 6, 7)
FONT = "/System/Library/Fonts/Helvetica.ttc"


def font(size, bold=False):
    return ImageFont.truetype(FONT, size, index=1 if bold else 0)


def thumb(path, height):
    image = Image.open(path).convert("RGB")
    return image.resize((round(image.width * height / image.height), height), Image.LANCZOS)


def grid(paths, height, out, cols, title, gap=28, label=True):
    """Thumbnails in rows of `cols` with the file id under each."""
    images = [(p, thumb(p, height)) for p in paths]
    width = max(i.width for _, i in images)
    label_h = 46 if label else 0
    rows = [images[r:r + cols] for r in range(0, len(images), cols)]
    canvas = Image.new("RGB", (gap + cols * (width + gap), 120 + len(rows) * (height + label_h + gap) + gap), CREAM)
    draw = ImageDraw.Draw(canvas)
    draw.text((gap, 36), title, fill=INK, font=font(44, True))
    y = 120
    for row in rows:
        x = gap
        for path, image in row:
            canvas.paste(image, (x, y))
            if label:
                draw.text((x, y + height + 10), path.stem, fill=INK, font=font(20))
            x += width + gap
        y += height + label_h + gap
    canvas.save(EXPORT / out, quality=86)
    print("Wrote", out)


def strips(groups, height, out, title, gap=24):
    """One labelled row per carousel/Reel."""
    rows = [(name, [thumb(p, height) for p in paths]) for name, paths in groups]
    width = max(sum(i.width + gap for i in imgs) for _, imgs in rows) + gap
    canvas = Image.new("RGB", (width, 120 + len(rows) * (height + 80 + gap)), CREAM)
    draw = ImageDraw.Draw(canvas)
    draw.text((gap, 36), title, fill=INK, font=font(44, True))
    y = 120
    for name, imgs in rows:
        draw.text((gap, y), name, fill=RED, font=font(30, True))
        x = gap
        for image in imgs:
            canvas.paste(image, (x, y + 56))
            x += image.width + gap
        y += height + 80 + gap
    canvas.save(EXPORT / out, quality=86)
    print("Wrote", out)


if __name__ == "__main__":
    launch = sorted(EXPORT.glob("feed-0*.png"))
    grid(list(reversed(launch)), 450, "review-instagram-grid.jpg", 3, "Launch grid (as posted 01→06)", gap=6, label=False)
    grid(launch + sorted(EXPORT.glob("lib-feed-*.png")), 420, "review-feed.jpg", 5, "Feed designs · 1080×1350")
    grid(sorted(EXPORT.glob("story-0*.png")) + sorted(EXPORT.glob("lib-story-*.png")), 560, "review-stories.jpg", 7, "Stories · 1080×1920")
    carousels = sorted((EXPORT / "carousels").iterdir()) if (EXPORT / "carousels").exists() else []
    if carousels:
        strips([(c.name, sorted(c.glob("*.png"))) for c in carousels], 380, "review-carousels.jpg", "Carousels · swipe left to right")
    reels = sorted(d for d in (EXPORT / "reels").iterdir() if d.is_dir()) if (EXPORT / "reels").exists() else []
    if reels:
        strips([(r.name + ".mp4", sorted(r.glob("frame-*.png"))) for r in reels], 460, "review-reels.jpg", "Reels · key frames in order")
    grid([EXPORT / n for n in ("flyer-beta-letter.png", "link-preview-1200x630.png", "template-announcement-feed.png",
                               "template-announcement-story.png")], 560, "review-other-materials.jpg", 4, "Flyer, link preview, templates")
