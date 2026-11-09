// Створення демо для клініки за адресою сайту: обхід → база знань → налаштування → скріншот → приклад діалогу.
import { createRequire } from 'node:module';
import { crawlSite, USER_AGENT } from './crawl.mjs';
import { buildKb } from './kb.mjs';
import { slugFromUrl } from './util.mjs';

export const SAMPLE_QUESTIONS = [
  'Скільки коштує імплантація зуба?',
  'Ви працюєте в суботу?',
  'У мене ввечері розболівся зуб, що робити?',
];

export const DEFAULT_QUICK_REPLIES = ['Ціни на імплантацію', 'Записатися на консультацію', 'Де ви знаходитесь?', 'Графік роботи'];

export function defaultGreeting(name) {
  return `Вітаю! Я онлайн-помічник клініки «${name}». Підкажу ціни, адресу й графік або запишу вас на консультацію. Що вас цікавить?`;
}

export async function takeScreenshot(url, file, log = () => {}) {
  let playwright;
  try { playwright = createRequire(import.meta.url)('playwright'); } catch {
    log('  (скріншот пропущено: playwright не встановлено — npm i playwright && npx playwright install chromium)');
    return false;
  }
  let browser;
  try {
    browser = await playwright.chromium.launch();
    const page = await browser.newPage({ viewport: { width: 1366, height: 860 }, userAgent: USER_AGENT, locale: 'uk-UA' });
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(2000);
    await page.screenshot({ path: file });
    return true;
  } catch (err) {
    log(`  (скріншот не вдався: ${err.message.split('\n')[0]})`);
    return false;
  } finally {
    await browser?.close();
  }
}

export async function createDemo(url, { store, config, assistant, log = () => {}, slug, name, maxPages = 25, screenshot = true, sample = true, fetchImpl } = {}) {
  log(`Обходжу сайт ${url} …`);
  const crawl = await crawlSite(url, { maxPages, log, fetchImpl });
  const kb = buildKb(crawl);
  const finalSlug = slug || slugFromUrl(kb.url);
  const existing = await store.getClinic(finalSlug);
  const clinicName = name || existing?.name || kb.name;
  const now = new Date().toISOString();
  const clinic = {
    slug: finalSlug,
    name: clinicName,
    url: kb.url,
    brandColor: existing?.brandColor || kb.brandColor,
    greeting: existing?.greeting || defaultGreeting(clinicName),
    quickReplies: existing?.quickReplies || DEFAULT_QUICK_REPLIES,
    audit: existing?.audit || null,
    telegram: existing?.telegram || {},
    offer: existing?.offer || {},
    status: existing?.status || 'demo',
    createdAt: existing?.createdAt || now,
    updatedAt: now,
    kbHash: kb.hash,
    hasShot: existing?.hasShot || false,
    sampleDialog: existing?.kbHash === kb.hash ? existing?.sampleDialog || [] : [],
  };
  await store.saveKb(finalSlug, kb);
  await store.saveClinic(clinic);

  if (screenshot) {
    log('Роблю скріншот головної сторінки …');
    clinic.hasShot = (await takeScreenshot(kb.url, store.shotPath(finalSlug), log)) || clinic.hasShot;
  }

  if (sample && assistant?.mode === 'ai' && !clinic.sampleDialog.length) {
    log('Генерую приклад діалогу для презентації …');
    const conversation = { id: `sample-${Date.now()}`, clinic: finalSlug, channel: 'sample', sample: true, createdAt: now, messages: [], transcript: [] };
    for (const q of SAMPLE_QUESTIONS) {
      const r = await assistant.reply({ clinic, kb, conversation, text: q, channel: 'sample' });
      if (r.mode !== 'ai') break; // AI недоступний — не показуємо в презентації відповіді локального режиму
      clinic.sampleDialog.push({ q, a: r.reply });
    }
  }
  await store.saveClinic(clinic);

  const warnings = [];
  if (!kb.prices.length) warnings.push('Цін на сайті не знайдено — бот казатиме, що вартість уточнить адміністратор.');
  if (!kb.facts.phones.length) warnings.push('Телефон не знайдено — перевірте вручну.');
  if (kb.stats.pages < 4) warnings.push(`Обійдено лише ${kb.stats.pages} стор. — можливо, сайт рендериться JavaScript-ом. Перевірте відповіді бота.`);
  if (kb.stats.omittedPages.length) warnings.push(`${kb.stats.omittedPages.length} стор. не влізли в базу знань (ліміт ${Math.round(kb.stats.promptChars / 1000)}K символів).`);
  if (crawl.skipped.robots) warnings.push(`Пропущено через robots.txt: ${crawl.skipped.robots} посил.`);
  if (crawl.errors.length) warnings.push(`Не завантажились: ${crawl.errors.length} стор.`);
  if (/(стоматолог|клінік|dental|clinic)/i.test(clinicName) && clinicName.length > 45) warnings.push(`Назва визначилась як «${clinicName}» — задайте коротшу через --name або в адмінці.`);

  return {
    clinic, kb, warnings,
    demoUrl: `${config.publicUrl}/demo/${finalSlug}`,
    pitchUrl: `${config.publicUrl}/pitch/${finalSlug}`,
  };
}
