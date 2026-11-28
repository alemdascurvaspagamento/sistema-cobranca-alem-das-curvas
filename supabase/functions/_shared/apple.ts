// Conferência das mensagens assinadas pela Apple (compras dentro do iPhone).
// Confere a assinatura digital, a cadeia de certificados até a raiz oficial da Apple,
// as marcas da Apple em cada certificado e o identificador do app. Nada é aceito sem passar por aqui.
// (A biblioteca oficial da Apple não roda no servidor do Supabase: ela usa uma função do Node
// que o Deno não tem. Por isso a conferência é feita aqui, com as mesmas regras.)
import * as x509 from "npm:@peculiar/x509@1";
import type {
  JWSTransactionDecodedPayload,
  JWSRenewalInfoDecodedPayload,
  ResponseBodyV2DecodedPayload,
} from "npm:@apple/app-store-server-library@1";

x509.cryptoProvider.set(crypto);

export const BUNDLE_ID = "br.com.alemdascurvas.coachflow";
// Identificador numérico do app (App Store Connect › Informações do app › Apple ID). Só é exigido em produção.
const APP_APPLE_ID = Number(Deno.env.get("APPLE_APP_ID") ?? "0") || undefined;

// Marcas que a Apple põe nos certificados de compras (mesmas que a biblioteca oficial confere).
const OID_LEAF = "1.2.840.113635.100.6.11.1";
const OID_INTERMEDIATE = "1.2.840.113635.100.6.2.1";

// Raiz oficial da Apple, baixada do site da Apple na primeira chamada.
const ROOT_URL = "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer";
let root: Uint8Array | null = null;
async function appleRoot(): Promise<Uint8Array> {
  if (root) return root;
  const r = await fetch(ROOT_URL);
  if (!r.ok) throw new Error(`raiz da Apple indisponível (${r.status})`);
  root = new Uint8Array(await r.arrayBuffer());
  return root;
}

function b64urlToBytes(s: string): Uint8Array {
  const b = s.replace(/-/g, "+").replace(/_/g, "/");
  const bin = atob(b + "===".slice((b.length + 3) % 4));
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}
const sameBytes = (a: Uint8Array, b: Uint8Array) => a.length === b.length && a.every((v, i) => v === b[i]);

class AppleError extends Error {}

/** Confere uma mensagem assinada pela Apple e devolve o conteúdo. */
async function verifyJws<T>(jws: string): Promise<T> {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new AppleError("formato inválido");
  const header = JSON.parse(new TextDecoder().decode(b64urlToBytes(parts[0])));
  const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(parts[1])));
  if (header.alg !== "ES256") throw new AppleError(`algoritmo inesperado: ${header.alg}`);
  const x5c: string[] = Array.isArray(header.x5c) ? header.x5c : [];
  if (x5c.length !== 3) throw new AppleError(`cadeia com ${x5c.length} certificados`);

  const [leaf, inter, top] = x5c.map((c) => new x509.X509Certificate(c));
  // 1. O topo da cadeia é exatamente a raiz oficial da Apple.
  if (!sameBytes(new Uint8Array(top.rawData), await appleRoot())) throw new AppleError("raiz não é da Apple");
  // 2. Cada certificado foi assinado pelo de cima e estava válido na data da assinatura.
  const ms = Number(payload.signedDate ?? payload.data?.signedDate ?? Date.now());
  const date = new Date(ms);
  if (!(await inter.verify({ publicKey: top.publicKey, date }))) throw new AppleError("intermediário inválido");
  if (!(await leaf.verify({ publicKey: inter.publicKey, date }))) throw new AppleError("certificado final inválido");
  // 3. Marcas da Apple para compras.
  if (!leaf.getExtension(OID_LEAF)) throw new AppleError("certificado final sem a marca da Apple");
  if (!inter.getExtension(OID_INTERMEDIATE)) throw new AppleError("intermediário sem a marca da Apple");
  // 4. A assinatura da mensagem confere com o certificado final.
  const key = await crypto.subtle.importKey(
    "spki",
    leaf.publicKey.rawData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["verify"],
  );
  const ok = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    b64urlToBytes(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!ok) throw new AppleError("assinatura não confere");
  return payload as T;
}

function checkApp(bundleId: unknown, env: unknown, appAppleId: unknown) {
  if (bundleId !== undefined && bundleId !== BUNDLE_ID) throw new AppleError(`app diferente: ${bundleId}`);
  if (env === "Production") {
    if (!APP_APPLE_ID) throw new AppleError("APPLE_APP_ID não configurado (necessário para compras reais)");
    if (appAppleId !== undefined && Number(appAppleId) !== APP_APPLE_ID) throw new AppleError("Apple ID do app diferente");
  } else if (env !== "Sandbox" && env !== "Xcode" && env !== "LocalTesting") {
    throw new AppleError(`ambiente desconhecido: ${env}`);
  }
}

export async function verifyNotification(signedPayload: string): Promise<ResponseBodyV2DecodedPayload> {
  const n = await verifyJws<ResponseBodyV2DecodedPayload & Record<string, any>>(signedPayload);
  const src = n.data ?? n.summary ?? n.externalPurchaseToken ?? {};
  checkApp(src.bundleId, src.environment ?? (n.externalPurchaseToken ? "Production" : undefined), src.appAppleId);
  return n;
}

export async function verifyTransaction(jws: string): Promise<JWSTransactionDecodedPayload> {
  const t = await verifyJws<JWSTransactionDecodedPayload>(jws);
  if (t.bundleId !== BUNDLE_ID) throw new AppleError(`app diferente: ${t.bundleId}`);
  checkApp(t.bundleId, t.environment, undefined);
  return t;
}

export async function verifyRenewal(jws: string): Promise<JWSRenewalInfoDecodedPayload> {
  const r = await verifyJws<JWSRenewalInfoDecodedPayload>(jws);
  checkApp(undefined, r.environment, undefined);
  return r;
}

export const PRODUCTS = new Set([
  "br.com.alemdascurvas.coachflow.essencial.mensal",
  "br.com.alemdascurvas.coachflow.essencial.anual",
  "br.com.alemdascurvas.coachflow.profissional.mensal",
  "br.com.alemdascurvas.coachflow.profissional.anual",
]);

/** appAccountToken só vale se for um identificador de conta (UUID). */
export function ownerFrom(token: unknown): string | null {
  const s = typeof token === "string" ? token.toLowerCase() : "";
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(s) ? s : null;
}

/** Descreve um erro de forma legível nos registros. */
export function describe(e: unknown): string {
  const x = e as { constructor?: { name?: string }; status?: unknown; message?: string; cause?: unknown; stack?: string };
  const causa = x?.cause as { message?: string } | undefined;
  return `${x?.constructor?.name ?? "erro"} status=${String(x?.status)} msg=${x?.message ?? ""} causa=${causa?.message ?? String(x?.cause ?? "")} ${(x?.stack ?? "").split("\n").slice(0, 4).join(" | ")}`;
}

export const iso = (ms?: number | null) => (ms ? new Date(ms).toISOString() : null);
