/// <reference lib="deno.ns" />

import { sha256Hex } from "./billing_backend.ts";

export { sha256Hex };

export interface GoogleServiceAccount {
  client_email?: string;
  private_key?: string;
}

function base64Url(value: string | Uint8Array): string {
  const bytes = typeof value === "string"
    ? new TextEncoder().encode(value)
    : value;
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
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
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body:
      `grant_type=urn%3Aietf%3Aparams%3Aoauth2%3Agrant-type%3Ajwt-bearer&assertion=${
        encodeURIComponent(jwt)
      }`,
  });
  if (!response.ok) throw new Error("google_oauth_failed");
  const data = await response.json();
  if (typeof data?.access_token !== "string") {
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
  ) return false;
  const token = authorization.slice("Bearer ".length).trim();
  if (!token || token.length > 8192) return false;
  const response = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${
      encodeURIComponent(token)
    }`,
  );
  if (!response.ok) return false;
  const claims = await response.json();
  const expiresAt = Number.parseInt(claims?.exp ?? "0", 10);
  return claims?.aud === expectedAudience &&
    claims?.email === expectedEmail &&
    (claims?.email_verified === "true" || claims?.email_verified === true) &&
    (claims?.iss === "accounts.google.com" ||
      claims?.iss === "https://accounts.google.com") &&
    Number.isFinite(expiresAt) && expiresAt > Math.floor(Date.now() / 1000);
}
