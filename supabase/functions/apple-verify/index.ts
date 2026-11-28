// Chamada pelo app do iPhone logo depois de uma compra (ou de "Restaurar compras"):
// recebe a compra assinada pela Apple, confere e libera a conta de quem está logado.
// Os avisos da Apple (apple-notifications) cuidam das renovações e cancelamentos depois.
import { createClient } from "npm:@supabase/supabase-js@2";
import { iso, ownerFrom, PRODUCTS, verifyTransaction } from "../_shared/apple.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Quem está logado.
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const u = await fetch(`${url}/auth/v1/user`, { headers: { apikey: key, Authorization: `Bearer ${token}` } });
  if (!u.ok) return json({ error: "Entre na sua conta." }, 401);
  const user = await u.json();

  const body = await req.json().catch(() => ({}));
  const signed = String(body?.signedTransaction ?? "");
  if (!signed) return json({ error: "Compra não enviada." }, 400);

  let tx;
  try {
    tx = await verifyTransaction(signed);
  } catch (e) {
    console.error("apple-verify: compra recusada:", (e as Error).message);
    return json({ error: "Não foi possível confirmar a compra com a Apple." }, 400);
  }
  const product = String(tx.productId ?? "");
  if (!PRODUCTS.has(product)) return json({ error: "Produto desconhecido." }, 400);

  // A compra precisa ter sido feita por esta conta (ou ainda não ter dono).
  const tokenOwner = ownerFrom(tx.appAccountToken);
  if (tokenOwner && tokenOwner !== String(user.id).toLowerCase()) {
    return json({ error: "Esta compra pertence a outra conta do Léguno." }, 409);
  }

  const expires = iso(tx.expiresDate);
  const kind = tx.revocationDate
    ? "revoked"
    : expires && new Date(expires).getTime() < Date.now()
      ? "expired"
      : "active";

  const db = createClient(url, key);
  const { data, error } = await db.rpc("cf_apple_apply", {
    p_owner: user.id,
    p_original_tx: String(tx.originalTransactionId),
    p_product: product,
    p_expires: expires,
    p_kind: kind,
    p_env: String(tx.environment ?? ""),
    p_event_id: null, // pode ser repetido sem problema (restaurar compras)
    p_type: "APP_VERIFY",
    p_subtype: null,
  });
  if (error) {
    console.error("apple-verify:", error.message);
    return json({ error: "Erro ao liberar a conta. Tente de novo." }, 500);
  }
  // Compra de teste (TestFlight) feita por uma conta que não é de teste: não libera nada.
  if (data?.result === "sandbox_ignorado") {
    return json({ error: "Esta é uma compra de teste. Ela só vale para as contas de teste do Léguno." }, 403);
  }
  // Compra já ligada a outra conta (alguém usou a compra de outra pessoa).
  if (data?.owner && String(data.owner) !== String(user.id)) {
    return json({ error: "Esta compra pertence a outra conta do Léguno." }, 409);
  }
  return json({ ok: true, ...data });
});
