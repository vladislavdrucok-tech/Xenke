// Котирування: справжні (Twelve Data) або демо-світ (детермінований генератор).
import { PAIRS } from './pairs.mjs';

// ---------- справжні дані: Twelve Data ----------
export async function fetchCandlesLive(cfg, { fetchImpl = fetch, now = new Date() } = {}) {
  const today = now.toISOString().slice(0, 10);
  const out = {};
  for (const p of PAIRS) {
    const url = `https://api.twelvedata.com/time_series?symbol=${encodeURIComponent(p.id)}&interval=1day&outputsize=200&timezone=UTC&apikey=${encodeURIComponent(cfg.twelveDataKey)}`;
    const res = await fetchImpl(url, { signal: AbortSignal.timeout(20000) });
    if (!res.ok) throw new Error(`Twelve Data ${p.id}: HTTP ${res.status}`);
    const body = await res.json();
    if (body.status === 'error' || !Array.isArray(body.values)) throw new Error(`Twelve Data ${p.id}: ${body.message || 'неочікувана відповідь'}`);
    out[p.id] = parseTwelveData(body.values, today);
  }
  return out;
}

// Twelve Data віддає найновіші свічки першими; сьогоднішня (незакрита) відкидається.
export function parseTwelveData(values, today) {
  return values
    .map((v) => ({ date: String(v.datetime).slice(0, 10), open: +v.open, high: +v.high, low: +v.low, close: +v.close }))
    .filter((c) => c.date < today && [c.open, c.high, c.low, c.close].every((x) => Number.isFinite(x) && x > 0))
    .sort((a, b) => a.date.localeCompare(b.date));
}

// ---------- демо-світ ----------
// Кожна валюта має «фундаментальні сюрпризи» (новини дня), які частково
// впливають на курс наступного дня. Так демо показує, як бот вчиться зважувати новини.
function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const gauss = (r) => Math.sqrt(-2 * Math.log(Math.max(r(), 1e-12))) * Math.cos(2 * Math.PI * r());

const DEMO_START = Date.UTC(2025, 0, 6); // понеділок
const ANCHOR = { 'EUR/USD': 1.08, 'GBP/USD': 1.27, 'EUR/GBP': 0.85 };
const CURRENCIES = ['USD', 'EUR', 'GBP'];

export function demoDate(i) {
  // i-й робочий день від DEMO_START
  const d = new Date(DEMO_START);
  let left = i;
  d.setUTCDate(d.getUTCDate() + Math.floor(left / 5) * 7);
  left %= 5;
  while (left > 0) { d.setUTCDate(d.getUTCDate() + 1); if (d.getUTCDay() % 6 !== 0) left--; }
  return d.toISOString().slice(0, 10);
}

export function demoWorld(seed, days) {
  const r = mulberry32(seed);
  const v = { USD: 0, EUR: 0, GBP: 0 };
  const trend = { USD: 0, EUR: 0, GBP: 0 };
  const surprises = []; // surprises[d][cur]
  const levels = [];
  let prev = { USD: 0, EUR: 0, GBP: 0 };
  for (let d = 0; d < days; d++) {
    const s = {};
    for (const c of CURRENCIES) {
      trend[c] = trend[c] * 0.97 + gauss(r) * 0.25;
      const last = d > 0 ? surprises[d - 1][c] : 0;
      v[c] += 0.004 * (0.3 * last + 0.12 * trend[c] + 0.95 * gauss(r));
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
      const high = Math.max(open, close) * (1 + Math.abs(L.wiggle[k]) * 0.0018);
      const low = Math.min(open, close) * (1 - Math.abs(L.wiggle[k + 3]) * 0.0018);
      candles[p.id].push({ date: demoDate(d), open: +open.toFixed(5), high: +high.toFixed(5), low: +low.toFixed(5), close: +close.toFixed(5) });
    });
  });
  return { candles, surprises, rnd: mulberry32(seed ^ 0x9e3779b9) };
}

const SRC = { USD: 'ФРС / США', EUR: 'ЄЦБ / єврозона', GBP: 'Банк Англії / Британія' };
const GOOD = {
  USD: ['Члени ФРС натякають на довше високі ставки', 'Зайнятість у США (NFP) значно вища за прогноз', 'Інфляція в США прискорилася понад очікування'],
  EUR: ['ЄЦБ звучить жорсткіше: можливе ще одне підвищення', 'PMI єврозони неочікувано зріс', 'Інфляція в єврозоні вища за прогноз'],
  GBP: ['Банк Англії залишив ставку, двоє голосували за підвищення', 'ВВП Британії зріс більше, ніж чекали', 'Зарплати у Британії ростуть швидше за прогноз'],
};
const BAD = {
  USD: ['ФРС відкриває двері для зниження ставки', 'Ринок праці США слабшає: заявок на допомогу більше', 'Роздрібні продажі в США розчарували'],
  EUR: ['ЄЦБ сигналізує про зниження ставок', 'Промисловість Німеччини скорочується', 'Інфляція в єврозоні сповільнилася сильніше, ніж чекали'],
  GBP: ['Банк Англії готується знижувати ставку', 'Економіка Британії стагнує', 'Інфляція у Британії нижча за прогноз'],
};
const NOISE = ['Ринки чекають на виступи центробанкірів наступного тижня', 'Ціни на нафту стабілізувалися', 'Інвестори обережні перед звітами компаній'];

// Демо-заголовки дня d. Іноді заголовок вводить в оману (як у житті).
export function demoHeadlines(world, d) {
  const s = world.surprises[d];
  const date = demoDate(d);
  const r = mulberry32((d + 1) * 7919);
  const out = [];
  for (const c of CURRENCIES) {
    if (Math.abs(s[c]) < 0.55) continue;
    const misleading = r() < 0.2;
    const positive = (s[c] > 0) !== misleading;
    const list = positive ? GOOD[c] : BAD[c];
    out.push({ title: list[Math.floor(r() * list.length)], source: `${SRC[c]} (демо)`, date, link: '' });
  }
  out.push({ title: NOISE[Math.floor(r() * NOISE.length)], source: 'Ринки (демо)', date, link: '' });
  return out;
}
