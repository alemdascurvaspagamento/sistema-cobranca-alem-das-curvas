/* O index.html não deve apontar para arquivos do próprio site que não existem
 * (manifest.json / ícones ausentes davam erro 404 ao instalar o app no celular). */
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('13. index.html não referencia arquivos locais inexistentes', () => {
  const root = path.resolve(__dirname, '..');
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const refs = [...html.matchAll(/<(?:link|script|img)\b[^>]*?\b(?:href|src)="([^"]+)"/g)].map((m) => m[1]);
  const local = refs.filter((r) => !/^(data:|https?:|\/\/|#)/i.test(r));
  const missing = local.filter((r) => !fs.existsSync(path.join(root, r.split(/[?#]/)[0])));
  assert.deepEqual(missing, []);
});
