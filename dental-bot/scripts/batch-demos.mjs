// Демо для всіх клінік зі списку: node scripts/batch-demos.mjs sales/prospects.csv [--max 15] [--no-screenshot]
// Бере рядки, де є website і порожній demo_url; дописує в CSV demo_url і pitch_url.
import { readFile, writeFile } from 'node:fs/promises';
import { createAssistant } from '../src/assistant.mjs';
import { loadConfig } from '../src/config.mjs';
import { createDemo } from '../src/demo.mjs';
import { createNotifier } from '../src/notify.mjs';
import { createStore } from '../src/store.mjs';
import { parseArgs, parseCsv, toCsv } from '../src/util.mjs';

const args = parseArgs(process.argv.slice(2));
const file = args._[0] || 'sales/prospects.csv';
const max = Number(args.max) || 15;
const text = await readFile(file, 'utf8');
const header = text.split(/\r?\n/)[0].split(',').map((h) => h.trim());
const rows = parseCsv(text);
const columns = [...new Set([...header, 'demo_url', 'pitch_url', 'status'])];

const config = loadConfig();
const store = createStore(config.dataDir);
await store.ensure();
const assistant = createAssistant({ store, notifier: createNotifier({ config }), config });

let done = 0;
for (const row of rows) {
  if (done >= max) break;
  if (!row.website || row.demo_url) continue;
  console.log(`\n▶ ${row.name || row.website}`);
  try {
    const r = await createDemo(row.website, { store, config, assistant, name: row.name || undefined, screenshot: !args['no-screenshot'], log: (m) => console.log(m) });
    row.demo_url = r.demoUrl;
    row.pitch_url = r.pitchUrl;
    row.status ||= 'demo';
    console.log(`  ✅ ${r.kb.stats.pages} стор., ${r.kb.prices.length} цін → ${r.demoUrl}`);
    r.warnings.forEach((w) => console.log(`  ⚠ ${w}`));
  } catch (err) {
    row.status = `помилка: ${err.message.slice(0, 80)}`;
    console.log(`  ❌ ${err.message}`);
  }
  done++;
  await writeFile(file, toCsv(rows, columns)); // зберігаємо після кожної клініки
}
console.log(`\nГотово: ${done} клінік оброблено. Файл оновлено: ${file}`);
