import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANDROID_PACKAGE_NAME = Deno.env.get("ANDROID_PACKAGE_NAME") ??
  "com.ghostheart5.chronospark";
const ALLOWED_PRODUCT_IDS = new Set([
  "chronospark_premium_monthly",
  "chronospark_premium_annual",
]);
const ALLOWED_ORIGINS = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ?? "https://chronospark.app,https://www.chronospark.app")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
);
const requestWindows = new Map<string, number[]>();

function cors(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  return {
    ...(ALLOWED_ORIGINS.has(origin) ? { "Access-Control-Allow-Origin": origin } : {}),
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
  };
}

async function authenticatedUserId(req: Request): Promise<string | null> {
  const authorization = req.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ") || !SUPABASE_URL || !SUPABASE_ANON_KEY) return null;
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: authorization, apikey: SUPABASE_ANON_KEY },
  });
  if (!response.ok) return null;
  const user = await response.json();
  return typeof user?.id === "string" ? user.id : null;
}

function withinRateLimit(userId: string): boolean {
  const now = Date.now();
  const recent = (requestWindows.get(userId) ?? []).filter((time) => now - time < 60_000);
  if (recent.length >= 10) return false;
  recent.push(now);
  requestWindows.set(userId, recent);
  return true;
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function bindPurchaseToken(
  purchaseToken: string,
  userId: string,
  productId: string,
): Promise<boolean> {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return false;
  const tokenHash = await sha256(purchaseToken);
  const endpoint = `${SUPABASE_URL}/rest/v1/purchase_bindings`;
  const lookup = await fetch(
    `${endpoint}?token_hash=eq.${tokenHash}&select=user_id`,
    {
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      },
    },
  );
  if (!lookup.ok) return false;
  const existing = await lookup.json();
  if (Array.isArray(existing) && existing.length > 0) {
    return existing[0]?.user_id === userId;
  }
  const inserted = await fetch(endpoint, {
    method: "POST",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    },
    body: JSON.stringify({
      token_hash: tokenHash,
      user_id: userId,
      product_id: productId,
    }),
  });
  return inserted.ok;
}

// Set GOOGLE_SERVICE_ACCOUNT_JSON as a Supabase secret:
//   supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
const SERVICE_ACCOUNT_JSON = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON") ?? "";

interface VerifyRequest {
  productId: string;         // e.g. "chronospark_premium_monthly"
  purchaseToken: string;     // from in_app_purchase PurchaseDetails
  purchaseType: "subscription" | "inapp";
}

interface VerifyResponse {
  valid: boolean;
  expiryTimeMs?: number;     // epoch ms — subscriptions only
  orderId?: string;
  productId?: string;
  error?: string;
}

async function getAccessToken(serviceAccountJson: string): Promise<string> {
  const sa = JSON.parse(serviceAccountJson);
  const now = Math.floor(Date.now() / 1000);
  const base64Url = (value: string | Uint8Array): string => {
    const bytes = typeof value === "string"
      ? new TextEncoder().encode(value)
      : value;
    return btoa(String.fromCharCode(...bytes))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
  };
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = base64Url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const payload = `${header}.${claim}`;

  const keyData = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const keyBytes = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
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
  const sig = base64Url(new Uint8Array(signature));
  const jwt = `${payload}.${sig}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${
      encodeURIComponent(jwt)
    }`,
  });
  const data = await res.json();
  return data.access_token as string;
}

serve(async (req) => {
  const headers = cors(req);
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers });
  }

  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405, headers });
    }
    const userId = await authenticatedUserId(req);
    if (!userId) {
      return new Response(JSON.stringify({ valid: false, error: "unauthorized" }), {
        status: 401,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }
    if (!withinRateLimit(userId)) {
      return new Response(JSON.stringify({ valid: false, error: "rate limit exceeded" }), {
        status: 429,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }
    const body: VerifyRequest = await req.json();
    const { productId, purchaseToken, purchaseType } = body;

    if (!productId || !ALLOWED_PRODUCT_IDS.has(productId) || !purchaseToken ||
      (purchaseType !== "subscription" && purchaseType !== "inapp")) {
      return new Response(
        JSON.stringify({ valid: false, error: "Missing required fields" } satisfies VerifyResponse),
        { status: 400, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    if (!SERVICE_ACCOUNT_JSON) {
      return new Response(
        JSON.stringify({ valid: false, error: "Service account not configured" } satisfies VerifyResponse),
        { status: 500, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    const accessToken = await getAccessToken(SERVICE_ACCOUNT_JSON);

    const apiBase = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications";
    const encodedPackage = encodeURIComponent(ANDROID_PACKAGE_NAME);
    const encodedProduct = encodeURIComponent(productId);
    const encodedToken = encodeURIComponent(purchaseToken);
    const url = purchaseType === "subscription"
      ? `${apiBase}/${encodedPackage}/purchases/subscriptionsv2/tokens/${encodedToken}`
      : `${apiBase}/${encodedPackage}/purchases/products/${encodedProduct}/tokens/${encodedToken}`;

    const gpRes = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!gpRes.ok) {
      await gpRes.body?.cancel();
      console.error("Google Play receipt verification failed");
      return new Response(
        JSON.stringify({ valid: false, error: "Google Play API error" } satisfies VerifyResponse),
        { status: 502, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    const gpData = await gpRes.json();

    // Subscription response
    if (purchaseType === "subscription") {
      const lineItem = gpData.lineItems?.[0];
      const expiryTimeMs = lineItem?.expiryTime
        ? new Date(lineItem.expiryTime).getTime()
        : undefined;
      const valid = gpData.subscriptionState === "SUBSCRIPTION_STATE_ACTIVE" ||
        gpData.subscriptionState === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD";
      const bound = valid &&
        await bindPurchaseToken(purchaseToken, userId, productId);
      return new Response(
        JSON.stringify({
          valid: valid && bound,
          expiryTimeMs,
          orderId: gpData.latestOrderId,
          productId,
          ...(!bound ? { error: "purchase binding failed" } : {}),
        } satisfies VerifyResponse),
        { headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    // One-time product response
    const valid = gpData.purchaseState === 0; // 0 = purchased
    const bound = valid &&
      await bindPurchaseToken(purchaseToken, userId, productId);
    return new Response(
      JSON.stringify({
        valid: valid && bound,
        orderId: gpData.orderId,
        productId,
        ...(!bound ? { error: "purchase binding failed" } : {}),
      } satisfies VerifyResponse),
      { headers: { ...headers, "Content-Type": "application/json" } },
    );
  } catch {
    console.error("Receipt verification request failed");
    return new Response(
      JSON.stringify({ valid: false, error: "request failed" } satisfies VerifyResponse),
      { status: 500, headers: { ...headers, "Content-Type": "application/json" } },
    );
  }
});
