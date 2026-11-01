// Ядро бота без залежностей від Node: один торговий день, демо-прогін і стан для дашборду.
// Використовується і сервером (lib/cycle.mjs), і браузерною демо-версією (web/).
import { PAIRS } from './pairs.mjs';
import { quantSignal } from './indicators.mjs';
import { demoWorld, demoHeadlines } from './market.mjs';
import { newAccount, processBar, decide, execute, equityUsd, grossNotionalUsd, unrealizedUsd, quoteToUsd } from './engine.mjs';
import { DEFAULT_WEIGHTS, evaluateJournal, updateWeights, componentStats, trackRecordLines } from './learning.mjs';

export const STATE_VERSION = 1;
export const DEMO_SEED = 20251101;
const DEMO_HISTORY = 60;  // днів історії до старту (для EMA50)
export const DEMO_WARMUP = 120;  // днів, які демо прокручує при першому запуску

export function freshState(cfg) {
  return {
    version: STATE_VERSION, mode: { data: cfg.liveData ? 'live' : 'demo', ai: cfg.liveAi ? 'claude' : 'demo' },
    account: newAccount(cfg.startEquity), positions: {}, trades: [], equityCurve: [], journal: [],
    weights: { ...DEFAULT_WEIGHTS }, weightHistory: [], lastBarDate: null, demoDay: null,
    latest: null, runs: [],
  };
}

export const barsOn = (candles, date) => Object.fromEntries(PAIRS.map((p) => [p.id, candles[p.id].find((c) => c.date === date)]));
const upTo = (candles, date) => Object.fromEntries(PAIRS.map((p) => [p.id, candles[p.id].filter((c) => c.date <= date)]));

// Один торговий день: свічка дня, оцінка минулих рішень, навчання, нове рішення.
export async function advanceDay(state, cfg, candles, date, headlines, analyze) {
  const isNew = !state.lastBarDate || date > state.lastBarDate;
  if (state.lastBarDate && isNew) processBar(state, date, barsOn(candles, date), cfg);
  if (!state.lastBarDate) state.equityCurve.push({ date, equity: state.account.cash });

  const hist = upTo(candles, date);
  evaluateJournal(state.journal, hist);
  const learned = updateWeights(state.weights, state.journal);
  if (learned.changed) {
    state.weights = learned.weights;
    state.weightHistory.push({ date, ...learned.weights });
    if (state.weightHistory.length > 1000) state.weightHistory.shift();
  }

  const technical = {};
  for (const p of PAIRS) {
    const cs = hist[p.id];
    const q = quantSignal(cs);
    const prev = cs.at(-2)?.close ?? cs.at(-1).close;
    technical[p.id] = { ...q, close: cs.at(-1).close, atr: q.parts.atr ?? cs.at(-1).close * 0.006, changePct: (cs.at(-1).close / prev - 1) * 100 };
  }
  const analysis = await analyze({ date, technical, headlines, trackRecord: trackRecordLines(state.journal), weights: state.weights });
  const plan = decide(state, cfg, { date, technical, analysis, weights: state.weights });
  const actions = execute(state, plan, date);

  for (const p of PAIRS) {
    const pl = plan.plans[p.id], t = technical[p.id], a = analysis.pairs[p.id];
    state.journal.push({ date, pair: p.id, price: t.close, atr: t.atr, quant: t.score, news: pl.news, bias: a.bias, confidence: a.confidence,
      score: pl.score, dir: pl.dir, action: actions[p.id], weights: { ...state.weights }, outcome: null });
  }
  if (state.journal.length > 3000) state.journal.splice(0, state.journal.length - 3000);

  const prices = plan.prices;
  state.latest = {
    date, headlines, analysis, actions,
    technical: Object.fromEntries(PAIRS.map((p) => [p.id, { score: technical[p.id].score, text: technical[p.id].text, close: technical[p.id].close,
      changePct: technical[p.id].changePct, rsi: technical[p.id].parts.rsi ?? null, atr: technical[p.id].atr }])),
    plans: Object.fromEntries(Object.entries(plan.plans).map(([id, pl]) => [id, { dir: pl.dir, score: pl.score, quant: pl.quant, news: pl.news, guard: pl.guard }])),
    equity: equityUsd(state, prices), gross: grossNotionalUsd(state, prices),
    market: Object.fromEntries(PAIRS.map((p) => [p.id, hist[p.id].slice(-90)])),
    stats: componentStats(state.journal),
  };
  state.lastBarDate = date;
}

// Демо: перший запуск прокручує DEMO_WARMUP днів, далі — по одному дню.
// warmAnalyze використовується для днів прогріву, analyze — для останнього дня.
export async function advanceDemo(state, cfg, analyze, warmAnalyze = analyze) {
  const first = state.demoDay == null;
  const target = first ? DEMO_HISTORY + DEMO_WARMUP : state.demoDay + 1;
  const world = demoWorld(DEMO_SEED, target + 1);
  for (let d = first ? DEMO_HISTORY : target; d <= target; d++) {
    const date = world.candles['EUR/USD'][d].date;
    await advanceDay(state, cfg, world.candles, date, demoHeadlines(world, d), d === target ? analyze : warmAnalyze);
  }
  state.demoDay = target;
  return first ? `Демо: прокручено ${DEMO_WARMUP} торгових днів, щоб показати, як бот працює й навчається.` : `Демо: день ${state.lastBarDate}.`;
}

export function nextRunAt(decisionTimeUtc, now = new Date()) {
  const [h, m] = decisionTimeUtc.split(':').map(Number);
  const t = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), h, m));
  if (t <= now) t.setUTCDate(t.getUTCDate() + 1);
  return t.toISOString();
}

// Те, що бачить дашборд.
export function publicState(state, cfg, extra = {}) {
  const prices = state.latest ? Object.fromEntries(PAIRS.map((p) => [p.id, state.latest.technical[p.id].close])) : null;
  const positions = Object.fromEntries(Object.entries(state.positions).map(([id, p]) => [id, {
    ...p, unrealizedUsd: prices ? unrealizedUsd(p, prices[id], quoteToUsd(id, prices)) : 0,
  }]));
  return {
    mode: state.mode, account: state.account, positions, equity: prices ? equityUsd(state, prices) : state.account.cash,
    trades: state.trades.slice(-60), equityCurve: state.equityCurve, journal: state.journal.slice(-120),
    weights: state.weights, weightHistory: state.weightHistory.slice(-300), latest: state.latest, runs: state.runs.slice(-10),
    lastBarDate: state.lastBarDate, nextRunAt: nextRunAt(cfg.decisionTimeUtc),
    config: { decisionTimeUtc: cfg.decisionTimeUtc, riskPerTradePct: cfg.riskPerTradePct, maxLeverage: cfg.maxLeverage, maxDrawdownPct: cfg.maxDrawdownPct,
      stopAtr: cfg.stopAtr, takeAtr: cfg.takeAtr, minScore: cfg.minScore, startEquity: cfg.startEquity, model: cfg.liveAi ? cfg.claudeModel : null },
    ...extra,
  };
}
