// Avisa o cliente por e-mail quando o profissional aceita ou recusa um pedido
// do agendamento online. Só o dono do pedido (logado) pode chamar.
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
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });
const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));
const WEEK = ['domingo', 'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado'];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (!RESEND) return json({ error: 'RESEND_API_KEY não configurada' }, 500);
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  const u = await fetch(`${URL_}/auth/v1/user`, { headers: { apikey: KEY, Authorization: `Bearer ${token}` } });
  if (!u.ok) return json({ error: 'Entre na sua conta.' }, 401);
  const user = await u.json();
  const { id, status } = await req.json().catch(() => ({}));
  if (typeof id !== 'string' || !['accepted', 'declined'].includes(status)) return json({ error: 'Pedido inválido.' }, 400);

  const rq = await (await fetch(`${URL_}/rest/v1/cf_booking_requests?id=eq.${encodeURIComponent(id)}&owner_id=eq.${user.id}&select=name,email,service,date,time,status`, { headers: admin })).json();
  const r = rq?.[0];
  if (!r) return json({ error: 'Pedido não encontrado.' }, 404);
  if (r.status !== status) return json({ error: 'O pedido não está nesse estado.' }, 409);
  if (!r.email) return json({ sent: 0, reason: 'sem e-mail' });

  const prof = (await (await fetch(`${URL_}/rest/v1/cf_profiles?owner_id=eq.${user.id}&select=business_name,pix_name`, { headers: admin })).json())?.[0] ?? {};
  const who = (prof.business_name || prof.pix_name || 'o profissional').trim();
  const set = (await (await fetch(`${URL_}/rest/v1/cf_booking_settings?owner_id=eq.${user.id}&select=slug`, { headers: admin })).json())?.[0];
  const link = set?.slug ? `${APP}/?agendar=${set.slug}` : '';

  const d = new Date(r.date + 'T12:00:00Z');
  const day = `${WEEK[d.getUTCDay()]}, ${String(d.getUTCDate()).padStart(2, '0')}/${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
  const first = String(r.name).trim().split(/\s+/)[0];
  const what = r.service ? esc(r.service) : 'atendimento';
  const ok = status === 'accepted';
  const subject = ok ? `Horário confirmado: ${day} às ${r.time}` : 'Seu pedido de horário não pôde ser aceito';
  const lines = ok
    ? [`Oi, ${first}!`, `${who} confirmou seu horário.`, `${r.service || 'Atendimento'} · ${day} às ${r.time}`, 'Até lá!']
    : [`Oi, ${first}!`, `${who} não conseguiu atender ${day} às ${r.time}.`, link ? 'Você pode escolher outro horário pelo mesmo link de agendamento.' : 'Entre em contato para combinar outro horário.'];
  const text = lines.join('\n\n') + (!ok && link ? `\n\n${link}` : '');
  const html = `<div style="font-family:Arial,Helvetica,sans-serif;max-width:520px;margin:0 auto;color:#0E1A2B">
<div style="background:#0F2236;padding:16px 24px;border-radius:14px 14px 0 0;color:#fff;font-size:20px;font-weight:800">Lé<span style="color:#FFC23D">g</span>uno</div>
<div style="border:1px solid #DDE4EE;border-top:0;padding:24px;border-radius:0 0 14px 14px;font-size:16px;line-height:1.5">
<p style="margin:0 0 12px">Oi, ${esc(first)}!</p>
${ok
    ? `<p style="margin:0 0 12px"><b>${esc(who)}</b> confirmou seu horário.</p><p style="margin:0 0 12px;background:#E8F7F8;padding:12px 14px;border-radius:12px"><b>${what}</b><br>${day} às ${esc(r.time)}</p><p style="margin:0">Até lá!</p>`
    : `<p style="margin:0 0 12px"><b>${esc(who)}</b> não conseguiu atender ${day} às ${esc(r.time)}.</p>${link ? `<p style="margin:0 0 16px">Você pode escolher outro horário pelo mesmo link:</p><a href="${link}" style="background:#0A7E8C;color:#fff;text-decoration:none;padding:12px 22px;border-radius:999px;font-weight:700;display:inline-block">Escolher outro horário</a>` : '<p style="margin:0">Entre em contato para combinar outro horário.</p>'}`}
</div>
<p style="font-size:12px;color:#8895A7;text-align:center">Mensagem automática do Léguno. Não responda este e-mail.</p></div>`;

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${RESEND}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from: FROM, to: [r.email], subject, html, text }),
  });
  if (!res.ok) console.error('Resend', res.status, await res.text());
  return json({ sent: res.ok ? 1 : 0 });
});
