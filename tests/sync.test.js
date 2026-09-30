/* Testes de sincronização do CoachFlow (banco simulado + navegador de verdade).
 * Rodar:  NODE_PATH=$(npm root -g) node --test tests/
 * Cada teste reproduz um problema que já aconteceu no sistema, para ele não voltar. */
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '..');
const FAKE_SRC = fs.readFileSync(path.join(__dirname, 'fake-supabase.js'), 'utf8');

let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser.close(); });

/** Abre o app numa aba limpa, com banco simulado no lugar do Supabase. */
async function openApp(seed) {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('dialog', (d) => d.accept());
  await page.route('**/*', (route) => {
    const url = route.request().url();
    if (url.startsWith('file://')) {
      if (url.endsWith('coachflow-api-client.js')) return route.fulfill({ body: '', contentType: 'text/javascript' });
      return route.continue();
    }
    return route.abort();
  });
  await page.goto('file://' + path.join(ROOT, 'index.html'));
  await page.evaluate(FAKE_SRC);
  await page.evaluate((s) => {
    window.__db = window.createFakeSupabase(s);
    adcSupabase = window.__db;
    // Sem sincronizações automáticas durante os testes: o teste decide quando sincronizar.
    clearInterval(adcSyncV2Interval);
    clearTimeout(adcAutoSyncV2Timer);
  }, seed || {});
  return { page, ctx, errors };
}

/** Uma segunda "aparelho" (ex.: celular) apontando para o MESMO banco simulado. */
async function openSecondDevice(first, seedFromFirst) {
  const dump = await first.page.evaluate(() => JSON.parse(JSON.stringify(window.__db.__tables)));
  return openApp(dump);
}

const sync = (page) => page.evaluate(() => adcSyncV2());
const tables = (page) => page.evaluate(() => JSON.parse(JSON.stringify(window.__db.__tables)));

/** Datas de segundas e quartas do mês atual (formato AAAA-MM-DD). */
const monthDates = (page) => page.evaluate(() => {
  const y = year(), m = month(), out = [];
  for (let d = 1; d <= 28; d++) {
    const dt = new Date(y, m, d, 12);
    if ([1, 3].includes(dt.getDay())) out.push(dt.toISOString().slice(0, 10));
  }
  return out;
});

const student = (id, name, extra = {}) => ({
  id, name, days: ['SEG', 'QUA'], times: { SEG: '06:00', QUA: '06:00' },
  rate: 100, duration: 60, active: true, email: '', phone: '', notes: '', ...extra,
});

async function putStudents(page, list) {
  await page.evaluate((l) => { data.students = l; data.events = {}; data.payments = {}; save(); }, list);
}

// ------------------------------------------------------------------ testes

test('1. sincronizar duas vezes seguidas não duplica alunos nem horários', async () => {
  const app = await openApp();
  await putStudents(app.page, [student('a1', 'Ana'), student('b1', 'Bruno')]);
  assert.equal(await sync(app.page), true);
  const t1 = await tables(app.page);
  assert.equal(t1.Alunos.length, 2);
  assert.equal(t1.horarios.filter((h) => h.ativo !== false).length, 4);
  assert.equal(await sync(app.page), true);
  assert.equal(await sync(app.page), true);
  const t2 = await tables(app.page);
  assert.equal(t2.Alunos.length, 2);
  assert.equal(t2.horarios.filter((h) => h.ativo !== false).length, 4);
  assert.deepEqual(app.errors, []);
  await app.ctx.close();
});

test('2. férias de 3 alunos marcadas antes de sincronizar: todas chegam ao banco e sobrevivem', async () => {
  const app = await openApp();
  await putStudents(app.page, [student('a1', 'Ana'), student('b1', 'Bruno'), student('c1', 'Carla')]);
  await sync(app.page); // cria cadastros
  const dates = await monthDates(app.page);
  const vac = dates.slice(0, 2);
  await app.page.evaluate((vac) => {
    for (const sid of ['b1', 'c1']) for (const dt of vac) data.events[eventKey(sid, dt)] = { status: 'cancelled', charge: false, credit: false, newDate: '', note: 'Férias' };
    save();
  }, vac);
  assert.equal(await sync(app.page), true);
  assert.equal(await sync(app.page), true);
  const cancelled = await app.page.evaluate((vac) => ['b1', 'c1'].every((sid) => vac.every((dt) => data.events[eventKey(sid, dt)]?.status === 'cancelled')), vac);
  assert.equal(cancelled, true, 'férias sumiram no aparelho depois de sincronizar');
  const t = await tables(app.page);
  assert.equal(t.aulas.filter((a) => a.status === 'cancelada').length, vac.length * 2);
  assert.equal(t.aulas.length, vac.length * 2, 'não deve criar aulas duplicadas');
  await app.ctx.close();
});

test('3. aluno duplicado no aparelho (mesmo cloudId) é unificado e as férias sobrevivem', async () => {
  const app = await openApp();
  await putStudents(app.page, [student('a1', 'Ana')]);
  await sync(app.page);
  const dates = await monthDates(app.page);
  await app.page.evaluate((dt) => {
    const cid = data.students[0].cloudId;
    data.students.push({ ...JSON.parse(JSON.stringify(data.students[0])), id: 'dup_' + cid });
    data.events[eventKey('dup_' + cid, dt)] = { status: 'cancelled', charge: false, credit: false, newDate: '', note: 'Férias' };
    save();
  }, dates[0]);
  assert.equal(await sync(app.page), true);
  assert.equal(await sync(app.page), true);
  const r = await app.page.evaluate((dt) => ({ n: data.students.length, st: Object.entries(data.events).filter(([k]) => k.endsWith('|' + dt)).map(([, e]) => e.status) }), dates[0]);
  assert.equal(r.n, 1, 'duplicado não foi unificado');
  assert.deepEqual(r.st, ['cancelled']);
  await app.ctx.close();
});

test('4. aluno excluído no banco some da lista; aluno ativo nunca fica "excluído" por engano', async () => {
  const app = await openApp();
  await putStudents(app.page, [student('a1', 'Ana'), student('b1', 'Bruno')]);
  await sync(app.page);
  // "excluem" o Bruno por outro aparelho
  await app.page.evaluate(() => { window.__db.__tables.Alunos.find((r) => r.nome === 'Bruno').excluido = true; });
  await sync(app.page);
  assert.deepEqual(await app.page.evaluate(() => data.students.map((s) => s.name)), ['Ana']);
  // Ana com cadastro marcado como excluído por engano no banco volta ao normal quando é reenviada
  await app.page.evaluate(() => {
    window.__db.__tables.Alunos.find((r) => r.nome === 'Ana').excluido = true;
    data.students = [data.students[0]]; // ainda está local
    data.pendingStudentChanges = { [data.students[0].id]: { ...data.students[0] } };
  });
  await sync(app.page);
  const ana = (await tables(app.page)).Alunos.find((r) => r.nome === 'Ana');
  assert.equal(ana.excluido, false);
  await app.ctx.close();
});

test('5. baixa de pagamento: grava uma vez, não some no celular e zerar remove', async () => {
  const app = await openApp();
  await putStudents(app.page, [student('a1', 'Ana')]);
  await sync(app.page);
  const key = await app.page.evaluate(() => {
    const k = billingKey('a1');
    data.payments[k] = { received: 200, date: '2026-09-10', method: 'Pix', dueDay: 5, note: '' };
    adcMarkPaymentDirty(k); save(); return k;
  });
  assert.equal(await sync(app.page), true);
  let t = await tables(app.page);
  assert.equal(t.pagamentos.length, 1);
  assert.equal(Number(t.pagamentos[0].valor), 200);
  // o celular (aparelho 2) abre, sincroniza e NÃO pode apagar a baixa
  const phone = await openSecondDevice(app);
  await putStudents(phone.page, [student('p1', 'Ana')]);
  await sync(phone.page);
  await sync(phone.page);
  t = await tables(phone.page);
  assert.equal(t.Alunos.length, 1, 'celular duplicou o aluno');
  assert.equal(t.pagamentos.length, 1, 'celular apagou ou duplicou a baixa');
  assert.equal(Number(t.pagamentos[0].valor), 200);
  // zerar a baixa remove o pagamento
  await app.page.evaluate((k) => { data.payments[k] = { received: 0, date: '', method: 'Pix', dueDay: 5, note: '' }; adcMarkPaymentDirty(k); save(); }, key);
  await sync(app.page);
  assert.equal((await tables(app.page)).pagamentos.length, 0);
  await app.ctx.close(); await phone.ctx.close();
});

test('6. falha ao gravar UMA aula não impede as outras e o erro é informado', async () => {
  const app = await openApp();
  await putStudents(app.page, [student('a1', 'Ana'), student('b1', 'Bruno')]);
  await sync(app.page);
  const dates = await monthDates(app.page);
  await app.page.evaluate(({ d0 }) => {
    data.events[eventKey('a1', d0)] = { status: 'cancelled', charge: false, credit: false, newDate: '', note: 'Férias' };
    data.events[eventKey('b1', d0)] = { status: 'cancelled', charge: false, credit: false, newDate: '', note: 'Férias' };
    // a gravação da aula do primeiro aluno falha
    const firstId = data.students[0].cloudId;
    window.__db.__state.failRule = (i) => (i.table === 'aulas' && i.action === 'insert' && i.payload.aluno_id === firstId ? 'erro de teste' : null);
    save();
  }, { d0: dates[0] });
  assert.equal(await sync(app.page), false);
  const t = await tables(app.page);
  assert.equal(t.aulas.filter((a) => a.status === 'cancelada').length, 1, 'a aula do segundo aluno deveria ter sido gravada');
  assert.match(await app.page.evaluate(() => adcLastSyncError), /alteraç/);
  // o problema some: o próximo ciclo grava a que faltou
  await app.page.evaluate(() => { window.__db.__state.failRule = null; });
  assert.equal(await sync(app.page), true);
  assert.equal((await tables(app.page)).aulas.filter((a) => a.status === 'cancelada').length, 2);
  await app.ctx.close();
});

test('7. aluno criado em dois aparelhos com o mesmo nome não vira dois alunos', async () => {
  const app = await openApp();
  await putStudents(app.page, [student('a1', 'Ana')]);
  await sync(app.page);
  const phone = await openSecondDevice(app);
  await putStudents(phone.page, [student('p1', 'ana')]); // sem cloudId, nome com caixa diferente
  await sync(phone.page);
  assert.equal(await phone.page.evaluate(() => data.students.length), 1);
  assert.equal((await tables(phone.page)).Alunos.length, 1);
  await app.ctx.close(); await phone.ctx.close();
});

// ------------------------------------------------ eficiência (menos idas ao banco)

const fullSetup = (page, n = 17) => page.evaluate((n) => {
  data.students = Array.from({ length: n }, (_, i) => ({ id: 's' + i, name: 'Aluno ' + i, days: ['SEG', 'QUA'], times: { SEG: '06:00', QUA: '06:00' }, rate: 100, duration: 60, active: true }));
  data.holidays = [{ id: 'h1', date: '2026-09-07', name: 'Independência', discount: true }];
  data.extraIncome = [{ id: 'x1', date: '2026-09-02', description: 'Avulso', amount: 50 }];
  data.expenses = [{ id: 'e1', date: '2026-09-03', description: 'Aluguel', amount: 300 }];
  data.fixedExpenses = [{ id: 'f1', description: 'Internet', amount: 100, day: 5, active: true }];
  data.revenueGoals = { 2026: 120000 };
  data.events = {}; data.payments = {}; save();
}, n);
const writes = (page) => page.evaluate(() => window.__db.__calls.filter((c) => c.action !== 'select').map((c) => c.table + '.' + c.action));
const resetCalls = (page) => page.evaluate(() => window.__db.__reset());

test('8. ciclo de sincronização sem nenhuma mudança não escreve nada no banco', async () => {
  const app = await openApp();
  await fullSetup(app.page);
  await sync(app.page);
  await sync(app.page); // o 2º ciclo já estabiliza o retrato (vem do pull)
  await resetCalls(app.page);
  assert.equal(await sync(app.page), true);
  assert.deepEqual(await writes(app.page), []);
  assert.ok((await app.page.evaluate(() => window.__db.__calls.length)) <= 12, 'mais idas ao banco do que o esperado num ciclo parado');
  await app.ctx.close();
});

test('9. mudança pontual envia só o que mudou (despesa, feriado, meta, configuração, valor de UM aluno)', async () => {
  const app = await openApp();
  await fullSetup(app.page);
  await sync(app.page); await sync(app.page);
  await resetCalls(app.page);
  await app.page.evaluate(() => {
    data.expenses[0].amount = 350;
    data.holidays[0].name = 'Independência do Brasil';
    data.revenueGoals = { 2026: 130000 };
    data.config.pixKey = 'chave-nova';
    data.students[3].rate = 120;
    save();
  });
  assert.equal(await sync(app.page), true);
  const w = (await writes(app.page)).sort();
  assert.deepEqual(w, ['cobrancas.update', 'configuracoes.upsert', 'despesas.upsert', 'feriados.upsert', 'metas_receita.upsert']);
  const t = await tables(app.page);
  assert.equal(Number(t.despesas.find((r) => r.id === 'e1').valor), 350);
  assert.equal(t.feriados[0].nome, 'Independência do Brasil');
  assert.equal(t.configuracoes[0].pix_key, 'chave-nova');
  assert.equal(Number(t.metas_receita.find((r) => r.ano === 2026).meta_anual), 130000);
  await app.ctx.close();
});

test('10. botão "Sincronizar" força envio completo e recria cobranças que faltarem no banco', async () => {
  const app = await openApp();
  await fullSetup(app.page, 3);
  await sync(app.page); await sync(app.page);
  // alguém apagou as cobranças direto no banco
  await app.page.evaluate(() => { window.__db.__tables.cobrancas.length = 0; });
  await sync(app.page); // ciclo automático não percebe (nada mudou no aparelho)
  assert.equal((await tables(app.page)).cobrancas.length, 0);
  await app.page.evaluate(() => adcManualSync(false)); // botão manual
  const t = await tables(app.page);
  assert.equal(t.cobrancas.length, 3, 'o botão Sincronizar deveria recriar as cobranças');
  await app.ctx.close();
});

test('11. falha no meio do envio não marca como enviado: o ciclo seguinte tenta de novo', async () => {
  const app = await openApp();
  await fullSetup(app.page, 2);
  await sync(app.page); await sync(app.page);
  await app.page.evaluate(() => {
    data.extraIncome[0].amount = 99; save();
    window.__db.__state.failRule = (i) => (i.table === 'ganhos_extras' && i.action === 'upsert' ? 'falha de teste' : null);
  });
  assert.equal(await sync(app.page), false);
  await app.page.evaluate(() => { window.__db.__state.failRule = null; });
  assert.equal(await sync(app.page), true);
  assert.equal(Number((await tables(app.page)).ganhos_extras[0].valor), 99);
  await app.ctx.close();
});

test('12. trocar de conta no aparelho descarta o retrato e reenvia tudo', async () => {
  const app = await openApp();
  await fullSetup(app.page, 2);
  await sync(app.page); await sync(app.page);
  await app.page.evaluate(() => { window.__db.__state.userId = 'user-test-2'; });
  await sync(app.page);
  assert.equal(await app.page.evaluate(() => data.pushedSnapshotV2.__owner), 'user-test-2');
  const t = await tables(app.page);
  assert.ok(t.feriados.some((r) => r.owner_id === 'user-test-2'), 'feriado não foi reenviado para a nova conta');
  await app.ctx.close();
});
