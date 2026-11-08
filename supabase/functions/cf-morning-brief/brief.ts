// Monta o e-mail do "Resumo da manhã" a partir do resumo que o app guarda.
// Sem dependências: dá para testar fora do Supabase.

export type Item = { t: string; n: string; k?: string };
export type Open = { n: string; v: number; due: string };
export type Payload = {
  v?: number;
  gen?: string;
  name?: string;
  term?: string;
  terms?: string;
  days?: Record<string, Item[]>;
  months?: Record<string, { rec: number; rem: number; tot: number }>;
  open?: Open[];
  bills?: Open[];
};

const WEEK = ['domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado'];
const MONTHS = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];

export function money(v: number): string {
  return 'R$ ' + v.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function esc(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));
}

function addDays(iso: string, n: number): string {
  const d = new Date(iso + 'T12:00:00Z');
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

export type Brief = { subject: string; html: string; text: string };

/** today: data de hoje em São Paulo, no formato AAAA-MM-DD. */
export function buildBrief(p: Payload, today: string, appUrl: string): Brief {
  const d = new Date(today + 'T12:00:00Z');
  const weekday = WEEK[d.getUTCDay()];
  const dayLabel = `${weekday}, ${d.getUTCDate()} de ${MONTHS[d.getUTCMonth()]}`;
  const first = (p.name ?? '').trim().split(/\s+/)[0] ?? '';
  const hello = first ? `Bom dia, ${first}!` : 'Bom dia!';
  const term = p.term || 'atendimento';
  const terms = p.terms || 'atendimentos';

  const gen = p.gen ? new Date(p.gen) : null;
  const stale = !gen || Date.now() - gen.getTime() > 7 * 86400000 || !p.days || !(today in p.days);

  const items = (p.days?.[today] ?? []).slice().sort((a, b) => (a.t || '99').localeCompare(b.t || '99'));
  const sessions = items.filter((i) => i.k !== 'e');
  const ym = today.slice(0, 7);
  const m = p.months?.[ym];
  const overdue = (p.open ?? []).filter((o) => o.due < today && o.v > 0);
  const dueToday = (p.open ?? []).filter((o) => o.due === today && o.v > 0);
  const soon = addDays(today, 2);
  const bills = (p.bills ?? []).filter((b) => b.due <= soon && b.v > 0);

  const count = sessions.length;
  const subject = stale
    ? 'Léguno: abra o app para atualizar seu resumo'
    : count === 0
      ? `Léguno: seu dia (${weekday}) está livre`
      : `Léguno: ${count} ${count === 1 ? term : terms} hoje (${weekday})`;

  // ---------- texto simples
  const t: string[] = [hello, `Seu dia no Léguno — ${dayLabel}`, ''];
  if (stale) {
    t.push('Faz alguns dias que o Léguno não é aberto, então seu resumo pode estar desatualizado.',
      'Abra o app uma vez e amanhã ele chega completo.');
  } else {
    t.push(count === 0 ? `Nenhum ${term} marcado hoje.` : `${count} ${count === 1 ? term : terms} hoje:`);
    for (const i of items) t.push(`  ${i.t || 'Dia todo'} · ${i.n}`);
    if (m) t.push('', `${capital(MONTHS[d.getUTCMonth()])}: ${money(m.rec)} recebidos · ${money(m.rem)} a receber`);
    if (dueToday.length) t.push('', 'Vencem hoje: ' + dueToday.map((o) => `${o.n} (${money(o.v)})`).join(', '));
    if (overdue.length) t.push('', 'Em atraso: ' + overdue.map((o) => `${o.n} (${money(o.v)})`).join(', '));
    if (bills.length) t.push('', 'Contas a pagar: ' + bills.map((o) => `${o.n} (${money(o.v)})`).join(', '));
  }
  t.push('', `Abrir o Léguno: ${appUrl}`, '', 'Para não receber mais, desligue em Ajustes › Resumo da manhã.');

  // ---------- HTML
  const row = (left: string, right: string, color = '#0E1A2B') =>
    `<tr><td style="padding:9px 0;border-bottom:1px solid #EEF2F7;font-size:15px;color:#55657A;width:84px;vertical-align:top">${left}</td>` +
    `<td style="padding:9px 0;border-bottom:1px solid #EEF2F7;font-size:15px;color:${color};font-weight:600">${right}</td></tr>`;
  const section = (title: string, body: string) =>
    `<h3 style="margin:22px 0 6px;font-size:13px;letter-spacing:.06em;text-transform:uppercase;color:#55657A">${title}</h3>${body}`;
  const list = (rows: Open[], color: string, showDue = false) =>
    `<table role="presentation" width="100%" cellspacing="0" cellpadding="0">${rows
      .map((o) => row(money(o.v), esc(o.n) + (showDue ? ` <span style="color:#8895A7;font-weight:400">· venceu ${o.due.slice(8, 10)}/${o.due.slice(5, 7)}</span>` : ''), color))
      .join('')}</table>`;

  let body = '';
  if (stale) {
    body = `<p style="font-size:15px;line-height:1.5">Faz alguns dias que o Léguno não é aberto, então seu resumo pode estar desatualizado. Abra o app uma vez e amanhã ele chega completo.</p>`;
  } else {
    body += section(
      count === 0 ? 'Agenda de hoje' : `Agenda de hoje · ${count} ${count === 1 ? term : terms}`,
      items.length
        ? `<table role="presentation" width="100%" cellspacing="0" cellpadding="0">${items.map((i) => row(i.t || 'Dia todo', esc(i.n) + (i.k === 'e' ? ' <span style="color:#8895A7;font-weight:400">· compromisso</span>' : ''))).join('')}</table>`
        : `<p style="font-size:15px;color:#55657A;margin:6px 0">Nenhum ${term} marcado. Bom dia para colocar as coisas em dia.</p>`,
    );
    if (m) {
      body += section(
        `${capital(MONTHS[d.getUTCMonth()])} até agora`,
        `<table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr>` +
          `<td style="background:#E8F7F8;border-radius:12px;padding:12px 14px;width:50%"><div style="font-size:12px;color:#0A7E8C;font-weight:700">RECEBIDO</div><div style="font-size:20px;font-weight:800;color:#0E1A2B">${money(m.rec)}</div></td>` +
          `<td style="width:10px"></td>` +
          `<td style="background:#FFF6E0;border-radius:12px;padding:12px 14px;width:50%"><div style="font-size:12px;color:#B07A00;font-weight:700">A RECEBER</div><div style="font-size:20px;font-weight:800;color:#0E1A2B">${money(m.rem)}</div></td>` +
          `</tr></table>`,
      );
    }
    if (dueToday.length) body += section('Vencem hoje', list(dueToday, '#B07A00'));
    if (overdue.length) body += section(`Em atraso · ${overdue.length}`, list(overdue, '#C2410C', true));
    if (bills.length) body += section('Contas a pagar', list(bills, '#0E1A2B', true).replaceAll('venceu', 'vence'));
  }

  const html = `<div style="font-family:Arial,Helvetica,sans-serif;max-width:520px;margin:0 auto;color:#0E1A2B">
  <div style="background:#0F2236;padding:18px 24px;border-radius:14px 14px 0 0">
    <span style="color:#ffffff;font-size:22px;font-weight:800">Lé<span style="color:#FFC23D">g</span>uno</span>
    <span style="color:#9FB3C8;font-size:13px;float:right;margin-top:7px">Resumo da manhã</span>
  </div>
  <div style="border:1px solid #DDE4EE;border-top:0;padding:24px;border-radius:0 0 14px 14px">
    <h2 style="margin:0 0 2px;font-size:21px">${esc(hello)}</h2>
    <p style="margin:0;font-size:15px;color:#55657A">${capital(dayLabel)}</p>
    ${body}
    <p style="margin:26px 0 8px"><a href="${appUrl}" style="background:#0A7E8C;color:#ffffff;text-decoration:none;padding:12px 22px;border-radius:999px;font-weight:700;display:inline-block">Abrir o Léguno</a></p>
    <p style="font-size:12px;color:#8895A7;line-height:1.5;margin-top:18px">Você recebe este e-mail porque ligou o Resumo da manhã. Para não receber mais, desligue em Ajustes › Resumo da manhã.</p>
  </div>
</div>`;
  return { subject, html, text: t.join('\n') };
}

function capital(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}
