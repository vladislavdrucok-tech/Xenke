// Демо-аналітик: словниковий розбір демо-заголовків (без мережі й SDK, працює і в браузері).
import { PAIRS } from './pairs.mjs';

const CUR_WORDS = { USD: ['ФРС', 'США'], EUR: ['ЄЦБ', 'єврозон', 'Німеччин'], GBP: ['Банк Англії', 'Британ'] };
const POS = ['жорсткіше', 'підвищення', 'вища', 'зріс', 'ростуть', 'довше високі', 'прискорилася', 'більше, ніж чекали'];
const NEG = ['зниження', 'знижувати', 'слабшає', 'розчарували', 'скорочується', 'сповільнилася', 'стагнує', 'нижча'];

export function analyzeDemo({ headlines }) {
  const score = { USD: 0, EUR: 0, GBP: 0 }, hits = { USD: [], EUR: [], GBP: [] };
  for (const h of headlines) {
    const text = `${h.source} ${h.title}`;
    const cur = Object.keys(CUR_WORDS).find((c) => CUR_WORDS[c].some((w) => text.includes(w)));
    if (!cur) continue;
    const s = NEG.some((w) => h.title.includes(w)) ? -1 : POS.some((w) => h.title.includes(w)) ? 1 : 0;
    if (!s) continue;
    score[cur] += s;
    hits[cur].push(`${s > 0 ? '▲' : '▼'} ${cur}: ${h.title}`);
  }
  const pairs = {};
  for (const p of PAIRS) {
    const diff = score[p.base] - score[p.quote];
    const drivers = [...hits[p.base], ...hits[p.quote]];
    pairs[p.id] = {
      bias: Math.tanh(diff * 0.8), confidence: drivers.length ? Math.min(0.9, 0.35 + 0.2 * drivers.length) : 0.05, eventRisk: false,
      reasoning: drivers.length
        ? `Новини ${diff > 0 ? `на користь ${p.base}` : diff < 0 ? `на користь ${p.quote}` : 'суперечливі'}: ${drivers.length} релевантн. заголовк. (демо-аналітик, словниковий метод).`
        : 'Нових релевантних новин немає, позиція нейтральна (демо-аналітик).',
      drivers,
    };
  }
  const total = Object.values(hits).reduce((s, h) => s + h.length, 0);
  return { ok: true, source: 'демо-аналітик', summary: `Демо-режим: оцінено ${headlines.length} заголовк., ${total} стосуються USD/EUR/GBP. Підключіть ANTHROPIC_API_KEY, щоб аналізував Claude.`, pairs };
}
