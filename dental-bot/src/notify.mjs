// Сповіщення адміністратору клініки в Telegram. Без токена — просто пише в консоль.
import { escapeHtml, formatPhone } from './util.mjs';

export function createTelegramApi({ token, apiBase = 'https://api.telegram.org', timeoutMs = 10000 }) {
  return async function call(method, payload, { timeout = timeoutMs } = {}) {
    if (!token) throw new Error('TELEGRAM_BOT_TOKEN не задано');
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), timeout);
    try {
      const res = await fetch(`${apiBase}/bot${token}/${method}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload), signal: ctrl.signal,
      });
      const body = await res.json().catch(() => ({}));
      if (!body.ok) throw new Error(`Telegram ${method}: ${body.description || res.status}`);
      return body.result;
    } finally {
      clearTimeout(timer);
    }
  };
}

export function leadMessage(clinic, lead, adminUrl) {
  const rows = [
    `🦷 <b>Нова заявка — ${escapeHtml(clinic.name)}</b>`,
    `👤 ${escapeHtml(lead.name || 'Без імені')}`,
    `📞 ${escapeHtml(formatPhone(lead.phone))}`,
  ];
  if (lead.service) rows.push(`🩺 ${escapeHtml(lead.service)}`);
  if (lead.preferredTime) rows.push(`🕐 ${escapeHtml(lead.preferredTime)}`);
  if (lead.notes) rows.push(`💬 ${escapeHtml(lead.notes)}`);
  rows.push(`Джерело: ${lead.channel === 'telegram' ? 'Telegram-бот' : lead.channel === 'form' ? 'форма запису на сайті' : 'чат на сайті'}`);
  if (adminUrl) rows.push(`<a href="${escapeHtml(adminUrl)}">Відкрити діалог</a>`);
  return rows.join('\n');
}

export function createNotifier({ config, log = console }) {
  const tg = config.telegram;
  const api = createTelegramApi({ token: tg.botToken, apiBase: tg.apiBase });
  return {
    async lead(clinic, lead) {
      const chatId = clinic.telegram?.adminChatId || tg.adminChatId;
      const adminUrl = lead.conversationId ? `${config.publicUrl}/admin#conv/${clinic.slug}/${lead.conversationId}` : `${config.publicUrl}/admin`;
      const text = leadMessage(clinic, lead, adminUrl);
      if (!tg.botToken || !chatId) {
        log.log(`[заявка] ${clinic.name}: ${lead.name} ${lead.phone} ${lead.service || ''} (Telegram не налаштовано — див. README)`);
        return { sent: false };
      }
      try {
        await api('sendMessage', { chat_id: chatId, text, parse_mode: 'HTML', disable_web_page_preview: true });
        return { sent: true };
      } catch (err) {
        log.error(`[заявка] не вдалося надіслати в Telegram: ${err.message}`);
        return { sent: false, error: err.message };
      }
    },
  };
}
