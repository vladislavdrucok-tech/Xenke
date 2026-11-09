// Повне демо без інтернету: вигаданий сайт «ДемоДент» → база знань → сервер із віджетом.
//   npm run sample   → відкрийте посилання з консолі
import { join } from 'node:path';
import { createApp } from '../server.mjs';
import { loadConfig, ROOT } from '../src/config.mjs';
import { createDemo } from '../src/demo.mjs';
import { serveStatic } from '../src/static.mjs';

const config = loadConfig();
const site = serveStatic(join(ROOT, 'examples', 'sample-clinic'));
await new Promise((r) => site.listen(8790, r));
const { server, store, assistant, adminPassword } = await createApp({ config });
const r = await createDemo('http://localhost:8790/', { store, config, assistant, slug: 'demodent', screenshot: true, log: (m) => console.log(m) });
server.listen(config.port, () => {
  console.log(`\nВигаданий сайт клініки: http://localhost:8790/`);
  console.log(`Демо:          ${r.demoUrl}`);
  console.log(`Презентація:   ${r.pitchUrl}`);
  console.log(`Кабінет:       ${config.publicUrl}/admin  (логін будь-який, пароль: ${adminPassword})`);
  console.log(`Режим бота:    ${assistant.mode === 'ai' ? 'AI' : 'локальний (додайте ANTHROPIC_API_KEY для AI)'}`);
});
