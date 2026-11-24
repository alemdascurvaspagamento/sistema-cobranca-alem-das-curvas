// Recebe os avisos da Apple sobre assinaturas compradas no iPhone (App Store Server Notifications V2):
// compra, renovação, troca de plano, falha de cobrança, vencimento, reembolso.
// A proteção é a assinatura digital da Apple: aviso que não passa na conferência é recusado.
// Precisa ficar com a verificação de login do Supabase DESLIGADA (verify_jwt=false): quem chama é a Apple.
import { createClient } from "npm:@supabase/supabase-js@2";
import { iso, ownerFrom, PRODUCTS, verifyNotification, verifyRenewal, verifyTransaction } from "../_shared/apple.ts";

type Kind = "active" | "expired" | "refunded" | "revoked";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("ok");
  let body: { signedPayload?: string };
  try {
    body = await req.json();
  } catch {
    return new Response("json inválido", { status: 400 });
  }
  if (!body.signedPayload) return new Response("sem signedPayload", { status: 400 });

  let n;
  try {
    n = await verifyNotification(body.signedPayload);
  } catch (e) {
    console.error("apple-notifications: assinatura recusada:", (e as Error).message);
    return new Response("assinatura inválida", { status: 401 });
  }

  const type = String(n.notificationType ?? "");
  const subtype = n.subtype ? String(n.subtype) : null;
  if (type === "TEST") return new Response("ok");
  const signedTx = n.data?.signedTransactionInfo;
  if (!signedTx) return new Response("ok"); // aviso sem compra (nada a fazer)

  const tx = await verifyTransaction(signedTx);
  const renewal = n.data?.signedRenewalInfo ? await verifyRenewal(n.data.signedRenewalInfo) : null;
  const product = String(tx.productId ?? "");
  if (!PRODUCTS.has(product)) return new Response("ok");

  // O que esse aviso significa para o acesso.
  let kind: Kind | null = null;
  let expires = iso(tx.expiresDate);
  switch (type) {
    case "SUBSCRIBED":
    case "DID_RENEW":
    case "DID_CHANGE_RENEWAL_PREF":
    case "DID_CHANGE_RENEWAL_STATUS":
    case "OFFER_REDEEMED":
    case "RENEWAL_EXTENDED":
    case "REFUND_REVERSED":
      kind = "active";
      break;
    case "DID_FAIL_TO_RENEW":
      // Com período de carência a pessoa continua usando até o fim dele.
      if (subtype === "GRACE_PERIOD" && renewal?.gracePeriodExpiresDate) {
        kind = "active";
        expires = iso(renewal.gracePeriodExpiresDate);
      } else {
        kind = "expired";
      }
      break;
    case "EXPIRED":
    case "GRACE_PERIOD_EXPIRED":
      kind = "expired";
      break;
    case "REFUND":
      kind = "refunded";
      break;
    case "REVOKE":
      kind = "revoked";
      break;
  }
  if (!kind) return new Response("ok"); // outros avisos: só registrados no log da Apple

  // Compra ativa com data já vencida conta como vencida.
  if (kind === "active" && expires && new Date(expires).getTime() < Date.now()) kind = "expired";

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data, error } = await db.rpc("cf_apple_apply", {
    p_owner: ownerFrom(tx.appAccountToken),
    p_original_tx: String(tx.originalTransactionId),
    p_product: product,
    p_expires: expires,
    p_kind: kind,
    p_env: String(tx.environment ?? n.data?.environment ?? ""),
    p_event_id: String(n.notificationUUID),
    p_type: type,
    p_subtype: subtype,
  });
  if (error) {
    console.error("apple-notifications:", error.message);
    return new Response("erro ao gravar", { status: 500 }); // a Apple tenta de novo
  }
  console.log("apple-notifications:", type, subtype ?? "", JSON.stringify(data));
  return new Response("ok");
});
