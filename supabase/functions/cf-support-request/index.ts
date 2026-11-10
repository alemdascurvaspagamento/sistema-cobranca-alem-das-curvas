// Recebe um pedido de ajuda de quem está logado no Léguno, guarda e manda por e-mail para a equipe.
const URL_ = Deno.env.get('SUPABASE_URL')!;
const KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RESEND = Deno.env.get('RESEND_API_KEY') ?? '';
const FROM = 'Léguno <nao-responda@leguno.com.br>';
const TO = 'daniel@leguno.com.br';
const admin = { apikey: KEY, Authorization: `Bearer ${KEY}` };
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });
const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (!RESEND) return json({ error: 'Envio indisponível no momento.' }, 500);
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  const u = await fetch(`${URL_}/auth/v1/user`, { headers: { apikey: KEY, Authorization: `Bearer ${token}` } });
  if (!u.ok) return json({ error: 'Entre na sua conta.' }, 401);
  const user = await u.json();
  const b = await req.json().catch(() => ({}));
  const message = String(b?.message ?? '').trim();
  const platform = String(b?.platform ?? '').slice(0, 40);
  const version = String(b?.version ?? '').slice(0, 20);
  if (message.length < 5) return json({ error: 'Conte um pouco mais sobre o problema.' }, 400);
  if (message.length > 4000) return json({ error: 'Texto muito longo (máximo 4000 letras).' }, 400);

  // No máximo 5 pedidos por dia por pessoa.
  const since = new Date(Date.now() - 86400000).toISOString();
  const cnt = await fetch(`${URL_}/rest/v1/cf_support_requests?owner_id=eq.${user.id}&created_at=gte.${since}&select=id`, { headers: { ...admin, Prefer: 'count=exact', Range: '0-0' } });
  const total = Number((cnt.headers.get('content-range') ?? '0/0').split('/')[1] ?? 0);
  if (total >= 5) return json({ error: 'Você já enviou vários pedidos hoje. Aguarde nossa resposta.' }, 429);

  const ins = await fetch(`${URL_}/rest/v1/cf_support_requests`, {
    method: 'POST',
    headers: { ...admin, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
    body: JSON.stringify({ owner_id: user.id, message, platform, app_version: version }),
  });
  if (!ins.ok) { console.error('insert', ins.status, await ins.text()); return json({ error: 'Não foi possível enviar. Tente de novo.' }, 500); }

  const who = user.email ?? '(sem e-mail)';
  const html = `<div style="font-family:Arial,sans-serif;max-width:560px;color:#0E1A2B">
<h3 style="margin:0 0 8px">Novo pedido de ajuda no Léguno</h3>
<p style="margin:0 0 12px;color:#55657A;font-size:14px">De: <b>${esc(who)}</b><br>Aparelho: ${esc(platform || '?')} · Versão: ${esc(version || '?')}</p>
<div style="white-space:pre-wrap;background:#F2F5F9;border-radius:12px;padding:14px;font-size:15px;line-height:1.5">${esc(message)}</div>
<p style="font-size:12px;color:#8895A7;margin-top:14px">Responda este e-mail: a resposta vai direto para a pessoa.</p></div>`;
  const text = `Novo pedido de ajuda no Léguno\nDe: ${who}\nAparelho: ${platform || '?'} · Versão: ${version || '?'}\n\n${message}`;
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${RESEND}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from: FROM, to: [TO], reply_to: user.email ? [user.email] : undefined, subject: `Léguno: pedido de ajuda de ${who}`, html, text }),
  });
  if (!res.ok) console.error('Resend', res.status, await res.text());
  // O pedido já está guardado; o aviso por e-mail é a parte que pode falhar.
  return json({ ok: true, emailed: res.ok });
});
