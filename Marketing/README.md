# #stayGRUBBY marketing kit

Status: **visual direction owner-approved (November 22, 2026)**. Nothing here has been posted or wired into the website; final assets swap in real screenshots and photos as the owner supplies them.

## Visual direction

- **Two surfaces only.** The first is logo red `#F10607` with white type and the white wordmark. The second is cream `#FAF3EC` with charcoal `#1F1F1F` type and red accents. The six feed posts alternate red and cream, so the profile grid reads as a checkerboard (see `export/review-instagram-grid.jpg`).
- **Same frame on every post.**
  - Top: the small wordmark and an `0N / 06` counter.
  - Middle: an eyebrow with the official tab glyph, a heavy, tightly set headline and one short line of copy.
  - Middle, below the copy: one visual.
  - Bottom: `staygrubby.com` and a **Join the iPhone beta** pill.
  - This frame is shared with the website: same system type, card style, headline treatment and CTA colours.
- **Official assets only.**
  - `brand/wordmark-red.png` is the asset-catalog wordmark cropped to its ink.
  - `brand/wordmark-white.png` is the same artwork recoloured through its own alpha mask. The wordmark is never retypeset.
  - Tab glyphs are inlined from `StayGrubby/Assets.xcassets`.
- **Honest visuals.**
  - No real screenshots or food photos exist yet. Each feature post therefore uses the website's own tutorial example card, labelled **Illustrative preview**.
  - There are no fabricated screenshots, rankings, users, activity or testimonials.
  - When a screenshot or photo slot is supplied, the renderer swaps it in automatically. A screenshot appears inside a plain device outline; a photo fills its area.
- **Copy** reuses approved website and tutorial wording and product vocabulary: Grub Rank, Signature Dishes, My Kitchen, Food Bible, The Pass, Sous Chefs, Give Hands 🙌.
- **Links.**
  - Printed links say `staygrubby.com`, which stays valid when TestFlight is replaced by the App Store. The homepage CTA already points at the TestFlight URL in `Website/distribution.json`.
  - The flyer QR code encodes `https://staygrubby.com`.

## Deliverables (`export/`)

| File | Size | Use |
| --- | --- | --- |
| `feed-01-introducing` … `feed-06-the-pass` | 1080×1350 | Launch campaign: Introducing, How it works, Grub Rank, My Kitchen, Food Bible, The Pass. Post in order 01→06. |
| `story-01-beta-open`, `story-02-this-or-that` | 1080×1920 | Beta Stories. Add an Instagram **Link sticker** in the empty band under the ↓ arrow. Use either `https://staygrubby.com` or the TestFlight link. Type is kept out of the top 220 px and bottom 300 px overlay zones. |
| `flyer-beta-letter.png` / `.pdf` | US Letter (1632×2112 PNG, vector PDF) | Shareable or printable beta flyer with QR code. |
| `link-preview-1200x630.png` | 1200×630 | Social link preview for staygrubby.com. **Not yet wired into the website.** Adopting it is a separate, approved website change (`Website/media` `social-card` slot plus deploy). |
| `template-announcement-feed`, `template-announcement-story` | 1080×1350, 1080×1920 | Reusable "New in #stayGRUBBY" announcement templates (shown with placeholder text). |
| `review-*.jpg` | — | Review sheets only; never post these. |

## Editing and re-rendering

1. Edit copy in `campaign.json`.
   - Each design has `id`, `format` (`feed` / `story` / `flyer` / `link`), `theme` (`red` / `cream`), `layout`, text fields, an optional `screen` or `photo` slot, example `cards` and a card `zoom`.
2. Render:
   - Everything: `python3 Marketing/render.py`
   - One design (any id prefix): `python3 Marketing/render.py feed-03`
   - Requires Google Chrome on macOS; standard-library Python.
3. Rebuild the review sheets with `python3 Marketing/contact_sheet.py` (needs Pillow).
4. Rebuild the brand derivatives and QR code only if the official artwork changes:
   - `python3 Marketing/prepare_brand.py`
   - `swift Marketing/qr.swift https://staygrubby.com Marketing/brand/qr-staygrubby.png`

To announce a new feature, copy a `template-announcement-*` entry and give it a new `id`. Then:
- Replace the bracketed text.
- Remove `"template": true`.
- Supply that feature's screenshot as `media/announce-screen.jpg`, or set `cards` to an approved example.

Styles live in `kit.css`, which layers on top of `Website/site.css`. That way the cards, tokens and glyphs stay identical to the website. Intermediate HTML goes to `build/`, which is ignored.

## Media the owner needs to provide

Screenshots must be captured on a **safe demo account**, never a private library or debug fixture. They should be portrait iPhone captures (1179×2556 or 1290×2796). Photos must be owned or licensed food photography.

**Screenshots (shared with the website):** the Grub Rank, My Kitchen and The Pass screens are the same captures the website uses, so supplying a website slot fills both. See `Website/media/media.json` and `Website/prepare_media.py`.

| Slot | Where it appears | What is needed |
| --- | --- | --- |
| `hero-screen` | Story 02 (and the website hero) | A This-or-that comparison or Grub Rank. |
| `rank-screen` | Feed 03 | Grub Rank with Signature Dishes. |
| `kitchen-screen` | Feed 04 | My Kitchen or a Dish page showing every cook. |
| `bible-screen` | Feed 05 | Food Bible or a Recipe page. Add it in `Marketing/media/`. |
| `pass-screen` | Feed 06 | The Pass with a posted cook and Hands, from demo Sous Chefs only. |
| `announce-screen` | Announcement templates | The new feature, supplied per announcement. |

**Photos:**

| Slot | Where it appears | What is needed |
| --- | --- | --- |
| `photo-hero` | Feed 01 | Hero food photo, 1080×1350, with calm space in the lower third for type. Add it in `Marketing/media/`. |
| `photo-story` | Story 01 | Vertical food photo, 1080×1920. Add it in `Marketing/media/`. |
| `photo-cook`, `photo-rank`, `photo-remember`, `photo-share` | Feed 02 as a 2×2 photo grid, and the website's How It Works steps | 4:5 portraits. When all four exist, Feed 02 switches from the typographic list to the grid. |
