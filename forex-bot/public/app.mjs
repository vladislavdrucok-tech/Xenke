const $ = (id) => document.getElementById(id);
const PAIRS = ['EUR/USD', 'GBP/USD', 'EUR/GBP'];
let state = null;

// Джерело даних: сервер (node server.mjs) або браузерна демо-версія, яка підставляє свій API.
const api = globalThis.PULSE_FX_API ?? {
  state: async () => (await fetch('/api/state')).json(),
  run: async () => (await fetch('/api/run', { method: 'POST', headers: { 'X-Pulse-FX': '1' } })).json(),
};

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const usd = (v, d = 2) => (v < 0 ? '−' : '') + '$' + Math.abs(v).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
const sgnUsd = (v) => (v >= 0 ? '+' : '−') + '$' + Math.abs(v).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const pct = (v, d = 2) => (v >= 0 ? '+' : '−') + Math.abs(v).toFixed(d) + '%';
const num = (v, d = 2) => (v >= 0 ? '+' : '−') + Math.abs(v).toFixed(d);
const cls = (v) => (v > 0 ? 'up' : v < 0 ? 'dn' : 'flat');
const fmtLocal = (iso) => new Date(iso).toLocaleString('uk-UA', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });

function lineChart(el, points, { color = '#ff8a96', base = null, fill = true, labels = true, fmt = (v) => usd(v) } = {}) {
  if (!points.length) { el.innerHTML = '<div class="empty">Ще немає даних</div>'; return; }
  const W = el.clientWidth || 600, H = el.clientHeight || 160, pb = labels ? 16 : 2;
  const vals = points.map((p) => p.v);
  let lo = Math.min(...vals, base ?? Infinity), hi = Math.max(...vals, base ?? -Infinity);
  const pad = (hi - lo) * 0.1 || Math.abs(hi) * 0.001 || 1; lo -= pad; hi += pad;
  const x = (i) => (points.length === 1 ? W / 2 : (i / (points.length - 1)) * W), y = (v) => H - pb - ((v - lo) / (hi - lo)) * (H - pb - 4);
  const d = points.map((p, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(p.v).toFixed(1)}`).join('');
  const gid = 'g' + Math.random().toString(36).slice(2, 8);
  el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">
    <defs><linearGradient id="${gid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${color}" stop-opacity=".35"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></linearGradient></defs>
    ${base != null ? `<line x1="0" x2="${W}" y1="${y(base)}" y2="${y(base)}" stroke="rgba(255,255,255,.18)" stroke-dasharray="3 4"/>` : ''}
    ${fill ? `<path d="${d}L${x(points.length - 1)},${H - pb}L0,${H - pb}Z" fill="url(#${gid})"/>` : ''}
    <path d="${d}" fill="none" stroke="${color}" stroke-width="2"/>
    <circle cx="${x(points.length - 1)}" cy="${y(points.at(-1).v)}" r="3.5" fill="#fff" stroke="${color}" stroke-width="2"/>
    ${labels ? `<text x="0" y="${H - 2}" fill="#7a5560" font-size="10" font-family="monospace">${esc(points[0].label)}</text>
    <text x="${W}" y="${H - 2}" fill="#7a5560" font-size="10" font-family="monospace" text-anchor="end">${esc(points.at(-1).label)}</text>` : ''}
  </svg>`;
  const tip = $('tip');
  el.onmousemove = (e) => {
    const r = el.getBoundingClientRect();
    const i = Math.round(((e.clientX - r.left) / r.width) * (points.length - 1));
    const p = points[Math.max(0, Math.min(points.length - 1, i))];
    tip.textContent = `${p.label} · ${fmt(p.v)}`; tip.style.left = e.clientX + 12 + 'px'; tip.style.top = e.clientY - 28 + 'px'; tip.style.opacity = 1;
  };
  el.onmouseleave = () => { tip.style.opacity = 0; };
}

function decisionChip(action) {
  const a = action || 'чекати';
  const kind = a.includes('купити') ? 'buy' : a.includes('продати') ? 'sell' : a === 'тримати' ? 'hold' : 'wait';
  return `<span class="decision ${kind}">${esc(a.toUpperCase())}</span>`;
}

function render() {
  const s = state;
  const live = s.mode.data === 'live';
  $('modeData').className = 'chip ' + (live ? 'live' : 'demo');
  $('modeData').textContent = live ? 'Дані: Twelve Data' : 'Дані: ДЕМО';
  $('modeAi').className = 'chip ' + (s.mode.ai === 'claude' ? 'live' : 'demo');
  $('modeAi').textContent = s.mode.ai === 'claude' ? `ШІ: Claude` : 'ШІ: демо-аналітик';
  $('lastBar').textContent = `Свічка: ${s.lastBarDate ?? '—'}`;
  $('nextRun').textContent = `Наступне рішення: ${fmtLocal(s.nextRunAt)}`;
  $('nextRun').hidden = !!s.webDemo;
  $('runBtn').textContent = live ? 'Запустити цикл зараз' : 'Наступний день (демо) ▶';

  const lastRun = s.runs.at(-1);
  const banner = $('banner');
  const msgs = [];
  if (s.webDemo) msgs.push('Браузерна демо-версія: курси й новини згенеровані, бот працює прямо на цій сторінці, а кнопка «Наступний день» прокручує один торговий день. У демо-світі новини навмисно трохи впливають на курс, щоб було видно навчання; на справжньому ринку все складніше. Справжні дані й Claude — у версії, що запускається на комп’ютері (node server.mjs).');
  else if (!live) msgs.push('Демо-режим: курси й новини згенеровані. У демо-світі новини навмисно трохи впливають на курс, щоб було видно навчання; на справжньому ринку все складніше. Додайте ключі у файл .env, щоб перейти на справжні дані.');
  if (s.account.pausedUntil) msgs.push('Guard: ' + s.account.pauseReason);
  if (lastRun?.errors?.length) msgs.push('Проблеми останнього запуску: ' + lastRun.errors.join('; '));
  banner.hidden = !msgs.length;
  banner.className = 'banner' + (lastRun && (!lastRun.ok || lastRun.errors.length) ? ' err' : '');
  banner.innerHTML = msgs.map(esc).join('<br>');

  // Капітал
  const eq = s.equity, start = s.account.startEquity, ret = (eq / start - 1) * 100;
  const [w, f] = eq.toFixed(2).split('.');
  $('eqBig').innerHTML = `$${Number(w).toLocaleString('en-US')}<small>.${f}</small>`;
  $('eqRet').textContent = `${sgnUsd(eq - start)} (${pct(ret)})`;
  $('eqRet').className = 'eq-ret ' + cls(ret);
  $('eqSub').textContent = `старт ${usd(start, 0)} · ${s.equityCurve.length} торг. днів`;
  lineChart($('eqChart'), s.equityCurve.map((p) => ({ v: p.equity, label: p.date })), { base: start });
  let peak = start, mdd = 0;
  for (const p of s.equityCurve) { peak = Math.max(peak, p.equity); mdd = Math.max(mdd, (peak - p.equity) / peak * 100); }
  const wins = s.trades.filter((t) => t.pnlUsd > 0).length;
  const gross = s.latest?.gross ?? 0;
  $('kpis').innerHTML = [
    ['Угод закрито', `${s.trades.length}`],
    ['Прибуткових', s.trades.length ? `${(wins / s.trades.length * 100).toFixed(0)}%` : '—'],
    ['Макс. просадка', `−${mdd.toFixed(1)}%`],
    ['Відкрито позицій', `${Object.keys(s.positions).length}`],
    ['Плече зараз', `${(gross / Math.max(eq, 1)).toFixed(2)}× / ${s.config.maxLeverage}×`],
  ].map(([k, v]) => `<div class="kpi"><small>${k}</small><b>${v}</b></div>`).join('');

  // Навчання
  const st = s.latest?.stats;
  $('learnSub').textContent = st ? `оцінено рішень: ${st.evaluated}` : '';
  $('weights').innerHTML = [['Технічний аналіз', s.weights.quant, 'var(--blu)'], ['Новини (ШІ)', s.weights.news, 'var(--vio)']].map(([k, v, c]) =>
    `<div class="wrow"><div class="lbl"><span>${k}</span><b>${(v * 100).toFixed(0)}%</b></div><div class="bar"><i style="width:${v * 100}%;background:${c}"></i></div></div>`).join('');
  lineChart($('wChart'), s.weightHistory.map((p) => ({ v: p.news, label: p.date })), { color: '#a78bfa', base: 0.5, labels: false, fmt: (v) => `вага новин ${(v * 100).toFixed(0)}%` });
  const hr = (x) => (x?.hitRate == null ? '—' : `${(x.hitRate * 100).toFixed(0)}%`);
  $('hits').innerHTML = st ? [['Тех. вгадує', st.quant], ['Новини вгадують', st.news], ['Угоди вгадують', st.final]].map(([k, x]) =>
    `<div class="hit"><small>${k}</small><b>${hr(x)}</b><small>з ${x.n}</small></div>`).join('') : '';

  // Пари
  const L = s.latest;
  $('pairs').innerHTML = PAIRS.map((id) => {
    if (!L) return `<div class="pair"><div class="pair-h"><b>${id}</b></div><div class="empty">Ще не було жодного циклу</div></div>`;
    const t = L.technical[id], pl = L.plans[id], pos = s.positions[id];
    const markerPos = ((Math.max(-1, Math.min(1, pl.score)) + 1) / 2) * 100;
    const thr = s.config.minScore;
    const posHtml = pos
      ? `<div class="pos">${pos.dir > 0 ? 'LONG (купівля)' : 'SHORT (продаж)'} ${Math.round(pos.units).toLocaleString('en-US')} од. @ ${pos.entry.toFixed(5)}<br>
         P&amp;L: <span class="${cls(pos.unrealizedUsd)}">${sgnUsd(pos.unrealizedUsd)}</span> · стоп ${pos.stop.toFixed(5)} · тейк ${pos.take.toFixed(5)}</div>`
      : '<div class="pos">Позиції немає</div>';
    return `<div class="pair">
      <div class="pair-h"><b>${id}</b>${decisionChip(L.actions[id])}</div>
      <div class="price">${t.close.toFixed(5)}<small class="${cls(t.changePct)}">${pct(t.changePct)}</small></div>
      <div class="spark" id="spark-${id.replace('/', '')}"></div>
      <div class="score"><div class="lbl"><span>Підсумкова оцінка</span><b class="${cls(pl.score)}">${num(pl.score)}</b></div>
        <div class="dial"><span class="thr" style="left:${(1 - thr) / 2 * 100}%;width:${thr * 100}%"></span><i style="left:${markerPos}%"></i></div>
        <div class="parts"><span>тех. ${num(pl.quant)}</span><span>новини ${num(pl.news)}</span>${t.rsi != null ? `<span>RSI ${t.rsi.toFixed(0)}</span>` : ''}</div></div>
      <div class="parts" style="font-family:inherit">${esc(t.text)}</div>
      ${posHtml}
      ${pl.guard.length ? `<div class="guard">⛉ ${pl.guard.map(esc).join(' · ')}</div>` : ''}
    </div>`;
  }).join('');
  if (L) for (const id of PAIRS) {
    const cs = L.market[id];
    lineChart($('spark-' + id.replace('/', '')), cs.map((c) => ({ v: c.close, label: c.date })), { labels: false, color: cs.at(-1).close >= cs[0].close ? '#3ee08f' : '#ff6b7d', fmt: (v) => v.toFixed(5) });
  }

  // Аналіз ШІ
  const A = L?.analysis;
  $('aiSub').textContent = A ? `${A.source}${L ? ' · ' + L.date : ''}` : '';
  $('aiSummary').textContent = A?.summary || 'Аналізу ще немає.';
  $('aiPairs').innerHTML = A ? PAIRS.map((id) => {
    const a = A.pairs[id];
    return `<div class="aipair"><div class="aipair-h"><b>${id}</b><span class="tag ${cls(a.bias)}">нахил ${num(a.bias)}</span><span class="tag">впевненість ${(a.confidence * 100).toFixed(0)}%</span>${a.eventRisk ? '<span class="tag risk">важлива подія попереду</span>' : ''}</div>
      <p>${esc(a.reasoning)}</p>${a.drivers.length ? `<ul class="drivers">${a.drivers.map((d) => `<li>${esc(d)}</li>`).join('')}</ul>` : ''}</div>`;
  }).join('') : '';

  // Новини
  const hl = L?.headlines || [];
  $('newsSub').textContent = `${hl.length} заголовків`;
  $('headlines').innerHTML = hl.map((h) => {
    const safe = /^https?:\/\//.test(h.link || '') ? h.link : '';
    return `<li>${safe ? `<a href="${esc(safe)}" target="_blank" rel="noopener noreferrer">${esc(h.title)}</a>` : esc(h.title)}<small>${esc(h.source)} · ${esc(h.date || '')}</small></li>`;
  }).join('') || '<li class="empty">Новин немає</li>';

  // Журнал
  $('journalBody').innerHTML = s.journal.slice().reverse().map((e) => {
    const o = e.outcome;
    const res = o ? `<span class="${cls(o.pips)}">${num(o.pips, 0)} п.</span> ${e.dir ? (o.finalRight ? '✓' : '✗') : ''}` : '<span class="flat">очікує</span>';
    return `<tr><td>${e.date}</td><td>${e.pair}</td><td>${esc(e.action)}</td><td class="${cls(e.score)}">${num(e.score)}</td><td>${num(e.quant)}</td><td>${num(e.news)}</td><td>${res}</td></tr>`;
  }).join('') || '<tr><td colspan="7" class="empty">Порожньо</td></tr>';

  // Угоди
  const pnl = s.trades.reduce((a, t) => a + t.pnlUsd, 0);
  $('tradesSub').textContent = s.trades.length ? `разом ${sgnUsd(pnl)}` : '';
  $('tradesBody').innerHTML = s.trades.slice().reverse().map((t) =>
    `<tr><td>${t.closedAt}</td><td>${t.pair}</td><td>${t.dir > 0 ? 'LONG' : 'SHORT'}</td><td class="${cls(t.pips)}">${num(t.pips, 1)}</td><td class="${cls(t.pnlUsd)}">${sgnUsd(t.pnlUsd)}</td><td class="txt">${esc(t.reason)}</td></tr>`).join('')
    || '<tr><td colspan="6" class="empty">Угод ще немає</td></tr>';

  // Правила
  const c = s.config;
  $('rules').innerHTML = `<div class="rules-grid">${[
    ['Ризик на угоду', `${c.riskPerTradePct}% капіталу`], ['Макс. плече', `${c.maxLeverage}×`], ['Аварійна зупинка', `просадка ${c.maxDrawdownPct}%`],
    ['Стоп-лосс', `${c.stopAtr} × ATR`], ['Тейк-профіт', `${c.takeAtr} × ATR`], ['Поріг входу', `|оцінка| > ${c.minScore}`],
    ['Рішення', `щодня ${c.decisionTimeUtc} UTC`], ['Модель ШІ', c.model || 'демо-аналітик'],
  ].map(([k, v]) => `<div class="rule"><small>${k}</small><b>${esc(v)}</b></div>`).join('')}</div>`;
  $('runs').innerHTML = s.runs.slice().reverse().map((r) =>
    `<div class="${r.ok && !r.errors.length ? '' : 'bad'}">${fmtLocal(r.at)} · ${r.ok ? 'OK' : 'ПОМИЛКА'} · ${esc(r.note)} ${esc(r.errors.join('; '))}</div>`).join('');
}

async function load() {
  state = await api.state();
  render();
}

$('runBtn').addEventListener('click', async () => {
  const b = $('runBtn');
  b.disabled = true; const old = b.textContent; b.textContent = 'Працюю…';
  try {
    state = await api.run();
    render();
  } catch (e) {
    $('banner').hidden = false; $('banner').className = 'banner err'; $('banner').textContent = 'Не вдалося запустити цикл: ' + e.message;
    b.textContent = old;
  } finally { b.disabled = false; }
});

addEventListener('resize', () => state && render());
load().catch((e) => { $('banner').hidden = false; $('banner').className = 'banner err'; $('banner').textContent = 'Сервер недоступний: ' + e.message; });
if (!globalThis.PULSE_FX_API) setInterval(() => load().catch(() => {}), 60000);
