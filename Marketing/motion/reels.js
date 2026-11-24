// The eight animated Reels. Real Cooking Reels (rc-*) use only @grubwithguy's snapshot (window.ASSETS.data) and photos;
// library Reels (reel-*) use the captioned illustrative cards. Edit scene order, copy and timing here, then run
// `node Marketing/motion/capture.mjs [reel-id]`.
'use strict';
const D = A.data, TOP = r => D.top20.find(x => x.rank === r), N = D.ranked_cooks, H = D.handle;
const ILLUSTRATIVE = 'Illustrative preview';

const REELS = {
  'rc-reel-1-top-5-countdown': () => [
    kinetic({ lines: ['My Top 5.'], sub: `${N} cooks ranked. One #1.`, theme: 'red', size: 210, dur: 1.5, tag: H }),
    photoScore({ row: TOP(5), theme: 'dark', total: N, dur: 1.9, tag: H }),
    photoScore({ row: TOP(4), theme: 'dark', total: N, dur: 1.9, tag: H }),
    photoScore({ row: TOP(3), theme: 'dark', total: N, dur: 1.9, tag: H }),
    photoScore({ row: TOP(2), theme: 'dark', total: N, dur: 1.9, tag: H }),
    photoScore({ row: TOP(1), theme: 'red', total: N, dur: 2.7, big: true, tag: H, caption: `Signature Dish #1 · ${A.caption_real}` }),
    rankStack({ card: 'real-top:1-5', theme: 'red', headline: 'The Top 5.', dur: 2.4, highlight: [1] }),
    endCard({ theme: 'dark', headline: "What's your #1?" }),
  ],

  'rc-reel-2-this-or-that': () => [
    kinetic({ lines: ['Lamb Chops', 'or *Short Rib?*'], theme: 'dark', size: 150, dur: 1.4, tag: H }),
    versus({ a: TOP(1), b: TOP(2), winner: 'a', theme: 'cream', headline: 'Pick one.', dur: 3.4, tapAt: 1.6, tag: H }),
    photoScore({ row: TOP(1), theme: 'red', total: N, dur: 2.3, big: true, tag: H, caption: `Won the head-to-head · ${A.caption_real}` }),
    rankStack({ card: 'real-top:1-3', theme: 'cream', headline: 'Picks become a Grub Rank.', dur: 2.5, highlight: [1, 2], zoom: 2.5 }),
    endCard({ theme: 'dark', headline: 'Made it? *Rank it.*' }),
  ],

  'rc-reel-3-recipe-in-seconds': () => [
    kinetic({ lines: ['Your recipe', 'deserves better', 'than a *screenshot.*'], theme: 'red', size: 118, dur: 1.9 }),
    recipeFlow({ recipe: D.recipes['Pasta alla Norma'], name: 'Pasta alla Norma', theme: 'cream', dur: 6.4,
      caption: `Animated walkthrough of Paste Recipe · real Recipe from ${H}` }),
    cardScene({ card: 'real-share-recipe:Pasta alla Norma', theme: 'dark', headline: 'Now your Sous Chefs can make it.', eyebrow: 'Rank My Version', dur: 2.3, zoom: 2.3 }),
    endCard({ theme: 'red', headline: 'Cook it once.\nRemember it forever.' }),
  ],

  'rc-reel-4-cooking-is-a-conversation': () => [
    kinetic({ lines: ['Cooking is a', '*conversation.*'], theme: 'dark', size: 150, dur: 1.4, tag: H }),
    cardScene({ card: 'real-post:Honey Glazed Duck', theme: 'dark', photo: TOP(6).photo, headline: 'Post a cook.', eyebrow: 'The Pass', glyph: 'TabPassFill',
      dur: 2.3, zoom: 2.6, tag: H }),
    passFeed({ posts: D.posts.filter(p => { const r = D.top20.find(x => x.dish === p.dish); return r && A.photos[r.photo]; }), theme: 'cream', headline: "What's cooking in *your circle?*",
      caption: `Real posts and Hands · ${A.caption_real}`, dur: 3.8, scroll: 1500 }),
    cardScene({ card: 'real-moved', theme: 'dark', headline: 'Watch it *move.*', eyebrow: 'Grub Rank', glyph: 'TabRankFill', dur: 2.3, zoom: 2.5 }),
    endCard({ theme: 'red', headline: 'Made in your kitchen.\nShared with theirs.' }),
  ],

  'reel-1-cook-rank-share': () => [
    kinetic({ lines: ['Cook it.', '*Rank it.*', 'Share it.'], theme: 'red', size: 200, dur: 1.7, stagger: .14 }),
    cardScene({ card: 'versus', theme: 'cream', headline: 'Rank it.', eyebrow: 'This or That', glyph: 'TabRankFill', dur: 2.1, zoom: 2.5 }),
    rankStack({ card: 'rank', theme: 'red', headline: 'Watch it build.', dur: 2.2, highlight: [1], zoom: 2.5 }),
    cardScene({ card: 'pass-post', theme: 'dark', headline: 'Share it.', eyebrow: 'The Pass', glyph: 'TabPassFill', dur: 2.1, zoom: 2.6, from: 'right' }),
    endCard({ theme: 'red', headline: 'Cook it. Rank it. Share it.' }),
  ],

  'reel-2-this-or-that': () => [
    kinetic({ lines: ['Two dishes.', '*One winner.*'], theme: 'cream', size: 170, dur: 1.4 }),
    versus({ a: { dish: 'Mushroom Risotto' }, b: { dish: 'Pan-Seared Duck Breast' }, winner: 'a', theme: 'dark', headline: 'Which was better?',
      dur: 3.2, tapAt: 1.5, photos: false, showScores: false, tag: ILLUSTRATIVE }),
    rankStack({ card: 'rank', theme: 'red', headline: 'Your Grub Rank builds itself.', dur: 2.4, highlight: [2], zoom: 2.5 }),
    endCard({ theme: 'dark', headline: 'Made it? *Rank it.*' }),
  ],

  'reel-3-make-it-yours': () => [
    kinetic({ lines: ['Your friend', 'made it.'], theme: 'dark', size: 180, dur: 1.4 }),
    cardScene({ card: 'pass-post', theme: 'red', headline: 'Spot it.', eyebrow: 'The Pass', glyph: 'TabPassFill', dur: 2.0, zoom: 2.6 }),
    cardScene({ card: 'send-recipe', theme: 'cream', headline: 'Get the Recipe.', eyebrow: 'Food Bible', dur: 2.1, zoom: 2.3, from: 'right' }),
    cardScene({ card: 'rank-my-version', theme: 'dark', headline: 'Make it *yours.*', eyebrow: 'Rank My Version', dur: 2.3, zoom: 2.3 }),
    endCard({ theme: 'red', headline: 'Now make it yours.' }),
  ],

  'reel-4-every-cook-counts': () => [
    kinetic({ lines: ['Every cook', '*counts.*'], theme: 'cream', size: 190, dur: 1.4 }),
    scoreClimb({ title: 'Sourdough Loaf · 4 cooks', theme: 'cream', dur: 4.6, caption: ILLUSTRATIVE,
      steps: [{ name: 'First loaf', label: 'Cook 1', value: 6.2 }, { name: 'Longer proof', label: 'Cook 2', value: 7.4 },
              { name: 'Higher hydration', label: 'Cook 3', value: 8.3 }, { name: 'Cold overnight proof', label: 'Cook 4', value: 9.1 }] }),
    cardScene({ card: 'progress', theme: 'dark', headline: 'Every cook, remembered.', eyebrow: 'My Kitchen', glyph: 'TabKitchenFill', dur: 2.2, zoom: 2.3 }),
    endCard({ theme: 'dark', headline: 'Your next signature dish starts here.' }),
  ],
};
