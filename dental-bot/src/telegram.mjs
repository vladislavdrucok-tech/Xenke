// Telegram-бот для пацієнтів (long polling, без вебхуків — працює і за NAT, і на ноутбуці).
// Той самий бот надсилає заявки адміністратору. Команда /id показує chat id для налаштування.
import { createTelegramApi } from './notify.mjs';

export function startTelegramBot({ config, store, assistant, log = console }) {
  const { botToken, botClinic, apiBase } = config.telegram;
  if (!botToken || !botClinic) return null;
  const api = createTelegramApi({ token: botToken, apiBase });
  let offset = 0;
  let stopped = false;

  async function handle(update) {
    const msg = update.message;
    if (!msg?.text || !msg.chat) return;
    const chatId = msg.chat.id;
    const text = msg.text.trim();
    if (text === '/id' || text.startsWith('/id@')) {
      await api('sendMessage', { chat_id: chatId, text: `chat id: ${chatId}\nВкажіть його як adminChatId клініки (адмінка → Клініки) або TELEGRAM_ADMIN_CHAT_ID, щоб сюди приходили заявки.` });
      return;
    }
    const clinic = await store.getClinic(botClinic);
    const kb = clinic && await store.getKb(botClinic);
    if (!clinic || !kb) {
      log.error(`[telegram] клініку "${botClinic}" не знайдено — створіть демо або змініть TELEGRAM_BOT_CLINIC`);
      return;
    }
    if (text === '/start' || text.startsWith('/start ')) {
      await api('sendMessage', { chat_id: chatId, text: clinic.greeting });
      return;
    }
    const id = `tg-${chatId}`;
    const conversation = (await store.getConversation(botClinic, id))
      || { id, clinic: botClinic, channel: 'telegram', createdAt: new Date().toISOString(), messages: [], transcript: [], telegram: { username: msg.from?.username || '', firstName: msg.from?.first_name || '' } };
    if ((conversation.transcript || []).filter((t) => t.role === 'user').length >= config.limits.messagesPerConversation) {
      await api('sendMessage', { chat_id: chatId, text: 'Для подальшої допомоги зателефонуйте, будь ласка, в клініку — адміністратор відповість на всі питання.' });
      return;
    }
    api('sendChatAction', { chat_id: chatId, action: 'typing' }).catch(() => {});
    const result = await assistant.reply({ clinic, kb, conversation, text: text.slice(0, config.limits.maxMessageChars), channel: 'telegram' });
    await api('sendMessage', { chat_id: chatId, text: result.reply });
  }

  (async function loop() {
    log.log(`Telegram-бот запущено для клініки "${botClinic}"`);
    while (!stopped) {
      try {
        const updates = await api('getUpdates', { offset, timeout: 25, allowed_updates: ['message'] }, { timeout: 35000 });
        for (const u of updates) {
          offset = u.update_id + 1;
          handle(u).catch((err) => log.error(`[telegram] ${err.message}`));
        }
      } catch (err) {
        if (stopped) break;
        log.error(`[telegram] ${err.message}; повтор через 5 с`);
        await new Promise((r) => setTimeout(r, 5000));
      }
    }
  })();

  return { stop() { stopped = true; } };
}
