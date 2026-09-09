/* CoachFlow API client v1
 * Backend: Supabase Edge Function /functions/v1/coachflow-api
 * This module is intentionally standalone so the legacy Supabase sync can be migrated safely module-by-module.
 */
(function (global) {
  'use strict';
  const SUPABASE_URL = 'https://yjpxjzgvshaabjpdpbsc.supabase.co';
  const API_URL = SUPABASE_URL + '/functions/v1/coachflow-api';
  const ALLOWED_TABLES = new Set([
    'Alunos','horarios','aulas','cobrancas','pagamentos','feriados',
    'ganhos_extras','configuracoes','despesas','despesas_fixas','despesas_fixas_lancamentos'
  ]);

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
    const response = await fetch(API_URL, {
      method: 'POST',
      headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || ('CoachFlow API HTTP ' + response.status));
    return payload.data;
  }

  global.coachflowApi = {
    url: API_URL,
    select: (table, options) => request(table, 'select', options),
    insert: (table, data) => request(table, 'insert', { data }),
    update: (table, id, data) => request(table, 'update', { id, data }),
    remove: (table, id) => request(table, 'delete', { id })
  };
})(window);
