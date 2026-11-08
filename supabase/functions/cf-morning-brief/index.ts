// Resumo da manhã do Léguno, por e-mail.
// Chamado a cada hora cheia (pg_cron). Só envia para quem ligou o resumo,
// escolheu aquela hora e ainda não recebeu hoje — chamar de novo não repete.
// Com {"test": true} e o login da pessoa, manda um de teste só para ela.
import { buildBrief, Payload } from './brief.ts';

const URL_ = Deno.env.get('SUPABASE_URL')!;
const KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RESEND = Deno.env.get('RESEND_API_KEY') ?? '';
const FROM = 'Léguno <nao-responda@leguno.com.br>';
const APP = 'https://app.leguno.com.br';

const admin = { apikey: KEY, Authorization: `Bearer ${KEY}` };
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function nowSaoPaulo(): { date: string; hour: number } {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', hourCycle: 'h23',
  }).formatToParts(new Date());
  const get = (t: string) => parts.find((p) => p.type === t)!.value;
  return { date: `${get('year')}-${get('month')}-${get('day')}`, hour: Number(get('hour')) };
}

async function emailOf(id: string): Promise<string | null> {
  const r = await fetch(`${URL_}/auth/v1/admin/users/${id}`, { headers: admin });
  if (!r.ok) return null;
  return (await r.json()).email ?? null;
}

async function send(to: string, payload: Payload, today: string): Promise<boolean> {
  const b = buildBrief(payload, today, APP);
  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${RESEND}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from: FROM, to: [to], subject: b.subject, html: b.html, text: b.text }),
  });
  if (!r.ok) console.error('Resend', r.status, await r.text());
  return r.ok;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (!RESEND) return json({ error: 'RESEND_API_KEY não configurada' }, 500);
  const { date, hour } = nowSaoPaulo();
  const body = await req.json().catch(() => ({}));

  // Teste: só para a pessoa logada, a qualquer hora.
  if (body?.test) {
    const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
    const u = await fetch(`${URL_}/auth/v1/user`, { headers: { apikey: KEY, Authorization: `Bearer ${token}` } });
    if (!u.ok) return json({ error: 'Entre na sua conta.' }, 401);
    const user = await u.json();
    const rows = await (await fetch(`${URL_}/rest/v1/cf_morning_brief?owner_id=eq.${user.id}&select=payload`, { headers: admin })).json();
    if (!rows.length || !user.email) return json({ error: 'Resumo ainda não preparado.' }, 404);
    const ok = await send(user.email, rows[0].payload, date);
    return json({ sent: ok ? 1 : 0 });
  }

  // Envio do horário.
  const q = `${URL_}/rest/v1/cf_morning_brief?email_on=eq.true&send_hour=eq.${hour}` +
    `&or=(last_sent_on.is.null,last_sent_on.lt.${date})&select=owner_id,payload&limit=500`;
  const rows: Array<{ owner_id: string; payload: Payload }> = await (await fetch(q, { headers: admin })).json();
  let sent = 0;
  for (const row of rows) {
    // Marca antes de enviar: se algo falhar, não manda duas vezes no mesmo dia.
    const mark = await fetch(
      `${URL_}/rest/v1/cf_morning_brief?owner_id=eq.${row.owner_id}&or=(last_sent_on.is.null,last_sent_on.lt.${date})`,
      { method: 'PATCH', headers: { ...admin, 'Content-Type': 'application/json', Prefer: 'return=representation' }, body: JSON.stringify({ last_sent_on: date }) },
    );
    const marked = mark.ok ? await mark.json() : [];
    if (!marked.length) continue;
    const to = await emailOf(row.owner_id);
    if (to && (await send(to, row.payload, date))) sent++;
  }
  return json({ hour, date, due: rows.length, sent });
});
