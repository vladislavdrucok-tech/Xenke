// Налаштування: значення за замовчуванням ← config.json ← змінні середовища.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = fileURLToPath(new URL('..', import.meta.url));

const DEFAULTS = {
  port: 8787,
  publicUrl: '',
  dataDir: join(ROOT, 'data'),
  seller: { name: 'Ваше ім’я', phone: '', telegram: '', email: '' },
  offer: { setupUsd: 1500, monthlyUsd: 120, launchHours: 48, guaranteeDays: 30, slots: 3 },
  ai: {
    enabled: null, // null = вмикається автоматично, якщо є ANTHROPIC_API_KEY або ANTHROPIC_AUTH_TOKEN
    model: 'claude-opus-5-5',
    effort: 'low', // чат: короткі відповіді, низька затримка
    maxTokens: 8000,
    maxRetries: 2,
    fallbacks: null, // null = автоматично для моделей, що підтримують серверний fallback
    dailyMessageCap: 2000,
    // Ціни за 1M токенів, лише для приблизної оцінки витрат в адмінці.
    pricing: { input: 4, output: 20, cacheRead: 0.2, cacheWrite: 8 },
  },
  limits: { messagesPerConversation: 60, messagesPerIpPer10Min: 30, maxMessageChars: 1000 },
  telegram: { botToken: '', adminChatId: '', botClinic: '' },
  adminPassword: '',
};

function merge(a, b) {
  const out = { ...a };
  for (const [k, v] of Object.entries(b || {})) {
    out[k] = v && typeof v === 'object' && !Array.isArray(v) && a[k] && typeof a[k] === 'object' ? merge(a[k], v) : v;
  }
  return out;
}

export function loadConfig({ env = process.env, file = join(ROOT, 'config.json') } = {}) {
  let fromFile = {};
  try { fromFile = JSON.parse(readFileSync(file, 'utf8')); } catch (err) {
    if (err.code !== 'ENOENT') throw new Error(`config.json не читається: ${err.message}`);
  }
  const cfg = merge(DEFAULTS, fromFile);
  if (env.PORT) cfg.port = Number(env.PORT);
  if (env.PUBLIC_URL) cfg.publicUrl = env.PUBLIC_URL;
  if (env.DATA_DIR) cfg.dataDir = env.DATA_DIR;
  if (env.ADMIN_PASSWORD) cfg.adminPassword = env.ADMIN_PASSWORD;
  if (env.CLAUDE_MODEL) cfg.ai.model = env.CLAUDE_MODEL;
  if (env.CLAUDE_EFFORT) cfg.ai.effort = env.CLAUDE_EFFORT;
  if (env.ANTHROPIC_MAX_RETRIES) cfg.ai.maxRetries = Number(env.ANTHROPIC_MAX_RETRIES);
  if (env.TELEGRAM_BOT_TOKEN) cfg.telegram.botToken = env.TELEGRAM_BOT_TOKEN;
  if (env.TELEGRAM_ADMIN_CHAT_ID) cfg.telegram.adminChatId = env.TELEGRAM_ADMIN_CHAT_ID;
  if (env.TELEGRAM_BOT_CLINIC) cfg.telegram.botClinic = env.TELEGRAM_BOT_CLINIC;
  cfg.telegram.apiBase = env.TELEGRAM_API_BASE || 'https://api.telegram.org';

  const mode = (env.AI_MODE || '').toLowerCase();
  if (mode === 'off') cfg.ai.enabled = false;
  else if (mode === 'on') cfg.ai.enabled = true;
  else if (cfg.ai.enabled == null) cfg.ai.enabled = Boolean(env.ANTHROPIC_API_KEY || env.ANTHROPIC_AUTH_TOKEN);
  if (cfg.ai.fallbacks == null) cfg.ai.fallbacks = /^claude-(opus-5|fable-5|sonnet-5-5)/.test(cfg.ai.model);
  cfg.publicUrl = (cfg.publicUrl || `http://localhost:${cfg.port}`).replace(/\/+$/, '');
  return cfg;
}
