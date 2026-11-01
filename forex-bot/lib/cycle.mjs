// Щоденний цикл: дані → новини → аналіз → рішення → віртуальні угоди → навчання → збереження.
import { mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { PAIRS } from './config.mjs';
import { quantSignal } from './indicators.mjs';
import { fetchCandlesLive, demoWorld, demoHeadlines } from './market.mjs';
import { fetchNewsLive } from './news.mjs';
import { analyzeWithClaude, analyzeDemo } from './analyst.mjs';
import { newAccount, processBar, decide, execute, equityUsd, grossNotionalUsd } from './engine.mjs';
import { DEFAULT_WEIGHTS, evaluateJournal, updateWeights, componentStats, trackRecordLines } from './learning.mjs';

export const STATE_VERSION = 1;
const DEMO_SEED = 20251101;
const DEMO_HISTORY = 60;  // днів історії до старту (для EMA50)
const DEMO_WARMUP = 120;  // днів, які демо прокручує при першому запуску

export function freshState(cfg) {
  return {
    version: STATE_VERSION, mode: { data: cfg.liveData ? 'live' : 'demo', ai: cfg.liveAi ? 'claude' : 'demo' },
    account: newAccount(cfg.startEquity), positions: {}, trades: [], equityCurve: [], journal: [],
    weights: { ...DEFAULT_WEIGHTS }, weightHistory: [], lastBarDate: null, demoDay: null,
    latest: null, runs: [],
  };
}

export function loadState(cfg) {
  try {
    const s = JSON.parse(readFileSync(cfg.dataFile, 'utf8'));
    if (s && s.version === STATE_VERSION) return s;
  } catch { /* немає файлу або він зіпсований — починаємо з нуля */ }
  return freshState(cfg);
}

export function saveState(cfg, state) {
  mkdirSync(dirname(cfg.dataFile), { recursive: true });
  const tmp = cfg.dataFile + '.tmp';
  writeFileSync(tmp, JSON.stringify(state));
  renameSync(tmp, cfg.dataFile);
}

const barsOn = (candles, date) => Object.fromEntries(PAIRS.map((p) => [p.id, candles[p.id].find((c) => c.date === date)]));
const upTo = (candles, date) => Object.fromEntries(PAIRS.map((p) => [p.id, candles[p.id].filter((c) => c.date <= date)]));

// Один торговий день: свічка дня, оцінка минулих рішень, навчання, нове рішення.
async function advanceDay(state, cfg, candles, date, headlines, analyze) {
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

let running = null;
export function runCycle(cfg, deps = {}) {
  // Один цикл за раз (ручний запуск і розклад не перетинаються).
  if (running) return running;
  running = runCycleInner(cfg, deps).finally(() => { running = null; });
  return running;
}

async function runCycleInner(cfg, { fetchImpl = fetch, claudeClient, now = new Date(), state = loadState(cfg), save = true } = {}) {
  const started = now.toISOString();
  const run = { at: started, ok: true, note: '', errors: [] };
  const mode = { data: cfg.liveData ? 'live' : 'demo', ai: cfg.liveAi ? 'claude' : 'demo' };
  if (state.mode.data !== mode.data) {
    // Перемикання демо ↔ живі дані: стара історія не має сенсу, починаємо новий рахунок.
    state = freshState(cfg);
    run.note = 'Режим даних змінився — розпочато новий віртуальний рахунок. ';
  }
  state.mode = mode;
  const analyze = cfg.liveAi
    ? (input) => analyzeWithClaude(input, { client: claudeClient, model: cfg.claudeModel })
    : async (input) => analyzeDemo(input);

  try {
    if (mode.data === 'demo') {
      const first = state.demoDay == null;
      const target = first ? DEMO_HISTORY + DEMO_WARMUP : state.demoDay + 1;
      const world = demoWorld(DEMO_SEED, target + 1);
      const demoAnalyze = cfg.liveAi && first ? async (input) => analyzeDemo(input) : analyze; // прогрів без витрат на API
      for (let d = first ? DEMO_HISTORY : target; d <= target; d++) {
        const date = world.candles['EUR/USD'][d].date;
        await advanceDay(state, cfg, world.candles, date, demoHeadlines(world, d), d === target ? analyze : demoAnalyze);
      }
      state.demoDay = target;
      run.note += first ? `Демо: прокручено ${DEMO_WARMUP} торгових днів, щоб показати, як бот працює й навчається.` : `Демо: день ${state.lastBarDate}.`;
    } else {
      const candles = await fetchCandlesLive(cfg, { fetchImpl, now });
      const dates = candles['EUR/USD'].map((c) => c.date).filter((d) => PAIRS.every((p) => candles[p.id].some((c) => c.date === d)));
      const latest = dates.at(-1);
      if (!latest) throw new Error('Twelve Data не повернув жодної закритої денної свічки');
      if (state.lastBarDate && latest <= state.lastBarDate) {
        run.note += `Нових денних свічок немає (остання — ${state.lastBarDate}). Рішення не змінювалося.`;
      } else {
        // Пропущені дні (наприклад, сервер був вимкнений): проводимо свічки через рахунок без нових рішень.
        const missed = state.lastBarDate ? dates.filter((d) => d > state.lastBarDate && d < latest) : [];
        for (const d of missed) { processBar(state, d, barsOn(candles, d), cfg); state.lastBarDate = d; }
        const news = await fetchNewsLive(cfg, { fetchImpl, now });
        run.errors.push(...news.errors.map((e) => `Новини — ${e}`));
        await advanceDay(state, cfg, candles, latest, news.items, analyze);
        run.note += `Рішення на основі свічки ${latest}.${missed.length ? ` Пропущено днів без рішень: ${missed.length}.` : ''}`;
      }
    }
    if (state.latest?.analysis?.error) run.errors.push(`Claude — ${state.latest.analysis.error}`);
  } catch (e) {
    run.ok = false;
    run.errors.push(e.message || String(e));
  }
  state.runs.push(run);
  if (state.runs.length > 60) state.runs.shift();
  if (save) saveState(cfg, state);
  return state;
}
