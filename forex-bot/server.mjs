// Pulse FX: дашборд + API + щоденний розклад.  node server.mjs → http://localhost:5174
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize, sep } from 'node:path';
import { ROOT, loadConfig } from './lib/config.mjs';
import { runCycle, loadState, saveState, freshState } from './lib/cycle.mjs';
import { publicState as toPublic } from './lib/core.mjs';

const cfg = loadConfig();
const pub = join(ROOT, 'public');
const types = { '.html': 'text/html; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.svg': 'image/svg+xml' };

const publicState = (state) => toPublic(state, cfg);

const send = (res, code, body) => { res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(body)); };

const server = createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  try {
    if (url.pathname.startsWith('/api/')) {
      // Власний заголовок: сторонній сайт не зможе змусити браузер викликати ці дії.
      if (req.method === 'POST' && req.headers['x-pulse-fx'] !== '1') return send(res, 403, { error: 'forbidden' });
      if (req.method === 'GET' && url.pathname === '/api/state') return send(res, 200, publicState(loadState(cfg)));
      if (req.method === 'POST' && url.pathname === '/api/run') return send(res, 200, publicState(await runCycle(cfg)));
      if (req.method === 'POST' && url.pathname === '/api/reset') { const s = freshState(cfg); saveState(cfg, s); return send(res, 200, publicState(s)); }
      return send(res, 404, { error: 'not found' });
    }
    const rel = decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname);
    const file = normalize(join(pub, rel));
    if (!file.startsWith(pub + sep)) { res.writeHead(403).end(); return; }
    const body = await readFile(file);
    res.writeHead(200, { 'Content-Type': types[extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
    res.end(body);
  } catch (e) {
    if (e.code === 'ENOENT') { res.writeHead(404).end('Not found'); return; }
    console.error(e);
    send(res, 500, { error: e.message });
  }
});

// Розклад: раз на добу в DECISION_TIME_UTC.
let lastScheduledDay = null;
async function tick() {
  const now = new Date();
  const day = now.toISOString().slice(0, 10);
  const hm = now.toISOString().slice(11, 16);
  if (hm >= cfg.decisionTimeUtc && lastScheduledDay !== day) {
    lastScheduledDay = day;
    const s = await runCycle(cfg);
    const r = s.runs.at(-1);
    console.log(`[${now.toISOString()}] цикл: ${r.ok ? 'OK' : 'ПОМИЛКА'} ${r.note} ${r.errors.join('; ')}`);
  }
}

server.listen(cfg.port, cfg.host, async () => {
  console.log(`Pulse FX → http://localhost:${cfg.port}`);
  console.log(`Дані: ${cfg.liveData ? 'Twelve Data' : 'ДЕМО'} · Аналітик: ${cfg.liveAi ? `Claude (${cfg.claudeModel})` : 'ДЕМО'} · рішення щодня о ${cfg.decisionTimeUtc} UTC`);
  if (!loadState(cfg).latest) { console.log('Перший запуск: виконую цикл…'); await runCycle(cfg); }
  lastScheduledDay = new Date().toISOString().slice(11, 16) >= cfg.decisionTimeUtc ? new Date().toISOString().slice(0, 10) : null;
  setInterval(() => tick().catch((e) => console.error(e)), 60000);
});
