// Браузерна демо-версія: той самий рушій (рахунок, Guard, навчання), що й на сервері,
// але працює прямо на сторінці з демо-ринком. Без мережі, ключів і Claude.
import { freshState, advanceDemo, publicState, STATE_VERSION } from '../lib/core.mjs';
import { analyzeDemo } from '../lib/demo-analyst.mjs';

const cfg = {
  liveData: false, liveAi: false, claudeModel: null, decisionTimeUtc: '00:20',
  startEquity: 10000, riskPerTradePct: 1, maxLeverage: 1, maxDrawdownPct: 10, stopAtr: 1.5, takeAtr: 3, minScore: 0.15,
};
const KEY = 'pulse-fx-web-demo-v1';

function load() {
  try {
    const s = JSON.parse(localStorage.getItem(KEY));
    if (s && s.version === STATE_VERSION) return s;
  } catch { /* сховище недоступне або порожнє */ }
  return null;
}
function save(s) {
  try { localStorage.setItem(KEY, JSON.stringify(s)); } catch { /* працюємо без збереження */ }
}

let state = load();
async function step() {
  state ??= freshState(cfg);
  const run = { at: new Date().toISOString(), ok: true, note: '', errors: [] };
  run.note = await advanceDemo(state, cfg, async (input) => analyzeDemo(input));
  state.runs.push(run);
  if (state.runs.length > 60) state.runs.shift();
  save(state);
}
const view = () => publicState(state, cfg, { webDemo: true });

globalThis.PULSE_FX_API = {
  async state() { if (!state) await step(); return view(); },
  async run() { await step(); return view(); },
};
