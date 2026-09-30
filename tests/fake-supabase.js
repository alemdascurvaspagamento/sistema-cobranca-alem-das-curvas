/* Banco de mentira (em memória) que imita o que o CoachFlow usa do cliente Supabase.
 * É injetado na página pelo teste: window.createFakeSupabase(seed) -> cliente com
 * from().select/insert/update/delete/upsert/eq/ilike/in/order/limit/single/maybeSingle e auth.*
 * Guarda um registro de todas as chamadas (calls) para medir quantas idas ao banco acontecem. */
(function (global) {
  const NUMERIC_ID = new Set(['Alunos', 'horarios', 'aulas', 'cobrancas', 'pagamentos']);

  function createFakeSupabase(seed) {
    const tables = {};
    const counters = {};
    const calls = [];
    const state = { failRule: null, userId: 'user-test-1', hasSession: true };

    const table = (n) => tables[n] || (tables[n] = []);
    const clone = (x) => JSON.parse(JSON.stringify(x));
    const nextId = (n) => (counters[n] = (counters[n] || 0) + 1);

    Object.entries(seed || {}).forEach(([n, rows]) => {
      rows.forEach((r) => {
        const row = clone(r);
        if (NUMERIC_ID.has(n)) {
          if (row.id == null) row.id = nextId(n);
          else counters[n] = Math.max(counters[n] || 0, Number(row.id));
        }
        table(n).push(row);
      });
    });

    function likeToRegex(p) {
      const esc = String(p).replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/%/g, '.*').replace(/_/g, '.');
      return new RegExp('^' + esc + '$', 'i');
    }

    function matches(row, filters) {
      return filters.every((f) => {
        const v = row[f.column];
        if (f.op === 'eq') return String(v) === String(f.value) && (v !== null && v !== undefined);
        if (f.op === 'ilike') return likeToRegex(f.value).test(String(v ?? ''));
        if (f.op === 'in') return f.value.map(String).includes(String(v));
        return true;
      });
    }

    function builder(name, action) {
      const q = { action, filters: [], returning: false, single: false, maybe: false, order: null, limit: null, payload: null, onConflict: null };
      const api = {
        select() { if (q.action !== 'select') q.returning = true; return api; },
        eq(column, value) { q.filters.push({ column, op: 'eq', value }); return api; },
        ilike(column, value) { q.filters.push({ column, op: 'ilike', value }); return api; },
        in(column, value) { q.filters.push({ column, op: 'in', value }); return api; },
        order(column, o) { q.order = { column, asc: !o || o.ascending !== false }; return api; },
        limit(n) { q.limit = n; return api; },
        single() { q.single = true; return api; },
        maybeSingle() { q.maybe = true; return api; },
        then(resolve, reject) { return Promise.resolve().then(() => run()).then(resolve, reject); },
      };

      function run() {
        const info = { table: name, action: q.action, payload: q.payload, filters: q.filters };
        calls.push({ table: name, action: q.action });
        if (!state.hasSession) return { data: null, error: { message: 'JWT expired' } };
        const failMsg = state.failRule && state.failRule(info);
        if (failMsg) return { data: null, error: { message: failMsg } };

        const rows = table(name);
        let out = [];

        if (q.action === 'select') {
          out = rows.filter((r) => matches(r, q.filters));
        } else if (q.action === 'insert') {
          const list = Array.isArray(q.payload) ? q.payload : [q.payload];
          list.forEach((p) => {
            const row = clone(p);
            if (NUMERIC_ID.has(name) && row.id == null) row.id = nextId(name);
            rows.push(row);
            out.push(row);
          });
        } else if (q.action === 'update') {
          rows.filter((r) => matches(r, q.filters)).forEach((r) => { Object.assign(r, clone(q.payload)); out.push(r); });
        } else if (q.action === 'delete') {
          const keep = []; rows.forEach((r) => { if (matches(r, q.filters)) out.push(r); else keep.push(r); });
          tables[name] = keep;
        } else if (q.action === 'upsert') {
          const list = Array.isArray(q.payload) ? q.payload : [q.payload];
          const keys = String(q.onConflict || 'id').split(',').map((s) => s.trim());
          list.forEach((p) => {
            const found = rows.find((r) => keys.every((k) => String(r[k]) === String(p[k])));
            if (found) { Object.assign(found, clone(p)); out.push(found); }
            else { const row = clone(p); if (NUMERIC_ID.has(name) && row.id == null) row.id = nextId(name); rows.push(row); out.push(row); }
          });
        }

        if (q.order) out = out.slice().sort((a, b) => (a[q.order.column] > b[q.order.column] ? 1 : -1) * (q.order.asc ? 1 : -1));
        if (q.limit != null) out = out.slice(0, q.limit);

        const wantsRows = q.action === 'select' || q.returning;
        if (q.single) {
          if (out.length !== 1) return { data: null, error: { message: 'Esperava exatamente 1 linha, veio ' + out.length } };
          return { data: clone(out[0]), error: null };
        }
        if (q.maybe) return { data: out.length ? clone(out[0]) : null, error: null };
        return { data: wantsRows ? clone(out) : null, error: null };
      }

      return Object.assign(api, {
        _setPayload(p, oc) { q.payload = p; q.onConflict = oc || null; return api; },
      });
    }

    const client = {
      from(name) {
        return {
          select: (...a) => builder(name, 'select').select(...a),
          insert: (p) => builder(name, 'insert')._setPayload(p),
          update: (p) => builder(name, 'update')._setPayload(p),
          upsert: (p, o) => builder(name, 'upsert')._setPayload(p, o && o.onConflict),
          delete: () => builder(name, 'delete'),
        };
      },
      auth: {
        getSession: async () => ({ data: { session: state.hasSession ? { access_token: 'tok' } : null }, error: null }),
        refreshSession: async () => ({ data: { session: state.hasSession ? { access_token: 'tok' } : null }, error: null }),
        getUser: async () => ({ data: { user: { id: state.userId } }, error: null }),
      },
    };

    // Acesso para os testes
    client.__tables = tables;
    client.__calls = calls;
    client.__state = state;
    client.__writes = () => calls.filter((c) => c.action !== 'select').length;
    client.__reset = () => { calls.length = 0; };
    return client;
  }

  global.createFakeSupabase = createFakeSupabase;
})(typeof window !== 'undefined' ? window : globalThis);
