import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = fileURLToPath(new URL('..', import.meta.url));

export const PAIRS = Object.freeze([
  { id: 'EUR/USD', base: 'EUR', quote: 'USD', spread: 0.0001 },
  { id: 'GBP/USD', base: 'GBP', quote: 'USD', spread: 0.00015 },
  { id: 'EUR/GBP', base: 'EUR', quote: 'GBP', spread: 0.00015 },
]);
export const PIP = 0.0001;

// Простий читач .env (без залежностей). Змінні середовища мають пріоритет.
function readDotEnv(file) {
  const out = {};
  let text;
  try { text = readFileSync(file, 'utf8'); } catch { return out; }
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (!m) continue;
    out[m[1]] = m[2].replace(/^(['"])(.*)\1$/, '$2');
  }
  return out;
}

const num = (v, d) => (v === undefined || v === '' || !Number.isFinite(Number(v)) ? d : Number(v));

export function loadConfig(env = process.env, dotEnvFile = join(ROOT, '.env')) {
  const e = { ...readDotEnv(dotEnvFile), ...env };
  // Ключ Anthropic потрібен SDK у process.env; з .env переносимо його туди.
  if (e.ANTHROPIC_API_KEY && !process.env.ANTHROPIC_API_KEY && env === process.env) process.env.ANTHROPIC_API_KEY = e.ANTHROPIC_API_KEY;
  const forceDemo = e.FX_DEMO === '1';
  const liveData = !forceDemo && !!e.TWELVEDATA_API_KEY;
  const liveAi = !forceDemo && (!!e.ANTHROPIC_API_KEY || e.FX_USE_CLAUDE === '1');
  return {
    liveData, liveAi,
    twelveDataKey: e.TWELVEDATA_API_KEY || '',
    claudeModel: e.CLAUDE_MODEL || 'claude-opus-5-5',
    newsFeeds: (e.NEWS_FEEDS || '').split(',').map((s) => s.trim()).filter(Boolean),
    decisionTimeUtc: /^\d{2}:\d{2}$/.test(e.DECISION_TIME_UTC || '') ? e.DECISION_TIME_UTC : '00:20',
    port: num(e.PORT, 5174),
    host: e.HOST || '127.0.0.1',
    startEquity: num(e.START_EQUITY, 10000),
    riskPerTradePct: num(e.RISK_PER_TRADE_PCT, 1),
    maxLeverage: num(e.MAX_LEVERAGE, 1),
    maxDrawdownPct: num(e.MAX_DRAWDOWN_PCT, 10),
    stopAtr: num(e.STOP_ATR, 1.5),
    takeAtr: num(e.TAKE_ATR, 3),
    minScore: num(e.MIN_SCORE, 0.15),
    dataFile: e.DATA_FILE || join(ROOT, 'data', 'state.json'),
  };
}
