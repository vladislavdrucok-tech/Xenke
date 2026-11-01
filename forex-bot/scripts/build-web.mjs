// Збирає браузерну демо-версію в web-demo/ (одна сторінка без сервера).  npm run build:web
import { build } from 'esbuild';
import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const out = join(root, 'web-demo');
mkdirSync(out, { recursive: true });
await build({ entryPoints: [join(root, 'web/entry.mjs')], bundle: true, format: 'esm', target: 'es2022', outfile: join(out, 'app.js'), legalComments: 'none' });
const html = readFileSync(join(root, 'public/index.html'), 'utf8')
  .replace('<title>Pulse FX · віртуальний рахунок</title>', '<title>Pulse FX · демо</title>')
  .replace('src="app.mjs"', 'src="app.js"');
writeFileSync(join(out, 'index.html'), html);
for (const f of ['style.css', 'mascot.svg']) copyFileSync(join(root, 'public', f), join(out, f));
console.log('web-demo/ готово');
