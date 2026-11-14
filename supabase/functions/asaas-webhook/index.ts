// Recebe os avisos do Asaas (pagamento criado, confirmado, atrasado...) e grava no banco.
// Só aceita quem manda o código secreto combinado (ASAAS_WEBHOOK_TOKEN), que o Asaas envia
// no cabeçalho "asaas-access-token". Sem ele, responde 401 e não faz nada.
// Esta função precisa ficar com a verificação de login do Supabase DESLIGADA (verify_jwt=false),
// porque o Asaas não tem login no Supabase; a proteção é o código secreto.
import { createClient } from "npm:@supabase/supabase-js@2";

function sameText(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("ok");

  const secret = Deno.env.get("ASAAS_WEBHOOK_TOKEN") ?? "";
  const sent = req.headers.get("asaas-access-token") ?? "";
  if (!secret || !sameText(secret, sent)) return new Response("unauthorized", { status: 401 });

  let body: { event?: string; payment?: Record<string, unknown> };
  try {
    body = await req.json();
  } catch {
    return new Response("json inválido", { status: 400 });
  }
  if (!body.payment) return new Response("ignorado"); // outros tipos de aviso

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { error } = await db.rpc("cf_asaas_apply", { p_event: body.event ?? "", p_payment: body.payment });
  if (error) {
    console.error("asaas-webhook:", error.message);
    // 500 faz o Asaas tentar de novo mais tarde.
    return new Response("erro ao gravar", { status: 500 });
  }
  return new Response("ok");
});
