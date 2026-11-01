import { createSim, step, stats, pnlByToken, positionValue, walletWinRate, fmtK, tokenMcap, tokenChangePct,
  DEFAULT_RULES, MOODS, STEP_SECONDS } from './sim.mjs';

const $ = (id) => document.getElementById(id);
const STORE = 'pulse-terminal-demo-settings';

const AGENTS = [
  { key: 'SCOUT', name: 'Scout', desc: 'стежить за гаманцями', icon: '⌕', color: '#5aa9ff' },
  { key: 'FILTER', name: 'Filter', desc: 'жорсткі правила', icon: '⧩', color: '#ffb547' },
  { key: 'ANALYST', name: 'Analyst', desc: 'глибокі перевірки', icon: '◈', color: '#a78bfa' },
  { key: 'SNIPER', name: 'Sniper', desc: 'копіює угоди', icon: '◎', color: '#3ee08f' },
  { key: 'GUARD', name: 'Guard', desc: 'стопи за правилами', icon: '⛉', color: '#ff6fb1' },
];
const RULE_FIELDS = [
  ['minLiquidityK', 'Мін. ліквідність пулу, тис. $', 1, 500],
  ['maxTopHolderPct', 'Макс. частка топ-холдера, %', 1, 100],
  ['minWalletWinRate', 'Мін. win rate гаманця, %', 0, 100],
  ['positionPct', 'Розмір позиції, % капіталу', 1, 100],
  ['takeProfitPct', 'Тейк-профіт, %', 1, 1000],
  ['stopLossPct', 'Стоп-лосс, %', 1, 95],
  ['trailingPct', 'Трейлінг від піку, %', 1, 95],
  ['maxOpen', 'Макс. відкритих позицій', 1, 20],
];

function loadSettings() {
  try {
    const s = JSON.parse(localStorage.getItem(STORE));
    if (s && typeof s === 'object') return { seed: s.seed ?? 42, startUsd: s.startUsd ?? 100, mood: s.mood in MOODS ? s.mood : 'neutral', rules: { ...DEFAULT_RULES, ...s.rules } };
  } catch { /* зіпсовані налаштування — беремо стандартні */ }
  return { seed: 42, startUsd: 100, mood: 'neutral', rules: { ...DEFAULT_RULES } };
}

let settings = loadSettings();
let sim = createSim(settings);
let running = true;
let speed = 20;
let acc = 0;
let lastLogEntry = null;

const money = (v, d = 2) => (v < 0 ? '−' : '') + '$' + Math.abs(v).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
const signed = (v, d = 2) => (v >= 0 ? '+' : '−') + '$' + Math.abs(v).toFixed(d);
const pct = (v, d = 1) => (v >= 0 ? '+' : '−') + Math.abs(v).toFixed(d) + '%';
const cls = (v) => (v >= 0 ? 'up' : 'dn');
const pad = (n) => String(n).padStart(2, '0');
const clock = (sec) => `${pad(Math.floor(sec / 3600))}:${pad(Math.floor(sec / 60) % 60)}:${pad(Math.floor(sec % 60))}`;
const wall = (t) => { const d = new Date(sim.startTime + t * 1000); return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`; };
const hm = (t) => wall(t).slice(0, 5);
const coin = (sym, hue) => `<span class="coin" style="background:radial-gradient(circle at 35% 30%,hsl(${hue} 90% 70%),hsl(${hue} 70% 38%))">${sym[0]}</span>`;

// ---------- вкладки ----------
function setTab(tab) {
  document.querySelectorAll('[data-tab]').forEach((b) => b.classList.toggle('on', b.dataset.tab === tab));
  document.querySelectorAll('.view').forEach((v) => v.classList.toggle('on', v.id === 'view-' + tab));
  render(true);
}
document.querySelectorAll('[data-tab]').forEach((b) => b.addEventListener('click', () => setTab(b.dataset.tab)));

// ---------- керування ----------
$('play').addEventListener('click', () => {
  running = !running;
  $('play').textContent = running ? '❚❚' : '▶';
  $('status').classList.toggle('paused', !running);
  $('status').lastChild.textContent = running ? 'Live' : 'Пауза';
});
$('speed').addEventListener('change', (e) => { speed = Number(e.target.value); });

function restart(next) {
  settings = next;
  localStorage.setItem(STORE, JSON.stringify(settings));
  sim = createSim(settings);
  lastLogEntry = null;
  render(true);
}

function buildRulesForm() {
  const f = $('rulesForm');
  f.innerHTML = RULE_FIELDS.map(([k, label, min, max]) =>
    `<label>${label}<input type="number" name="${k}" min="${min}" max="${max}" step="1" value="${settings.rules[k]}"></label>`).join('') +
    `<label>Настрій ринку<select name="mood">${Object.keys(MOODS).map((m) => `<option value="${m}" ${m === settings.mood ? 'selected' : ''}>${{ bear: 'ведмежий', neutral: 'нейтральний', bull: 'бичачий' }[m]}</option>`).join('')}</select></label>` +
    `<label>Стартовий капітал, $<input type="number" name="startUsd" min="10" max="1000000" step="1" value="${settings.startUsd}"></label>` +
    `<label>Seed (генератор)<input type="number" name="seed" min="0" max="4294967295" step="1" value="${settings.seed}"></label>` +
    `<div class="act"><button class="primary" type="submit">Застосувати й перезапустити</button>
     <button class="btn" type="button" id="newSeed">Новий seed</button><button class="btn" type="button" id="defaults">Стандартні правила</button></div>`;
  $('newSeed').onclick = () => { f.seed.value = Math.floor(Math.random() * 1e9); };
  $('defaults').onclick = () => { for (const [k] of RULE_FIELDS) f[k].value = DEFAULT_RULES[k]; };
}
$('rulesForm').addEventListener('submit', (e) => {
  e.preventDefault();
  const f = e.target;
  const clamp = (v, lo, hi, d) => (Number.isFinite(v) ? Math.min(hi, Math.max(lo, v)) : d);
  const rules = {};
  for (const [k, , min, max] of RULE_FIELDS) rules[k] = clamp(Number(f[k].value), min, max, DEFAULT_RULES[k]);
  restart({ seed: clamp(Math.floor(Number(f.seed.value)), 0, 4294967295, 42), startUsd: clamp(Number(f.startUsd.value), 10, 1e6, 100), mood: f.mood.value, rules });
  setTab('overview');
});
buildRulesForm();

// ---------- графік капіталу ----------
const chartEl = $('chart');
const tip = $('tip');
function renderChart() {
  const pts = sim.equity;
  const W = chartEl.clientWidth || 600, H = chartEl.clientHeight || 150;
  const vals = pts.map((p) => p.v);
  let lo = Math.min(...vals, sim.startUsd), hi = Math.max(...vals, sim.startUsd);
  const padV = (hi - lo) * 0.12 || 1; lo -= padV; hi += padV;
  const t0 = pts[0].t, t1 = Math.max(pts.at(-1).t, t0 + 60);
  const x = (t) => (t - t0) / (t1 - t0) * W, y = (v) => H - 18 - (v - lo) / (hi - lo) * (H - 26);
  const line = pts.map((p, i) => `${i ? 'L' : 'M'}${x(p.t).toFixed(1)},${y(p.v).toFixed(1)}`).join('');
  const last = pts.at(-1);
  const bars = [];
  const n = 70;
  for (let i = 0; i < n; i++) {
    const a = pts[Math.floor(i / n * (pts.length - 1))], b = pts[Math.floor((i + 1) / n * (pts.length - 1))];
    const d = b.v - a.v, h = Math.min(14, Math.abs(d) / (hi - lo) * 120 + 1.5);
    bars.push(`<rect x="${(i / n * W).toFixed(1)}" y="${H - 18 - h}" width="${Math.max(1, W / n - 2).toFixed(1)}" height="${h.toFixed(1)}" fill="${d >= 0 ? 'rgba(255,120,140,.35)' : 'rgba(255,255,255,.12)'}"/>`);
  }
  chartEl.innerHTML = `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">
    <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff4258" stop-opacity=".35"/><stop offset="1" stop-color="#ff4258" stop-opacity="0"/></linearGradient>
    <filter id="glow"><feGaussianBlur stdDeviation="3" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>
    ${bars.join('')}
    <line x1="0" x2="${W}" y1="${y(sim.startUsd)}" y2="${y(sim.startUsd)}" stroke="rgba(255,255,255,.18)" stroke-dasharray="3 4"/>
    <path d="${line}L${x(last.t)},${H - 18}L0,${H - 18}Z" fill="url(#g)"/>
    <path d="${line}" fill="none" stroke="#ff8a96" stroke-width="2" filter="url(#glow)"/>
    <circle cx="${x(last.t)}" cy="${y(last.v)}" r="4.5" fill="#fff" stroke="#ff4258" stroke-width="2"/>
    <text x="0" y="${H - 2}" fill="#7a5560" font-size="10" font-family="monospace">${hm(t0)}</text>
    <text x="${W}" y="${H - 2}" fill="#7a5560" font-size="10" font-family="monospace" text-anchor="end">${hm(last.t)}</text>
  </svg>`;
  chartEl.onmousemove = (e) => {
    const r = chartEl.getBoundingClientRect();
    const t = t0 + (e.clientX - r.left) / r.width * (t1 - t0);
    let best = pts[0];
    for (const p of pts) if (Math.abs(p.t - t) < Math.abs(best.t - t)) best = p;
    tip.textContent = `${hm(best.t)} · ${money(best.v)}`;
    tip.style.left = e.clientX + 12 + 'px'; tip.style.top = e.clientY - 28 + 'px'; tip.style.opacity = 1;
  };
  chartEl.onmouseleave = () => { tip.style.opacity = 0; };
}

// ---------- радар ----------
const radar = $('radar');
const rctx = radar.getContext('2d');
let sweep = 0;
function drawRadar() {
  const dpr = devicePixelRatio || 1;
  const w = radar.clientWidth, h = radar.clientHeight;
  if (w < 40 || h < 40) { requestAnimationFrame(drawRadar); return; } // вкладка прихована
  if (radar.width !== Math.round(w * dpr) || radar.height !== Math.round(h * dpr)) { radar.width = Math.round(w * dpr); radar.height = Math.round(h * dpr); }
  const c = rctx; c.setTransform(dpr, 0, 0, dpr, 0, 0); c.clearRect(0, 0, w, h);
  const cx = w / 2, cy = h / 2, R = Math.min(w, h) / 2 - 8;
  c.strokeStyle = 'rgba(255,90,110,.16)'; c.lineWidth = 1;
  for (const k of [0.33, 0.66, 1]) { c.beginPath(); c.arc(cx, cy, R * k, 0, Math.PI * 2); c.stroke(); }
  c.beginPath(); c.moveTo(cx - R, cy); c.lineTo(cx + R, cy); c.moveTo(cx, cy - R); c.lineTo(cx, cy + R); c.stroke();
  if (running) sweep += 0.03;
  const g = c.createConicGradient ? c.createConicGradient(sweep - 0.9, cx, cy) : null;
  if (g) {
    g.addColorStop(0, 'rgba(255,66,88,0)'); g.addColorStop(0.14, 'rgba(255,66,88,.28)'); g.addColorStop(0.1401, 'rgba(255,66,88,0)');
    c.fillStyle = g; c.beginPath(); c.arc(cx, cy, R, 0, Math.PI * 2); c.fill();
  }
  c.strokeStyle = 'rgba(255,140,155,.7)'; c.beginPath(); c.moveTo(cx, cy); c.lineTo(cx + Math.cos(sweep) * R, cy + Math.sin(sweep) * R); c.stroke();
  c.font = '600 10.5px -apple-system, Segoe UI, sans-serif';
  for (const b of sim.radar) {
    const age = (sim.t - b.t) / 400;
    if (age > 1) continue;
    const a = 1 - age, px = cx + Math.cos(b.angle) * b.dist * R, py = cy + Math.sin(b.angle) * b.dist * R;
    c.globalAlpha = a;
    c.fillStyle = b.copied ? '#3ee08f' : 'rgba(255,120,140,.9)';
    c.shadowColor = c.fillStyle; c.shadowBlur = b.copied ? 12 : 6;
    c.beginPath(); c.arc(px, py, b.copied ? 5 : 2.5, 0, Math.PI * 2); c.fill();
    c.shadowBlur = 0;
    if (b.copied) {
      const label = `$${b.symbol} copied`;
      const tw = c.measureText(label).width + 12;
      c.fillStyle = 'rgba(10,30,20,.85)'; c.strokeStyle = 'rgba(62,224,143,.6)';
      c.beginPath(); c.roundRect ? c.roundRect(px + 8, py - 9, tw, 18, 9) : c.rect(px + 8, py - 9, tw, 18); c.fill(); c.stroke();
      c.fillStyle = '#c9ffe3'; c.fillText(label, px + 14, py + 4);
    }
    c.globalAlpha = 1;
  }
  c.fillStyle = '#ff4258'; c.beginPath(); c.arc(cx, cy, 3, 0, Math.PI * 2); c.fill();
  requestAnimationFrame(drawRadar);
}

// ---------- treemap ----------
function layout(items, x, y, w, h, out) {
  if (!items.length) return;
  if (items.length === 1) { out.push({ ...items[0], x, y, w, h }); return; }
  const total = items.reduce((s, i) => s + i.weight, 0);
  let acc2 = 0, k = 0;
  while (k < items.length - 1 && acc2 + items[k].weight < total / 2) acc2 += items[k++].weight;
  if (k === 0) acc2 = items[k++].weight;
  const f = acc2 / total;
  if (w >= h) { layout(items.slice(0, k), x, y, w * f, h, out); layout(items.slice(k), x + w * f, y, w * (1 - f), h, out); }
  else { layout(items.slice(0, k), x, y, w, h * f, out); layout(items.slice(k), x, y + h * f, w, h * (1 - f), out); }
}
function renderTreemap() {
  const el = $('treemap');
  const data = pnlByToken(sim).slice(0, 10);
  if (!data.length) { el.innerHTML = '<div class="empty">Ще немає угод</div>'; return; }
  const max = Math.max(...data.map((d) => Math.abs(d.pnl)), 0.01);
  const items = data.map((d) => ({ ...d, weight: Math.abs(d.pnl) + max * 0.08 }));
  const W = el.clientWidth || 300, H = el.clientHeight || 210, out = [];
  layout(items, 0, 0, W, H, out);
  const gap = 3;
  el.innerHTML = out.map((r) => {
    const k = 0.35 + 0.65 * Math.abs(r.pnl) / max;
    const bg = r.pnl >= 0 ? `rgba(40,${Math.round(150 + 60 * k)},100,${0.35 + 0.5 * k})` : `rgba(${Math.round(150 + 80 * k)},40,60,${0.3 + 0.5 * k})`;
    const small = r.w < 60 || r.h < 38;
    return `<div class="tm" style="left:${r.x + gap / 2}px;top:${r.y + gap / 2}px;width:${Math.max(0, r.w - gap)}px;height:${Math.max(0, r.h - gap)}px;background:${bg}">
      ${small ? '' : `<b>${coin(r.symbol, r.hue)} ${r.symbol}</b><span>${signed(r.pnl, 0)}</span>`}</div>`;
  }).join('');
}

// ---------- рендер ----------
function agentInfo(st) {
  const c = sim.counters;
  const lastOf = (key) => { for (let i = sim.log.length - 1; i >= 0; i--) if (sim.log[i].agent === key) return sim.log[i]; return null; };
  return AGENTS.map((a) => {
    const last = lastOf(a.key);
    const n = { SCOUT: c.spotted, FILTER: c.filtered, ANALYST: c.analysed, SNIPER: c.copied, GUARD: c.stops + c.exits }[a.key];
    const sub = { SCOUT: `${c.spotted} сигналів`, FILTER: `відсіяно ${c.filtered}`, ANALYST: `перевірок ${c.analysed}`, SNIPER: `${c.copied} скопійовано`,
      GUARD: `${st.open} відкр. · стоп −${sim.rules.stopLossPct}%` }[a.key];
    return { ...a, n, sub, last, hot: last && sim.t - last.t <= 30 };
  });
}

function render(force = false) {
  const st = stats(sim);
  const agents = agentInfo(st);
  const elapsed = sim.t;
  $('clock').textContent = clock(elapsed);
  $('walletPill').textContent = `демо · ${st.sol.toFixed(2)} SOL`;
  $('sideCopied').textContent = sim.counters.copied;
  $('sideStops').textContent = `${sim.counters.stops} стопів`;
  $('mwSol').innerHTML = `${st.sol.toFixed(2)} <small>SOL</small>`;
  $('mwUsd').textContent = `${money(st.equity)} · ${pct(st.pnlPct)}`;
  $('mwUsd').className = 'mw-s ' + cls(st.pnlUsd);

  $('ticker').innerHTML = sim.tokens.filter((t) => t.alive).sort((a, b) => tokenMcap(b) - tokenMcap(a)).slice(0, 9).map((t) => {
    const ch = tokenChangePct(t);
    return `<span class="tk">${coin(t.symbol, t.hue)}<b>${t.symbol}</b><span>$${fmtK(tokenMcap(t))}</span><em class="${cls(ch)}">${pct(ch, 0)}</em></span>`;
  }).join('');

  $('sideAgents').innerHTML = agents.map((a) => {
    const bars = Array.from({ length: 5 }, (_, i) => `<i style="height:${4 + ((a.n * 7 + i * 13) % 10)}px;background:${a.color};opacity:${a.hot ? 1 : 0.4}"></i>`).join('');
    return `<div class="agent ${a.hot && a.key === 'SNIPER' ? 'hot' : ''}"><span class="ic" style="background:${a.color}22;color:${a.color}">${a.icon}</span>
      <div><b>${a.name}</b><small>${a.sub}</small></div><span class="bars">${bars}</span></div>`;
  }).join('');

  const view = document.querySelector('.view.on').id;
  if (view === 'view-overview') {
    const [whole, frac] = st.equity.toFixed(2).split('.');
    $('eqBig').innerHTML = `$${Number(whole).toLocaleString('en-US')}<small>.${frac}</small>`;
    $('eqSub').textContent = `старт $${sim.startUsd} · ${Math.floor(elapsed / 60)} хв симуляції`;
    $('eqMult').textContent = st.multiple.toFixed(2) + '×';
    $('eqMult').classList.toggle('loss', st.multiple < 1);
    $('eqPnl').textContent = `${signed(st.pnlUsd)} (${pct(st.pnlPct)})`;
    $('eqPnl').className = 'eq-pnl ' + cls(st.pnlUsd);
    $('eqOpen').textContent = `${st.open} відкрито · ${st.closedCount} закрито`;
    renderChart();
    const best = st.best;
    $('kpis').innerHTML = [
      ['Скопійовано', `${sim.counters.copied}<span>/ ${sim.counters.spotted}</span>`],
      ['Win rate', st.winRate == null ? '—' : `${st.winRate.toFixed(0)}%<span>${st.wins}W ${st.losses}L</span>`],
      ['Найкраща угода', best ? `<span class="${cls(best.pnlUsd)}" style="margin:0;font-size:15px">${signed(best.pnlUsd)}</span><span>$${best.symbol}</span>` : '—'],
      ['Макс. просадка', `−${st.maxDrawdown.toFixed(1)}%`],
    ].map(([k, v]) => `<div class="kpi"><small>${k}</small><b>${v}</b></div>`).join('');
    $('radarHits').textContent = `${sim.counters.copied} копій`;

    $('pipeline').innerHTML = agents.map((a) => {
      const last = a.last ? a.last.text : 'очікування…';
      return `<div class="pipe ${a.hot && a.key === 'SNIPER' ? 'hot' : ''}"><div class="pipe-h"><span class="ic" style="width:30px;height:30px;border-radius:9px;display:grid;place-items:center;background:${a.color}26;color:${a.color};font-size:16px">${a.icon}</span>
        <div><b>${a.name}</b><small>${a.desc}</small></div><span class="pipe-n" style="color:${a.color}">${a.n.toLocaleString('en-US')}</span></div>
        <div class="pipe-last">${last}</div></div>`;
    }).join('');

    const rows = [];
    for (const p of sim.positions) {
      const v = positionValue(p, p.token), pnl = v - p.costUsd, pp = pnl / p.costUsd * 100;
      rows.push({ sym: p.token.symbol, hue: p.token.hue, size: p.costUsd / sim.solUsd, pnl, pp, status: 'OPEN', t: p.openedAt });
    }
    for (const c of sim.closed.slice(-8).reverse()) rows.push({ sym: c.symbol, hue: c.hue, size: c.costUsd / sim.solUsd, pnl: c.pnlUsd, pp: c.pnlPct, status: c.status, t: c.closedAt });
    $('posSub').textContent = `${st.open} відкрито · ${st.closedCount} закрито`;
    $('posBody').innerHTML = rows.slice(0, 7).map((r) => `<tr class="${sim.t - r.t <= STEP_SECONDS * 2 ? 'fresh' : ''}">
      <td class="sym"><span>${coin(r.sym, r.hue)}$${r.sym}</span></td><td>${r.size.toFixed(2)} SOL</td>
      <td class="${cls(r.pnl)}">${signed(r.pnl)}</td>
      <td><div class="pbar"><i style="width:${Math.min(100, Math.abs(r.pp) * 2)}%;background:${r.pnl >= 0 ? 'var(--grn)' : 'var(--red)'}"></i></div><span class="${cls(r.pp)}" style="font-size:10.5px">${pct(r.pp)}</span></td>
      <td><span class="badge ${r.status}">${r.status === 'OPEN' ? '● OPEN' : r.status === 'TP' ? 'TP ✓' : r.status}</span></td></tr>`).join('')
      || '<tr><td colspan="5" class="muted">Чекаємо на перший сигнал…</td></tr>';
    renderTreemap();
  }
  if (force || sim.log.at(-1) !== lastLogEntry) {
    lastLogEntry = sim.log.at(-1);
    const colors = Object.fromEntries(AGENTS.map((a) => [a.key, a.color]));
    $('log').innerHTML = sim.log.slice(-40).reverse().map((l) =>
      `<div class="${l.kind}"><time>${wall(l.t)}</time><b style="color:${colors[l.agent]}">${l.agent}</b>${l.text}</div>`).join('');
  }
  if (view === 'view-feed') {
    $('feedSub').textContent = `${st.closedCount} угод · win rate ${st.winRate == null ? '—' : st.winRate.toFixed(0) + '%'}`;
    $('feedBody').innerHTML = sim.closed.slice().reverse().slice(0, 150).map((c) => `<tr>
      <td>${wall(c.closedAt)}</td><td class="sym"><span>${coin(c.symbol, c.hue)}$${c.symbol}</span></td><td>${c.wallet}</td>
      <td>${money(c.costUsd)}</td><td class="${cls(c.pnlUsd)}">${signed(c.pnlUsd)} (${pct(c.pnlPct)})</td>
      <td><span class="badge ${c.status}">${c.status}</span></td><td class="muted">${c.reason}</td></tr>`).join('')
      || '<tr><td colspan="7" class="muted">Ще немає закритих угод</td></tr>';
  }
  if (view === 'view-wallets') {
    $('walletBody').innerHTML = sim.wallets.slice().sort((a, b) => walletWinRate(b) - walletWinRate(a)).map((w) => {
      const wr = walletWinRate(w);
      return `<tr><td>${w.address}</td><td>${w.trades}</td><td class="${wr >= sim.rules.minWalletWinRate ? 'up' : 'muted'}">${wr.toFixed(0)}%</td>
        <td>${w.copied}</td><td class="${w.copied ? cls(w.pnlUsd) : 'muted'}">${w.copied ? signed(w.pnlUsd) : '—'}</td>
        <td class="muted">${[...w.holding.keys()].map((s) => '$' + s).join(' ') || '—'}</td></tr>`;
    }).join('');
  }
}

// ---------- цикл ----------
const TICK_MS = 250;
setInterval(() => {
  if (running) {
    acc += speed * TICK_MS / 1000;
    const n = Math.floor(acc);
    acc -= n;
    for (let i = 0; i < n; i++) step(sim);
  }
  render();
}, TICK_MS);
addEventListener('resize', () => render(true));

render(true);
requestAnimationFrame(drawRadar);
setTimeout(() => $('boot').classList.add('gone'), 2200);
