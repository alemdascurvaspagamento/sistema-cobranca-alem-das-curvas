// Assinatura do Léguno pelo Asaas.
// - Quem ainda não paga: cria a assinatura e devolve o link da fatura (Pix, boleto ou cartão).
//   No teste grátis, o primeiro vencimento é o último dia do teste (não perde dias).
// - Quem já paga: troca o plano na hora e o novo valor vale a partir da próxima cobrança.
// Segredos: ASAAS_API_KEY (obrigatório) e ASAAS_BASE (padrão: sandbox, o ambiente de teste do Asaas).
const URL_ = Deno.env.get('SUPABASE_URL')!;
const KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ASAAS_KEY = Deno.env.get('ASAAS_API_KEY') ?? '';
const ASAAS = Deno.env.get('ASAAS_BASE') ?? 'https://api-sandbox.asaas.com/v3';
const admin = { apikey: KEY, Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' };
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });

const PRICES: Record<string, Record<string, number>> = {
  essencial: { monthly: 34.9, annual: 349 },
  profissional: { monthly: 59.9, annual: 599 },
};
const FOUNDER = 39.9;

function validDoc(d: string): boolean {
  if (!/^\d{11}$|^\d{14}$/.test(d) || /^(\d)\1+$/.test(d)) return false;
  const n = d.split('').map(Number);
  if (d.length === 11) {
    const dv = (len: number) => {
      let s = 0;
      for (let i = 0; i < len; i++) s += n[i] * (len + 1 - i);
      const r = (s * 10) % 11;
      return r === 10 ? 0 : r;
    };
    return dv(9) === n[9] && dv(10) === n[10];
  }
  const dv = (w: number[]) => {
    const s = w.reduce((a, x, i) => a + n[i] * x, 0) % 11;
    return s < 2 ? 0 : 11 - s;
  };
  return dv([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) === n[12] && dv([6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) === n[13];
}

async function asaas(path: string, method = 'GET', body?: unknown) {
  const r = await fetch(`${ASAAS}${path}`, {
    method,
    headers: { access_token: ASAAS_KEY, 'Content-Type': 'application/json', 'User-Agent': 'Leguno' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await r.json().catch(() => ({}));
  if (!r.ok) {
    const msg = data?.errors?.[0]?.description ?? `Asaas ${r.status}`;
    throw new Error(msg);
  }
  return data;
}

const ymd = (d: Date) => new Date(d.getTime() - 3 * 3600_000).toISOString().slice(0, 10); // horário de Brasília

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (!ASAAS_KEY) return json({ error: 'Os pagamentos online ainda não foram ligados. Fale com daniel@leguno.com.br.' }, 503);

  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  const u = await fetch(`${URL_}/auth/v1/user`, { headers: { apikey: KEY, Authorization: `Bearer ${token}` } });
  if (!u.ok) return json({ error: 'Entre na sua conta.' }, 401);
  const user = await u.json();

  const b = await req.json().catch(() => ({}));
  const plan = String(b.plan ?? '');
  const cycle = String(b.cycle ?? '');
  if (!PRICES[plan] || !PRICES[plan][cycle]) return json({ error: 'Plano inválido.' }, 400);

  const subs = await (await fetch(`${URL_}/rest/v1/cf_subscriptions?owner_id=eq.${user.id}&select=*`, { headers: admin })).json();
  const sub = subs?.[0];
  if (!sub) return json({ error: 'Conta sem cadastro completo. Saia e entre de novo.' }, 409);
  if (sub.status === 'courtesy') return json({ error: 'Sua conta é cortesia: não precisa assinar.' }, 409);

  const now = new Date();
  const trialing = sub.status === 'trialing' && sub.trial_ends_at && new Date(sub.trial_ends_at) > now;
  const paying = ['active', 'past_due'].includes(sub.status) && sub.asaas_subscription_id;

  let founder = false;
  if (plan === 'profissional' && cycle === 'monthly') {
    if (sub.founder) founder = true;
    else if (trialing) {
      const slots = await (await fetch(`${URL_}/rest/v1/rpc/_cf_founder_slots`, { method: 'POST', headers: admin, body: '{}' })).json();
      founder = Number(slots) > 0;
    }
  }
  const value = founder ? FOUNDER : PRICES[plan][cycle];
  const asaasCycle = cycle === 'annual' ? 'YEARLY' : 'MONTHLY';
  const description = `Léguno ${plan === 'essencial' ? 'Essencial' : 'Profissional'} (${cycle === 'annual' ? 'anual' : 'mensal'})${founder ? ' · fundador' : ''}`;

  try {
    if (paying) {
      // Troca de plano: o valor novo vale na próxima cobrança; as funções mudam na hora.
      await asaas(`/subscriptions/${sub.asaas_subscription_id}`, 'POST', {
        value, cycle: asaasCycle, description, updatePendingPayments: true,
      });
      await fetch(`${URL_}/rest/v1/cf_checkouts`, {
        method: 'POST', headers: admin,
        body: JSON.stringify({ owner_id: user.id, asaas_subscription_id: sub.asaas_subscription_id, plan, cycle, founder, value }),
      });
      await fetch(`${URL_}/rest/v1/cf_subscriptions?owner_id=eq.${user.id}`, {
        method: 'PATCH', headers: admin, body: JSON.stringify({ plan, cycle, founder }),
      });
      return json({ changed: true });
    }

    const doc = String(b.cpfCnpj ?? '').replace(/\D/g, '');
    const name = String(b.name ?? '').trim().slice(0, 100);
    if (name.length < 3) return json({ error: 'Digite o nome completo ou a razão social.' }, 400);
    if (!validDoc(doc)) return json({ error: 'Confira o CPF ou CNPJ.' }, 400);

    let customer = sub.asaas_customer_id as string | null;
    if (customer) {
      await asaas(`/customers/${customer}`, 'POST', { name, cpfCnpj: doc, email: user.email });
    } else {
      const c = await asaas('/customers', 'POST', { name, cpfCnpj: doc, email: user.email, externalReference: user.id });
      customer = c.id;
      await fetch(`${URL_}/rest/v1/cf_subscriptions?owner_id=eq.${user.id}`, {
        method: 'PATCH', headers: admin, body: JSON.stringify({ asaas_customer_id: customer }),
      });
    }

    // Tentativas anteriores que não foram pagas: apaga para não cobrar duas vezes.
    const old = await (await fetch(
      `${URL_}/rest/v1/cf_checkouts?owner_id=eq.${user.id}&asaas_subscription_id=not.is.null&select=asaas_subscription_id`,
      { headers: admin },
    )).json();
    for (const o of old ?? []) {
      if (o.asaas_subscription_id && o.asaas_subscription_id !== sub.asaas_subscription_id) {
        await asaas(`/subscriptions/${o.asaas_subscription_id}`, 'DELETE').catch(() => {});
      }
    }

    const due = trialing ? ymd(new Date(sub.trial_ends_at)) : ymd(now);
    const s = await asaas('/subscriptions', 'POST', {
      customer, billingType: 'UNDEFINED', value, nextDueDate: due, cycle: asaasCycle, description,
      externalReference: user.id,
    });
    await fetch(`${URL_}/rest/v1/cf_checkouts`, {
      method: 'POST', headers: admin,
      body: JSON.stringify({ owner_id: user.id, asaas_subscription_id: s.id, plan, cycle, founder, value }),
    });
    const pays = await asaas(`/subscriptions/${s.id}/payments?limit=1`);
    const url = pays?.data?.[0]?.invoiceUrl;
    if (!url) return json({ error: 'A assinatura foi criada, mas o link de pagamento ainda não saiu. Tente de novo em instantes.' }, 502);
    return json({ url });
  } catch (e) {
    console.error('cf-checkout:', (e as Error).message);
    return json({ error: 'O sistema de pagamento recusou o pedido: ' + (e as Error).message }, 502);
  }
});
