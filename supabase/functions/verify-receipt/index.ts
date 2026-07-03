import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Set GOOGLE_SERVICE_ACCOUNT_JSON as a Supabase secret:
//   supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
const SERVICE_ACCOUNT_JSON = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON") ?? "";

interface VerifyRequest {
  packageName: string;       // e.g. "com.ghostheart5.chronospark"
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
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = btoa(JSON.stringify({
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
  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)));
  const jwt = `${payload}.${sig}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  const data = await res.json();
  return data.access_token as string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  try {
    const body: VerifyRequest = await req.json();
    const { packageName, productId, purchaseToken, purchaseType } = body;

    if (!packageName || !productId || !purchaseToken) {
      return new Response(
        JSON.stringify({ valid: false, error: "Missing required fields" } satisfies VerifyResponse),
        { status: 400, headers: { ...CORS, "Content-Type": "application/json" } },
      );
    }

    if (!SERVICE_ACCOUNT_JSON) {
      return new Response(
        JSON.stringify({ valid: false, error: "Service account not configured" } satisfies VerifyResponse),
        { status: 500, headers: { ...CORS, "Content-Type": "application/json" } },
      );
    }

    const accessToken = await getAccessToken(SERVICE_ACCOUNT_JSON);

    const apiBase = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications";
    const url = purchaseType === "subscription"
      ? `${apiBase}/${packageName}/purchases/subscriptionsv2/tokens/${purchaseToken}`
      : `${apiBase}/${packageName}/purchases/products/${productId}/tokens/${purchaseToken}`;

    const gpRes = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!gpRes.ok) {
      const err = await gpRes.text();
      console.error("Google Play API error:", err);
      return new Response(
        JSON.stringify({ valid: false, error: "Google Play API error" } satisfies VerifyResponse),
        { status: 200, headers: { ...CORS, "Content-Type": "application/json" } },
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
      return new Response(
        JSON.stringify({ valid, expiryTimeMs, orderId: gpData.latestOrderId, productId } satisfies VerifyResponse),
        { headers: { ...CORS, "Content-Type": "application/json" } },
      );
    }

    // One-time product response
    const valid = gpData.purchaseState === 0; // 0 = purchased
    return new Response(
      JSON.stringify({ valid, orderId: gpData.orderId, productId } satisfies VerifyResponse),
      { headers: { ...CORS, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error(err);
    return new Response(
      JSON.stringify({ valid: false, error: String(err) } satisfies VerifyResponse),
      { status: 500, headers: { ...CORS, "Content-Type": "application/json" } },
    );
  }
});
