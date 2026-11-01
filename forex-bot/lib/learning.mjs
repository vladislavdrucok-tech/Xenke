// Навчання: оцінюємо кожне рішення за рухом наступного дня і перерозподіляємо
// вагу між технічним сигналом і новинами залежно від того, що реально спрацьовувало.
import { PIP } from './config.mjs';
import { clamp } from './indicators.mjs';

export const DEFAULT_WEIGHTS = Object.freeze({ quant: 0.5, news: 0.5 });
const WINDOW = 60;     // скільки останніх оцінених рішень враховувати
const MIN_SAMPLES = 8; // менше — замало даних, вагу не чіпаємо
const LEARN_RATE = 0.15;

// Заповнює outcome для записів журналу, для яких з'явилася наступна свічка.
export function evaluateJournal(journal, candlesByPair) {
  for (const e of journal) {
    if (e.outcome) continue;
    const cs = candlesByPair[e.pair];
    const i = cs.findIndex((c) => c.date === e.date);
    if (i < 0 || i + 1 >= cs.length) continue;
    const next = cs[i + 1];
    const move = next.close - e.price;
    const retAtr = e.atr > 0 ? move / e.atr : 0;
    const right = (s) => (Math.abs(s) < 0.05 ? null : Math.sign(s) === Math.sign(move));
    e.outcome = { nextDate: next.date, pips: move / PIP, retAtr, quantRight: right(e.quant), newsRight: right(e.news), finalRight: e.dir ? Math.sign(e.dir) === Math.sign(move) : null };
  }
}

export function componentStats(journal) {
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
    quant: stat('quant', 'quantRight'),
    news: stat('news', 'newsRight'),
    final: { n: trades.length, hitRate: trades.length ? trades.filter((e) => e.outcome.finalRight).length / trades.length : null },
  };
}

export function updateWeights(weights, journal) {
  const s = componentStats(journal);
  if (s.quant.n < MIN_SAMPLES || s.news.n < MIN_SAMPLES) return { weights: { ...weights }, stats: s, changed: false };
  const rawQ = Math.max(0.05, 0.5 + s.quant.edge), rawN = Math.max(0.05, 0.5 + s.news.edge);
  const target = rawQ / (rawQ + rawN);
  const quant = clamp((1 - LEARN_RATE) * weights.quant + LEARN_RATE * target, 0.2, 0.8);
  return { weights: { quant, news: 1 - quant }, stats: s, changed: Math.abs(quant - weights.quant) > 1e-9 };
}

// Короткий підсумок останніх новинних рішень — для підказки Claude (навчання в контексті).
export function trackRecordLines(journal, n = 12) {
  return journal.filter((e) => e.outcome && Math.abs(e.news) >= 0.05).slice(-n).map((e) =>
    `- ${e.date} ${e.pair}: news ${e.news >= 0 ? '+' : ''}${e.news.toFixed(2)} -> next day ${e.outcome.pips >= 0 ? '+' : ''}${e.outcome.pips.toFixed(0)} pips (${e.outcome.newsRight ? 'right' : 'wrong'})`);
}
