// Conferência das mensagens assinadas pela Apple (compras dentro do iPhone).
// Usa a biblioteca oficial da Apple: confere a assinatura digital, a cadeia de certificados
// até a raiz da Apple e o identificador do app. Nada é aceito sem passar por aqui.
import {
  Environment,
  SignedDataVerifier,
  type JWSTransactionDecodedPayload,
  type JWSRenewalInfoDecodedPayload,
  type ResponseBodyV2DecodedPayload,
} from "npm:@apple/app-store-server-library@1";

export const BUNDLE_ID = "br.com.alemdascurvas.coachflow";
// Identificador numérico do app (App Store Connect › Informações do app › Apple ID). Só é exigido em produção.
const APP_APPLE_ID = Number(Deno.env.get("APPLE_APP_ID") ?? "0") || undefined;

// Raízes oficiais da Apple, baixadas do site da Apple na primeira chamada.
const ROOTS = [
  "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer",
  "https://www.apple.com/appleca/AppleIncRootCertificate.cer",
];
let roots: Uint8Array[] | null = null;
async function appleRoots(): Promise<Uint8Array[]> {
  if (roots) return roots;
  const out: Uint8Array[] = [];
  for (const url of ROOTS) {
    const r = await fetch(url);
    if (!r.ok) throw new Error(`raiz da Apple indisponível (${r.status})`);
    out.push(new Uint8Array(await r.arrayBuffer()));
  }
  roots = out;
  return out;
}

/** Lê (sem confiar) o ambiente indicado na mensagem, só para escolher o verificador certo. */
function claimedEnvironment(jws: string): string {
  try {
    const part = jws.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    const p = JSON.parse(atob(part + "===".slice((part.length + 3) % 4)));
    return String(p?.data?.environment ?? p?.environment ?? "Production");
  } catch {
    return "Production";
  }
}

async function verifierFor(env: string): Promise<SignedDataVerifier> {
  // Buffer é o formato que a biblioteca espera.
  const { Buffer } = await import("node:buffer");
  const certs = (await appleRoots()).map((c) => Buffer.from(c));
  if (env === "Sandbox") return new SignedDataVerifier(certs, true, Environment.SANDBOX, BUNDLE_ID);
  if (!APP_APPLE_ID) throw new Error("APPLE_APP_ID não configurado (necessário para compras reais)");
  return new SignedDataVerifier(certs, true, Environment.PRODUCTION, BUNDLE_ID, APP_APPLE_ID);
}

export async function verifyNotification(signedPayload: string): Promise<ResponseBodyV2DecodedPayload> {
  const v = await verifierFor(claimedEnvironment(signedPayload));
  return await v.verifyAndDecodeNotification(signedPayload);
}

export async function verifyTransaction(jws: string): Promise<JWSTransactionDecodedPayload> {
  const v = await verifierFor(claimedEnvironment(jws));
  return await v.verifyAndDecodeTransaction(jws);
}

export async function verifyRenewal(jws: string): Promise<JWSRenewalInfoDecodedPayload> {
  const v = await verifierFor(claimedEnvironment(jws));
  return await v.verifyAndDecodeRenewalInfo(jws);
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

export const iso = (ms?: number | null) => (ms ? new Date(ms).toISOString() : null);
