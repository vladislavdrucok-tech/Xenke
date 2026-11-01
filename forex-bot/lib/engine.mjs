// Віртуальний рахунок, Trader (рішення + розмір позиції) і Guard (ризик-ліміти).
import { PAIRS, PIP } from './config.mjs';
import { clamp } from './indicators.mjs';

const pairInfo = (id) => PAIRS.find((p) => p.id === id);

// Скільки USD коштує 1 одиниця валюти котирування.
export function quoteToUsd(pairId, prices) {
  const q = pairInfo(pairId).quote;
  if (q === 'USD') return 1;
  if (q === 'GBP') return prices['GBP/USD'];
  throw new Error(`невідома валюта котирування ${q}`);
}

export function newAccount(startEquity) {
  return { cash: startEquity, startEquity, peakEquity: startEquity, pausedUntil: null, pauseReason: '' };
}

export const unrealizedUsd = (pos, price, q2u) => pos.dir * (price - pos.entry) * pos.units * q2u;

export function equityUsd(state, prices) {
  let eq = state.account.cash;
  for (const [id, pos] of Object.entries(state.positions)) eq += unrealizedUsd(pos, prices[id], quoteToUsd(id, prices));
  return eq;
}

export function grossNotionalUsd(state, prices) {
  let n = 0;
  for (const [id, pos] of Object.entries(state.positions)) n += pos.units * prices[id] * quoteToUsd(id, prices);
  return n;
}

export function openPosition(state, id, dir, units, price, prices, { date, stop, take, reason }) {
  const spread = pairInfo(id).spread;
  const entry = price + (dir * spread) / 2;
  state.positions[id] = { dir, units, entry, stop, take, openedAt: date, reason };
  return state.positions[id];
}

export function closePosition(state, id, price, prices, { date, reason }) {
  const pos = state.positions[id];
  if (!pos) return null;
  const spread = pairInfo(id).spread;
  const exit = price - (pos.dir * spread) / 2;
  const q2u = quoteToUsd(id, prices);
  const pnl = pos.dir * (exit - pos.entry) * pos.units * q2u;
  state.account.cash += pnl;
  delete state.positions[id];
  const trade = { pair: id, dir: pos.dir, units: Math.round(pos.units), entry: pos.entry, exit, openedAt: pos.openedAt, closedAt: date,
    pnlUsd: pnl, pips: (pos.dir * (exit - pos.entry)) / PIP, reason };
  state.trades.push(trade);
  if (state.trades.length > 500) state.trades.shift();
  return trade;
}

// Прохід нової денної свічки: стопи/тейки за high/low, потім оцінка за close.
export function processBar(state, date, bars, cfg) {
  const closes = Object.fromEntries(Object.entries(bars).map(([id, c]) => [id, c.close]));
  const events = [];
  for (const [id, pos] of Object.entries({ ...state.positions })) {
    const c = bars[id];
    const hitStop = pos.dir > 0 ? c.low <= pos.stop : c.high >= pos.stop;
    const hitTake = pos.dir > 0 ? c.high >= pos.take : c.low <= pos.take;
    // Якщо за день зачеплено і стоп, і тейк — консервативно вважаємо, що спрацював стоп.
    if (hitStop) events.push(closePosition(state, id, pos.dir > 0 ? Math.min(pos.stop, c.open) : Math.max(pos.stop, c.open), closes, { date, reason: 'стоп-лосс' }));
    else if (hitTake) events.push(closePosition(state, id, pos.dir > 0 ? Math.max(pos.take, c.open) : Math.min(pos.take, c.open), closes, { date, reason: 'тейк-профіт' }));
  }
  const eq = equityUsd(state, closes);
  state.account.peakEquity = Math.max(state.account.peakEquity, eq);
  state.equityCurve.push({ date, equity: eq });
  if (state.equityCurve.length > 2000) state.equityCurve.shift();
  // Guard: аварійна зупинка при просадці.
  const dd = (state.account.peakEquity - eq) / state.account.peakEquity * 100;
  if (dd >= cfg.maxDrawdownPct && !state.account.pausedUntil) {
    for (const id of Object.keys(state.positions)) events.push(closePosition(state, id, closes[id], closes, { date, reason: `Guard: просадка ${dd.toFixed(1)}%` }));
    state.account.pausedUntil = addTradingDays(date, 5);
    state.account.pauseReason = `Просадка ${dd.toFixed(1)}% від піку ≥ ${cfg.maxDrawdownPct}%: усі позиції закрито, пауза на 5 торгових днів.`;
  }
  return events.filter(Boolean);
}

export function addTradingDays(date, n) {
  const d = new Date(date + 'T00:00:00Z');
  while (n > 0) { d.setUTCDate(d.getUTCDate() + 1); if (d.getUTCDay() % 6 !== 0) n--; }
  return d.toISOString().slice(0, 10);
}

// Trader + Guard: цільові позиції на основі сигналів.
export function decide(state, cfg, { date, technical, analysis, weights }) {
  const prices = Object.fromEntries(PAIRS.map((p) => [p.id, technical[p.id].close]));
  const equity = equityUsd(state, prices);
  const paused = state.account.pausedUntil && date < state.account.pausedUntil;
  if (state.account.pausedUntil && !paused) {
    state.account.pausedUntil = null; state.account.pauseReason = '';
    state.account.peakEquity = equity; // після паузи відлік просадки з нуля
  }
  const plans = {};
  for (const p of PAIRS) {
    const t = technical[p.id], a = analysis.pairs[p.id];
    const news = a.bias * a.confidence;
    const score = weights.quant * t.score + weights.news * news;
    let dir = score > cfg.minScore ? 1 : score < -cfg.minScore ? -1 : 0;
    const guard = [];
    if (paused) { dir = 0; guard.push(`пауза до ${state.account.pausedUntil}`); }
    const conviction = clamp(Math.abs(score) / 0.6, 0.5, 1);
    let riskUsd = equity * cfg.riskPerTradePct / 100 * conviction;
    if (a.eventRisk && dir) { riskUsd *= 0.5; guard.push('важлива подія попереду: розмір ×0.5'); }
    const stopDist = cfg.stopAtr * t.atr;
    const q2u = quoteToUsd(p.id, prices);
    const units = dir ? riskUsd / (stopDist * q2u) : 0;
    plans[p.id] = { dir, units, score, quant: t.score, news, stopDist, takeDist: cfg.takeAtr * t.atr, guard, price: t.close };
  }
  // Ліміт плеча: позиції, що лишаються, займають частину ліміту, нові ділять решту.
  let held = 0, fresh = 0;
  for (const [id, pl] of Object.entries(plans)) {
    const cur = state.positions[id];
    const n = (u) => u * pl.price * quoteToUsd(id, prices);
    if (cur && cur.dir === pl.dir) held += n(cur.units);
    else if (pl.dir) fresh += n(pl.units);
  }
  const room = Math.max(0, cfg.maxLeverage * equity - held);
  const scale = fresh > room ? room / fresh : 1;
  if (scale < 1) for (const [id, pl] of Object.entries(plans)) {
    const cur = state.positions[id];
    if (!pl.dir || (cur && cur.dir === pl.dir)) continue;
    pl.units *= scale;
    pl.guard.push(`ліміт плеча ${cfg.maxLeverage}×: розмір ×${scale.toFixed(2)}`);
  }
  return { plans, prices, equity, paused };
}

export function execute(state, { plans, prices }, date) {
  const actions = {};
  for (const [id, pl] of Object.entries(plans)) {
    const cur = state.positions[id];
    if (cur && cur.dir === pl.dir) {
      // Тримаємо позицію, підтягуємо стоп (трейлінг), стоп ніколи не віддаляється.
      const trail = pl.price - pl.dir * pl.stopDist;
      cur.stop = pl.dir > 0 ? Math.max(cur.stop, trail) : Math.min(cur.stop, trail);
      actions[id] = 'тримати';
      continue;
    }
    if (cur) closePosition(state, id, pl.price, prices, { date, reason: pl.dir ? 'розворот сигналу' : 'сигнал зник' });
    if (pl.dir && pl.units > 0) {
      openPosition(state, id, pl.dir, pl.units, pl.price, prices, {
        date, stop: pl.price - pl.dir * pl.stopDist, take: pl.price + pl.dir * pl.takeDist, reason: `оцінка ${pl.score.toFixed(2)}`,
      });
      actions[id] = pl.dir > 0 ? (cur ? 'розворот → купити' : 'купити') : (cur ? 'розворот → продати' : 'продати');
    } else actions[id] = cur ? 'закрити' : 'чекати';
  }
  return actions;
}
