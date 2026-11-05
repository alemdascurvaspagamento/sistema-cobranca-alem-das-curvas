// Calendário do Léguno em formato .ics (Office 365/Outlook, Google Agenda, Apple).
// Acesso só por um código secreto (?t=...). Não precisa de login.
// Os eventos são publicados pelo próprio app do profissional em cf_calendar_feed.

const URL_ = Deno.env.get('SUPABASE_URL')!;
const KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

function esc(s: string) {
  return s.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n');
}

// Quebra linhas longas (máx. 75 bytes), como pede o padrão.
function fold(line: string) {
  const out: string[] = [];
  let cur = '';
  for (const ch of line) {
    if (new TextEncoder().encode(cur + ch).length > 73) {
      out.push(cur);
      cur = ' ' + ch;
    } else cur += ch;
  }
  out.push(cur);
  return out.join('\r\n');
}

function stamp(d: Date) {
  return d.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
}

Deno.serve(async (req) => {
  const token = new URL(req.url).searchParams.get('t') ?? '';
  if (!/^[a-f0-9]{32,64}$/.test(token)) return new Response('Link inválido', { status: 404 });
  const r = await fetch(`${URL_}/rest/v1/cf_calendar_feed?token=eq.${token}&select=events,updated_at`, {
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}` },
  });
  const rows = r.ok ? await r.json() : [];
  if (!rows.length) return new Response('Link inválido', { status: 404 });
  const events: Array<Record<string, unknown>> = rows[0].events ?? [];
  const now = stamp(new Date());
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Leguno//Agenda//PT-BR',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:Léguno',
    'X-WR-TIMEZONE:America/Sao_Paulo',
    'REFRESH-INTERVAL;VALUE=DURATION:PT1H',
    'X-PUBLISHED-TTL:PT1H',
    'BEGIN:VTIMEZONE',
    'TZID:America/Sao_Paulo',
    'BEGIN:STANDARD',
    'DTSTART:19700101T000000',
    'TZOFFSETFROM:-0300',
    'TZOFFSETTO:-0300',
    'TZNAME:-03',
    'END:STANDARD',
    'END:VTIMEZONE',
  ];
  for (const e of events) {
    const date = String(e.date ?? '').replace(/-/g, '');
    if (!/^\d{8}$/.test(date)) continue;
    const start = Number(e.start ?? -1);
    const end = Number(e.end ?? -1);
    lines.push('BEGIN:VEVENT');
    // O final "@okday" fica igual: trocar duplicaria os eventos em quem já assinou o calendário.
    lines.push(`UID:${esc(String(e.id ?? date + start))}@okday`);
    lines.push(`DTSTAMP:${now}`);
    if (start < 0) {
      const d = new Date(Date.UTC(+date.slice(0, 4), +date.slice(4, 6) - 1, +date.slice(6, 8) + 1));
      const next = d.toISOString().slice(0, 10).replace(/-/g, '');
      lines.push(`DTSTART;VALUE=DATE:${date}`, `DTEND;VALUE=DATE:${next}`);
    } else {
      const hm = (m: number) => `${String(Math.floor(m / 60) % 24).padStart(2, '0')}${String(m % 60).padStart(2, '0')}00`;
      const endDay = end >= 1440 ? date : date;
      lines.push(`DTSTART;TZID=America/Sao_Paulo:${date}T${hm(start)}`);
      lines.push(`DTEND;TZID=America/Sao_Paulo:${endDay}T${hm(Math.min(end, 1439))}`);
    }
    lines.push(fold(`SUMMARY:${esc(String(e.title ?? 'Atendimento'))}`));
    if (e.kind === 'busy') lines.push('TRANSP:OPAQUE');
    lines.push('END:VEVENT');
  }
  lines.push('END:VCALENDAR');
  return new Response(lines.join('\r\n') + '\r\n', {
    headers: {
      'Content-Type': 'text/calendar; charset=utf-8',
      'Content-Disposition': 'inline; filename="leguno.ics"',
      'Cache-Control': 'max-age=300',
    },
  });
});
