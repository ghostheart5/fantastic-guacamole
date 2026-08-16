/// <reference lib="deno.ns" />
import { fetchWithDeadline, readBoundedResponseJson } from "./edge_http.ts";

export interface GoogleServiceAccount {
  client_email?: string;
  private_key?: string;
}

interface GoogleJwk extends JsonWebKey {
  kid?: string;
  alg?: string;
  use?: string;
}

let cachedGoogleJwks: { keys: GoogleJwk[]; expiresAt: number } | null = null;

function base64Url(value: string | Uint8Array): string {
  const bytes = typeof value === "string"
    ? new TextEncoder().encode(value)
    : value;
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function decodeBase64Url(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
}

function decodeJwtPart(value: string): Record<string, unknown> | null {
  try {
    const decoded = new TextDecoder("utf-8", { fatal: true }).decode(
      decodeBase64Url(value),
    );
    const parsed = JSON.parse(decoded);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? parsed as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

async function googleJwks(forceRefresh = false): Promise<GoogleJwk[]> {
  const now = Date.now();
  if (!forceRefresh && cachedGoogleJwks && cachedGoogleJwks.expiresAt > now) {
    return cachedGoogleJwks.keys;
  }
  const response = await fetchWithDeadline(
    "https://www.googleapis.com/oauth2/v3/certs",
    {},
    { timeoutMs: 5_000, dependency: "google_oidc_jwks" },
  );
  if (!response.ok) throw new Error("google_oidc_jwks_failed");
  const rawBody = await readBoundedResponseJson(response, { maxBytes: 65_536 });
  const body = rawBody && typeof rawBody === "object" && !Array.isArray(rawBody)
    ? rawBody as Record<string, unknown>
    : {};
  const keys = Array.isArray(body.keys)
    ? body.keys.filter((key: unknown) =>
      key && typeof key === "object" && !Array.isArray(key)
    ) as GoogleJwk[]
    : [];
  if (keys.length === 0) throw new Error("google_oidc_jwks_empty");
  const cacheControl = response.headers.get("cache-control") ?? "";
  const maxAgeMatch = /(?:^|,)\s*max-age=(\d+)/i.exec(cacheControl);
  const advertisedSeconds = maxAgeMatch ? Number(maxAgeMatch[1]) : 300;
  const ttlSeconds = Math.min(Math.max(advertisedSeconds, 300), 3_600);
  cachedGoogleJwks = { keys, expiresAt: now + ttlSeconds * 1_000 };
  return keys;
}

export async function getGoogleAccessToken(
  serviceAccount: GoogleServiceAccount,
): Promise<string> {
  if (!serviceAccount.client_email || !serviceAccount.private_key) {
    throw new Error("invalid_service_account_json");
  }
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = base64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const payload = `${header}.${claim}`;
  const keyData = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const keyBytes = Uint8Array.from(atob(keyData), (char) => char.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(payload),
  );
  const jwt = `${payload}.${base64Url(new Uint8Array(signature))}`;
  const response = await fetchWithDeadline(
    "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body:
        `grant_type=urn%3Aietf%3Aparams%3Aoauth2%3Agrant-type%3Ajwt-bearer&assertion=${
          encodeURIComponent(jwt)
        }`,
    },
    { timeoutMs: 8_000, dependency: "google_oauth" },
  );
  if (!response.ok) throw new Error("google_oauth_failed");
  const rawData = await readBoundedResponseJson(response, { maxBytes: 16_384 });
  const data = rawData && typeof rawData === "object" && !Array.isArray(rawData)
    ? rawData as Record<string, unknown>
    : {};
  if (typeof data.access_token !== "string") {
    throw new Error("google_oauth_missing_access_token");
  }
  return data.access_token;
}

export async function validateGoogleOidcPush(
  req: Request,
  expectedAudience: string,
  expectedEmail: string,
): Promise<boolean> {
  const authorization = req.headers.get("authorization") ?? "";
  if (
    !authorization.startsWith("Bearer ") || !expectedAudience || !expectedEmail
  ) {
    return false;
  }
  const token = authorization.slice("Bearer ".length).trim();
  if (!token || token.length > 8192) return false;
  const parts = token.split(".");
  if (parts.length !== 3) return false;
  const header = decodeJwtPart(parts[0]);
  const claims = decodeJwtPart(parts[1]);
  if (
    !header || !claims || header.alg !== "RS256" ||
    typeof header.kid !== "string"
  ) return false;
  let keys = await googleJwks();
  let jwk = keys.find((key) => key.kid === header.kid && key.kty === "RSA");
  if (!jwk) {
    keys = await googleJwks(true);
    jwk = keys.find((key) => key.kid === header.kid && key.kty === "RSA");
  }
  if (!jwk) return false;
  const key = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const signatureBytes = Uint8Array.from(decodeBase64Url(parts[2]));
  const signingInput = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const verified = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    signatureBytes,
    signingInput,
  );
  if (!verified) return false;
  const now = Math.floor(Date.now() / 1_000);
  return validateGoogleOidcClaims(claims, expectedAudience, expectedEmail, now);
}

export function validateGoogleOidcClaims(
  claims: Record<string, unknown>,
  expectedAudience: string,
  expectedEmail: string,
  now = Math.floor(Date.now() / 1_000),
): boolean {
  const expiresAt = Number(claims.exp ?? 0);
  const issuedAt = Number(claims.iat ?? 0);
  return claims.aud === expectedAudience &&
    claims.email === expectedEmail &&
    claims.email_verified === true &&
    (claims.iss === "accounts.google.com" ||
      claims.iss === "https://accounts.google.com") &&
    Number.isFinite(expiresAt) && expiresAt > now &&
    Number.isFinite(issuedAt) && issuedAt <= now + 300;
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

