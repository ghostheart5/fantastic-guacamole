/// <reference lib="deno.ns" />
import { verifySubscriptionLineItem } from "../_shared/subscription_verification.ts";
import {
  getGoogleAccessToken,
  type GoogleServiceAccount,
  sha256Hex,
} from "../_shared/google_auth.ts";
import {
  completeGooglePlayDelivery,
  GOOGLE_PLAY_PRODUCTS,
  googlePlayProductConfig,
} from "../_shared/google_play_product.ts";
import {
  EdgeHttpError,
  fetchWithDeadline,
  logEdgeEvent,
  readBoundedJson,
} from "../_shared/edge_http.ts";
import { readVerifyRequest } from "../_shared/monetization_request_validation.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_PUBLISHABLE_KEY = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANDROID_PACKAGE_NAME = Deno.env.get("ANDROID_PACKAGE_NAME") ??
  "com.ghostheart5.chronospark";
const ALLOWED_PRODUCT_IDS = new Set(Object.keys(GOOGLE_PLAY_PRODUCTS));
const ALLOWED_ORIGINS = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ??
    "https://chronospark.app,https://www.chronospark.app")
    .split(",")
    .map((value: string) => value.trim())
    .filter(Boolean),
);
const MAX_PURCHASE_TOKEN_LENGTH = 4096;

function cors(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  return {
    ...(ALLOWED_ORIGINS.has(origin)
      ? { "Access-Control-Allow-Origin": origin }
      : {}),
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
    "X-ChronoSpark-Contract": "monetization-v2",
  };
}

async function authenticatedUserId(req: Request): Promise<string | null> {
  const authorization = req.headers.get("authorization") ?? "";
  if (
    !authorization.startsWith("Bearer ") || !SUPABASE_URL ||
    !SUPABASE_PUBLISHABLE_KEY
  ) return null;
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/auth/v1/user`,
    {
      headers: {
        Authorization: authorization,
        apikey: SUPABASE_PUBLISHABLE_KEY,
      },
    },
    { timeoutMs: 5_000, dependency: "supabase_auth_user" },
  );
  if (!response.ok) return null;
  const user = await response.json();
  return typeof user?.id === "string" ? user.id : null;
}

async function consumeRateLimit(authorization: string): Promise<boolean> {
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/rest/v1/rpc/consume_monetization_verify_rate_limit`,
    {
      method: "POST",
      headers: {
        Authorization: authorization,
        apikey: SUPABASE_PUBLISHABLE_KEY,
        "Content-Type": "application/json",
      },
      body: "{}",
    },
    { timeoutMs: 5_000, dependency: "monetization_rate_limit" },
  );
  return response.ok;
}

async function sha256(value: string): Promise<string> {
  return await sha256Hex(value);
}

async function bindPurchaseToken(
  purchaseToken: string,
  userId: string,
  productId: string,
): Promise<boolean> {
  if (!SUPABASE_URL || !SUPABASE_SECRET_KEY) return false;
  const tokenHash = await sha256(purchaseToken);
  const endpoint = `${SUPABASE_URL}/rest/v1/purchase_bindings`;
  const lookup = await fetchWithDeadline(
    `${endpoint}?token_hash=eq.${tokenHash}&select=user_id`,
    {
      headers: {
        apikey: SUPABASE_SECRET_KEY,
        Authorization: `Bearer ${SUPABASE_SECRET_KEY}`,
      },
    },
    { timeoutMs: 5_000, dependency: "purchase_binding_lookup" },
  );
  if (!lookup.ok) return false;
  const existing = await lookup.json();
  if (Array.isArray(existing) && existing.length > 0) {
    return existing[0]?.user_id === userId;
  }
  const inserted = await fetchWithDeadline(
    endpoint,
    {
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
    },
    { timeoutMs: 5_000, dependency: "purchase_binding_insert" },
  );
  if (inserted.ok) return true;
  if (inserted.status === 409) {
    const retryLookup = await fetchWithDeadline(
      `${endpoint}?token_hash=eq.${tokenHash}&select=user_id`,
      {
        headers: {
          apikey: SUPABASE_SECRET_KEY,
          Authorization: `Bearer ${SUPABASE_SECRET_KEY}`,
        },
      },
      { timeoutMs: 5_000, dependency: "purchase_binding_retry_lookup" },
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
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/rest/v1/rpc/apply_verified_purchase`,
    {
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
    },
    { timeoutMs: 5_000, dependency: "apply_verified_purchase" },
  );
  if (!response.ok) {
    return null;
  }
  return await response.json() as Record<string, unknown>;
}

async function serviceRpc(
  name: string,
  body: Record<string, unknown>,
): Promise<Record<string, unknown> | null> {
  if (!SUPABASE_URL || !SUPABASE_SECRET_KEY) return null;
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/rest/v1/rpc/${name}`,
    {
      method: "POST",
      headers: {
        apikey: SUPABASE_SECRET_KEY,
        Authorization: `Bearer ${SUPABASE_SECRET_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    },
    { timeoutMs: 5_000, dependency: `supabase_rpc_${name}` },
  );
  if (!response.ok) {
    await response.body?.cancel();
    return null;
  }
  const value = await response.json();
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

// Set GOOGLE_SERVICE_ACCOUNT_JSON as a Supabase secret:
//   supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
const serviceAccount = JSON.parse(
  Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON") ?? "null",
) as GoogleServiceAccount | null;

interface VerifyResponse {
  valid: boolean;
  expiryTimeMs?: number; // epoch ms — subscriptions only
  orderId?: string;
  productId?: string;
  creditsGranted?: unknown;
  planId?: unknown;
  eventType?: unknown;
  error?: string;
}

Deno.serve(async (req: Request) => {
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
      return new Response(
        JSON.stringify({ valid: false, error: "unauthorized" }),
        {
          status: 401,
          headers: { ...headers, "Content-Type": "application/json" },
        },
      );
    }
    const authorization = req.headers.get("authorization")!;
    if (!await consumeRateLimit(authorization)) {
      return new Response(
        JSON.stringify({ valid: false, error: "rate limit exceeded" }),
        {
          status: 429,
          headers: { ...headers, "Content-Type": "application/json" },
        },
      );
    }
    const body = readVerifyRequest(
      await readBoundedJson(req, { maxBytes: 8_192 }),
    );
    if (!body) {
      return new Response(
        JSON.stringify(
          {
            valid: false,
            error: "invalid request body",
          } satisfies VerifyResponse,
        ),
        {
          status: 400,
          headers: { ...headers, "Content-Type": "application/json" },
        },
      );
    }
    const { productId, purchaseToken, purchaseType } = body;
    const productConfig = googlePlayProductConfig(productId);
    const token = purchaseToken.trim();

    if (
      !productId || !ALLOWED_PRODUCT_IDS.has(productId) || !productConfig ||
      !token ||
      token.length > MAX_PURCHASE_TOKEN_LENGTH ||
      (purchaseType !== "subscription" && purchaseType !== "inapp") ||
      purchaseType !== productConfig.purchaseType
    ) {
      return new Response(
        JSON.stringify(
          {
            valid: false,
            error: "Missing required fields",
          } satisfies VerifyResponse,
        ),
        {
          status: 400,
          headers: { ...headers, "Content-Type": "application/json" },
        },
      );
    }

    if (!serviceAccount) {
      return new Response(
        JSON.stringify(
          {
            valid: false,
            error: "Service account not configured",
          } satisfies VerifyResponse,
        ),
        {
          status: 500,
          headers: { ...headers, "Content-Type": "application/json" },
        },
      );
    }

    const accessToken = await getGoogleAccessToken(serviceAccount);

    const apiBase =
      "https://androidpublisher.googleapis.com/androidpublisher/v3/applications";
    const encodedPackage = encodeURIComponent(ANDROID_PACKAGE_NAME);
    const encodedProduct = encodeURIComponent(productId);
    const encodedToken = encodeURIComponent(purchaseToken);
    const url = purchaseType === "subscription"
      ? `${apiBase}/${encodedPackage}/purchases/subscriptionsv2/tokens/${encodedToken}`
      : `${apiBase}/${encodedPackage}/purchases/products/${encodedProduct}/tokens/${encodedToken}`;

    const gpRes = await fetchWithDeadline(
      url,
      { headers: { Authorization: `Bearer ${accessToken}` } },
      { timeoutMs: 10_000, dependency: "google_play_purchase_lookup" },
    );

    if (!gpRes.ok) {
      await gpRes.body?.cancel();
      logEdgeEvent("warn", "google_play_receipt_lookup_failed", {
        status: gpRes.status,
      });
      return new Response(
        JSON.stringify(
          {
            valid: false,
            error: "Google Play API error",
          } satisfies VerifyResponse,
        ),
        {
          status: 502,
          headers: { ...headers, "Content-Type": "application/json" },
        },
      );
    }

    const gpData = await gpRes.json();

    // Subscription response
    if (purchaseType === "subscription") {
      const verifiedLineItem = verifySubscriptionLineItem(
        gpData as Record<string, unknown>,
        productId,
      );
      const expiryTimeMs = verifiedLineItem?.expiryTimeMs;
      const valid = verifiedLineItem !== null;
      const bound = valid &&
        await bindPurchaseToken(token, userId, productId);
      const tokenHash = await sha256(token);
      const lineItems = Array.isArray(gpData.lineItems) ? gpData.lineItems : [];
      const matchedLine = lineItems.find((item: unknown) => {
        if (!item || typeof item !== "object" || Array.isArray(item)) {
          return false;
        }
        return (item as Record<string, unknown>).productId ===
          verifiedLineItem?.productId;
      }) as Record<string, unknown> | undefined;
      const autoRenewingPlan = matchedLine?.autoRenewingPlan as
        | Record<string, unknown>
        | undefined;
      const status = gpData.subscriptionState ===
          "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
        ? "grace"
        : "active";
      const eventKey = `verify:${tokenHash}:${expiryTimeMs ?? 0}:${
        gpData.latestOrderId ?? "none"
      }`;
      const applied = bound
        ? await serviceRpc("reconcile_google_play_subscription", {
          p_purchase_token_hash: tokenHash,
          p_product_id: verifiedLineItem?.productId,
          p_status: status,
          p_is_active: true,
          p_auto_renews: autoRenewingPlan?.autoRenewEnabled === true,
          p_order_id: gpData.latestOrderId ?? null,
          p_expires_at: expiryTimeMs
            ? new Date(expiryTimeMs).toISOString()
            : null,
          p_event_key: eventKey,
          p_payload: {
            source: "client_verification",
            subscriptionState: gpData.subscriptionState,
            acknowledgementState: gpData.acknowledgementState,
          },
        })
        : null;
      const deliveryCompleted = applied !== null && valid && bound &&
        await completeGooglePlayDelivery({
          accessToken,
          packageName: ANDROID_PACKAGE_NAME,
          productId,
          purchaseToken: token,
          kind: productConfig.kind,
          alreadyAcknowledged: gpData.acknowledgementState ===
            "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
        });
      return new Response(
        JSON.stringify(
          {
            valid: valid && bound && applied !== null && deliveryCompleted,
            expiryTimeMs,
            orderId: gpData.latestOrderId,
            productId,
            creditsGranted: applied?.creditsGranted,
            planId: applied?.planId,
            eventType: applied?.eventType,
            ...(!bound ? { error: "purchase binding failed" } : {}),
            ...(bound && applied === null
              ? { error: "purchase application failed" }
              : {}),
            ...(applied !== null && !deliveryCompleted
              ? { error: "purchase acknowledgement failed" }
              : {}),
          } satisfies VerifyResponse,
        ),
        { headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    // One-time product response
    const valid = gpData.purchaseState === 0 &&
      (gpData.quantity === undefined || gpData.quantity === 1);
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
        {
          source: "client_verification",
          purchaseState: gpData.purchaseState,
          acknowledgementState: gpData.acknowledgementState,
          consumptionState: gpData.consumptionState,
        },
      )
      : null;
    const deliveryCompleted = applied !== null && valid && bound &&
      await completeGooglePlayDelivery({
        accessToken,
        packageName: ANDROID_PACKAGE_NAME,
        productId,
        purchaseToken: token,
        kind: productConfig.kind,
        alreadyAcknowledged: gpData.acknowledgementState === 1,
        alreadyConsumed: gpData.consumptionState === 1,
      });
    return new Response(
      JSON.stringify(
        {
          valid: valid && bound && applied !== null && deliveryCompleted,
          orderId: gpData.orderId,
          productId,
          creditsGranted: applied?.creditsGranted,
          planId: applied?.planId,
          eventType: applied?.eventType,
          ...(!bound ? { error: "purchase binding failed" } : {}),
          ...(bound && applied === null
            ? { error: "purchase application failed" }
            : {}),
          ...(applied !== null && !deliveryCompleted
            ? { error: "purchase delivery completion failed" }
            : {}),
        } satisfies VerifyResponse,
      ),
      { headers: { ...headers, "Content-Type": "application/json" } },
    );
  } catch (error) {
    const status = error instanceof EdgeHttpError ? error.status : 500;
    const code = error instanceof EdgeHttpError ? error.code : "request_failed";
    logEdgeEvent("error", "receipt_verification_failed", { code, status });
    return new Response(
      JSON.stringify(
        { valid: false, error: "request failed" } satisfies VerifyResponse,
      ),
      {
        status,
        headers: { ...headers, "Content-Type": "application/json" },
      },
    );
  }
});

