// Pulse Terminal — симулятор копітрейдингу (ДЕМО).
// Жодних мережевих запитів, гаманців чи ключів: усі токени, гаманці та угоди вигадані
// й генеруються детермінованим генератором випадкових чисел за seed.
// Модель свідомо «чесна»: у середньому стратегія не має гарантованого плюса,
// ринок мемкоїнів тут волатильний, з рагпулами, прослизанням і комісіями.

export const STEP_SECONDS = 5; // один крок симуляції = 5 секунд ринкового часу
export const TRACKED_WALLETS = 512;

export const DEFAULT_RULES = Object.freeze({
  minLiquidityK: 25,      // мін. ліквідність пулу, тис. $
  maxTopHolderPct: 20,    // макс. частка найбільшого холдера, %
  minWalletWinRate: 55,   // мін. win rate гаманця, якого копіюємо, %
  positionPct: 10,        // розмір позиції, % від капіталу
  takeProfitPct: 45,      // тейк-профіт, %
  stopLossPct: 8,         // стоп-лосс, %
  trailingPct: 15,        // трейлінг від піку прибутку, %
  maxOpen: 5,             // макс. відкритих позицій
});

// Додатковий дрейф ціни за крок для «настрою ринку».
export const MOODS = Object.freeze({ bear: -0.0016, neutral: 0, bull: 0.0016 });

const SYMBOLS = ['LUMI', 'PIZZA', 'ONBOARD', 'MONEKO', 'AI', 'KAIJU', 'ZENKO', 'MOCHI', 'SPRK', 'BLIP',
  'ICOIN', 'ZAPCAT', 'NUBI', 'GRAVY', 'DINKY', 'BEANZ', 'CHOMPY', 'DUSTY', 'RIZZLE', 'SQUID', 'TOFU',
  'WOBL', 'NOVA', 'PEPO', 'GLIMR', 'HONK', 'YETI', 'FIZZ', 'ORBIT', 'MUNCH', 'KOI', 'BAMBU', 'FROGO',
  'QUOKKA', 'SNEK', 'TURBO', 'WAFL', 'CRUMB', 'ZIGGY', 'PUDDL'];
const HUES = [0, 18, 36, 140, 160, 190, 210, 260, 280, 300, 330];
const B58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
const ANALYST_CHECKS = [
  ['mintRevoked', 'mint authority не відкликано'],
  ['freezeRevoked', 'freeze authority активна'],
  ['lpLocked', 'LP не заблоковано'],
  ['sellable', 'honeypot: продаж неможливий'],
  ['devOk', 'dev тримає забагато'],
  ['bundleOk', 'бандл-снайпери на старті'],
];
const SUPPLY = 1e9;

export function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function gauss(rnd) {
  const u = Math.max(rnd(), 1e-12);
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * rnd());
}
const pick = (rnd, arr) => arr[Math.floor(rnd() * arr.length)];
const between = (rnd, a, b) => a + (b - a) * rnd();
const addr = (rnd) => Array.from({ length: 4 }, () => pick(rnd, B58)).join('') + '…' + Array.from({ length: 4 }, () => pick(rnd, B58)).join('');

function newToken(s) {
  const { rnd } = s;
  const used = new Set(s.tokens.map((t) => t.symbol));
  const free = SYMBOLS.filter((x) => !used.has(x));
  const symbol = free.length ? pick(rnd, free) : 'T' + Math.floor(rnd() * 9999);
  const mcap = Math.exp(between(rnd, Math.log(30e3), Math.log(4e6)));
  const price = mcap / SUPPLY;
  const scam = rnd() < 0.35;
  const checks = {};
  for (const [k] of ANALYST_CHECKS) checks[k] = rnd() > (scam ? 0.45 : 0.06);
  return {
    symbol, hue: pick(rnd, HUES), price, open: price, peak: price,
    liquidityK: Math.max(3, mcap / 1000 * between(rnd, 0.05, 0.35)),
    topHolderPct: scam ? between(rnd, 12, 60) : between(rnd, 2, 24),
    vol: between(rnd, 0.008, 0.03),
    momentum: gauss(rnd) * 0.002,
    rugChance: scam ? between(rnd, 0.0006, 0.002) : between(rnd, 0.00002, 0.0002),
    checks, alive: true, bornAt: s.t,
  };
}

function newWallet(rnd) {
  const skill = Math.min(0.98, Math.max(0.02, between(rnd, 0.15, 0.9)));
  // Стартова історія: win rate у гаманців різний, у «розумних» трохи вищий.
  const trades = Math.floor(between(rnd, 20, 200));
  const wins = Math.round(trades * Math.min(0.85, Math.max(0.25, 0.32 + skill * 0.4 + gauss(rnd) * 0.06)));
  return { address: addr(rnd), skill, trades, wins, copied: 0, pnlUsd: 0, holding: new Map() };
}

export function createSim(opts = {}) {
  const seed = (opts.seed ?? 42) >>> 0;
  const startUsd = opts.startUsd ?? 100;
  const rules = { ...DEFAULT_RULES, ...(opts.rules || {}) };
  const mood = opts.mood in MOODS ? opts.mood : 'neutral';
  const rnd = mulberry32(seed);
  const s = {
    seed, rnd, rules, mood, startUsd,
    t: 0, startTime: opts.startTime ?? Date.now(),
    solUsd: opts.solUsd ?? 186, cash: startUsd,
    tokens: [], wallets: [], positions: [], closed: [], log: [],
    equity: [{ t: 0, v: startUsd }], peakEquity: startUsd, maxDrawdown: 0,
    counters: { spotted: 0, filtered: 0, analysed: 0, analystKilled: 0, copied: 0, stops: 0, exits: 0 },
    radar: [],
  };
  for (let i = 0; i < 24; i++) s.tokens.push(newToken(s));
  for (let i = 0; i < 48; i++) s.wallets.push(newWallet(rnd));
  return s;
}

function log(s, agent, text, kind = 'info') {
  s.log.push({ t: s.t, agent, text, kind });
  if (s.log.length > 300) s.log.splice(0, s.log.length - 300);
}

export function positionValue(p, tok) {
  return p.qty * tok.price;
}
export function tokenOf(s, symbol) {
  return s.tokens.find((t) => t.symbol === symbol);
}
export function equityNow(s) {
  let v = s.cash;
  for (const p of s.positions) v += positionValue(p, p.token);
  return v;
}

function closePosition(s, p, status, reason) {
  const tok = p.token;
  const slip = tok.alive ? 0.01 + s.rnd() * 0.02 : 0.08;
  const gross = p.qty * tok.price * (1 - slip);
  const proceeds = gross * (1 - 0.003);
  s.cash += proceeds;
  const pnlUsd = proceeds - p.costUsd;
  const closed = { symbol: tok.symbol, hue: tok.hue, costUsd: p.costUsd, pnlUsd, pnlPct: pnlUsd / p.costUsd * 100,
    status, reason, openedAt: p.openedAt, closedAt: s.t, wallet: p.wallet.address };
  s.closed.push(closed);
  if (s.closed.length > 400) s.closed.shift();
  s.positions.splice(s.positions.indexOf(p), 1);
  p.wallet.pnlUsd += pnlUsd;
  const sign = pnlUsd >= 0 ? '+' : '−';
  const agent = status === 'EXIT' ? 'SNIPER' : 'GUARD';
  log(s, agent, `${status === 'EXIT' ? 'sold' : status === 'TP' ? 'take profit' : 'stop'} $${tok.symbol} ${sign}$${Math.abs(pnlUsd).toFixed(2)} · ${reason}`, pnlUsd >= 0 ? 'win' : 'loss');
  if (status === 'STOP') s.counters.stops++;
  else s.counters.exits++;
}

function marketStep(s) {
  const { rnd } = s;
  const moodDrift = MOODS[s.mood];
  s.solUsd *= Math.exp(gauss(rnd) * 0.0008);
  for (const tok of s.tokens) {
    if (!tok.alive) continue;
    if (rnd() < 0.01) tok.momentum = tok.momentum * 0.4 + gauss(rnd) * 0.002;
    // Мемкоїни в середньому згасають: базовий дрейф від'ємний.
    let r = -0.001 + moodDrift + tok.momentum + gauss(rnd) * tok.vol;
    if (rnd() < 0.0025) r += between(rnd, 0.15, 0.6); // памп
    if (rnd() < 0.002) r -= between(rnd, 0.1, 0.3);   // злив
    tok.price *= Math.exp(r);
    tok.peak = Math.max(tok.peak, tok.price);
    tok.liquidityK = Math.max(1, tok.liquidityK * Math.exp(r * 0.5));
    if (rnd() < tok.rugChance) {
      tok.price *= between(rnd, 0.02, 0.12);
      tok.alive = false;
      tok.diedAt = s.t;
      log(s, 'SCOUT', `rug: $${tok.symbol} LP вилучено`, 'loss');
    }
  }
  // Мертві токени поступово замінюються новими.
  for (let i = 0; i < s.tokens.length; i++) {
    const tok = s.tokens[i];
    if (!tok.alive && s.t - tok.diedAt > 60 && !s.positions.some((p) => p.token === tok)) {
      s.tokens[i] = newToken(s);
      log(s, 'SCOUT', `новий пул $${s.tokens[i].symbol} · mcap $${fmtK(s.tokens[i].price * SUPPLY)}`);
    }
  }
}

function walletActivity(s) {
  const { rnd, rules } = s;
  // Гаманці продають свої позиції — копія виходить слідом.
  for (const w of s.wallets) {
    for (const [sym, h] of w.holding) {
      const tok = tokenOf(s, sym);
      const done = !tok || !tok.alive || tok.price >= h.entry * between(rnd, 1.3, 3) || tok.price <= h.entry * 0.7 || rnd() < 0.004;
      if (!done) continue;
      w.holding.delete(sym);
      w.trades++;
      if (tok && tok.price > h.entry) w.wins++;
      const p = s.positions.find((x) => x.wallet === w && x.token === tok);
      if (p) closePosition(s, p, 'EXIT', `гаманець ${w.address} вийшов`);
    }
  }

  if (rnd() > 0.55) return;
  const w = pick(rnd, s.wallets);
  const alive = s.tokens.filter((t) => t.alive);
  if (!alive.length) return;
  // «Розумні» гаманці частіше обирають токени з позитивним імпульсом.
  let tok = pick(rnd, alive);
  if (rnd() < w.skill) {
    const best = alive.slice().sort((a, b) => b.momentum - a.momentum).slice(0, 6);
    tok = pick(rnd, best);
  }
  if (w.holding.has(tok.symbol)) return;
  w.holding.set(tok.symbol, { entry: tok.price });
  s.counters.spotted++;
  s.radar.push({ t: s.t, angle: rnd() * Math.PI * 2, dist: 0.25 + rnd() * 0.7, symbol: tok.symbol, copied: false });
  if (s.radar.length > 40) s.radar.shift();
  log(s, 'SCOUT', `spotted $${tok.symbol} · ${w.address} buying`);

  const wr = w.wins / Math.max(1, w.trades) * 100;
  let reason = null;
  if (tok.liquidityK < rules.minLiquidityK) reason = `ліквідність $${tok.liquidityK.toFixed(0)}K < $${rules.minLiquidityK}K`;
  else if (tok.topHolderPct > rules.maxTopHolderPct) reason = `топ-холдер ${tok.topHolderPct.toFixed(0)}% > ${rules.maxTopHolderPct}%`;
  else if (wr < rules.minWalletWinRate) reason = `win rate гаманця ${wr.toFixed(0)}% < ${rules.minWalletWinRate}%`;
  if (reason) {
    s.counters.filtered++;
    log(s, 'FILTER', `killed $${tok.symbol} · ${reason}`, 'muted');
    return;
  }
  s.counters.analysed++;
  const failed = ANALYST_CHECKS.find(([k]) => !tok.checks[k]);
  if (failed) {
    s.counters.analystKilled++;
    log(s, 'ANALYST', `killed $${tok.symbol} · ${failed[1]}`, 'muted');
    return;
  }
  log(s, 'ANALYST', `passed $${tok.symbol} · ${ANALYST_CHECKS.length}/${ANALYST_CHECKS.length} перевірок`, 'ok');

  if (s.positions.length >= rules.maxOpen) { log(s, 'GUARD', `skip $${tok.symbol} · ліміт ${rules.maxOpen} позицій`, 'muted'); return; }
  if (s.positions.some((p) => p.token === tok)) { log(s, 'GUARD', `skip $${tok.symbol} · позиція вже відкрита`, 'muted'); return; }
  const eq = equityNow(s);
  const costUsd = Math.min(s.cash, eq * rules.positionPct / 100);
  if (costUsd < 1) { log(s, 'GUARD', `skip $${tok.symbol} · недостатньо коштів`, 'muted'); return; }
  // Копія заходить пізніше за гаманець: ціна вже зрушила + прослизання + комісія.
  const entry = tok.price * (1 + 0.005 + rnd() * 0.03);
  const qty = costUsd * (1 - 0.003) / entry;
  s.cash -= costUsd;
  w.copied++;
  s.counters.copied++;
  const p = { token: tok, wallet: w, qty, entry, costUsd, openedAt: s.t, peakPct: 0 };
  s.positions.push(p);
  s.radar[s.radar.length - 1].copied = true;
  log(s, 'SNIPER', `copied $${tok.symbol} · ${(costUsd / s.solUsd).toFixed(2)} SOL`, 'ok');
}

function guardStep(s) {
  const { rules } = s;
  for (const p of s.positions.slice()) {
    const tok = p.token;
    const pct = (positionValue(p, tok) / p.costUsd - 1) * 100;
    p.peakPct = Math.max(p.peakPct, pct);
    if (!tok.alive) closePosition(s, p, 'STOP', 'рагпул, аварійний вихід');
    else if (pct <= -rules.stopLossPct) closePosition(s, p, 'STOP', `стоп −${rules.stopLossPct}%`);
    else if (pct >= rules.takeProfitPct) closePosition(s, p, 'TP', `тейк +${rules.takeProfitPct}%`);
    else if (p.peakPct >= rules.trailingPct && p.peakPct - pct >= rules.trailingPct) closePosition(s, p, pct >= 0 ? 'TP' : 'STOP', `трейлінг ${rules.trailingPct}% від піку`);
  }
}

export function step(s) {
  s.t += STEP_SECONDS;
  marketStep(s);
  walletActivity(s);
  guardStep(s);
  const v = equityNow(s);
  s.equity.push({ t: s.t, v });
  if (s.equity.length > 1200) s.equity = s.equity.filter((_, i) => i % 2 === 0 || i === s.equity.length - 1);
  s.peakEquity = Math.max(s.peakEquity, v);
  s.maxDrawdown = Math.max(s.maxDrawdown, (s.peakEquity - v) / s.peakEquity * 100);
}

export function stats(s) {
  const eq = equityNow(s);
  const wins = s.closed.filter((c) => c.pnlUsd > 0).length;
  const losses = s.closed.length - wins;
  const best = s.closed.reduce((b, c) => (!b || c.pnlUsd > b.pnlUsd ? c : b), null);
  return {
    equity: eq, pnlUsd: eq - s.startUsd, pnlPct: (eq / s.startUsd - 1) * 100, multiple: eq / s.startUsd,
    sol: eq / s.solUsd, wins, losses, winRate: s.closed.length ? wins / s.closed.length * 100 : null,
    best, maxDrawdown: s.maxDrawdown, open: s.positions.length, closedCount: s.closed.length,
  };
}

// PnL за токенами: реалізований + нереалізований.
export function pnlByToken(s) {
  const m = new Map();
  const add = (sym, hue, v) => { const e = m.get(sym) || { symbol: sym, hue, pnl: 0 }; e.pnl += v; m.set(sym, e); };
  for (const c of s.closed) add(c.symbol, c.hue, c.pnlUsd);
  for (const p of s.positions) add(p.token.symbol, p.token.hue, positionValue(p, p.token) - p.costUsd);
  return [...m.values()].sort((a, b) => Math.abs(b.pnl) - Math.abs(a.pnl));
}

export function walletWinRate(w) {
  return w.wins / Math.max(1, w.trades) * 100;
}

export function fmtK(v) {
  if (v >= 1e6) return (v / 1e6).toFixed(2) + 'M';
  if (v >= 1e3) return (v / 1e3).toFixed(1) + 'K';
  return v.toFixed(0);
}
export const tokenMcap = (tok) => tok.price * SUPPLY;
export const tokenChangePct = (tok) => (tok.price / tok.open - 1) * 100;
