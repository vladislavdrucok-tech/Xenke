// Мінімальний статичний сервер для прикладу сайту клініки (тести й `npm run sample`).
// /tsiny → tsiny.html, /ru/ → ru/index.html.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize, sep } from 'node:path';

const TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.txt': 'text/plain; charset=utf-8', '.png': 'image/png' };

export function serveStatic(root) {
  return createServer(async (req, res) => {
    const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    const candidates = path.endsWith('/') ? [`${path}index.html`] : extname(path) ? [path] : [`${path}.html`, `${path}/index.html`];
    for (const c of candidates) {
      const file = normalize(join(root, c));
      if (!file.startsWith(root + sep) && file !== root) continue;
      try {
        const body = await readFile(file);
        res.writeHead(200, { 'Content-Type': TYPES[extname(file)] || 'application/octet-stream' });
        res.end(body);
        return;
      } catch { /* наступний варіант */ }
    }
    res.writeHead(404, { 'Content-Type': 'text/html; charset=utf-8' }).end('<h1>404</h1>');
  });
}
