// Технічні індикатори на денних свічках { date, open, high, low, close }.

export function sma(values, n) {
  if (values.length < n) return null;
  let s = 0;
  for (let i = values.length - n; i < values.length; i++) s += values[i];
  return s / n;
}

export function ema(values, n) {
  if (values.length < n) return null;
  const k = 2 / (n + 1);
  let e = 0;
  for (let i = 0; i < n; i++) e += values[i];
  e /= n;
  for (let i = n; i < values.length; i++) e = values[i] * k + e * (1 - k);
  return e;
}

// RSI за Вайлдером.
export function rsi(values, n = 14) {
  if (values.length < n + 1) return null;
  let gain = 0, loss = 0;
  for (let i = 1; i <= n; i++) {
    const d = values[i] - values[i - 1];
    if (d >= 0) gain += d; else loss -= d;
  }
  gain /= n; loss /= n;
  for (let i = n + 1; i < values.length; i++) {
    const d = values[i] - values[i - 1];
    gain = (gain * (n - 1) + Math.max(d, 0)) / n;
    loss = (loss * (n - 1) + Math.max(-d, 0)) / n;
  }
  if (loss === 0) return gain === 0 ? 50 : 100;
  return 100 - 100 / (1 + gain / loss);
}

// ATR за Вайлдером.
export function atr(candles, n = 14) {
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

export const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

// Технічний сигнал −1…+1 з поясненням.
export function quantSignal(candles) {
  const closes = candles.map((c) => c.close);
  const last = closes.at(-1);
  const a = atr(candles, 14);
  const e20 = ema(closes, 20), e50 = ema(closes, 50);
  const r = rsi(closes, 14);
  if (a == null || e50 == null || r == null || a <= 0) {
    return { score: 0, parts: {}, text: 'замало історії для технічного аналізу' };
  }
  const trend = clamp((e20 - e50) / a, -3, 3);
  const mom = clamp((last - closes.at(-11)) / (a * Math.sqrt(10)), -3, 3);
  let fade = 0;
  if (r > 72) fade = -(r - 72) / 28;
  if (r < 28) fade = (28 - r) / 28;
  const score = Math.tanh(0.5 * trend + 0.4 * mom + 0.6 * fade);
  const words = [];
  words.push(trend > 0.3 ? 'висхідний тренд (EMA20 > EMA50)' : trend < -0.3 ? 'низхідний тренд (EMA20 < EMA50)' : 'тренду немає');
  words.push(mom > 0.3 ? 'імпульс угору за 10 днів' : mom < -0.3 ? 'імпульс униз за 10 днів' : 'імпульс слабкий');
  if (fade) words.push(r > 50 ? `RSI ${r.toFixed(0)}: перекупленість` : `RSI ${r.toFixed(0)}: перепроданість`);
  return { score, parts: { trend, momentum: mom, rsi: r, atr: a, ema20: e20, ema50: e50 }, text: words.join(', ') };
}
