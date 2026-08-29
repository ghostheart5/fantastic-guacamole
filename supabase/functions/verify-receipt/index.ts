/// <reference lib="deno.ns" />

import {
  authenticatedUserId,
  type BillingBackendConfig,
  consumeDurableRateLimits,
  serviceRpc,
} from "../_shared/billing_backend.ts";
import {
  getGoogleAccessToken,
  type GoogleServiceAccount,
  sha256Hex,
} from "../_shared/google_auth.ts";
import {
  buildPurchaseBindingArgs,
  buildSubscriptionReconciliationArgs,
  classifyVerificationReconciliation,
  readLinkedPurchaseToken,
  verifySubscriptionLineItem,
} from "../_shared/subscription_verification.ts";

const config: BillingBackendConfig = {
  supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
  publishableKey: Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
  secretKey: Deno.env.get("SUPABASE_SECRET_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
};
const ANDROID_PACKAGE_NAME = Deno.env.get("ANDROID_PACKAGE_NAME") ??
  "com.ghostheart5.chronospark";
const ALLOWED_PRODUCT_IDS = new Set([
  "chronospark_premium_monthly",
  "chronospark_premium_annual",
]);
const ALLOWED_ORIGINS = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ??
    "https://chronospark.app,https://www.chronospark.app")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
);
const MAX_PURCHASE_TOKEN_LENGTH = 4096;

interface VerifyRequest {
  productId: string;
  purchaseToken: string;
  purchaseType: "subscription";
}

interface VerifyResponse {
  valid: boolean;
  expiryTimeMs?: number;
  status?: "active" | "grace" | "cancelled";
  orderId?: string;
  productId?: string;
  planId?: unknown;
  eventType?: unknown;
  error?: string;
}

function cors(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  return {
    ...(ALLOWED_ORIGINS.has(origin)
      ? { "Access-Control-Allow-Origin": origin }
      : {}),
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Cache-Control": "no-store",
    "Vary": "Origin",
    "X-Content-Type-Options": "nosniff",
    "X-ChronoSpark-Contract": "verify-receipt-v2",
  };
}

function jsonResponse(
  req: Request,
  body: VerifyResponse,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors(req), "Content-Type": "application/json" },
  });
}

function readServiceAccount(): GoogleServiceAccount | null {
  try {
    const value = JSON.parse(
      Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON") ?? "null",
    );
    return value && typeof value === "object"
      ? value as GoogleServiceAccount
      : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors(req) });
  }
  if (req.method !== "POST") {
    return jsonResponse(
      req,
      { valid: false, error: "method_not_allowed" },
      405,
    );
  }
  if (!config.supabaseUrl || !config.publishableKey || !config.secretKey) {
    return jsonResponse(
      req,
      { valid: false, error: "backend_not_configured" },
      503,
    );
  }
  const userId = await authenticatedUserId(req, config);
  if (!userId) {
    return jsonResponse(req, { valid: false, error: "unauthorized" }, 401);
  }
  if (
    !await consumeDurableRateLimits(req, config, userId, {
      bucket: "verify_receipt",
      userLimit: 10,
      ipLimit: 30,
    })
  ) {
    return jsonResponse(
      req,
      { valid: false, error: "rate_limit_exceeded" },
      429,
    );
  }

  try {
    const body = await req.json() as Partial<VerifyRequest>;
    const productId = body.productId?.trim() ?? "";
    const purchaseToken = body.purchaseToken?.trim() ?? "";
    if (
      !ALLOWED_PRODUCT_IDS.has(productId) ||
      body.purchaseType !== "subscription" ||
      !purchaseToken || purchaseToken.length > MAX_PURCHASE_TOKEN_LENGTH
    ) {
      return jsonResponse(
        req,
        { valid: false, error: "invalid_request_body" },
        400,
      );
    }
    const serviceAccount = readServiceAccount();
    if (!serviceAccount) {
      return jsonResponse(req, {
        valid: false,
        error: "service_account_not_configured",
      }, 503);
    }
    const accessToken = await getGoogleAccessToken(serviceAccount);
    const response = await fetch(
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
        encodeURIComponent(ANDROID_PACKAGE_NAME)
      }/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
      { headers: { Authorization: `Bearer ${accessToken}` } },
    );
    const providerObservedAt = new Date();
    if (!response.ok) {
      await response.body?.cancel();
      return jsonResponse(
        req,
        { valid: false, error: "google_play_api_error" },
        502,
      );
    }
    const play = await response.json() as Record<string, unknown>;
    const lineItem = verifySubscriptionLineItem(play, productId);
    if (!lineItem) {
      return jsonResponse(req, {
        valid: false,
        productId,
        error: "purchase_not_active",
      }, 200);
    }
    const tokenHash = await sha256Hex(purchaseToken);
    const linkedPurchaseToken = readLinkedPurchaseToken(
      play,
      MAX_PURCHASE_TOKEN_LENGTH,
    );
    const predecessorTokenHash = linkedPurchaseToken
      ? await sha256Hex(linkedPurchaseToken)
      : null;
    const bound = await serviceRpc(
      config,
      "bind_verified_purchase_token",
      buildPurchaseBindingArgs({
        purchaseTokenHash: tokenHash,
        userId,
        productId,
        boundAt: providerObservedAt,
        predecessorTokenHash,
      }),
    );
    if (bound?.bound !== true) {
      return jsonResponse(req, {
        valid: false,
        productId,
        error: "purchase_binding_failed",
      }, 409);
    }
    const lineItems = Array.isArray(play.lineItems) ? play.lineItems : [];
    const matched = lineItems.find((item) =>
      item && typeof item === "object" && !Array.isArray(item) &&
      (item as Record<string, unknown>).productId === productId
    ) as Record<string, unknown> | undefined;
    const autoRenewingPlan = matched?.autoRenewingPlan as
      | Record<string, unknown>
      | undefined;
    const status = lineItem.status;
    const responseStatus = status === "canceled" ? "cancelled" : status;
    const orderId = typeof play.latestOrderId === "string"
      ? play.latestOrderId
      : undefined;
    const applied = await serviceRpc(
      config,
      "reconcile_google_play_subscription",
      buildSubscriptionReconciliationArgs({
        purchaseTokenHash: tokenHash,
        productId,
        status,
        autoRenews: autoRenewingPlan?.autoRenewEnabled === true,
        orderId,
        expiryTimeMs: lineItem.expiryTimeMs,
        providerObservedAt,
        subscriptionState: play.subscriptionState,
        acknowledgementState: play.acknowledgementState,
      }),
    );
    const reconciliationOutcome = classifyVerificationReconciliation(applied);
    if (reconciliationOutcome === "terminal") {
      return jsonResponse(req, {
        valid: false,
        productId,
        error: "purchase_not_active",
      }, 200);
    }
    if (!applied || reconciliationOutcome !== "accepted") {
      return jsonResponse(req, {
        valid: false,
        productId,
        error: "purchase_application_failed",
      }, 503);
    }
    return jsonResponse(req, {
      valid: true,
      expiryTimeMs: lineItem.expiryTimeMs,
      status: responseStatus,
      orderId,
      productId,
      planId: applied.planId,
      eventType: applied.eventType,
    });
  } catch {
    return jsonResponse(req, { valid: false, error: "request_failed" }, 500);
  }
});
