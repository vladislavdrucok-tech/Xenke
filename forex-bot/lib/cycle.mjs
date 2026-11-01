// Щоденний цикл: дані → новини → аналіз → рішення → віртуальні угоди → навчання → збереження.
import { mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { PAIRS } from './pairs.mjs';
import { fetchCandlesLive } from './market.mjs';
import { fetchNewsLive } from './news.mjs';
import { analyzeWithClaude, analyzeDemo } from './analyst.mjs';
import { processBar } from './engine.mjs';
import { STATE_VERSION, freshState, barsOn, advanceDay, advanceDemo } from './core.mjs';

export { freshState };

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
      const warm = cfg.liveAi ? async (input) => analyzeDemo(input) : analyze; // прогрів без витрат на API
      run.note += await advanceDemo(state, cfg, analyze, warm);
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
