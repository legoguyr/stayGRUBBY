// #stayGRUBBY motion engine. Every frame is a pure function of time: window.seek(t) poses the whole Reel for that
// instant, so capture.mjs can step frame by frame (30 fps) with no dropped or timing-dependent frames.
// A Reel is a list of scenes; each scene builds DOM once and exposes update(localTime). Scenes overlap by the
// transition length, and a brand "swipe" panel sweeps across each cut.
'use strict';

const E = {
  lin: t => t,
  out: t => 1 - Math.pow(1 - t, 3),
  out5: t => 1 - Math.pow(1 - t, 5),
  inOut: t => (t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  in: t => t * t * t,
  back: t => { const c1 = 1.9, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); },
  elastic: t => (t === 0 || t === 1 ? t : Math.pow(2, -10 * t) * Math.sin((t * 10 - .75) * (2 * Math.PI) / 3) + 1),
};
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const prog = (t, t0, t1, ease = E.out) => ease(clamp((t - t0) / (t1 - t0)));
const mix = (a, b, k) => a + (b - a) * k;
const A = window.ASSETS;

function el(tag, cls, html) {
  const node = document.createElement(tag);
  if (cls) node.className = cls;
  if (html !== undefined) node.innerHTML = html;
  return node;
}
function style(node, s) { Object.assign(node.style, s); }
const T = (x = 0, y = 0, s = 1, r = 0) => `translate3d(${x}px,${y}px,0) scale(${s}) rotate(${r}deg)`;

function wordmark(theme) { return `<img class="m-wordmark" src="${A.wordmark[theme === 'red' ? 'white' : 'red']}" alt="#stayGRUBBY">`; }
function photoLayer(slot, label) {
  const url = A.photos[slot];
  return url ? `<div class="m-photo" style="background-image:url('${url}')"></div>`
             : `<div class="m-photo empty"><p>Photo · ${label || slot}</p><small>add real-cooking/photos/${slot}.jpg</small></div>`;
}
function rich(text) {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/\*(.+?)\*/g, '<em>$1</em>');
}

// ---- Scene builders -------------------------------------------------------------------------------------------
// Each returns {node, dur, update(lt)}; lt is seconds since the scene's start (may be negative / beyond dur).

/** Kinetic type: lines rise out of masks one after another, punch, then lift away. */
function kinetic({ lines, theme = 'red', dur = 1.6, size = 190, align = 'left', sub, stagger = .09, tag }) {
  const node = el('section', `m-scene theme-${theme} m-kinetic ${align}`);
  node.innerHTML = `<header class="m-top">${wordmark(theme)}<span>${tag || ''}</span></header>` +
    `<h1 style="font-size:${size}px">${lines.map(l => `<span class="m-mask"><span>${rich(l)}</span></span>`).join('')}</h1>` +
    (sub ? `<p class="m-sub">${rich(sub)}</p>` : '');
  const spans = [...node.querySelectorAll('.m-mask > span')], subEl = node.querySelector('.m-sub');
  return { node, dur, update(lt) {
    spans.forEach((s, i) => {
      const k = prog(lt, i * stagger, i * stagger + .45, E.out5);
      const out = prog(lt, dur - .32, dur, E.in);
      s.style.transform = `translateY(${mix(115, 0, k) - out * 115}%)`;
    });
    if (subEl) { const k = prog(lt, .35, .8); subEl.style.opacity = k * (1 - prog(lt, dur - .3, dur)); subEl.style.transform = T(0, mix(30, 0, k)); }
  } };
}

/** Ranked cook photo: Ken Burns + parallax, rank badge drop, name rise, score counting up to the real value. */
function photoScore({ row, theme = 'dark', dur = 2.2, total, caption, big = false, tag }) {
  const node = el('section', `m-scene theme-${theme} m-photoscore${big ? ' big' : ''}`);
  node.innerHTML = photoLayer(row.photo, `#${row.rank} ${row.dish}`) +
    `<div class="m-shade"></div><header class="m-top">${wordmark(theme)}<span>${tag || ''}</span></header>` +
    `<div class="m-ps"><p class="m-rank">#${row.rank}<small>of ${total}</small></p>` +
    `<h1><span class="m-mask"><span>${rich(row.dish)}</span></span></h1>` +
    (row.cook ? `<p class="m-cook">${rich(row.cook)}</p>` : '') +
    `<p class="m-score">0.0</p>${caption ? `<p class="m-cap">${caption}</p>` : ''}</div>`;
  const photo = node.querySelector('.m-photo'), rank = node.querySelector('.m-rank'), name = node.querySelector('.m-mask > span'),
    cook = node.querySelector('.m-cook'), score = node.querySelector('.m-score'), cap = node.querySelector('.m-cap');
  const target = parseFloat(row.score);
  return { node, dur, update(lt) {
    const z = mix(1.18, 1.0, prog(lt, 0, dur, E.out));
    photo.style.transform = T(mix(-40, 20, prog(lt, 0, dur, E.inOut)), mix(30, -10, prog(lt, 0, dur, E.lin)), z);
    const r = prog(lt, .15, .55, E.back); rank.style.transform = T(0, mix(-120, 0, r), mix(.6, 1, r)); rank.style.opacity = clamp(r * 2);
    name.style.transform = `translateY(${mix(115, 0, prog(lt, .25, .7, E.out5))}%)`;
    if (cook) cook.style.opacity = prog(lt, .5, .9);
    const c = prog(lt, .45, 1.25, E.out5);
    score.textContent = (Math.round(target * c * 10) / 10).toFixed(1);
    const pop = prog(lt, 1.2, 1.5, E.back);
    score.style.transform = T(0, 0, lt < 1.2 ? mix(.7, 1, c) : mix(1.25, 1, pop));
    if (cap) cap.style.opacity = prog(lt, .9, 1.3);
    node.style.opacity = 1;
  } };
}

/** This or That split screen: halves slide in, VS spins, simulated tap on the real winner, loser dims. */
function versus({ a, b, winner = 'a', theme = 'cream', dur = 3.2, headline = 'This or that?', showScores = true, tapAt = 1.5, photos = true, tag }) {
  const node = el('section', `m-scene theme-${theme} m-versus`);
  const half = (row, side) => `<div class="m-half ${side}">${photos ? photoLayer(row.photo, row.dish) : '<div class="m-photo flat"></div>'}` +
    `<p class="m-label"><span>${rich(row.dish)}</span>${showScores && row.score ? `<b class="m-chip">${row.score}</b>` : ''}<i class="m-check">✓</i></p></div>`;
  node.innerHTML = `<header class="m-top">${wordmark(theme)}<span>${tag || ''}</span></header>` +
    `<h2 class="m-vs-title"><span class="m-mask"><span>${rich(headline)}</span></span></h2>` +
    `<div class="m-split">${half(a, 'a')}${half(b, 'b')}<div class="m-vs">or</div><div class="m-tap"></div></div>`;
  const ha = node.querySelector('.m-half.a'), hb = node.querySelector('.m-half.b'), vs = node.querySelector('.m-vs'), tap = node.querySelector('.m-tap'),
    title = node.querySelector('.m-vs-title .m-mask > span');
  const win = winner === 'a' ? ha : hb, lose = winner === 'a' ? hb : ha;
  const chips = node.querySelectorAll('.m-chip'), check = win.querySelector('.m-check');
  return { node, dur, update(lt) {
    title.style.transform = `translateY(${mix(115, 0, prog(lt, 0, .4, E.out5))}%)`;
    const ia = prog(lt, .05, .55, E.out5), ib = prog(lt, .15, .65, E.out5);
    ha.style.transform = T(mix(-1100, 0, ia), 0); hb.style.transform = T(mix(1100, 0, ib), 0);
    [ha, hb].forEach(h => { h.querySelector('.m-photo').style.transform = T(0, 0, mix(1.25, 1.05, prog(lt, 0, dur, E.out))); });
    const v = prog(lt, .55, .9, E.back); vs.style.transform = `translate(-50%,-50%) scale(${v}) rotate(${mix(-180, 0, v)}deg)`;
    // Simulated tap: finger ripple on the winner, then the result.
    const tp = prog(lt, tapAt, tapAt + .45, E.out);
    const box = winner === 'a' ? { top: '27%' } : { top: '73%' };
    style(tap, { top: box.top, opacity: lt >= tapAt ? 1 - tp : 0, transform: `translate(-50%,-50%) scale(${mix(.3, 2.2, tp)})` });
    const res = prog(lt, tapAt + .1, tapAt + .5, E.back);
    win.style.transform += ` scale(${mix(1, 1.03, res)})`;
    win.classList.toggle('won', lt >= tapAt + .1);
    lose.style.filter = `grayscale(${res * .9}) brightness(${mix(1, .55, res)})`;
    lose.style.transform += ` scale(${mix(1, .94, res)})`;
    check.style.transform = `scale(${res})`;
    chips.forEach(c => { c.style.opacity = prog(lt, tapAt + .35, tapAt + .7); });
  } };
}

/** Card scene: an existing StayGrubby card flies in with parallax tilt; optional headline and row stagger. */
function cardScene({ card, theme = 'cream', dur = 2.4, headline, eyebrow, glyph, zoom = 2.1, caption, photo, rows = true, tag, from = 'bottom' }) {
  const node = el('section', `m-scene theme-${theme} m-cardscene${photo ? ' with-photo' : ''}`);
  node.innerHTML = (photo ? photoLayer(photo) + '<div class="m-shade"></div>' : '') +
    `<header class="m-top">${wordmark(theme)}<span>${tag || ''}</span></header>` +
    (headline ? `<div class="m-copy">${eyebrow ? `<p class="m-eyebrow">${glyph ? A.glyphs[glyph] : ''}${eyebrow}</p>` : ''}` +
      `<h2><span class="m-mask"><span>${rich(headline)}</span></span></h2></div>` : '') +
    `<div class="m-cardwrap"><div class="m-card" style="zoom:${zoom}">${A.cards[card]}</div>` +
    `<p class="m-cap">${caption || (card.startsWith('real-') ? A.caption_real : 'Illustrative preview')}</p></div>`;
  const wrap = node.querySelector('.m-card'), h = node.querySelector('.m-copy .m-mask > span'), eb = node.querySelector('.m-eyebrow'),
    cap = node.querySelector('.m-cap'), ph = node.querySelector('.m-photo');
  const items = rows ? [...node.querySelectorAll('.m-card li, .m-card .actions, .m-card .action-button, .m-card .moved, .m-card .recipe-chip')] : [];
  return { node, dur, update(lt) {
    if (h) h.style.transform = `translateY(${mix(115, 0, prog(lt, 0, .45, E.out5))}%)`;
    if (eb) eb.style.opacity = prog(lt, 0, .3);
    const k = prog(lt, .1, .75, E.out5);
    const dy = from === 'bottom' ? mix(900, 0, k) : 0, dx = from === 'right' ? mix(1000, 0, k) : 0;
    wrap.style.transform = `${T(dx / zoom, dy / zoom, 1, mix(8, -2, k) + Math.sin(lt * 1.6) * .6)}`;
    items.forEach((it, i) => { const q = prog(lt, .45 + i * .07, .8 + i * .07, E.out); it.style.opacity = q; it.style.transform = T(mix(40, 0, q), 0); });
    if (cap) cap.style.opacity = prog(lt, .8, 1.1);
    if (ph) ph.style.transform = T(0, mix(40, -20, prog(lt, 0, dur, E.lin)), mix(1.15, 1.02, prog(lt, 0, dur, E.out)));
  } };
}

/** End card: wordmark slams in, CTA pill pulses. */
function endCard({ theme = 'red', headline, sub = 'Join the iPhone beta · staygrubby.com', dur = 2.4 }) {
  const node = el('section', `m-scene theme-${theme} m-end`);
  node.innerHTML = `<div class="m-burst"></div>${wordmark(theme).replace('m-wordmark', 'm-wordmark big')}` +
    `<h2>${headline.split('\n').map(l => `<span class="m-mask"><span>${rich(l)}</span></span>`).join('')}</h2><p class="m-pill">${sub}</p>`;
  const wm = node.querySelector('.m-wordmark'), lines = [...node.querySelectorAll('.m-mask > span')], pill = node.querySelector('.m-pill'),
    burst = node.querySelector('.m-burst');
  return { node, dur, update(lt) {
    const w = prog(lt, 0, .5, E.back); wm.style.transform = T(0, 0, mix(2.2, 1, w), mix(-8, 0, w)); wm.style.opacity = clamp(w * 3);
    burst.style.transform = `translate(-50%,-50%) scale(${mix(.2, 1.6, prog(lt, .05, .9, E.out))}) rotate(${lt * 12}deg)`;
    burst.style.opacity = 1 - prog(lt, .5, 1.2);
    lines.forEach((s, i) => { s.style.transform = `translateY(${mix(115, 0, prog(lt, .35 + i * .1, .8 + i * .1, E.out5))}%)`; });
    const p = prog(lt, .8, 1.2, E.back); pill.style.transform = T(0, 0, mix(.6, 1, p) + Math.sin(Math.max(0, lt - 1.2) * 6) * .025);
    pill.style.opacity = clamp(p * 2);
  } };
}

/** Kinetic score climb across cooks of one Dish (illustrative library Reel). */
function scoreClimb({ steps, theme = 'cream', dur = 4.2, title, caption }) {
  const node = el('section', `m-scene theme-${theme} m-climb`);
  node.innerHTML = `<header class="m-top">${wordmark(theme)}<span></span></header><p class="m-eyebrow">${title}</p>` +
    `<p class="m-bignum">0.0</p><p class="m-stepname"></p><div class="m-bars">${steps.map(s => `<div><i></i><span>${s.label}</span></div>`).join('')}</div>` +
    `<p class="m-cap">${caption}</p>`;
  const num = node.querySelector('.m-bignum'), name = node.querySelector('.m-stepname'), bars = [...node.querySelectorAll('.m-bars > div')];
  const seg = (dur - .6) / steps.length;
  return { node, dur, update(lt) {
    let shown = 0, label = '';
    steps.forEach((s, i) => {
      const k = prog(lt, .3 + i * seg, .3 + i * seg + seg * .7, E.out5);
      bars[i].querySelector('i').style.width = `${k * s.value * 10}%`;
      bars[i].style.opacity = lt >= .3 + i * seg - .1 ? 1 : .25;
      if (lt >= .3 + i * seg) { shown = mix(i ? steps[i - 1].value : 0, s.value, k); label = s.name; }
    });
    num.textContent = shown.toFixed(1);
    name.textContent = label;
    num.style.color = shown >= 9 ? 'var(--red)' : '';
  } };
}

/** Recipe creation, depicted step by step with the real Recipe's own content (Paste Recipe → review → Save). */
function recipeFlow({ recipe, name, theme = 'cream', dur = 6.4, caption }) {
  const node = el('section', `m-scene theme-${theme} m-flow`);
  const lines = recipe.ingredients;
  node.innerHTML = `<header class="m-top">${wordmark(theme)}<span>Food Bible</span></header>` +
    `<div class="m-device"><div class="m-screen">` +
    `<div class="m-step s1"><p class="m-screen-title">Add a Recipe</p><p class="m-btn paste">Paste Recipe</p><p class="m-btn ghost">Add Manually</p></div>` +
    `<div class="m-step s2"><p class="m-screen-title">Paste Recipe</p><div class="m-paste"><p class="m-pasted">${[name, ...lines].join('<br>')}</p></div><p class="m-btn go">Continue</p></div>` +
    `<div class="m-step s3"><p class="m-screen-title">Review</p><div class="m-draft"><p class="m-draft-title">${name}</p>` +
    `<p class="m-draft-meta">${[recipe.yield, recipe.time, recipe.cuisine].filter(Boolean).join(' · ')}</p>` +
    `<ul>${lines.map(l => `<li>${l}</li>`).join('')}</ul><p class="m-draft-meta">${recipe.ingredients_total} ingredients · ${recipe.steps} steps</p></div>` +
    `<p class="m-btn save">Save</p></div>` +
    `<div class="m-step s4"><p class="m-screen-title">Food Bible</p><ul class="m-bible">` +
    Object.keys(A.data.recipes).map(t => `<li class="${t === name ? 'new' : ''}"><b>${t}</b><small>${A.data.recipes[t].cuisine || ''}</small></li>`).join('') +
    `</ul></div></div><div class="m-tap"></div></div><p class="m-cap">${caption}</p>`;
  const steps = [...node.querySelectorAll('.m-step')], tap = node.querySelector('.m-tap'), pasted = node.querySelector('.m-pasted'),
    draftItems = [...node.querySelectorAll('.m-draft > *, .m-draft li')], newRow = node.querySelector('.m-bible .new'),
    device = node.querySelector('.m-device');
  // Timeline: s1 0–1.2 (tap Paste at .8) · s2 1.2–2.8 (paste fills, tap Continue at 2.4) · s3 2.8–4.8 (fields fill, tap Save at 4.4) · s4 4.8+
  const at = [[0, 1.2], [1.2, 2.8], [2.8, 4.8], [4.8, 99]];
  const taps = [[.8, '58%', '30%'], [2.4, '50%', '84%'], [4.4, '50%', '88%']];
  return { node, dur, update(lt) {
    device.style.transform = T(0, mix(1400, 0, prog(lt, 0, .5, E.out5)), 1, mix(6, 0, prog(lt, 0, .6)));
    steps.forEach((s, i) => {
      const [a, b] = at[i];
      const vin = prog(lt, a, a + .3, E.out5), vout = prog(lt, b - .05, b + .25, E.inOut);
      s.style.transform = T(mix(i ? 600 : 0, 0, vin) - vout * 600, 0);
      s.style.opacity = (i ? vin : 1) * (1 - vout);
    });
    pasted.style.clipPath = `inset(0 0 ${100 - prog(lt, 1.5, 2.2, E.lin) * 100}% 0)`;
    draftItems.forEach((d, i) => { const q = prog(lt, 3.0 + i * .08, 3.3 + i * .08); d.style.opacity = q; d.style.transform = T(mix(30, 0, q), 0); });
    if (newRow) { const q = prog(lt, 5.0, 5.5, E.back); newRow.style.transform = T(0, 0, mix(.85, 1, q)); newRow.style.background = lt > 5 ? '#fde3e2' : ''; }
    let tapState = null;
    taps.forEach(([t, x, y]) => { if (lt >= t && lt < t + .45) tapState = [prog(lt, t, t + .45), x, y]; });
    if (tapState) style(tap, { opacity: 1 - tapState[0], left: tapState[1], top: tapState[2], transform: `translate(-50%,-50%) scale(${mix(.3, 2, tapState[0])})` });
    else tap.style.opacity = 0;
  } };
}

/** The Pass feed: real posts scroll with parallax while Hands tick up to their real totals. */
function passFeed({ posts, theme = 'cream', dur = 3.6, headline, caption, scroll = 900 }) {
  const node = el('section', `m-scene theme-${theme} m-feed`);
  node.innerHTML = `<header class="m-top">${wordmark(theme)}<span>The Pass</span></header>` +
    `<h2><span class="m-mask"><span>${rich(headline)}</span></span></h2><div class="m-feedwin"><div class="m-feedlist">` +
    posts.map(p => {
      const row = A.data.top20.find(r => r.dish === p.dish || r.dish.startsWith(p.dish));
      return `<article class="m-post">${row ? photoLayer(row.photo, p.dish) : '<div class="m-photo flat"></div>'}` +
        `<div class="m-postbar"><p class="byline"><span class="avatar">G</span>${A.data.handle}</p><p class="m-postdish">${p.dish}<b class="m-chip">${p.score_at_sharing}</b></p>` +
        `<p class="actions"><span class="hands" data-n="${p.hands}">🙌 0</span>${p.comments ? `<span>💬 ${p.comments}</span>` : ''}${p.recipe ? '<span class="recipe-link">Recipe</span>' : ''}</p></div></article>`;
    }).join('') + `</div></div><p class="m-cap">${caption}</p>`;
  const list = node.querySelector('.m-feedlist'), h = node.querySelector('h2 .m-mask > span'), hands = [...node.querySelectorAll('.hands')],
    photos = [...node.querySelectorAll('.m-post .m-photo')];
  return { node, dur, update(lt) {
    h.style.transform = `translateY(${mix(115, 0, prog(lt, 0, .45, E.out5))}%)`;
    const y = -scroll * prog(lt, .6, dur - .2, E.inOut);
    list.style.transform = T(0, mix(500, 0, prog(lt, 0, .6, E.out5)) + y);
    photos.forEach((p, i) => { p.style.transform = T(0, y * -.12 + i * 6, 1.12); });
    hands.forEach((s, i) => { const n = +s.dataset.n; s.textContent = `🙌 ${Math.round(n * prog(lt, .5 + i * .35, 1.2 + i * .35, E.out))}`; });
  } };
}

/** Animated ranking list: rows slide in, the highlighted rows glow, optional connector for a real head-to-head. */
function rankStack({ card = 'real-top:1-5', theme = 'red', dur = 2.6, headline, eyebrow = 'Grub Rank', zoom = 2.3, highlight = [] }) {
  const s = cardScene({ card, theme, dur, headline, eyebrow, glyph: 'TabRankFill', zoom });
  const rows = [...s.node.querySelectorAll('.m-card li')];
  const base = s.update;
  s.update = lt => {
    base(lt);
    rows.forEach((r, i) => {
      const q = prog(lt, .35 + i * .12, .75 + i * .12, E.back);
      r.style.transform = T(0, mix(60, 0, q)); r.style.opacity = clamp(q * 1.5);
      const hi = highlight.includes(i + 1) && lt > 1.4;
      r.style.background = hi ? `rgba(241,6,7,${.08 + .06 * Math.sin(lt * 8)})` : '';
      r.style.borderRadius = '10px';
    });
  };
  return s;
}

// ---- Timeline -------------------------------------------------------------------------------------------------
const OVERLAP = .3;
function buildReel(scenes) {
  const stage = document.getElementById('stage');
  let t = 0;
  const placed = scenes.map((s, i) => { const start = t; t += s.dur - (i < scenes.length - 1 ? OVERLAP : 0); stage.appendChild(s.node); return { s, start }; });
  const wipe = el('div', 'm-wipe'); stage.appendChild(wipe);
  const total = t;
  window.REEL_DURATION = total;
  window.seek = time => {
    placed.forEach(({ s, start }, i) => {
      const lt = time - start, end = start + s.dur;
      const visible = time >= start - .001 && time <= end;
      s.node.style.display = visible ? '' : 'none';
      s.node.style.zIndex = i + 1;
      if (visible) s.update(lt);
    });
    // Brand swipe across each cut: a red/charcoal panel sweeps through during the overlap.
    let w = null;
    placed.forEach(({ s, start }, i) => { if (i && time >= start - .05 && time <= start + OVERLAP + .05) w = (time - start + .05) / (OVERLAP + .1); });
    if (w !== null) { wipe.style.display = ''; wipe.style.transform = `translateX(${mix(-110, 110, E.inOut(clamp(w)))}%) skewX(-12deg)`; }
    else wipe.style.display = 'none';
  };
  window.seek(0);
}
