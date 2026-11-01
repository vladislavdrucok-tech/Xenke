// lib/pairs.mjs
var PAIRS = Object.freeze([
  { id: "EUR/USD", base: "EUR", quote: "USD", spread: 1e-4 },
  { id: "GBP/USD", base: "GBP", quote: "USD", spread: 15e-5 },
  { id: "EUR/GBP", base: "EUR", quote: "GBP", spread: 15e-5 }
]);
var PIP = 1e-4;

// lib/indicators.mjs
function ema(values, n) {
  if (values.length < n) return null;
  const k = 2 / (n + 1);
  let e = 0;
  for (let i = 0; i < n; i++) e += values[i];
  e /= n;
  for (let i = n; i < values.length; i++) e = values[i] * k + e * (1 - k);
  return e;
}
function rsi(values, n = 14) {
  if (values.length < n + 1) return null;
  let gain = 0, loss = 0;
  for (let i = 1; i <= n; i++) {
    const d = values[i] - values[i - 1];
    if (d >= 0) gain += d;
    else loss -= d;
  }
  gain /= n;
  loss /= n;
  for (let i = n + 1; i < values.length; i++) {
    const d = values[i] - values[i - 1];
    gain = (gain * (n - 1) + Math.max(d, 0)) / n;
    loss = (loss * (n - 1) + Math.max(-d, 0)) / n;
  }
  if (loss === 0) return gain === 0 ? 50 : 100;
  return 100 - 100 / (1 + gain / loss);
}
function atr(candles, n = 14) {
  if (candles.length < n + 1) return null;
  const tr = [];
  for (let i = 1; i < candles.length; i++) {
    const c = candles[i], p = candles[i - 1].close;
    tr.push(Math.max(c.high - c.low, Math.abs(c.high - p), Math.abs(c.low - p)));
  }
  let a = 0;
  for (let i = 0; i < n; i++) a += tr[i];
  a /= n;
  for (let i = n; i < tr.length; i++) a = (a * (n - 1) + tr[i]) / n;
  return a;
}
var clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
function quantSignal(candles) {
  const closes = candles.map((c) => c.close);
  const last = closes.at(-1);
  const a = atr(candles, 14);
  const e20 = ema(closes, 20), e50 = ema(closes, 50);
  const r = rsi(closes, 14);
  if (a == null || e50 == null || r == null || a <= 0) {
    return { score: 0, parts: {}, text: "\u0437\u0430\u043C\u0430\u043B\u043E \u0456\u0441\u0442\u043E\u0440\u0456\u0457 \u0434\u043B\u044F \u0442\u0435\u0445\u043D\u0456\u0447\u043D\u043E\u0433\u043E \u0430\u043D\u0430\u043B\u0456\u0437\u0443" };
  }
  const trend = clamp((e20 - e50) / a, -3, 3);
  const mom = clamp((last - closes.at(-11)) / (a * Math.sqrt(10)), -3, 3);
  let fade = 0;
  if (r > 72) fade = -(r - 72) / 28;
  if (r < 28) fade = (28 - r) / 28;
  const score = Math.tanh(0.5 * trend + 0.4 * mom + 0.6 * fade);
  const words = [];
  words.push(trend > 0.3 ? "\u0432\u0438\u0441\u0445\u0456\u0434\u043D\u0438\u0439 \u0442\u0440\u0435\u043D\u0434 (EMA20 > EMA50)" : trend < -0.3 ? "\u043D\u0438\u0437\u0445\u0456\u0434\u043D\u0438\u0439 \u0442\u0440\u0435\u043D\u0434 (EMA20 < EMA50)" : "\u0442\u0440\u0435\u043D\u0434\u0443 \u043D\u0435\u043C\u0430\u0454");
  words.push(mom > 0.3 ? "\u0456\u043C\u043F\u0443\u043B\u044C\u0441 \u0443\u0433\u043E\u0440\u0443 \u0437\u0430 10 \u0434\u043D\u0456\u0432" : mom < -0.3 ? "\u0456\u043C\u043F\u0443\u043B\u044C\u0441 \u0443\u043D\u0438\u0437 \u0437\u0430 10 \u0434\u043D\u0456\u0432" : "\u0456\u043C\u043F\u0443\u043B\u044C\u0441 \u0441\u043B\u0430\u0431\u043A\u0438\u0439");
  if (fade) words.push(r > 50 ? `RSI ${r.toFixed(0)}: \u043F\u0435\u0440\u0435\u043A\u0443\u043F\u043B\u0435\u043D\u0456\u0441\u0442\u044C` : `RSI ${r.toFixed(0)}: \u043F\u0435\u0440\u0435\u043F\u0440\u043E\u0434\u0430\u043D\u0456\u0441\u0442\u044C`);
  return { score, parts: { trend, momentum: mom, rsi: r, atr: a, ema20: e20, ema50: e50 }, text: words.join(", ") };
}

// lib/market.mjs
function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = a + 1831565813 >>> 0;
    let t = a;
    t = Math.imul(t ^ t >>> 15, t | 1);
    t ^= t + Math.imul(t ^ t >>> 7, t | 61);
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
var gauss = (r) => Math.sqrt(-2 * Math.log(Math.max(r(), 1e-12))) * Math.cos(2 * Math.PI * r());
var DEMO_START = Date.UTC(2025, 0, 6);
var ANCHOR = { "EUR/USD": 1.08, "GBP/USD": 1.27, "EUR/GBP": 0.85 };
var CURRENCIES = ["USD", "EUR", "GBP"];
function demoDate(i) {
  const d = new Date(DEMO_START);
  let left = i;
  d.setUTCDate(d.getUTCDate() + Math.floor(left / 5) * 7);
  left %= 5;
  while (left > 0) {
    d.setUTCDate(d.getUTCDate() + 1);
    if (d.getUTCDay() % 6 !== 0) left--;
  }
  return d.toISOString().slice(0, 10);
}
function demoWorld(seed, days) {
  const r = mulberry32(seed);
  const v = { USD: 0, EUR: 0, GBP: 0 };
  const trend = { USD: 0, EUR: 0, GBP: 0 };
  const surprises = [];
  const levels = [];
  let prev = { USD: 0, EUR: 0, GBP: 0 };
  for (let d = 0; d < days; d++) {
    const s = {};
    for (const c of CURRENCIES) {
      trend[c] = trend[c] * 0.97 + gauss(r) * 0.25;
      const last = d > 0 ? surprises[d - 1][c] : 0;
      v[c] += 4e-3 * (0.3 * last + 0.12 * trend[c] + 0.95 * gauss(r));
      s[c] = gauss(r);
    }
    surprises.push(s);
    levels.push({ ...v, wiggle: [gauss(r), gauss(r), gauss(r), gauss(r), gauss(r), gauss(r)], prev });
    prev = { ...v };
  }
  const candles = Object.fromEntries(PAIRS.map((p) => [p.id, []]));
  levels.forEach((L, d) => {
    PAIRS.forEach((p, k) => {
      const px = (lv) => ANCHOR[p.id] * Math.exp(lv[p.base] - lv[p.quote]);
      const open = px(L.prev), close = px(L);
      const high = Math.max(open, close) * (1 + Math.abs(L.wiggle[k]) * 18e-4);
      const low = Math.min(open, close) * (1 - Math.abs(L.wiggle[k + 3]) * 18e-4);
      candles[p.id].push({ date: demoDate(d), open: +open.toFixed(5), high: +high.toFixed(5), low: +low.toFixed(5), close: +close.toFixed(5) });
    });
  });
  return { candles, surprises, rnd: mulberry32(seed ^ 2654435769) };
}
var SRC = { USD: "\u0424\u0420\u0421 / \u0421\u0428\u0410", EUR: "\u0404\u0426\u0411 / \u0454\u0432\u0440\u043E\u0437\u043E\u043D\u0430", GBP: "\u0411\u0430\u043D\u043A \u0410\u043D\u0433\u043B\u0456\u0457 / \u0411\u0440\u0438\u0442\u0430\u043D\u0456\u044F" };
var GOOD = {
  USD: ["\u0427\u043B\u0435\u043D\u0438 \u0424\u0420\u0421 \u043D\u0430\u0442\u044F\u043A\u0430\u044E\u0442\u044C \u043D\u0430 \u0434\u043E\u0432\u0448\u0435 \u0432\u0438\u0441\u043E\u043A\u0456 \u0441\u0442\u0430\u0432\u043A\u0438", "\u0417\u0430\u0439\u043D\u044F\u0442\u0456\u0441\u0442\u044C \u0443 \u0421\u0428\u0410 (NFP) \u0437\u043D\u0430\u0447\u043D\u043E \u0432\u0438\u0449\u0430 \u0437\u0430 \u043F\u0440\u043E\u0433\u043D\u043E\u0437", "\u0406\u043D\u0444\u043B\u044F\u0446\u0456\u044F \u0432 \u0421\u0428\u0410 \u043F\u0440\u0438\u0441\u043A\u043E\u0440\u0438\u043B\u0430\u0441\u044F \u043F\u043E\u043D\u0430\u0434 \u043E\u0447\u0456\u043A\u0443\u0432\u0430\u043D\u043D\u044F"],
  EUR: ["\u0404\u0426\u0411 \u0437\u0432\u0443\u0447\u0438\u0442\u044C \u0436\u043E\u0440\u0441\u0442\u043A\u0456\u0448\u0435: \u043C\u043E\u0436\u043B\u0438\u0432\u0435 \u0449\u0435 \u043E\u0434\u043D\u0435 \u043F\u0456\u0434\u0432\u0438\u0449\u0435\u043D\u043D\u044F", "PMI \u0454\u0432\u0440\u043E\u0437\u043E\u043D\u0438 \u043D\u0435\u043E\u0447\u0456\u043A\u0443\u0432\u0430\u043D\u043E \u0437\u0440\u0456\u0441", "\u0406\u043D\u0444\u043B\u044F\u0446\u0456\u044F \u0432 \u0454\u0432\u0440\u043E\u0437\u043E\u043D\u0456 \u0432\u0438\u0449\u0430 \u0437\u0430 \u043F\u0440\u043E\u0433\u043D\u043E\u0437"],
  GBP: ["\u0411\u0430\u043D\u043A \u0410\u043D\u0433\u043B\u0456\u0457 \u0437\u0430\u043B\u0438\u0448\u0438\u0432 \u0441\u0442\u0430\u0432\u043A\u0443, \u0434\u0432\u043E\u0454 \u0433\u043E\u043B\u043E\u0441\u0443\u0432\u0430\u043B\u0438 \u0437\u0430 \u043F\u0456\u0434\u0432\u0438\u0449\u0435\u043D\u043D\u044F", "\u0412\u0412\u041F \u0411\u0440\u0438\u0442\u0430\u043D\u0456\u0457 \u0437\u0440\u0456\u0441 \u0431\u0456\u043B\u044C\u0448\u0435, \u043D\u0456\u0436 \u0447\u0435\u043A\u0430\u043B\u0438", "\u0417\u0430\u0440\u043F\u043B\u0430\u0442\u0438 \u0443 \u0411\u0440\u0438\u0442\u0430\u043D\u0456\u0457 \u0440\u043E\u0441\u0442\u0443\u0442\u044C \u0448\u0432\u0438\u0434\u0448\u0435 \u0437\u0430 \u043F\u0440\u043E\u0433\u043D\u043E\u0437"]
};
var BAD = {
  USD: ["\u0424\u0420\u0421 \u0432\u0456\u0434\u043A\u0440\u0438\u0432\u0430\u0454 \u0434\u0432\u0435\u0440\u0456 \u0434\u043B\u044F \u0437\u043D\u0438\u0436\u0435\u043D\u043D\u044F \u0441\u0442\u0430\u0432\u043A\u0438", "\u0420\u0438\u043D\u043E\u043A \u043F\u0440\u0430\u0446\u0456 \u0421\u0428\u0410 \u0441\u043B\u0430\u0431\u0448\u0430\u0454: \u0437\u0430\u044F\u0432\u043E\u043A \u043D\u0430 \u0434\u043E\u043F\u043E\u043C\u043E\u0433\u0443 \u0431\u0456\u043B\u044C\u0448\u0435", "\u0420\u043E\u0437\u0434\u0440\u0456\u0431\u043D\u0456 \u043F\u0440\u043E\u0434\u0430\u0436\u0456 \u0432 \u0421\u0428\u0410 \u0440\u043E\u0437\u0447\u0430\u0440\u0443\u0432\u0430\u043B\u0438"],
  EUR: ["\u0404\u0426\u0411 \u0441\u0438\u0433\u043D\u0430\u043B\u0456\u0437\u0443\u0454 \u043F\u0440\u043E \u0437\u043D\u0438\u0436\u0435\u043D\u043D\u044F \u0441\u0442\u0430\u0432\u043E\u043A", "\u041F\u0440\u043E\u043C\u0438\u0441\u043B\u043E\u0432\u0456\u0441\u0442\u044C \u041D\u0456\u043C\u0435\u0447\u0447\u0438\u043D\u0438 \u0441\u043A\u043E\u0440\u043E\u0447\u0443\u0454\u0442\u044C\u0441\u044F", "\u0406\u043D\u0444\u043B\u044F\u0446\u0456\u044F \u0432 \u0454\u0432\u0440\u043E\u0437\u043E\u043D\u0456 \u0441\u043F\u043E\u0432\u0456\u043B\u044C\u043D\u0438\u043B\u0430\u0441\u044F \u0441\u0438\u043B\u044C\u043D\u0456\u0448\u0435, \u043D\u0456\u0436 \u0447\u0435\u043A\u0430\u043B\u0438"],
  GBP: ["\u0411\u0430\u043D\u043A \u0410\u043D\u0433\u043B\u0456\u0457 \u0433\u043E\u0442\u0443\u0454\u0442\u044C\u0441\u044F \u0437\u043D\u0438\u0436\u0443\u0432\u0430\u0442\u0438 \u0441\u0442\u0430\u0432\u043A\u0443", "\u0415\u043A\u043E\u043D\u043E\u043C\u0456\u043A\u0430 \u0411\u0440\u0438\u0442\u0430\u043D\u0456\u0457 \u0441\u0442\u0430\u0433\u043D\u0443\u0454", "\u0406\u043D\u0444\u043B\u044F\u0446\u0456\u044F \u0443 \u0411\u0440\u0438\u0442\u0430\u043D\u0456\u0457 \u043D\u0438\u0436\u0447\u0430 \u0437\u0430 \u043F\u0440\u043E\u0433\u043D\u043E\u0437"]
};
var NOISE = ["\u0420\u0438\u043D\u043A\u0438 \u0447\u0435\u043A\u0430\u044E\u0442\u044C \u043D\u0430 \u0432\u0438\u0441\u0442\u0443\u043F\u0438 \u0446\u0435\u043D\u0442\u0440\u043E\u0431\u0430\u043D\u043A\u0456\u0440\u0456\u0432 \u043D\u0430\u0441\u0442\u0443\u043F\u043D\u043E\u0433\u043E \u0442\u0438\u0436\u043D\u044F", "\u0426\u0456\u043D\u0438 \u043D\u0430 \u043D\u0430\u0444\u0442\u0443 \u0441\u0442\u0430\u0431\u0456\u043B\u0456\u0437\u0443\u0432\u0430\u043B\u0438\u0441\u044F", "\u0406\u043D\u0432\u0435\u0441\u0442\u043E\u0440\u0438 \u043E\u0431\u0435\u0440\u0435\u0436\u043D\u0456 \u043F\u0435\u0440\u0435\u0434 \u0437\u0432\u0456\u0442\u0430\u043C\u0438 \u043A\u043E\u043C\u043F\u0430\u043D\u0456\u0439"];
function demoHeadlines(world, d) {
  const s = world.surprises[d];
  const date = demoDate(d);
  const r = mulberry32((d + 1) * 7919);
  const out = [];
  for (const c of CURRENCIES) {
    if (Math.abs(s[c]) < 0.55) continue;
    const misleading = r() < 0.2;
    const positive = s[c] > 0 !== misleading;
    const list = positive ? GOOD[c] : BAD[c];
    out.push({ title: list[Math.floor(r() * list.length)], source: `${SRC[c]} (\u0434\u0435\u043C\u043E)`, date, link: "" });
  }
  out.push({ title: NOISE[Math.floor(r() * NOISE.length)], source: "\u0420\u0438\u043D\u043A\u0438 (\u0434\u0435\u043C\u043E)", date, link: "" });
  return out;
}

// lib/engine.mjs
var pairInfo = (id) => PAIRS.find((p) => p.id === id);
function quoteToUsd(pairId, prices) {
  const q = pairInfo(pairId).quote;
  if (q === "USD") return 1;
  if (q === "GBP") return prices["GBP/USD"];
  throw new Error(`\u043D\u0435\u0432\u0456\u0434\u043E\u043C\u0430 \u0432\u0430\u043B\u044E\u0442\u0430 \u043A\u043E\u0442\u0438\u0440\u0443\u0432\u0430\u043D\u043D\u044F ${q}`);
}
function newAccount(startEquity) {
  return { cash: startEquity, startEquity, peakEquity: startEquity, pausedUntil: null, pauseReason: "" };
}
var unrealizedUsd = (pos, price, q2u) => pos.dir * (price - pos.entry) * pos.units * q2u;
function equityUsd(state3, prices) {
  let eq = state3.account.cash;
  for (const [id, pos] of Object.entries(state3.positions)) eq += unrealizedUsd(pos, prices[id], quoteToUsd(id, prices));
  return eq;
}
function grossNotionalUsd(state3, prices) {
  let n = 0;
  for (const [id, pos] of Object.entries(state3.positions)) n += pos.units * prices[id] * quoteToUsd(id, prices);
  return n;
}
function openPosition(state3, id, dir, units, price, prices, { date, stop, take, reason }) {
  const spread = pairInfo(id).spread;
  const entry = price + dir * spread / 2;
  state3.positions[id] = { dir, units, entry, stop, take, openedAt: date, reason };
  return state3.positions[id];
}
function closePosition(state3, id, price, prices, { date, reason }) {
  const pos = state3.positions[id];
  if (!pos) return null;
  const spread = pairInfo(id).spread;
  const exit = price - pos.dir * spread / 2;
  const q2u = quoteToUsd(id, prices);
  const pnl = pos.dir * (exit - pos.entry) * pos.units * q2u;
  state3.account.cash += pnl;
  delete state3.positions[id];
  const trade = {
    pair: id,
    dir: pos.dir,
    units: Math.round(pos.units),
    entry: pos.entry,
    exit,
    openedAt: pos.openedAt,
    closedAt: date,
    pnlUsd: pnl,
    pips: pos.dir * (exit - pos.entry) / PIP,
    reason
  };
  state3.trades.push(trade);
  if (state3.trades.length > 500) state3.trades.shift();
  return trade;
}
function processBar(state3, date, bars, cfg2) {
  const closes = Object.fromEntries(Object.entries(bars).map(([id, c]) => [id, c.close]));
  const events = [];
  for (const [id, pos] of Object.entries({ ...state3.positions })) {
    const c = bars[id];
    const hitStop = pos.dir > 0 ? c.low <= pos.stop : c.high >= pos.stop;
    const hitTake = pos.dir > 0 ? c.high >= pos.take : c.low <= pos.take;
    if (hitStop) events.push(closePosition(state3, id, pos.dir > 0 ? Math.min(pos.stop, c.open) : Math.max(pos.stop, c.open), closes, { date, reason: "\u0441\u0442\u043E\u043F-\u043B\u043E\u0441\u0441" }));
    else if (hitTake) events.push(closePosition(state3, id, pos.dir > 0 ? Math.max(pos.take, c.open) : Math.min(pos.take, c.open), closes, { date, reason: "\u0442\u0435\u0439\u043A-\u043F\u0440\u043E\u0444\u0456\u0442" }));
  }
  const eq = equityUsd(state3, closes);
  state3.account.peakEquity = Math.max(state3.account.peakEquity, eq);
  state3.equityCurve.push({ date, equity: eq });
  if (state3.equityCurve.length > 2e3) state3.equityCurve.shift();
  const dd = (state3.account.peakEquity - eq) / state3.account.peakEquity * 100;
  if (dd >= cfg2.maxDrawdownPct && !state3.account.pausedUntil) {
    for (const id of Object.keys(state3.positions)) events.push(closePosition(state3, id, closes[id], closes, { date, reason: `Guard: \u043F\u0440\u043E\u0441\u0430\u0434\u043A\u0430 ${dd.toFixed(1)}%` }));
    state3.account.pausedUntil = addTradingDays(date, 5);
    state3.account.pauseReason = `\u041F\u0440\u043E\u0441\u0430\u0434\u043A\u0430 ${dd.toFixed(1)}% \u0432\u0456\u0434 \u043F\u0456\u043A\u0443 \u2265 ${cfg2.maxDrawdownPct}%: \u0443\u0441\u0456 \u043F\u043E\u0437\u0438\u0446\u0456\u0457 \u0437\u0430\u043A\u0440\u0438\u0442\u043E, \u043F\u0430\u0443\u0437\u0430 \u043D\u0430 5 \u0442\u043E\u0440\u0433\u043E\u0432\u0438\u0445 \u0434\u043D\u0456\u0432.`;
  }
  return events.filter(Boolean);
}
function addTradingDays(date, n) {
  const d = /* @__PURE__ */ new Date(date + "T00:00:00Z");
  while (n > 0) {
    d.setUTCDate(d.getUTCDate() + 1);
    if (d.getUTCDay() % 6 !== 0) n--;
  }
  return d.toISOString().slice(0, 10);
}
function decide(state3, cfg2, { date, technical, analysis, weights }) {
  const prices = Object.fromEntries(PAIRS.map((p) => [p.id, technical[p.id].close]));
  const equity = equityUsd(state3, prices);
  const paused = state3.account.pausedUntil && date < state3.account.pausedUntil;
  if (state3.account.pausedUntil && !paused) {
    state3.account.pausedUntil = null;
    state3.account.pauseReason = "";
    state3.account.peakEquity = equity;
  }
  const plans = {};
  for (const p of PAIRS) {
    const t = technical[p.id], a = analysis.pairs[p.id];
    const news = a.bias * a.confidence;
    const score = weights.quant * t.score + weights.news * news;
    let dir = score > cfg2.minScore ? 1 : score < -cfg2.minScore ? -1 : 0;
    const guard = [];
    if (paused) {
      dir = 0;
      guard.push(`\u043F\u0430\u0443\u0437\u0430 \u0434\u043E ${state3.account.pausedUntil}`);
    }
    const conviction = clamp(Math.abs(score) / 0.6, 0.5, 1);
    let riskUsd = equity * cfg2.riskPerTradePct / 100 * conviction;
    if (a.eventRisk && dir) {
      riskUsd *= 0.5;
      guard.push("\u0432\u0430\u0436\u043B\u0438\u0432\u0430 \u043F\u043E\u0434\u0456\u044F \u043F\u043E\u043F\u0435\u0440\u0435\u0434\u0443: \u0440\u043E\u0437\u043C\u0456\u0440 \xD70.5");
    }
    const stopDist = cfg2.stopAtr * t.atr;
    const q2u = quoteToUsd(p.id, prices);
    const units = dir ? riskUsd / (stopDist * q2u) : 0;
    plans[p.id] = { dir, units, score, quant: t.score, news, stopDist, takeDist: cfg2.takeAtr * t.atr, guard, price: t.close };
  }
  let held = 0, fresh = 0;
  for (const [id, pl] of Object.entries(plans)) {
    const cur = state3.positions[id];
    const n = (u) => u * pl.price * quoteToUsd(id, prices);
    if (cur && cur.dir === pl.dir) held += n(cur.units);
    else if (pl.dir) fresh += n(pl.units);
  }
  const room = Math.max(0, cfg2.maxLeverage * equity - held);
  const scale = fresh > room ? room / fresh : 1;
  if (scale < 1) for (const [id, pl] of Object.entries(plans)) {
    const cur = state3.positions[id];
    if (!pl.dir || cur && cur.dir === pl.dir) continue;
    pl.units *= scale;
    pl.guard.push(`\u043B\u0456\u043C\u0456\u0442 \u043F\u043B\u0435\u0447\u0430 ${cfg2.maxLeverage}\xD7: \u0440\u043E\u0437\u043C\u0456\u0440 \xD7${scale.toFixed(2)}`);
  }
  return { plans, prices, equity, paused };
}
function execute(state3, { plans, prices }, date) {
  const actions = {};
  for (const [id, pl] of Object.entries(plans)) {
    const cur = state3.positions[id];
    if (cur && cur.dir === pl.dir) {
      const trail = pl.price - pl.dir * pl.stopDist;
      cur.stop = pl.dir > 0 ? Math.max(cur.stop, trail) : Math.min(cur.stop, trail);
      actions[id] = "\u0442\u0440\u0438\u043C\u0430\u0442\u0438";
      continue;
    }
    if (cur) closePosition(state3, id, pl.price, prices, { date, reason: pl.dir ? "\u0440\u043E\u0437\u0432\u043E\u0440\u043E\u0442 \u0441\u0438\u0433\u043D\u0430\u043B\u0443" : "\u0441\u0438\u0433\u043D\u0430\u043B \u0437\u043D\u0438\u043A" });
    if (pl.dir && pl.units > 0) {
      openPosition(state3, id, pl.dir, pl.units, pl.price, prices, {
        date,
        stop: pl.price - pl.dir * pl.stopDist,
        take: pl.price + pl.dir * pl.takeDist,
        reason: `\u043E\u0446\u0456\u043D\u043A\u0430 ${pl.score.toFixed(2)}`
      });
      actions[id] = pl.dir > 0 ? cur ? "\u0440\u043E\u0437\u0432\u043E\u0440\u043E\u0442 \u2192 \u043A\u0443\u043F\u0438\u0442\u0438" : "\u043A\u0443\u043F\u0438\u0442\u0438" : cur ? "\u0440\u043E\u0437\u0432\u043E\u0440\u043E\u0442 \u2192 \u043F\u0440\u043E\u0434\u0430\u0442\u0438" : "\u043F\u0440\u043E\u0434\u0430\u0442\u0438";
    } else actions[id] = cur ? "\u0437\u0430\u043A\u0440\u0438\u0442\u0438" : "\u0447\u0435\u043A\u0430\u0442\u0438";
  }
  return actions;
}

// lib/learning.mjs
var DEFAULT_WEIGHTS = Object.freeze({ quant: 0.5, news: 0.5 });
var WINDOW = 60;
var MIN_SAMPLES = 8;
var LEARN_RATE = 0.15;
function evaluateJournal(journal, candlesByPair) {
  for (const e of journal) {
    if (e.outcome) continue;
    const cs = candlesByPair[e.pair];
    const i = cs.findIndex((c) => c.date === e.date);
    if (i < 0 || i + 1 >= cs.length) continue;
    const next = cs[i + 1];
    const move = next.close - e.price;
    const retAtr = e.atr > 0 ? move / e.atr : 0;
    const right = (s) => Math.abs(s) < 0.05 ? null : Math.sign(s) === Math.sign(move);
    e.outcome = { nextDate: next.date, pips: move / PIP, retAtr, quantRight: right(e.quant), newsRight: right(e.news), finalRight: e.dir ? Math.sign(e.dir) === Math.sign(move) : null };
  }
}
function componentStats(journal) {
  const done = journal.filter((e) => e.outcome).slice(-WINDOW);
  const stat = (key, rightKey) => {
    const used = done.filter((e) => Math.abs(e[key]) >= 0.05);
    const n = used.length;
    const edge = n ? used.reduce((s, e) => s + Math.sign(e[key]) * clamp(e.outcome.retAtr, -3, 3), 0) / n : 0;
    const hits = used.filter((e) => e.outcome[rightKey]).length;
    return { n, edge, hitRate: n ? hits / n : null };
  };
  const trades = done.filter((e) => e.dir);
  return {
    evaluated: done.length,
    quant: stat("quant", "quantRight"),
    news: stat("news", "newsRight"),
    final: { n: trades.length, hitRate: trades.length ? trades.filter((e) => e.outcome.finalRight).length / trades.length : null }
  };
}
function updateWeights(weights, journal) {
  const s = componentStats(journal);
  if (s.quant.n < MIN_SAMPLES || s.news.n < MIN_SAMPLES) return { weights: { ...weights }, stats: s, changed: false };
  const rawQ = Math.max(0.05, 0.5 + s.quant.edge), rawN = Math.max(0.05, 0.5 + s.news.edge);
  const target = rawQ / (rawQ + rawN);
  const quant = clamp((1 - LEARN_RATE) * weights.quant + LEARN_RATE * target, 0.2, 0.8);
  return { weights: { quant, news: 1 - quant }, stats: s, changed: Math.abs(quant - weights.quant) > 1e-9 };
}
function trackRecordLines(journal, n = 12) {
  return journal.filter((e) => e.outcome && Math.abs(e.news) >= 0.05).slice(-n).map((e) => `- ${e.date} ${e.pair}: news ${e.news >= 0 ? "+" : ""}${e.news.toFixed(2)} -> next day ${e.outcome.pips >= 0 ? "+" : ""}${e.outcome.pips.toFixed(0)} pips (${e.outcome.newsRight ? "right" : "wrong"})`);
}

// lib/core.mjs
var STATE_VERSION = 1;
var DEMO_SEED = 20251101;
var DEMO_HISTORY = 60;
var DEMO_WARMUP = 120;
function freshState(cfg2) {
  return {
    version: STATE_VERSION,
    mode: { data: cfg2.liveData ? "live" : "demo", ai: cfg2.liveAi ? "claude" : "demo" },
    account: newAccount(cfg2.startEquity),
    positions: {},
    trades: [],
    equityCurve: [],
    journal: [],
    weights: { ...DEFAULT_WEIGHTS },
    weightHistory: [],
    lastBarDate: null,
    demoDay: null,
    latest: null,
    runs: []
  };
}
var barsOn = (candles, date) => Object.fromEntries(PAIRS.map((p) => [p.id, candles[p.id].find((c) => c.date === date)]));
var upTo = (candles, date) => Object.fromEntries(PAIRS.map((p) => [p.id, candles[p.id].filter((c) => c.date <= date)]));
async function advanceDay(state3, cfg2, candles, date, headlines, analyze) {
  const isNew = !state3.lastBarDate || date > state3.lastBarDate;
  if (state3.lastBarDate && isNew) processBar(state3, date, barsOn(candles, date), cfg2);
  if (!state3.lastBarDate) state3.equityCurve.push({ date, equity: state3.account.cash });
  const hist = upTo(candles, date);
  evaluateJournal(state3.journal, hist);
  const learned = updateWeights(state3.weights, state3.journal);
  if (learned.changed) {
    state3.weights = learned.weights;
    state3.weightHistory.push({ date, ...learned.weights });
    if (state3.weightHistory.length > 1e3) state3.weightHistory.shift();
  }
  const technical = {};
  for (const p of PAIRS) {
    const cs = hist[p.id];
    const q = quantSignal(cs);
    const prev = cs.at(-2)?.close ?? cs.at(-1).close;
    technical[p.id] = { ...q, close: cs.at(-1).close, atr: q.parts.atr ?? cs.at(-1).close * 6e-3, changePct: (cs.at(-1).close / prev - 1) * 100 };
  }
  const analysis = await analyze({ date, technical, headlines, trackRecord: trackRecordLines(state3.journal), weights: state3.weights });
  const plan = decide(state3, cfg2, { date, technical, analysis, weights: state3.weights });
  const actions = execute(state3, plan, date);
  for (const p of PAIRS) {
    const pl = plan.plans[p.id], t = technical[p.id], a = analysis.pairs[p.id];
    state3.journal.push({
      date,
      pair: p.id,
      price: t.close,
      atr: t.atr,
      quant: t.score,
      news: pl.news,
      bias: a.bias,
      confidence: a.confidence,
      score: pl.score,
      dir: pl.dir,
      action: actions[p.id],
      weights: { ...state3.weights },
      outcome: null
    });
  }
  if (state3.journal.length > 3e3) state3.journal.splice(0, state3.journal.length - 3e3);
  const prices = plan.prices;
  state3.latest = {
    date,
    headlines,
    analysis,
    actions,
    technical: Object.fromEntries(PAIRS.map((p) => [p.id, {
      score: technical[p.id].score,
      text: technical[p.id].text,
      close: technical[p.id].close,
      changePct: technical[p.id].changePct,
      rsi: technical[p.id].parts.rsi ?? null,
      atr: technical[p.id].atr
    }])),
    plans: Object.fromEntries(Object.entries(plan.plans).map(([id, pl]) => [id, { dir: pl.dir, score: pl.score, quant: pl.quant, news: pl.news, guard: pl.guard }])),
    equity: equityUsd(state3, prices),
    gross: grossNotionalUsd(state3, prices),
    market: Object.fromEntries(PAIRS.map((p) => [p.id, hist[p.id].slice(-90)])),
    stats: componentStats(state3.journal)
  };
  state3.lastBarDate = date;
}
async function advanceDemo(state3, cfg2, analyze, warmAnalyze = analyze) {
  const first = state3.demoDay == null;
  const target = first ? DEMO_HISTORY + DEMO_WARMUP : state3.demoDay + 1;
  const world = demoWorld(DEMO_SEED, target + 1);
  for (let d = first ? DEMO_HISTORY : target; d <= target; d++) {
    const date = world.candles["EUR/USD"][d].date;
    await advanceDay(state3, cfg2, world.candles, date, demoHeadlines(world, d), d === target ? analyze : warmAnalyze);
  }
  state3.demoDay = target;
  return first ? `\u0414\u0435\u043C\u043E: \u043F\u0440\u043E\u043A\u0440\u0443\u0447\u0435\u043D\u043E ${DEMO_WARMUP} \u0442\u043E\u0440\u0433\u043E\u0432\u0438\u0445 \u0434\u043D\u0456\u0432, \u0449\u043E\u0431 \u043F\u043E\u043A\u0430\u0437\u0430\u0442\u0438, \u044F\u043A \u0431\u043E\u0442 \u043F\u0440\u0430\u0446\u044E\u0454 \u0439 \u043D\u0430\u0432\u0447\u0430\u0454\u0442\u044C\u0441\u044F.` : `\u0414\u0435\u043C\u043E: \u0434\u0435\u043D\u044C ${state3.lastBarDate}.`;
}
function nextRunAt(decisionTimeUtc, now = /* @__PURE__ */ new Date()) {
  const [h, m] = decisionTimeUtc.split(":").map(Number);
  const t = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), h, m));
  if (t <= now) t.setUTCDate(t.getUTCDate() + 1);
  return t.toISOString();
}
function publicState(state3, cfg2, extra = {}) {
  const prices = state3.latest ? Object.fromEntries(PAIRS.map((p) => [p.id, state3.latest.technical[p.id].close])) : null;
  const positions = Object.fromEntries(Object.entries(state3.positions).map(([id, p]) => [id, {
    ...p,
    unrealizedUsd: prices ? unrealizedUsd(p, prices[id], quoteToUsd(id, prices)) : 0
  }]));
  return {
    mode: state3.mode,
    account: state3.account,
    positions,
    equity: prices ? equityUsd(state3, prices) : state3.account.cash,
    trades: state3.trades.slice(-60),
    equityCurve: state3.equityCurve,
    journal: state3.journal.slice(-120),
    weights: state3.weights,
    weightHistory: state3.weightHistory.slice(-300),
    latest: state3.latest,
    runs: state3.runs.slice(-10),
    lastBarDate: state3.lastBarDate,
    nextRunAt: nextRunAt(cfg2.decisionTimeUtc),
    config: {
      decisionTimeUtc: cfg2.decisionTimeUtc,
      riskPerTradePct: cfg2.riskPerTradePct,
      maxLeverage: cfg2.maxLeverage,
      maxDrawdownPct: cfg2.maxDrawdownPct,
      stopAtr: cfg2.stopAtr,
      takeAtr: cfg2.takeAtr,
      minScore: cfg2.minScore,
      startEquity: cfg2.startEquity,
      model: cfg2.liveAi ? cfg2.claudeModel : null
    },
    ...extra
  };
}

// lib/demo-analyst.mjs
var CUR_WORDS = { USD: ["\u0424\u0420\u0421", "\u0421\u0428\u0410"], EUR: ["\u0404\u0426\u0411", "\u0454\u0432\u0440\u043E\u0437\u043E\u043D", "\u041D\u0456\u043C\u0435\u0447\u0447\u0438\u043D"], GBP: ["\u0411\u0430\u043D\u043A \u0410\u043D\u0433\u043B\u0456\u0457", "\u0411\u0440\u0438\u0442\u0430\u043D"] };
var POS = ["\u0436\u043E\u0440\u0441\u0442\u043A\u0456\u0448\u0435", "\u043F\u0456\u0434\u0432\u0438\u0449\u0435\u043D\u043D\u044F", "\u0432\u0438\u0449\u0430", "\u0437\u0440\u0456\u0441", "\u0440\u043E\u0441\u0442\u0443\u0442\u044C", "\u0434\u043E\u0432\u0448\u0435 \u0432\u0438\u0441\u043E\u043A\u0456", "\u043F\u0440\u0438\u0441\u043A\u043E\u0440\u0438\u043B\u0430\u0441\u044F", "\u0431\u0456\u043B\u044C\u0448\u0435, \u043D\u0456\u0436 \u0447\u0435\u043A\u0430\u043B\u0438"];
var NEG = ["\u0437\u043D\u0438\u0436\u0435\u043D\u043D\u044F", "\u0437\u043D\u0438\u0436\u0443\u0432\u0430\u0442\u0438", "\u0441\u043B\u0430\u0431\u0448\u0430\u0454", "\u0440\u043E\u0437\u0447\u0430\u0440\u0443\u0432\u0430\u043B\u0438", "\u0441\u043A\u043E\u0440\u043E\u0447\u0443\u0454\u0442\u044C\u0441\u044F", "\u0441\u043F\u043E\u0432\u0456\u043B\u044C\u043D\u0438\u043B\u0430\u0441\u044F", "\u0441\u0442\u0430\u0433\u043D\u0443\u0454", "\u043D\u0438\u0436\u0447\u0430"];
function analyzeDemo({ headlines }) {
  const score = { USD: 0, EUR: 0, GBP: 0 }, hits = { USD: [], EUR: [], GBP: [] };
  for (const h of headlines) {
    const text = `${h.source} ${h.title}`;
    const cur = Object.keys(CUR_WORDS).find((c) => CUR_WORDS[c].some((w) => text.includes(w)));
    if (!cur) continue;
    const s = NEG.some((w) => h.title.includes(w)) ? -1 : POS.some((w) => h.title.includes(w)) ? 1 : 0;
    if (!s) continue;
    score[cur] += s;
    hits[cur].push(`${s > 0 ? "\u25B2" : "\u25BC"} ${cur}: ${h.title}`);
  }
  const pairs = {};
  for (const p of PAIRS) {
    const diff = score[p.base] - score[p.quote];
    const drivers = [...hits[p.base], ...hits[p.quote]];
    pairs[p.id] = {
      bias: Math.tanh(diff * 0.8),
      confidence: drivers.length ? Math.min(0.9, 0.35 + 0.2 * drivers.length) : 0.05,
      eventRisk: false,
      reasoning: drivers.length ? `\u041D\u043E\u0432\u0438\u043D\u0438 ${diff > 0 ? `\u043D\u0430 \u043A\u043E\u0440\u0438\u0441\u0442\u044C ${p.base}` : diff < 0 ? `\u043D\u0430 \u043A\u043E\u0440\u0438\u0441\u0442\u044C ${p.quote}` : "\u0441\u0443\u043F\u0435\u0440\u0435\u0447\u043B\u0438\u0432\u0456"}: ${drivers.length} \u0440\u0435\u043B\u0435\u0432\u0430\u043D\u0442\u043D. \u0437\u0430\u0433\u043E\u043B\u043E\u0432\u043A. (\u0434\u0435\u043C\u043E-\u0430\u043D\u0430\u043B\u0456\u0442\u0438\u043A, \u0441\u043B\u043E\u0432\u043D\u0438\u043A\u043E\u0432\u0438\u0439 \u043C\u0435\u0442\u043E\u0434).` : "\u041D\u043E\u0432\u0438\u0445 \u0440\u0435\u043B\u0435\u0432\u0430\u043D\u0442\u043D\u0438\u0445 \u043D\u043E\u0432\u0438\u043D \u043D\u0435\u043C\u0430\u0454, \u043F\u043E\u0437\u0438\u0446\u0456\u044F \u043D\u0435\u0439\u0442\u0440\u0430\u043B\u044C\u043D\u0430 (\u0434\u0435\u043C\u043E-\u0430\u043D\u0430\u043B\u0456\u0442\u0438\u043A).",
      drivers
    };
  }
  const total = Object.values(hits).reduce((s, h) => s + h.length, 0);
  return { ok: true, source: "\u0434\u0435\u043C\u043E-\u0430\u043D\u0430\u043B\u0456\u0442\u0438\u043A", summary: `\u0414\u0435\u043C\u043E-\u0440\u0435\u0436\u0438\u043C: \u043E\u0446\u0456\u043D\u0435\u043D\u043E ${headlines.length} \u0437\u0430\u0433\u043E\u043B\u043E\u0432\u043A., ${total} \u0441\u0442\u043E\u0441\u0443\u044E\u0442\u044C\u0441\u044F USD/EUR/GBP. \u041F\u0456\u0434\u043A\u043B\u044E\u0447\u0456\u0442\u044C ANTHROPIC_API_KEY, \u0449\u043E\u0431 \u0430\u043D\u0430\u043B\u0456\u0437\u0443\u0432\u0430\u0432 Claude.`, pairs };
}

// web/local-api.mjs
var cfg = {
  liveData: false,
  liveAi: false,
  claudeModel: null,
  decisionTimeUtc: "00:20",
  startEquity: 1e4,
  riskPerTradePct: 1,
  maxLeverage: 1,
  maxDrawdownPct: 10,
  stopAtr: 1.5,
  takeAtr: 3,
  minScore: 0.15
};
var KEY = "pulse-fx-web-demo-v1";
function load() {
  try {
    const s = JSON.parse(localStorage.getItem(KEY));
    if (s && s.version === STATE_VERSION) return s;
  } catch {
  }
  return null;
}
function save(s) {
  try {
    localStorage.setItem(KEY, JSON.stringify(s));
  } catch {
  }
}
var state = load();
async function step() {
  state ??= freshState(cfg);
  const run = { at: (/* @__PURE__ */ new Date()).toISOString(), ok: true, note: "", errors: [] };
  run.note = await advanceDemo(state, cfg, async (input) => analyzeDemo(input));
  state.runs.push(run);
  if (state.runs.length > 60) state.runs.shift();
  save(state);
}
var view = () => publicState(state, cfg, { webDemo: true });
globalThis.PULSE_FX_API = {
  async state() {
    if (!state) await step();
    return view();
  },
  async run() {
    await step();
    return view();
  }
};

// public/app.mjs
var $ = (id) => document.getElementById(id);
var PAIRS2 = ["EUR/USD", "GBP/USD", "EUR/GBP"];
var state2 = null;
var api = globalThis.PULSE_FX_API ?? {
  state: async () => (await fetch("/api/state")).json(),
  run: async () => (await fetch("/api/run", { method: "POST", headers: { "X-Pulse-FX": "1" } })).json()
};
var esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
var usd = (v, d = 2) => (v < 0 ? "\u2212" : "") + "$" + Math.abs(v).toLocaleString("en-US", { minimumFractionDigits: d, maximumFractionDigits: d });
var sgnUsd = (v) => (v >= 0 ? "+" : "\u2212") + "$" + Math.abs(v).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
var pct = (v, d = 2) => (v >= 0 ? "+" : "\u2212") + Math.abs(v).toFixed(d) + "%";
var num = (v, d = 2) => (v >= 0 ? "+" : "\u2212") + Math.abs(v).toFixed(d);
var cls = (v) => v > 0 ? "up" : v < 0 ? "dn" : "flat";
var fmtLocal = (iso) => new Date(iso).toLocaleString("uk-UA", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });
function lineChart(el, points, { color = "#ff8a96", base = null, fill = true, labels = true, fmt = (v) => usd(v) } = {}) {
  if (!points.length) {
    el.innerHTML = '<div class="empty">\u0429\u0435 \u043D\u0435\u043C\u0430\u0454 \u0434\u0430\u043D\u0438\u0445</div>';
    return;
  }
  const W = el.clientWidth || 600, H = el.clientHeight || 160, pb = labels ? 16 : 2;
  const vals = points.map((p) => p.v);
  let lo = Math.min(...vals, base ?? Infinity), hi = Math.max(...vals, base ?? -Infinity);
  const pad = (hi - lo) * 0.1 || Math.abs(hi) * 1e-3 || 1;
  lo -= pad;
  hi += pad;
  const x = (i) => points.length === 1 ? W / 2 : i / (points.length - 1) * W, y = (v) => H - pb - (v - lo) / (hi - lo) * (H - pb - 4);
  const d = points.map((p, i) => `${i ? "L" : "M"}${x(i).toFixed(1)},${y(p.v).toFixed(1)}`).join("");
  const gid = "g" + Math.random().toString(36).slice(2, 8);
  el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">
    <defs><linearGradient id="${gid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${color}" stop-opacity=".35"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></linearGradient></defs>
    ${base != null ? `<line x1="0" x2="${W}" y1="${y(base)}" y2="${y(base)}" stroke="rgba(255,255,255,.18)" stroke-dasharray="3 4"/>` : ""}
    ${fill ? `<path d="${d}L${x(points.length - 1)},${H - pb}L0,${H - pb}Z" fill="url(#${gid})"/>` : ""}
    <path d="${d}" fill="none" stroke="${color}" stroke-width="2"/>
    <circle cx="${x(points.length - 1)}" cy="${y(points.at(-1).v)}" r="3.5" fill="#fff" stroke="${color}" stroke-width="2"/>
    ${labels ? `<text x="0" y="${H - 2}" fill="#7a5560" font-size="10" font-family="monospace">${esc(points[0].label)}</text>
    <text x="${W}" y="${H - 2}" fill="#7a5560" font-size="10" font-family="monospace" text-anchor="end">${esc(points.at(-1).label)}</text>` : ""}
  </svg>`;
  const tip = $("tip");
  el.onmousemove = (e) => {
    const r = el.getBoundingClientRect();
    const i = Math.round((e.clientX - r.left) / r.width * (points.length - 1));
    const p = points[Math.max(0, Math.min(points.length - 1, i))];
    tip.textContent = `${p.label} \xB7 ${fmt(p.v)}`;
    tip.style.left = e.clientX + 12 + "px";
    tip.style.top = e.clientY - 28 + "px";
    tip.style.opacity = 1;
  };
  el.onmouseleave = () => {
    tip.style.opacity = 0;
  };
}
function decisionChip(action) {
  const a = action || "\u0447\u0435\u043A\u0430\u0442\u0438";
  const kind = a.includes("\u043A\u0443\u043F\u0438\u0442\u0438") ? "buy" : a.includes("\u043F\u0440\u043E\u0434\u0430\u0442\u0438") ? "sell" : a === "\u0442\u0440\u0438\u043C\u0430\u0442\u0438" ? "hold" : "wait";
  return `<span class="decision ${kind}">${esc(a.toUpperCase())}</span>`;
}
function render() {
  const s = state2;
  const live = s.mode.data === "live";
  $("modeData").className = "chip " + (live ? "live" : "demo");
  $("modeData").textContent = live ? "\u0414\u0430\u043D\u0456: Twelve Data" : "\u0414\u0430\u043D\u0456: \u0414\u0415\u041C\u041E";
  $("modeAi").className = "chip " + (s.mode.ai === "claude" ? "live" : "demo");
  $("modeAi").textContent = s.mode.ai === "claude" ? `\u0428\u0406: Claude` : "\u0428\u0406: \u0434\u0435\u043C\u043E-\u0430\u043D\u0430\u043B\u0456\u0442\u0438\u043A";
  $("lastBar").textContent = `\u0421\u0432\u0456\u0447\u043A\u0430: ${s.lastBarDate ?? "\u2014"}`;
  $("nextRun").textContent = `\u041D\u0430\u0441\u0442\u0443\u043F\u043D\u0435 \u0440\u0456\u0448\u0435\u043D\u043D\u044F: ${fmtLocal(s.nextRunAt)}`;
  $("nextRun").hidden = !!s.webDemo;
  $("runBtn").textContent = live ? "\u0417\u0430\u043F\u0443\u0441\u0442\u0438\u0442\u0438 \u0446\u0438\u043A\u043B \u0437\u0430\u0440\u0430\u0437" : "\u041D\u0430\u0441\u0442\u0443\u043F\u043D\u0438\u0439 \u0434\u0435\u043D\u044C (\u0434\u0435\u043C\u043E) \u25B6";
  const lastRun = s.runs.at(-1);
  const banner = $("banner");
  const msgs = [];
  if (s.webDemo) msgs.push("\u0411\u0440\u0430\u0443\u0437\u0435\u0440\u043D\u0430 \u0434\u0435\u043C\u043E-\u0432\u0435\u0440\u0441\u0456\u044F: \u043A\u0443\u0440\u0441\u0438 \u0439 \u043D\u043E\u0432\u0438\u043D\u0438 \u0437\u0433\u0435\u043D\u0435\u0440\u043E\u0432\u0430\u043D\u0456, \u0431\u043E\u0442 \u043F\u0440\u0430\u0446\u044E\u0454 \u043F\u0440\u044F\u043C\u043E \u043D\u0430 \u0446\u0456\u0439 \u0441\u0442\u043E\u0440\u0456\u043D\u0446\u0456, \u0430 \u043A\u043D\u043E\u043F\u043A\u0430 \xAB\u041D\u0430\u0441\u0442\u0443\u043F\u043D\u0438\u0439 \u0434\u0435\u043D\u044C\xBB \u043F\u0440\u043E\u043A\u0440\u0443\u0447\u0443\u0454 \u043E\u0434\u0438\u043D \u0442\u043E\u0440\u0433\u043E\u0432\u0438\u0439 \u0434\u0435\u043D\u044C. \u0423 \u0434\u0435\u043C\u043E-\u0441\u0432\u0456\u0442\u0456 \u043D\u043E\u0432\u0438\u043D\u0438 \u043D\u0430\u0432\u043C\u0438\u0441\u043D\u043E \u0442\u0440\u043E\u0445\u0438 \u0432\u043F\u043B\u0438\u0432\u0430\u044E\u0442\u044C \u043D\u0430 \u043A\u0443\u0440\u0441, \u0449\u043E\u0431 \u0431\u0443\u043B\u043E \u0432\u0438\u0434\u043D\u043E \u043D\u0430\u0432\u0447\u0430\u043D\u043D\u044F; \u043D\u0430 \u0441\u043F\u0440\u0430\u0432\u0436\u043D\u044C\u043E\u043C\u0443 \u0440\u0438\u043D\u043A\u0443 \u0432\u0441\u0435 \u0441\u043A\u043B\u0430\u0434\u043D\u0456\u0448\u0435. \u0421\u043F\u0440\u0430\u0432\u0436\u043D\u0456 \u0434\u0430\u043D\u0456 \u0439 Claude \u2014 \u0443 \u0432\u0435\u0440\u0441\u0456\u0457, \u0449\u043E \u0437\u0430\u043F\u0443\u0441\u043A\u0430\u0454\u0442\u044C\u0441\u044F \u043D\u0430 \u043A\u043E\u043C\u043F\u2019\u044E\u0442\u0435\u0440\u0456 (node server.mjs).");
  else if (!live) msgs.push("\u0414\u0435\u043C\u043E-\u0440\u0435\u0436\u0438\u043C: \u043A\u0443\u0440\u0441\u0438 \u0439 \u043D\u043E\u0432\u0438\u043D\u0438 \u0437\u0433\u0435\u043D\u0435\u0440\u043E\u0432\u0430\u043D\u0456. \u0423 \u0434\u0435\u043C\u043E-\u0441\u0432\u0456\u0442\u0456 \u043D\u043E\u0432\u0438\u043D\u0438 \u043D\u0430\u0432\u043C\u0438\u0441\u043D\u043E \u0442\u0440\u043E\u0445\u0438 \u0432\u043F\u043B\u0438\u0432\u0430\u044E\u0442\u044C \u043D\u0430 \u043A\u0443\u0440\u0441, \u0449\u043E\u0431 \u0431\u0443\u043B\u043E \u0432\u0438\u0434\u043D\u043E \u043D\u0430\u0432\u0447\u0430\u043D\u043D\u044F; \u043D\u0430 \u0441\u043F\u0440\u0430\u0432\u0436\u043D\u044C\u043E\u043C\u0443 \u0440\u0438\u043D\u043A\u0443 \u0432\u0441\u0435 \u0441\u043A\u043B\u0430\u0434\u043D\u0456\u0448\u0435. \u0414\u043E\u0434\u0430\u0439\u0442\u0435 \u043A\u043B\u044E\u0447\u0456 \u0443 \u0444\u0430\u0439\u043B .env, \u0449\u043E\u0431 \u043F\u0435\u0440\u0435\u0439\u0442\u0438 \u043D\u0430 \u0441\u043F\u0440\u0430\u0432\u0436\u043D\u0456 \u0434\u0430\u043D\u0456.");
  if (s.account.pausedUntil) msgs.push("Guard: " + s.account.pauseReason);
  if (lastRun?.errors?.length) msgs.push("\u041F\u0440\u043E\u0431\u043B\u0435\u043C\u0438 \u043E\u0441\u0442\u0430\u043D\u043D\u044C\u043E\u0433\u043E \u0437\u0430\u043F\u0443\u0441\u043A\u0443: " + lastRun.errors.join("; "));
  banner.hidden = !msgs.length;
  banner.className = "banner" + (lastRun && (!lastRun.ok || lastRun.errors.length) ? " err" : "");
  banner.innerHTML = msgs.map(esc).join("<br>");
  const eq = s.equity, start = s.account.startEquity, ret = (eq / start - 1) * 100;
  const [w, f] = eq.toFixed(2).split(".");
  $("eqBig").innerHTML = `$${Number(w).toLocaleString("en-US")}<small>.${f}</small>`;
  $("eqRet").textContent = `${sgnUsd(eq - start)} (${pct(ret)})`;
  $("eqRet").className = "eq-ret " + cls(ret);
  $("eqSub").textContent = `\u0441\u0442\u0430\u0440\u0442 ${usd(start, 0)} \xB7 ${s.equityCurve.length} \u0442\u043E\u0440\u0433. \u0434\u043D\u0456\u0432`;
  lineChart($("eqChart"), s.equityCurve.map((p) => ({ v: p.equity, label: p.date })), { base: start });
  let peak = start, mdd = 0;
  for (const p of s.equityCurve) {
    peak = Math.max(peak, p.equity);
    mdd = Math.max(mdd, (peak - p.equity) / peak * 100);
  }
  const wins = s.trades.filter((t) => t.pnlUsd > 0).length;
  const gross = s.latest?.gross ?? 0;
  $("kpis").innerHTML = [
    ["\u0423\u0433\u043E\u0434 \u0437\u0430\u043A\u0440\u0438\u0442\u043E", `${s.trades.length}`],
    ["\u041F\u0440\u0438\u0431\u0443\u0442\u043A\u043E\u0432\u0438\u0445", s.trades.length ? `${(wins / s.trades.length * 100).toFixed(0)}%` : "\u2014"],
    ["\u041C\u0430\u043A\u0441. \u043F\u0440\u043E\u0441\u0430\u0434\u043A\u0430", `\u2212${mdd.toFixed(1)}%`],
    ["\u0412\u0456\u0434\u043A\u0440\u0438\u0442\u043E \u043F\u043E\u0437\u0438\u0446\u0456\u0439", `${Object.keys(s.positions).length}`],
    ["\u041F\u043B\u0435\u0447\u0435 \u0437\u0430\u0440\u0430\u0437", `${(gross / Math.max(eq, 1)).toFixed(2)}\xD7 / ${s.config.maxLeverage}\xD7`]
  ].map(([k, v]) => `<div class="kpi"><small>${k}</small><b>${v}</b></div>`).join("");
  const st = s.latest?.stats;
  $("learnSub").textContent = st ? `\u043E\u0446\u0456\u043D\u0435\u043D\u043E \u0440\u0456\u0448\u0435\u043D\u044C: ${st.evaluated}` : "";
  $("weights").innerHTML = [["\u0422\u0435\u0445\u043D\u0456\u0447\u043D\u0438\u0439 \u0430\u043D\u0430\u043B\u0456\u0437", s.weights.quant, "var(--blu)"], ["\u041D\u043E\u0432\u0438\u043D\u0438 (\u0428\u0406)", s.weights.news, "var(--vio)"]].map(([k, v, c2]) => `<div class="wrow"><div class="lbl"><span>${k}</span><b>${(v * 100).toFixed(0)}%</b></div><div class="bar"><i style="width:${v * 100}%;background:${c2}"></i></div></div>`).join("");
  lineChart($("wChart"), s.weightHistory.map((p) => ({ v: p.news, label: p.date })), { color: "#a78bfa", base: 0.5, labels: false, fmt: (v) => `\u0432\u0430\u0433\u0430 \u043D\u043E\u0432\u0438\u043D ${(v * 100).toFixed(0)}%` });
  const hr = (x) => x?.hitRate == null ? "\u2014" : `${(x.hitRate * 100).toFixed(0)}%`;
  $("hits").innerHTML = st ? [["\u0422\u0435\u0445. \u0432\u0433\u0430\u0434\u0443\u0454", st.quant], ["\u041D\u043E\u0432\u0438\u043D\u0438 \u0432\u0433\u0430\u0434\u0443\u044E\u0442\u044C", st.news], ["\u0423\u0433\u043E\u0434\u0438 \u0432\u0433\u0430\u0434\u0443\u044E\u0442\u044C", st.final]].map(([k, x]) => `<div class="hit"><small>${k}</small><b>${hr(x)}</b><small>\u0437 ${x.n}</small></div>`).join("") : "";
  const L = s.latest;
  $("pairs").innerHTML = PAIRS2.map((id) => {
    if (!L) return `<div class="pair"><div class="pair-h"><b>${id}</b></div><div class="empty">\u0429\u0435 \u043D\u0435 \u0431\u0443\u043B\u043E \u0436\u043E\u0434\u043D\u043E\u0433\u043E \u0446\u0438\u043A\u043B\u0443</div></div>`;
    const t = L.technical[id], pl = L.plans[id], pos = s.positions[id];
    const markerPos = (Math.max(-1, Math.min(1, pl.score)) + 1) / 2 * 100;
    const thr = s.config.minScore;
    const posHtml = pos ? `<div class="pos">${pos.dir > 0 ? "LONG (\u043A\u0443\u043F\u0456\u0432\u043B\u044F)" : "SHORT (\u043F\u0440\u043E\u0434\u0430\u0436)"} ${Math.round(pos.units).toLocaleString("en-US")} \u043E\u0434. @ ${pos.entry.toFixed(5)}<br>
         P&amp;L: <span class="${cls(pos.unrealizedUsd)}">${sgnUsd(pos.unrealizedUsd)}</span> \xB7 \u0441\u0442\u043E\u043F ${pos.stop.toFixed(5)} \xB7 \u0442\u0435\u0439\u043A ${pos.take.toFixed(5)}</div>` : '<div class="pos">\u041F\u043E\u0437\u0438\u0446\u0456\u0457 \u043D\u0435\u043C\u0430\u0454</div>';
    return `<div class="pair">
      <div class="pair-h"><b>${id}</b>${decisionChip(L.actions[id])}</div>
      <div class="price">${t.close.toFixed(5)}<small class="${cls(t.changePct)}">${pct(t.changePct)}</small></div>
      <div class="spark" id="spark-${id.replace("/", "")}"></div>
      <div class="score"><div class="lbl"><span>\u041F\u0456\u0434\u0441\u0443\u043C\u043A\u043E\u0432\u0430 \u043E\u0446\u0456\u043D\u043A\u0430</span><b class="${cls(pl.score)}">${num(pl.score)}</b></div>
        <div class="dial"><span class="thr" style="left:${(1 - thr) / 2 * 100}%;width:${thr * 100}%"></span><i style="left:${markerPos}%"></i></div>
        <div class="parts"><span>\u0442\u0435\u0445. ${num(pl.quant)}</span><span>\u043D\u043E\u0432\u0438\u043D\u0438 ${num(pl.news)}</span>${t.rsi != null ? `<span>RSI ${t.rsi.toFixed(0)}</span>` : ""}</div></div>
      <div class="parts" style="font-family:inherit">${esc(t.text)}</div>
      ${posHtml}
      ${pl.guard.length ? `<div class="guard">\u26C9 ${pl.guard.map(esc).join(" \xB7 ")}</div>` : ""}
    </div>`;
  }).join("");
  if (L) for (const id of PAIRS2) {
    const cs = L.market[id];
    lineChart($("spark-" + id.replace("/", "")), cs.map((c2) => ({ v: c2.close, label: c2.date })), { labels: false, color: cs.at(-1).close >= cs[0].close ? "#3ee08f" : "#ff6b7d", fmt: (v) => v.toFixed(5) });
  }
  const A = L?.analysis;
  $("aiSub").textContent = A ? `${A.source}${L ? " \xB7 " + L.date : ""}` : "";
  $("aiSummary").textContent = A?.summary || "\u0410\u043D\u0430\u043B\u0456\u0437\u0443 \u0449\u0435 \u043D\u0435\u043C\u0430\u0454.";
  $("aiPairs").innerHTML = A ? PAIRS2.map((id) => {
    const a = A.pairs[id];
    return `<div class="aipair"><div class="aipair-h"><b>${id}</b><span class="tag ${cls(a.bias)}">\u043D\u0430\u0445\u0438\u043B ${num(a.bias)}</span><span class="tag">\u0432\u043F\u0435\u0432\u043D\u0435\u043D\u0456\u0441\u0442\u044C ${(a.confidence * 100).toFixed(0)}%</span>${a.eventRisk ? '<span class="tag risk">\u0432\u0430\u0436\u043B\u0438\u0432\u0430 \u043F\u043E\u0434\u0456\u044F \u043F\u043E\u043F\u0435\u0440\u0435\u0434\u0443</span>' : ""}</div>
      <p>${esc(a.reasoning)}</p>${a.drivers.length ? `<ul class="drivers">${a.drivers.map((d) => `<li>${esc(d)}</li>`).join("")}</ul>` : ""}</div>`;
  }).join("") : "";
  const hl = L?.headlines || [];
  $("newsSub").textContent = `${hl.length} \u0437\u0430\u0433\u043E\u043B\u043E\u0432\u043A\u0456\u0432`;
  $("headlines").innerHTML = hl.map((h) => {
    const safe = /^https?:\/\//.test(h.link || "") ? h.link : "";
    return `<li>${safe ? `<a href="${esc(safe)}" target="_blank" rel="noopener noreferrer">${esc(h.title)}</a>` : esc(h.title)}<small>${esc(h.source)} \xB7 ${esc(h.date || "")}</small></li>`;
  }).join("") || '<li class="empty">\u041D\u043E\u0432\u0438\u043D \u043D\u0435\u043C\u0430\u0454</li>';
  $("journalBody").innerHTML = s.journal.slice().reverse().map((e) => {
    const o = e.outcome;
    const res = o ? `<span class="${cls(o.pips)}">${num(o.pips, 0)} \u043F.</span> ${e.dir ? o.finalRight ? "\u2713" : "\u2717" : ""}` : '<span class="flat">\u043E\u0447\u0456\u043A\u0443\u0454</span>';
    return `<tr><td>${e.date}</td><td>${e.pair}</td><td>${esc(e.action)}</td><td class="${cls(e.score)}">${num(e.score)}</td><td>${num(e.quant)}</td><td>${num(e.news)}</td><td>${res}</td></tr>`;
  }).join("") || '<tr><td colspan="7" class="empty">\u041F\u043E\u0440\u043E\u0436\u043D\u044C\u043E</td></tr>';
  const pnl = s.trades.reduce((a, t) => a + t.pnlUsd, 0);
  $("tradesSub").textContent = s.trades.length ? `\u0440\u0430\u0437\u043E\u043C ${sgnUsd(pnl)}` : "";
  $("tradesBody").innerHTML = s.trades.slice().reverse().map((t) => `<tr><td>${t.closedAt}</td><td>${t.pair}</td><td>${t.dir > 0 ? "LONG" : "SHORT"}</td><td class="${cls(t.pips)}">${num(t.pips, 1)}</td><td class="${cls(t.pnlUsd)}">${sgnUsd(t.pnlUsd)}</td><td class="txt">${esc(t.reason)}</td></tr>`).join("") || '<tr><td colspan="6" class="empty">\u0423\u0433\u043E\u0434 \u0449\u0435 \u043D\u0435\u043C\u0430\u0454</td></tr>';
  const c = s.config;
  $("rules").innerHTML = `<div class="rules-grid">${[
    ["\u0420\u0438\u0437\u0438\u043A \u043D\u0430 \u0443\u0433\u043E\u0434\u0443", `${c.riskPerTradePct}% \u043A\u0430\u043F\u0456\u0442\u0430\u043B\u0443`],
    ["\u041C\u0430\u043A\u0441. \u043F\u043B\u0435\u0447\u0435", `${c.maxLeverage}\xD7`],
    ["\u0410\u0432\u0430\u0440\u0456\u0439\u043D\u0430 \u0437\u0443\u043F\u0438\u043D\u043A\u0430", `\u043F\u0440\u043E\u0441\u0430\u0434\u043A\u0430 ${c.maxDrawdownPct}%`],
    ["\u0421\u0442\u043E\u043F-\u043B\u043E\u0441\u0441", `${c.stopAtr} \xD7 ATR`],
    ["\u0422\u0435\u0439\u043A-\u043F\u0440\u043E\u0444\u0456\u0442", `${c.takeAtr} \xD7 ATR`],
    ["\u041F\u043E\u0440\u0456\u0433 \u0432\u0445\u043E\u0434\u0443", `|\u043E\u0446\u0456\u043D\u043A\u0430| > ${c.minScore}`],
    ["\u0420\u0456\u0448\u0435\u043D\u043D\u044F", `\u0449\u043E\u0434\u043D\u044F ${c.decisionTimeUtc} UTC`],
    ["\u041C\u043E\u0434\u0435\u043B\u044C \u0428\u0406", c.model || "\u0434\u0435\u043C\u043E-\u0430\u043D\u0430\u043B\u0456\u0442\u0438\u043A"]
  ].map(([k, v]) => `<div class="rule"><small>${k}</small><b>${esc(v)}</b></div>`).join("")}</div>`;
  $("runs").innerHTML = s.runs.slice().reverse().map((r) => `<div class="${r.ok && !r.errors.length ? "" : "bad"}">${fmtLocal(r.at)} \xB7 ${r.ok ? "OK" : "\u041F\u041E\u041C\u0418\u041B\u041A\u0410"} \xB7 ${esc(r.note)} ${esc(r.errors.join("; "))}</div>`).join("");
}
async function load2() {
  state2 = await api.state();
  render();
}
$("runBtn").addEventListener("click", async () => {
  const b = $("runBtn");
  b.disabled = true;
  const old = b.textContent;
  b.textContent = "\u041F\u0440\u0430\u0446\u044E\u044E\u2026";
  try {
    state2 = await api.run();
    render();
  } catch (e) {
    $("banner").hidden = false;
    $("banner").className = "banner err";
    $("banner").textContent = "\u041D\u0435 \u0432\u0434\u0430\u043B\u043E\u0441\u044F \u0437\u0430\u043F\u0443\u0441\u0442\u0438\u0442\u0438 \u0446\u0438\u043A\u043B: " + e.message;
    b.textContent = old;
  } finally {
    b.disabled = false;
  }
});
addEventListener("resize", () => state2 && render());
load2().catch((e) => {
  $("banner").hidden = false;
  $("banner").className = "banner err";
  $("banner").textContent = "\u0421\u0435\u0440\u0432\u0435\u0440 \u043D\u0435\u0434\u043E\u0441\u0442\u0443\u043F\u043D\u0438\u0439: " + e.message;
});
if (!globalThis.PULSE_FX_API) setInterval(() => load2().catch(() => {
}), 6e4);
