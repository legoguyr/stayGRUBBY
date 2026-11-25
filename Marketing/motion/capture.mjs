// Frame-exact Reel capture: headless Chrome over the DevTools Protocol calls window.seek(t) for every frame at 30 fps
// and screenshots the 1080x1920 stage; frames.swift encodes the sequence to H.264 MP4. No network, no npm packages.
//   python3 Marketing/motion/export_cards.py && node Marketing/motion/capture.mjs            # all Reels
//   node Marketing/motion/capture.mjs rc-reel-2-this-or-that                                 # one Reel
import { spawn, execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const KIT = dirname(HERE);
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const FPS = 30;
const OUT = {  // Real Cooking Reels export beside that campaign; library Reels beside the library.
  rc: join(KIT, 'real-cooking/export/reels'),
  reel: join(KIT, 'export/reels'),
};
const REEL_IDS = ['rc-reel-1-top-5-countdown', 'rc-reel-2-this-or-that', 'rc-reel-3-recipe-in-seconds', 'rc-reel-4-cooking-is-a-conversation',
  'reel-1-cook-rank-share', 'reel-2-this-or-that', 'reel-3-make-it-yours', 'reel-4-every-cook-counts'];

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function launch() {
  const profile = mkdtempSync(join(tmpdir(), 'sg-motion-'));
  const proc = spawn(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files', '--remote-debugging-port=0',
    `--user-data-dir=${profile}`, '--window-size=1080,1920', '--force-device-scale-factor=1', 'about:blank'], { stdio: 'ignore' });
  let port;
  for (let i = 0; i < 100 && !port; i++) {
    await sleep(100);
    if (existsSync(join(profile, 'DevToolsActivePort'))) port = readFileSync(join(profile, 'DevToolsActivePort'), 'utf8').split('\n')[0];
  }
  if (!port) throw new Error('Chrome did not start');
  const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  const page = targets.find(t => t.type === 'page');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
  let id = 0; const pending = new Map();
  ws.onmessage = ev => { const m = JSON.parse(ev.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } };
  const send = (method, params = {}) => new Promise((res, rej) => {
    const mid = ++id; pending.set(mid, m => (m.error ? rej(new Error(`${method}: ${m.error.message}`)) : res(m.result)));
    ws.send(JSON.stringify({ id: mid, method, params }));
    setTimeout(() => { if (pending.has(mid)) { pending.delete(mid); rej(new Error(`${method} timed out`)); } }, 30000);
  });
  const close = async () => {
    try { ws.close(); } catch {}
    proc.kill('SIGKILL');
    await new Promise(r => (proc.exitCode !== null || proc.signalCode ? r() : proc.once('exit', r)));
    for (let i = 0; i < 5; i++) { try { rmSync(profile, { recursive: true, force: true }); break; } catch { await sleep(200); } }
  };
  return { send, close };
}

async function capture(chrome, reel) {
  const { send } = chrome;
  const dest = OUT[reel.startsWith('rc-') ? 'rc' : 'reel'];
  const frames = join(dest, `${reel}-frames`);
  rmSync(frames, { recursive: true, force: true }); mkdirSync(frames, { recursive: true });
  await send('Page.enable'); await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 1080, height: 1920, deviceScaleFactor: 1, mobile: false });
  await send('Page.navigate', { url: `${pathToFileURL(join(HERE, 'reel.html')).href}?reel=${reel}` });
  const evalJS = async expr => (await send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true })).result.value;
  for (let i = 0; i < 100 && !(await evalJS('typeof window.REEL_DURATION === "number"')); i++) await sleep(100);
  await evalJS(`Promise.all([document.fonts.ready, ...[...document.querySelectorAll('img')].map(i => i.decode().catch(() => {})),
    ...[...document.querySelectorAll('.m-photo')].map(d => { const u = (getComputedStyle(d).backgroundImage.match(/url\\("?(.*?)"?\\)/) || [])[1];
      return u ? new Promise(r => { const im = new Image(); im.onload = im.onerror = r; im.src = u; }) : 0; })]).then(() => true)`);
  const duration = await evalJS('window.REEL_DURATION');
  const count = Math.round(duration * FPS);
  for (let f = 0; f < count; f++) {
    await evalJS(`window.seek(${(f / FPS).toFixed(4)}); true`);
    const shot = await send('Page.captureScreenshot', { format: 'jpeg', quality: 93, clip: { x: 0, y: 0, width: 1080, height: 1920, scale: 1 } });
    writeFileSync(join(frames, `f${String(f).padStart(5, '0')}.jpg`), Buffer.from(shot.data, 'base64'));
  }
  const mp4 = join(dest, `${reel}.mp4`);
  execFileSync('swift', [join(HERE, 'frames.swift'), frames, String(FPS), mp4], { stdio: 'inherit' });
  // Keep six evenly spaced key frames for the contact sheet; drop the rest of the sequence.
  // Overwrite files in place: deleting and recreating the folder makes iCloud Drive leave "frame-01 2.jpg" conflict copies.
  const keyDir = join(dest, reel); mkdirSync(keyDir, { recursive: true });
  for (const f of readdirSync(keyDir)) if (f.startsWith('frame-')) rmSync(join(keyDir, f), { force: true });
  for (let k = 0; k < 6; k++) {
    const f = Math.min(count - 1, Math.round((k + .5) * count / 6));
    writeFileSync(join(keyDir, `frame-${String(k + 1).padStart(2, '0')}.jpg`), readFileSync(join(frames, `f${String(f).padStart(5, '0')}.jpg`)));
  }
  rmSync(frames, { recursive: true, force: true });
  return { mp4, duration, count };
}

const wanted = process.argv.slice(2).length ? process.argv.slice(2) : REEL_IDS;
for (const reel of wanted) {
  const chrome = await launch();  // fresh browser per Reel: a hung page can never stall the whole batch
  try {
    const r = await capture(chrome, reel);
    console.log(`Reel ${reel}: ${r.count} frames, ${r.duration.toFixed(1)} s → ${r.mp4}`);
  } catch (e) {
    console.log(`Reel ${reel} FAILED: ${e.message}`);
  } finally { await chrome.close(); }
}
