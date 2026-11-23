// Local preview only: runs the real link Worker over Website/public with the production `/*` headers (CSP).
// Never a deployment path. Usage: python3 Website/build.py && node Website/preview.mjs [port]
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {extname, join, normalize} from 'node:path';
import {fileURLToPath} from 'node:url';
import worker from './link-worker.mjs';

const root = fileURLToPath(new URL('./public/', import.meta.url));
const port = Number(process.argv[2] ?? 8788);
const types = {'.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.png': 'image/png', '.jpg': 'image/jpeg', '.json': 'application/json'};
const global = {};
for (const line of (await readFile(join(root, '_headers'), 'utf8')).split('\n').slice(1)) {
  if (!line.startsWith('  ')) break;
  const [name, ...value] = line.trim().split(': ');
  global[name] = value.join(': ');
}
const ASSETS = {async fetch(request) {
  const path = normalize(decodeURIComponent(new URL(request.url).pathname)).replace(/^\/+/, '');
  try {
    if (path.startsWith('..') || path.startsWith('_')) throw Error('outside');
    return new Response(await readFile(join(root, path)), {headers: {...global, 'Content-Type': types[extname(path)] ?? 'application/octet-stream'}});
  } catch {
    return new Response(await readFile(join(root, '404.html')), {status: 404, headers: {...global, 'Content-Type': types['.html']}});
  }
}};
createServer(async (req, res) => {
  const response = await worker.fetch(new Request('https://staygrubby.com' + req.url, {method: req.method}), {ASSETS});
  res.writeHead(response.status, Object.fromEntries(response.headers));
  res.end(Buffer.from(await response.arrayBuffer()));
}).listen(port, '127.0.0.1', () => console.log(`StayGrubby preview: http://127.0.0.1:${port}/`));
