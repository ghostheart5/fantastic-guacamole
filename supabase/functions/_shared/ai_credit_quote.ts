import { sha256Hex } from "./billing_backend.ts";

export const CREDIT_POLICY = "monthly-credits-v2-sonnet46-20260908";
export const MAX_PROVIDER_MICROUSD_PER_CREDIT = 3000;
// Includes a conservative framing allowance. Count all serialized request bytes,
// not only the newest prompt; UTF-8 bytes bound text-token encoding size.
export function quotedCreditCost(upstream: Record<string, unknown>): number {
  const max = upstream.max_tokens;
  if (!Number.isInteger(max) || Number(max) < 1 || Number(max) > 1024) {
    throw new Error("invalid_output_limit");
  }
  const bytes = new TextEncoder().encode(JSON.stringify(upstream)).length;
  if (bytes > 64000) throw new Error("request_too_large");
  return Math.max(
    1,
    Math.ceil(
      ((bytes + 1024) * 3 + Number(max) * 15) /
        MAX_PROVIDER_MICROUSD_PER_CREDIT,
    ),
  );
}

async function signature(secret: string, payload: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const result = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(payload),
  );
  return Array.from(
    new Uint8Array(result),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
}
export async function createCreditQuote(
  secret: string,
  userId: string,
  requestId: string,
  upstream: Record<string, unknown>,
  now = Date.now(),
) {
  const credits = quotedCreditCost(upstream);
  const digest = await sha256Hex(JSON.stringify(upstream));
  const expiresAt = now + 5 * 60 * 1000;
  const proof = await signature(
    secret,
    JSON.stringify([
      CREDIT_POLICY,
      userId,
      requestId,
      digest,
      credits,
      expiresAt,
    ]),
  );
  return { credits, digest, expiresAt, proof, policy: CREDIT_POLICY };
}
export async function verifyCreditQuote(
  secret: string,
  userId: string,
  requestId: string,
  upstream: Record<string, unknown>,
  quote: unknown,
  now = Date.now(),
): Promise<boolean> {
  if (!quote || typeof quote !== "object" || Array.isArray(quote)) return false;
  const q = quote as Record<string, unknown>;
  if (
    !Number.isSafeInteger(q.expiresAt) || Number(q.expiresAt) <= now ||
    Number(q.expiresAt) > now + 5 * 60 * 1000 || q.policy !== CREDIT_POLICY
  ) return false;
  const credits = quotedCreditCost(upstream),
    digest = await sha256Hex(JSON.stringify(upstream));
  if (
    q.credits !== credits || q.digest !== digest || typeof q.proof !== "string"
  ) return false;
  const expected = await signature(
    secret,
    JSON.stringify([
      CREDIT_POLICY,
      userId,
      requestId,
      digest,
      credits,
      q.expiresAt,
    ]),
  );
  if (q.proof.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ q.proof.charCodeAt(i);
  }
  return diff === 0;
}
