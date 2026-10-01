/* CoachFlow API client v7 */
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
      return {
        select(columns) { return builder(table, 'select', { columns: columns || '*' }); },
        insert(data) { return builder(table, 'insert', { data }); },
        update(data) { return builder(table, 'update', { data }); },
        delete() { return builder(table, 'delete'); },
        /* Temporary compatibility path: deployed API v2 has no upsert action. RLS still scopes this authenticated native call. */
        upsert(data, options) { return nativeFrom(table).upsert(data, options); }
      };
    }
    proxyFrom.__coachflowProxy = true;
    sb.from = proxyFrom;
    global.coachflowApi = { url: API_URL, select: (table, options) => request(table, 'select', options), insert: (table, data) => request(table, 'insert', { data }), update: (table, id, data) => request(table, 'update', { id, data }), remove: (table, id) => request(table, 'delete', { id }) };
    return true;
  }

  /*
   * Financeiro v7
   * O script principal mantém renderFinance/data como bindings lexicais e não como
   * propriedades de window. A v6 tentou acessá-los por global.renderFinance/global.data,
   * portanto o patch nunca era instalado. A v7 trabalha diretamente com os KPIs que o
   * renderFinance já preenche no DOM: finPrevisto (serviços) + finExtraTotal (extras).
   */
  function parseBRL(text) {
    const raw = String(text || '').replace(/[^0-9,.-]/g, '').replace(/\./g, '').replace(',', '.');
    const value = Number(raw);
    return Number.isFinite(value) ? value : 0;
  }
  function formatBRL(value) {
    return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(Number(value) || 0);
  }
  let financePatchBusy = false;
  function applyFinanceForecastPatch() {
    if (financePatchBusy) return false;
    const previstoEl = document.getElementById('finPrevisto');
    const extraEl = document.getElementById('finExtraTotal');
    if (!previstoEl || !extraEl) return false;

    const extra = parseBRL(extraEl.textContent);
    const current = parseBRL(previstoEl.textContent);
    const lastApplied = Number(previstoEl.dataset.coachflowAppliedTotal || NaN);
    const lastExtra = Number(previstoEl.dataset.coachflowExtra || NaN);
    let servicesForecast;

    // Se o valor atual é exatamente o que nós aplicamos, não soma de novo.
    // Se renderFinance acabou de rodar, ele terá restaurado finPrevisto para o valor-base
    // dos atendimentos; nesse caso current passa a ser a nova base.
    if (Number.isFinite(lastApplied) && Math.abs(current - lastApplied) < 0.005) {
      servicesForecast = Number(previstoEl.dataset.coachflowServices || 0);
      if (Number.isFinite(lastExtra) && Math.abs(extra - lastExtra) < 0.005) return true;
    } else {
      servicesForecast = current;
    }

    const total = servicesForecast + extra;
    financePatchBusy = true;
    previstoEl.dataset.coachflowServices = String(servicesForecast);
    previstoEl.dataset.coachflowExtra = String(extra);
    previstoEl.dataset.coachflowAppliedTotal = String(total);
    previstoEl.textContent = formatBRL(total);

    const card = previstoEl.closest('.dataCard,.kpiCard,.card') || previstoEl.parentElement;
    if (card) {
      let detail = card.querySelector('[data-coachflow-forecast-detail]');
      if (!detail) {
        detail = document.createElement('div');
        detail.setAttribute('data-coachflow-forecast-detail', '1');
        detail.style.cssText = 'margin-top:7px;padding-top:7px;border-top:1px solid rgba(15,23,42,.10);font-size:12px;line-height:1.35;color:#667085;font-weight:600';
        card.appendChild(detail);
      }
      detail.innerHTML = '<span style="color:#18212B">' + formatBRL(servicesForecast) + '</span> atendimentos + <span style="color:#2F766D">' + formatBRL(extra) + '</span> ganhos extras';
    }
    financePatchBusy = false;
    return true;
  }
  function installFinanceForecastPatch() {
    if (global.__coachflowFinanceForecastObserver) return true;
    const root = document.body;
    if (!root) return false;
    let scheduled = false;
    const schedule = function () {
      if (financePatchBusy || scheduled) return;
      scheduled = true;
      setTimeout(function () { scheduled = false; applyFinanceForecastPatch(); }, 0);
    };
    const observer = new MutationObserver(function (mutations) {
      for (const mutation of mutations) {
        const target = mutation.target.nodeType === 3 ? mutation.target.parentElement : mutation.target;
        if (target && (target.id === 'finPrevisto' || target.id === 'finExtraTotal' || target.closest?.('#finPrevisto,#finExtraTotal'))) {
          schedule();
          break;
        }
      }
    });
    observer.observe(root, { subtree: true, childList: true, characterData: true });
    global.__coachflowFinanceForecastObserver = observer;
    schedule();
    return true;
  }

  let attempts = 0;
  const timer = setInterval(() => {
    attempts += 1;
    const proxyReady = installProxy();
    const financeReady = installFinanceForecastPatch();
    if ((proxyReady && financeReady) || attempts >= 300) clearInterval(timer);
  }, 10);
  installProxy();
  installFinanceForecastPatch();
})(window);
