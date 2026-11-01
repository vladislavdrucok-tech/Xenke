import assert from 'node:assert/strict';
import { createSim, step, stats, equityNow, positionValue, pnlByToken, DEFAULT_RULES } from './public/sim.mjs';

const run = (opts, steps) => { const s = createSim({ startTime: 0, ...opts }); for (let i = 0; i < steps; i++) step(s); return s; };

// Детермінізм: однаковий seed → однаковий результат.
const a = run({ seed: 7 }, 1500), b = run({ seed: 7 }, 1500), c = run({ seed: 8 }, 1500);
assert.equal(stats(a).equity, stats(b).equity);
assert.deepEqual(a.closed, b.closed);
assert.notEqual(stats(a).equity, stats(c).equity);
console.log('PASS: детермінований результат за seed.');

// Облік: капітал = кеш + вартість позицій, нічого не стає NaN чи від'ємним.
for (let seed = 1; seed <= 25; seed++) {
  const s = run({ seed, mood: ['bear', 'neutral', 'bull'][seed % 3] }, 2000);
  const sum = s.cash + s.positions.reduce((v, p) => v + positionValue(p, p.token), 0);
  assert.ok(Math.abs(sum - equityNow(s)) < 1e-9);
  assert.ok(s.cash >= -1e-9, `seed ${seed}: від'ємний кеш`);
  assert.ok(s.positions.length <= DEFAULT_RULES.maxOpen);
  assert.ok(s.equity.every((p) => Number.isFinite(p.v) && p.v >= 0));
  assert.ok(s.equity.length <= 1201);
  assert.equal(new Set(s.positions.map((p) => p.token.symbol)).size, s.positions.length, 'одна позиція на токен');
  const realized = s.closed.reduce((v, c) => v + c.pnlUsd, 0);
  const unrealized = s.positions.reduce((v, p) => v + positionValue(p, p.token) - p.costUsd, 0);
  if (s.closed.length < 400) assert.ok(Math.abs(s.startUsd + realized + unrealized - equityNow(s)) < 1e-6, `seed ${seed}: PnL не сходиться`);
  const byTok = pnlByToken(s).reduce((v, e) => v + e.pnl, 0);
  assert.ok(Math.abs(byTok - realized - unrealized) < 1e-6);
}
console.log('PASS: облік капіталу, PnL, ліміт позицій, без NaN.');

// Правила реально впливають: нульовий ліміт ліквідності пропускає більше сигналів, ніж суворий.
const loose = run({ seed: 3, rules: { minLiquidityK: 1, maxTopHolderPct: 100, minWalletWinRate: 0 } }, 1500);
const strict = run({ seed: 3, rules: { minLiquidityK: 400 } }, 1500);
assert.ok(loose.counters.analysed > strict.counters.analysed);
assert.equal(strict.counters.copied <= loose.counters.copied, true);
console.log('PASS: правила фільтра впливають на кількість угод.');

// Чесність моделі: при нейтральному ринку немає гарантованого прибутку.
const mult = [];
for (let seed = 100; seed < 140; seed++) mult.push(stats(run({ seed }, 720)).multiple);
mult.sort((x, y) => x - y);
const losers = mult.filter((m) => m < 1).length;
assert.ok(losers >= 8, `надто мало збиткових прогонів: ${losers}/40`);
assert.ok(mult[20] < 1.25, `медіана підозріло висока: ${mult[20]}`);
console.log(`PASS: нейтральний ринок, 1 год: збиткових ${losers}/40, медіана ${mult[20].toFixed(2)}×, діапазон ${mult[0].toFixed(2)}–${mult.at(-1).toFixed(2)}×.`);
