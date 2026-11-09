// Демо для клініки за адресою сайту:
//   node scripts/new-demo.mjs https://clinic.kyiv.ua [--name "Стоматологія «Посмішка»"] [--slug posmishka]
//                             [--max-pages 25] [--no-screenshot] [--no-sample]
import { createAssistant } from '../src/assistant.mjs';
import { loadConfig } from '../src/config.mjs';
import { createDemo } from '../src/demo.mjs';
import { createNotifier } from '../src/notify.mjs';
import { createStore } from '../src/store.mjs';
import { parseArgs } from '../src/util.mjs';

const args = parseArgs(process.argv.slice(2));
const url = args._[0];
if (!url) {
  console.log('Використання: node scripts/new-demo.mjs <сайт клініки> [--name "Назва"] [--slug slug] [--max-pages 25] [--no-screenshot] [--no-sample]');
  process.exit(1);
}
const config = loadConfig();
const store = createStore(config.dataDir);
await store.ensure();
const assistant = createAssistant({ store, notifier: createNotifier({ config }), config });
try {
  const r = await createDemo(url, {
    store, config, assistant, log: (m) => console.log(m),
    slug: typeof args.slug === 'string' ? args.slug : undefined,
    name: typeof args.name === 'string' ? args.name : undefined,
    maxPages: Number(args['max-pages']) || 25,
    screenshot: !args['no-screenshot'],
    sample: !args['no-sample'],
  });
  const { clinic, kb } = r;
  console.log(`\n✅ ${clinic.name}  (slug: ${clinic.slug})`);
  console.log(`   Сторінок: ${kb.stats.pages} · рядків цін: ${kb.prices.length} · телефони: ${kb.facts.phones.join(', ') || '—'}`);
  if (kb.implantPrice) console.log(`   Імплант: ${kb.implantPrice.text}`);
  if (clinic.sampleDialog.length) console.log(`   Приклад діалогу для презентації: ${clinic.sampleDialog.length} відповіді`);
  else if (assistant.mode !== 'ai') console.log('   Приклад діалогу не згенеровано: немає ANTHROPIC_API_KEY (локальний режим).');
  for (const w of r.warnings) console.log(`   ⚠ ${w}`);
  console.log(`\n   Демо:         ${r.demoUrl}`);
  console.log(`   Презентація:  ${r.pitchUrl}`);
  console.log(`   Код для сайту: <script src="${config.publicUrl}/widget.js" data-clinic="${clinic.slug}" defer></script>`);
  if (config.publicUrl.includes('localhost')) console.log('\n   Посилання локальні. Щоб надіслати клініці — див. README, розділ «Публічна адреса».');
} catch (err) {
  console.error(`\n❌ Не вдалося: ${err.message}`);
  process.exit(1);
}
