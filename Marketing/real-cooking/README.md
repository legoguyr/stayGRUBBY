# Real Cooking, Real Rankings — @grubwithguy campaign

**Status:** first full render on November 24, 2026, for owner review. Nothing is posted, nothing on the website changed and the app is untouched.

This campaign sits alongside the launch set and creative library in `Marketing/`; it doesn't replace them. It reuses the same design system: `kit.css`, the three surfaces and the official wordmark.

## Real data used

All data comes from a **read-only** snapshot of @grubwithguy's production account, saved in [data.json](data.json). Only SELECT queries were run, and nothing in production was modified.

**How the scores were produced**
- Scores are exactly what the app displays. They use ScoreCalibration v1 on each cook's stored strength and Liked / Fine reaction, shown to one decimal place.
- Check: Pasta alla Norma comes out at **8.8, #9 of 35**, matching the app's own share snapshot from Nov 23.

**Grub Rank, Top 20 of 35 ranked cooks (as of Nov 24)**
1. Lamb Chops · Herb Crust — 9.6
2. Braised Short Rib — 9.5
3. Honey-Chili Duck Breast · Honey chili glaze — 9.4
4. Butternut Squash Risotto — 9.3
5. French Onion Soup · Vita Nova — 9.1
6. Honey Glazed Duck — 9.1
7. Mushroom Risotto — 9.0
8. Chimmi Steak Sandwich — 9.0
9. Pasta alla Norma — 8.8
10. Creamy French Toast — 8.8
11. Shakshuka — 8.6
12. Pastrami Pita — 8.6
13. Chicken Marsala — 8.4
14. Lamb Chops · Double chop — 8.3
15. Chicken Parm — 8.3
16. Tandoori Chicken with Coconut Mint Chutney — 8.3
17. Miso Eggplant — 8.2
18. Kale Radiatori — 8.1
19. Pollo Martini — 8.1
20. Bolognese — 8.0

**This or That: real head-to-head picks**
- Lamb Chops (Herb Crust) beat Braised Short Rib.
- Braised Short Rib beat Honey-Chili Duck Breast **three times**.
- Butternut beat Mushroom (risotto vs risotto).
- Honey Glazed Duck beat Pasta alla Norma.

**Lamb Chops: two cooks of the same Dish**
- Cook 1, Herb Crust: #1, 9.6.
- Cook 2, Double chop: #14, 8.3.
- So far the earlier cook ranks higher. No Dish in the account improves over time yet, so **no design claims improvement**. The "progress" story is told truthfully instead:
  - each cook is ranked on its own;
  - rankings move (see Pastrami Pita).

**Rankings move.** Pastrami Pita was #13 of 35 (8.5) when shared on Nov 21, and is #12 (8.6) today.

**Food Bible.** Real content from four friends-visible Recipes, condensed but never invented:
- Pasta alla Norma
- Grubtastic French Toast with maple butter
- Miso Glazed Eggplant, at revision 10
- Tandoori Chicken with Coconut Mint Chutney

These two are in the snapshot but not on any design:
- Beef Bolognese
- Cucumber salad

These two are deliberately left out:
- **Butternut Squash Risotto:** the Recipe is private.
- **Kale Pasta:** it credits another person.

**The Pass.** Guy's own posts, with Hands and comment counts only; no one else's comment text is shown.
- Miso Eggplant: 🙌 4 · 💬 1, shared at 8.1.
- Tandoori Chicken: 🙌 2, posted with its Recipe attached.

**Never shown:** account IDs, private notes, private Recipes, other users' names or content, and Stars / Want to Cook / Run It Back.

Rankings change as Guy keeps cooking. **Re-snapshot before posting anything dated later.** The as-of date is printed on every real-data card.

## What I still need from you

1. **Your cook photos.** Your cook photos are only on your iPhone; their upload status is still "pending". The 17 shared-post photos are in a private bucket. I didn't use privileged keys or signed URLs to work around either.
   - Export each photo from the app or Photos and drop it into `Marketing/real-cooking/photos/` using the names below (jpg or png, any size; designs crop to fit).
   - Then run `python3 Marketing/render.py --campaign real-cooking`.

   | File | Cook |
   | --- | --- |
   | `lamb-chops-herb-crust.jpg` | #1 Lamb Chops · Herb Crust (must be the Herb Crust cook, not Double chop) |
   | `braised-short-rib.jpg` | #2 Braised Short Rib |
   | `honey-chili-duck.jpg` | #3 Honey-Chili Duck Breast |
   | `butternut-squash-risotto.jpg` | #4 |
   | `french-onion-soup.jpg` | #5 |
   | `honey-glazed-duck.jpg` | #6 |
   | `mushroom-risotto.jpg` | #7 |
   | `chimmi-steak-sandwich.jpg` | #8 |
   | `pasta-alla-norma.jpg` | #9 (also the Food Bible hero) |
   | `miso-eggplant.jpg` | #17 (Food Bible / The Pass) |
   | `tandoori-chicken.jpg` | #16 (The Pass, with Recipe) |

   These photos are needed for:
   - the 4 photo-score posts;
   - the This or That tiles;
   - the photo grids;
   - the photo-card designs;
   - all 4 Reels.

   Until a photo is added, its spot shows a striped "Photo · …" placeholder. **Don't post a design that still shows a placeholder.**

2. **Optional: real app screenshots** from your phone of Grub Rank, a This-or-that comparison, Food Bible / Paste Recipe, and The Pass. They can replace the data cards and fill the website slots too (`Website/media/media.json`).

3. **Confirm the public tone.** Several designs speak as "@grubwithguy" ("My Top 5", "What's your #1?"). Confirm you're happy for your handle and rankings to appear publicly in brand marketing.

## Deliverables (`export/`)

| Set | Files |
| --- | --- |
| 23 feed posts (1080×1350) | `rc-feed-01…23-*.png` |
| 13 Stories (1080×1920) | `rc-story-01…13-*.png` (02 needs a Poll sticker, 11 a Question sticker, the rest a Link sticker under the arrow) |
| 3 carousels | `carousels/rc-carousel-1-top-3-countdown` (6), `-2-food-bible` (5), `-3-this-or-that` (6) |
| 4 Reels (silent H.264, 11–13 s; add music in Instagram) | `reels/rc-reel-1-top-5-countdown.mp4`, `-2-this-or-that`, `-3-recipe-in-seconds`, `-4-cooking-is-a-conversation` |
| Contact sheets | `review-feed.jpg`, `review-stories.jpg`, `review-carousels.jpg`, `review-reels.jpg`, `review-instagram-grid.jpg` |

**Feature coverage**
- **Grub Rank:** Top 3, 5, 9, 10 and 11–20.
- **Signature Dishes:** feed 01–04.
- **This or That:** feed 05–07, Story 02–03, carousel 3, Reel 2.
- **My Kitchen, multiple cooks:** feed 11, Story 12.
- **Rankings evolving:** feed 12, Story 09.
- **Food Bible and Recipe creation:** feed 13–16, Stories 06–07, carousel 2, Reel 3.
- **Recipe sharing / Rank My Version:** feed 17, Story 08.
- **The Pass and community:** feed 18–19, Story 10, Reel 4.

## Suggested posting sequence (after photos are in)

| Week | Feed | Stories | Reel |
| --- | --- | --- | --- |
| 1 | rc-feed-22 (Not just recipes) → rc-carousel-1 (Top 3 countdown) → rc-feed-01 (#1 Lamb Chops) | rc-story-02 Poll, then rc-story-03 reveal the next day | rc-reel-2 This or That |
| 2 | rc-feed-14 (Better than a screenshot) → rc-carousel-2 (Food Bible) → rc-feed-13 (Remember it forever) | rc-story-06, rc-story-07 | rc-reel-3 Recipe in seconds |
| 3 | rc-feed-08 (Top 9) → rc-feed-06 (Lamb Chops won) → rc-feed-11 (Same Dish, two cooks) | rc-story-04, rc-story-11 Question | rc-reel-1 Top 5 countdown |
| 4 | rc-feed-17 (Make it yours) → rc-feed-18 (Shared with theirs) → rc-carousel-3 | rc-story-08, rc-story-10 | rc-reel-4 Conversation |

Fill the gaps from the general creative library (`Marketing/export/lib-*`) so the grid alternates red, cream and charcoal.

## Captions and hashtags

Hashtag set (rotate 5–8 per post; always lead with #stayGRUBBY):

> #stayGRUBBY #homecooking #cookathome #homechef #whatsfordinner #foodie #homemade #recipeoftheday #cookingathome #foodstagram #iphoneapp #testflight

Captions to use with each design:

- **rc-feed-01** — Signature Dish #1: Lamb Chops, Herb Crust. 9.6 on my Grub Rank, and it earned it one This or That at a time. What's your #1? Join the iPhone beta, link in bio. #stayGRUBBY
- **rc-feed-05 / rc-story-02** — Lamb Chops or Braised Short Rib? I had to pick. You tell me first. 👇
- **rc-feed-06** — Lamb Chops won. No stars, no sliders: two dishes, one tap, and the Grub Rank updates itself.
- **rc-feed-07** — Braised Short Rib vs Honey-Chili Duck. Short Rib won three times. Some rivalries are settled.
- **rc-feed-09 / rc-carousel-1** — 35 cooks ranked. Here's the Top 10. Your next signature dish starts here.
- **rc-feed-11** — Same Dish, two cooks: Herb Crust is #1, Double chop is #14. Every cook gets its own rank, so you know which version to make again.
- **rc-feed-12** — Rankings move. Pastrami Pita went from #13 to #12 as more cooks got ranked. Cook more, and your Grub Rank gets sharper.
- **rc-feed-13** — Cook it once. Remember it forever. My Pasta alla Norma lives in Food Bible: 10 ingredients, 9 steps, #9 on my Grub Rank.
- **rc-feed-14 / rc-carousel-2 / rc-reel-3** — Your recipe deserves better than a screenshot. Paste it in, review the draft, save it to Food Bible.
- **rc-feed-16** — From kitchen notes to Food Bible. My Miso Glazed Eggplant is on revision 10, and Recipe History keeps every one.
- **rc-feed-17** — Your friend made it. Now make it yours. Open a Sous Chef's Recipe, cook it and rank your version.
- **rc-feed-18** — Made in my kitchen. Shared with theirs. Tandoori Chicken went to The Pass with the Recipe attached.
- **rc-feed-19** — What's cooking in your circle? Post a cook to The Pass; your Sous Chefs Give Hands 🙌 and comment.
- **rc-feed-21** — Every dish has a story. 35 cooks, 35 stories, all ranked.
- **rc-feed-22** — Not just recipes. Real cooking. Everything in this campaign came out of one real kitchen.

**Caption rules**
- Never imply a feature that isn't live. There are no followers; it's mutual Sous Chefs.
- Say "beta" until the App Store launch.
- Keep scores and ranks matched to the as-of date shown on the design.

## Rebuilding

```bash
python3 Marketing/render.py --campaign real-cooking            # everything, about 6 minutes
python3 Marketing/render.py --campaign real-cooking rc-feed-01 # one design
python3 Marketing/contact_sheet.py --campaign real-cooking
```

**Editing**
- Copy and layouts live in `designs.json`.
- Data cards are built only from `data.json`, by `Marketing/real_cards.py`.

**Refreshing the data.** Re-run the read-only queries and update `data.json` before reusing this campaign later. They are the same queries used on Nov 24: displayed score from strength and reaction, ordered by strength.
