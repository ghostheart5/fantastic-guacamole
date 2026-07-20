import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_PUBLISHABLE_KEY = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANDROID_PACKAGE_NAME = Deno.env.get("ANDROID_PACKAGE_NAME") ??
  "com.ghostheart5.chronospark";
const PRODUCT_CONFIG: Record<string, {
  purchaseType: "subscription" | "inapp";
}> = {
  chronospark_premium_monthly: { purchaseType: "subscription" },
  chronospark_premium_annual: { purchaseType: "subscription" },
  chronospark_lifetime: { purchaseType: "inapp" },
  chronospark_credits_100: { purchaseType: "inapp" },
  chronospark_credits_500: { purchaseType: "inapp" },
  chronospark_credits_1200: { purchaseType: "inapp" },
  chronospark_credits_3000: { purchaseType: "inapp" },
};
const ALLOWED_PRODUCT_IDS = new Set(Object.keys(PRODUCT_CONFIG));
const ALLOWED_ORIGINS = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ?? "https://chronospark.app,https://www.chronospark.app")
    .split(",")
    .map((value: string) => value.trim())
    .filter(Boolean),
);
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX_REQUESTS = 10;
const MAX_PURCHASE_TOKEN_LENGTH = 4096;
const requestWindows = new Map<string, number[]>();

function cors(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  return {
    ...(ALLOWED_ORIGINS.has(origin) ? { "Access-Control-Allow-Origin": origin } : {}),
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
  };
}

async function authenticatedUserId(req: Request): Promise<string | null> {
  const authorization = req.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ") || !SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY) return null;
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: authorization, apikey: SUPABASE_PUBLISHABLE_KEY },
  });
  if (!response.ok) return null;
  const user = await response.json();
  return typeof user?.id === "string" ? user.id : null;
}

function withinRateLimit(userId: string): boolean {
  const now = Date.now();
  const recent = (requestWindows.get(userId) ?? []).filter((time) => now - time < RATE_LIMIT_WINDOW_MS);
  if (recent.length >= RATE_LIMIT_MAX_REQUESTS) return false;
  recent.push(now);
  requestWindows.set(userId, recent);
  return true;
}

async function readVerifyRequest(req: Request): Promise<VerifyRequest | null> {
  try {
    const parsed = await req.json();
    if (!parsed || typeof parsed !== "object") return null;
    const record = parsed as Record<string, unknown>;
    if (
      typeof record.productId !== "string" ||
      typeof record.purchaseToken !== "string" ||
      typeof record.purchaseType !== "string"
    ) {
      return null;
    }
    return {
      productId: record.productId,
      purchaseToken: record.purchaseToken,
      purchaseType: record.purchaseType === "subscription" ? "subscription" : "inapp",
    };
  } catch {
    return null;
  }
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
  if (!SUPABASE_URL || !SUPABASE_SECRET_KEY) return false;
  const tokenHash = await sha256(purchaseToken);
  const endpoint = `${SUPABASE_URL}/rest/v1/purchase_bindings`;
  const lookup = await fetch(
    `${endpoint}?token_hash=eq.${tokenHash}&select=user_id`,
    {
      headers: {
        apikey: SUPABASE_SECRET_KEY,
        Authorization: `Bearer ${SUPABASE_SECRET_KEY}`,
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
      apikey: SUPABASE_SECRET_KEY,
      Authorization: `Bearer ${SUPABASE_SECRET_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    },
    body: JSON.stringify({
      token_hash: tokenHash,
      user_id: userId,
      product_id: productId,
    }),
  });
  if (inserted.ok) return true;
  if (inserted.status === 409) {
    const retryLookup = await fetch(
      `${endpoint}?token_hash=eq.${tokenHash}&select=user_id`,
      {
        headers: {
          apikey: SUPABASE_SECRET_KEY,
          Authorization: `Bearer ${SUPABASE_SECRET_KEY}`,
        },
      },
    );
    if (!retryLookup.ok) return false;
    const retryExisting = await retryLookup.json();
    return Array.isArray(retryExisting) && retryExisting[0]?.user_id === userId;
  }
  return false;
}

async function applyVerifiedPurchase(
  userId: string,
  productId: string,
  purchaseType: "subscription" | "inapp",
  purchaseToken: string,
  orderId?: string,
  expiryTimeMs?: number,
  payload: Record<string, unknown> = {},
): Promise<Record<string, unknown> | null> {
  if (!SUPABASE_URL || !SUPABASE_SECRET_KEY) return null;
  const purchaseTokenHash = await sha256(purchaseToken);
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/apply_verified_purchase`, {
    method: "POST",
    headers: {
      apikey: SUPABASE_SECRET_KEY,
      Authorization: `Bearer ${SUPABASE_SECRET_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      target_user_id: userId,
      product_id: productId,
      purchase_type: purchaseType,
      purchase_token_hash: purchaseTokenHash,
      order_id: orderId ?? null,
      verified_at: new Date().toISOString(),
      expires_at: expiryTimeMs ? new Date(expiryTimeMs).toISOString() : null,
      payload,
    }),
  });
  if (!response.ok) {
    return null;
  }
  return await response.json() as Record<string, unknown>;
}

// Set GOOGLE_SERVICE_ACCOUNT_JSON as a Supabase secret:
//   supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
const serviceAccount = JSON.parse(
  Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON") ?? "null",
) as { client_email?: string; private_key?: string } | null;

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
  creditsGranted?: unknown;
  planId?: unknown;
  eventType?: unknown;
  error?: string;
}

async function getAccessToken(
  sa: { client_email?: string; private_key?: string },
): Promise<string> {
  if (!sa?.client_email || !sa?.private_key) {
    throw new Error("invalid_service_account_json");
  }
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
  if (!res.ok) {
    throw new Error("google_oauth_failed");
  }
  const data = await res.json();
  if (!data?.access_token || typeof data.access_token !== "string") {
    throw new Error("google_oauth_missing_access_token");
  }
  return data.access_token as string;
}

serve(async (req: Request) => {
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
    const body = await readVerifyRequest(req);
    if (!body) {
      return new Response(
        JSON.stringify({ valid: false, error: "invalid request body" } satisfies VerifyResponse),
        { status: 400, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }
    const { productId, purchaseToken, purchaseType } = body;
    const productConfig = PRODUCT_CONFIG[productId];
    const token = purchaseToken.trim();

    if (!productId || !ALLOWED_PRODUCT_IDS.has(productId) || !productConfig || !token ||
      token.length > MAX_PURCHASE_TOKEN_LENGTH ||
      (purchaseType !== "subscription" && purchaseType !== "inapp") ||
      purchaseType !== productConfig.purchaseType) {
      return new Response(
        JSON.stringify({ valid: false, error: "Missing required fields" } satisfies VerifyResponse),
        { status: 400, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    if (!serviceAccount) {
      return new Response(
        JSON.stringify({ valid: false, error: "Service account not configured" } satisfies VerifyResponse),
        { status: 500, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    const accessToken = await getAccessToken(serviceAccount);

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
        await bindPurchaseToken(token, userId, productId);
      const applied = bound
        ? await applyVerifiedPurchase(
          userId,
          productId,
          purchaseType,
          token,
          gpData.latestOrderId,
          expiryTimeMs,
          gpData as Record<string, unknown>,
        )
        : null;
      return new Response(
        JSON.stringify({
          valid: valid && bound && applied !== null,
          expiryTimeMs,
          orderId: gpData.latestOrderId,
          productId,
          creditsGranted: applied?.creditsGranted,
          planId: applied?.planId,
          eventType: applied?.eventType,
          ...(!bound ? { error: "purchase binding failed" } : {}),
          ...(bound && applied === null ? { error: "purchase application failed" } : {}),
        } satisfies VerifyResponse),
        { headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    // One-time product response
    const valid = gpData.purchaseState === 0; // 0 = purchased
    const bound = valid &&
      await bindPurchaseToken(token, userId, productId);
    const applied = bound
      ? await applyVerifiedPurchase(
        userId,
        productId,
        purchaseType,
        token,
        gpData.orderId,
        undefined,
        gpData as Record<string, unknown>,
      )
      : null;
    return new Response(
      JSON.stringify({
        valid: valid && bound && applied !== null,
        orderId: gpData.orderId,
        productId,
        creditsGranted: applied?.creditsGranted,
        planId: applied?.planId,
        eventType: applied?.eventType,
        ...(!bound ? { error: "purchase binding failed" } : {}),
        ...(bound && applied === null ? { error: "purchase application failed" } : {}),
      } satisfies VerifyResponse),
      { headers: { ...headers, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("Receipt verification request failed", error);
    return new Response(
      JSON.stringify({ valid: false, error: "request failed" } satisfies VerifyResponse),
      { status: 500, headers: { ...headers, "Content-Type": "application/json" } },
    );
  }
});
