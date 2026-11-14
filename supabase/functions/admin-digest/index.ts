// Monta o resumo diário do painel (novos cadastros, testes acabando, atrasos, pedidos de ajuda)
// e manda por e-mail para o administrador.
// Segurança: só roda com o código secreto combinado (DIGEST_SECRET) no cabeçalho "x-digest-secret".
// Sem RESEND_API_KEY ele NÃO envia nada: só devolve o texto do resumo (modo teste).
import { createClient } from "npm:@supabase/supabase-js@2";

function sameText(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

const esc = (s: unknown) =>
  String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!);

const brl = (n: number) => "R$ " + n.toFixed(2).replace(".", ",").replace(/\B(?=(\d{3})+,)/g, ".");

function dayText(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo", day: "2-digit", month: "2-digit" });
}

// deno-lint-ignore no-explicit-any
function build(d: any): { subject: string; html: string; empty: boolean } {
  const novos = d.new_accounts ?? [], fim = d.trials_ending ?? [], atraso = d.late ?? [], ajuda = d.support ?? [];
  const empty = !novos.length && !fim.length && !atraso.length && !ajuda.length;
  const li = (items: string[]) => (items.length ? `<ul>${items.map((i) => `<li>${i}</li>`).join("")}</ul>` : "<p style='color:#55657A'>Nada por aqui.</p>");
  const html = `<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;color:#0E1A2B">
  <h2 style="margin:0 0 4px">Resumo do Léguno</h2>
  <p style="margin:0 0 16px;color:#55657A">${d.totals?.accounts ?? 0} contas · ${d.totals?.trialing ?? 0} em teste · ${d.totals?.paying ?? 0} pagantes · receita mensal estimada ${brl(Number(d.totals?.mrr ?? 0))}</p>
  <h3>Contas novas (24 h)</h3>${li(novos.map((n: { email: string; profession?: string }) => `${esc(n.email)}${n.profession ? " · " + esc(n.profession) : ""}`))}
  <h3>Testes acabando (3 dias)</h3>${li(fim.map((n: { email: string; ends: string; clients?: number }) => `${esc(n.email)} · acaba em ${dayText(n.ends)} · ${n.clients ?? 0} clientes`))}
  <h3>Pagamento em atraso</h3>${li(atraso.map((n: { email: string }) => esc(n.email)))}
  <h3>Pedidos de ajuda (24 h)</h3>${li(ajuda.map((n: { email: string; message: string }) => `${esc(n.email)}: ${esc(n.message)}`))}
  </div>`;
  const subject = empty ? "Léguno: dia tranquilo" : `Léguno: ${novos.length} novas · ${fim.length} testes acabando · ${atraso.length} em atraso`;
  return { subject, html, empty };
}

Deno.serve(async (req) => {
  const secret = Deno.env.get("DIGEST_SECRET") ?? "";
  const sent = req.headers.get("x-digest-secret") ?? "";
  if (!secret || !sameText(secret, sent)) return new Response("unauthorized", { status: 401 });

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data, error } = await db.rpc("cf_admin_digest");
  if (error) return new Response("erro: " + error.message, { status: 500 });

  const mail = build(data);
  const key = Deno.env.get("RESEND_API_KEY");
  const dry = new URL(req.url).searchParams.get("dry") === "1";
  if (!key || dry) {
    return new Response(JSON.stringify({ enviado: false, motivo: dry ? "modo teste" : "sem RESEND_API_KEY", assunto: mail.subject, html: mail.html }), {
      headers: { "content-type": "application/json" },
    });
  }
  const to = Deno.env.get("DIGEST_TO") ?? "daniel@leguno.com.br";
  const from = Deno.env.get("DIGEST_FROM") ?? "Léguno <painel@leguno.com.br>";
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "content-type": "application/json" },
    body: JSON.stringify({ from, to: [to], subject: mail.subject, html: mail.html }),
  });
  if (!res.ok) return new Response("falha no envio: " + (await res.text()), { status: 502 });
  return new Response(JSON.stringify({ enviado: true, assunto: mail.subject }), { headers: { "content-type": "application/json" } });
});
