/* CoachFlow API client v3 */
(function (global) {
  'use strict';
  const SUPABASE_URL = 'https://yjpxjzgvshaabjpdpbsc.supabase.co';
  const API_URL = SUPABASE_URL + '/functions/v1/coachflow-api';
  const ALLOWED_TABLES = new Set(['Alunos','horarios','aulas','cobrancas','pagamentos','feriados','ganhos_extras','configuracoes','despesas','despesas_fixas','despesas_fixas_lancamentos']);
  async function getAccessToken() {
    if (!global.adcSupabase || !global.adcSupabase.auth) throw new Error('Supabase client indisponível');
    const { data, error } = await global.adcSupabase.auth.getSession();
    if (error) throw error;
    const token = data && data.session && data.session.access_token;
    if (!token) throw new Error('Sessão não autenticada');
    return token;
  }
  async function request(table, action, options) {
    if (!ALLOWED_TABLES.has(table)) throw new Error('Tabela não permitida: ' + table);
    options = options || {};
    const token = await getAccessToken();
    const body = { table, action };
    if (options.id != null) body.id = options.id;
    if (options.data != null) body.data = options.data;
    if (options.filters) body.filters = options.filters;
    if (options.columns) body.columns = options.columns;
    if (options.limit != null) body.limit = options.limit;
    if (options.order) body.order = options.order;
    const response = await fetch(API_URL, { method: 'POST', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || ('CoachFlow API HTTP ' + response.status));
    return payload.data;
  }
  function builder(table, action, initial) {
    const state = Object.assign({ filters: [] }, initial || {});
    const api = {
      select(columns) { state.columns = columns || '*'; return api; },
      eq(column, value) { if ((action === 'update' || action === 'delete') && column === 'id') state.id = value; else state.filters.push({ column, op: 'eq', value }); return api; },
      neq(column, value) { state.filters.push({ column, op: 'neq', value }); return api; },
      gt(column, value) { state.filters.push({ column, op: 'gt', value }); return api; },
      gte(column, value) { state.filters.push({ column, op: 'gte', value }); return api; },
      lt(column, value) { state.filters.push({ column, op: 'lt', value }); return api; },
      lte(column, value) { state.filters.push({ column, op: 'lte', value }); return api; },
      in(column, value) { state.filters.push({ column, op: 'in', value }); return api; },
      is(column, value) { state.filters.push({ column, op: 'is', value }); return api; },
      ilike(column, value) { state.filters.push({ column, op: 'ilike', value }); return api; },
      order(column, options) { state.order = { column, ascending: !options || options.ascending !== false }; return api; },
      limit(value) { state.limit = value; return api; },
      single() { state.single = true; return api; },
      maybeSingle() { state.maybeSingle = true; return api; },
      then(resolve, reject) { return request(table, action, state).then((data) => { let result = data; if (state.single || state.maybeSingle) result = Array.isArray(data) ? (data.length ? data[0] : null) : data; return resolve ? resolve({ data: result, error: null }) : result; }).catch((error) => reject ? reject({ data: null, error }) : Promise.reject(error)); },
      catch(reject) { return api.then(undefined, reject); }
    };
    return api;
  }
  function installProxy() {
    const sb = global.adcSupabase;
    if (!sb || typeof sb.from !== 'function') return false;
    if (sb.from.__coachflowProxy) return true;
    const nativeFrom = sb.from.bind(sb);
    function proxyFrom(table) {
      if (!ALLOWED_TABLES.has(table)) return nativeFrom(table);
      return { select(columns) { return builder(table, 'select', { columns: columns || '*' }); }, insert(data) { return builder(table, 'insert', { data }); }, update(data) { return builder(table, 'update', { data }); }, delete() { return builder(table, 'delete'); }, upsert(data) { return builder(table, 'insert', { data }); } };
    }
    proxyFrom.__coachflowProxy = true;
    sb.from = proxyFrom;
    global.coachflowApi = { url: API_URL, select: (table, options) => request(table, 'select', options), insert: (table, data) => request(table, 'insert', { data }), update: (table, id, data) => request(table, 'update', { id, data }), remove: (table, id) => request(table, 'delete', { id }) };
    return true;
  }
  let attempts = 0;
  const timer = setInterval(() => { attempts += 1; if (installProxy() || attempts >= 300) clearInterval(timer); }, 10);
  installProxy();
})(window);
