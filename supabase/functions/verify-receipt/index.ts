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
import { googleSubscriptionState } from "../_shared/google_play_rtdn.ts";
import {
  acknowledgeGooglePlaySubscription,
  applyGooglePlayAuthorityAfterAcknowledgement,
  buildPurchaseBindingArgs,
  buildSubscriptionReconciliationArgs,
  classifyGooglePlayProviderFailure,
  classifyPurchaseBinding,
  classifyVerificationReconciliation,
  existingPurchaseProofPolicy,
  readPurchaseLineage,
  verifyExistingPurchaseRecoveryBinding,
  verifyExternalAccountBinding,
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
const LEGACY_ACCOUNT_BINDING_CUTOFF =
  Deno.env.get("GOOGLE_PLAY_LEGACY_ACCOUNT_BINDING_CUTOFF")?.trim() ?? "";

interface VerifyRequest {
  productId: string;
  purchaseToken: string;
  purchaseType: "subscription";
}

interface VerifyResponse {
  valid: boolean;
  acknowledged?: boolean;
  retryable?: boolean;
  expiryTimeMs?: number;
  status?: "active" | "grace" | "cancelled";
  orderId?: string;
  productId?: string;
  planId?: unknown;
  eventType?: unknown;
  error?: string;
}

function readLegacyAccountBindingCutoff(): Date | null | undefined {
  if (!LEGACY_ACCOUNT_BINDING_CUTOFF) return null;
  const cutoff = new Date(LEGACY_ACCOUNT_BINDING_CUTOFF);
  return Number.isFinite(cutoff.getTime()) ? cutoff : undefined;
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
      const failure = classifyGooglePlayProviderFailure(response.status);
      await response.body?.cancel();
      if (failure === "terminal") {
        return jsonResponse(req, {
          valid: false,
          productId,
          error: "purchase_not_active",
        }, 200);
      }
      return jsonResponse(
        req,
        {
          valid: false,
          retryable: true,
          error: "google_play_verification_retryable",
        },
        503,
      );
    }
    const decodedPlay: unknown = await response.json();
    if (
      !decodedPlay || typeof decodedPlay !== "object" ||
      Array.isArray(decodedPlay)
    ) {
      return jsonResponse(req, {
        valid: false,
        retryable: true,
        error: "google_play_response_retryable",
      }, 503);
    }
    const play = decodedPlay as Record<string, unknown>;
    const providerState = googleSubscriptionState(
      play.subscriptionState,
      null,
    );
    if (!providerState.supported) {
      return jsonResponse(req, {
        valid: false,
        retryable: true,
        productId,
        error: "google_play_state_unsupported",
      }, 503);
    }
    let lineItem: ReturnType<typeof verifySubscriptionLineItem>;
    try {
      lineItem = verifySubscriptionLineItem(
        play,
        productId,
        providerObservedAt.getTime(),
        ALLOWED_PRODUCT_IDS,
      );
    } catch {
      return jsonResponse(req, {
        valid: false,
        retryable: true,
        productId,
        error: "google_play_authority_retryable",
      }, 503);
    }
    if (!lineItem) {
      return jsonResponse(req, {
        valid: false,
        productId,
        error: "purchase_not_active",
      }, 200);
    }
    const tokenHash = await sha256Hex(purchaseToken);
    const lineage = readPurchaseLineage(play, MAX_PURCHASE_TOKEN_LENGTH);
    const predecessorTokenHash = lineage === null
      ? null
      : await sha256Hex(lineage.purchaseToken);
    if (predecessorTokenHash === tokenHash) {
      return jsonResponse(req, {
        valid: false,
        productId,
        error: "purchase_lineage_invalid",
      }, 409);
    }
    const legacyCutoff = readLegacyAccountBindingCutoff();
    if (legacyCutoff === undefined) {
      return jsonResponse(req, {
        valid: false,
        retryable: true,
        productId,
        error: "account_binding_policy_invalid",
      }, 503);
    }
    const accountBinding = await verifyExternalAccountBinding(
      play,
      userId,
      legacyCutoff,
    );
    const legacyBindingRequired = accountBinding.accepted &&
      accountBinding.mode === "legacy_existing_binding_required";
    let recoveryBinding:
      | Awaited<
        ReturnType<typeof verifyExistingPurchaseRecoveryBinding>
      >
      | null = null;
    const proofPolicy = existingPurchaseProofPolicy(accountBinding);
    if (proofPolicy === "required") {
      recoveryBinding = await verifyExistingPurchaseRecoveryBinding({
        supabaseUrl: config.supabaseUrl,
        secretKey: config.secretKey,
        purchaseTokenHash: tokenHash,
        predecessorTokenHash,
        userId,
        productId,
        allowedProductIds: ALLOWED_PRODUCT_IDS,
      });
      if (recoveryBinding === "retryable") {
        return jsonResponse(req, {
          valid: false,
          retryable: true,
          productId,
          error: "purchase_recovery_binding_retryable",
        }, 503);
      }
    }
    if (!accountBinding.accepted) {
      if (
        recoveryBinding === null || recoveryBinding === "mismatch"
      ) {
        return jsonResponse(req, {
          valid: false,
          productId,
          error: accountBinding.reason === "missing"
            ? "purchase_account_identifier_missing"
            : "purchase_account_mismatch",
        }, 409);
      }
    }
    if (legacyBindingRequired && recoveryBinding === "mismatch") {
      return jsonResponse(req, {
        valid: false,
        productId,
        error: "purchase_account_binding_unverified",
      }, 409);
    }
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
    const bindingOutcome = classifyPurchaseBinding(bound, userId);
    if (
      bindingOutcome !== "accepted" ||
      ((recoveryBinding === "same_user" ||
        recoveryBinding === "detached_current") &&
        bound?.reason !== "already_bound")
    ) {
      return jsonResponse(req, {
        valid: false,
        retryable: bindingOutcome === "retry" ? true : undefined,
        productId,
        error: bindingOutcome === "retry"
          ? "purchase_binding_retryable"
          : "purchase_binding_failed",
      }, bindingOutcome === "retry" ? 503 : 409);
    }
    const status = lineItem.status;
    const responseStatus = status === "canceled" ? "cancelled" : status;
    const orderId = lineItem.orderId;
    const authority = await applyGooglePlayAuthorityAfterAcknowledgement(
      {
        active: lineItem.active,
        acknowledgementState: play.acknowledgementState,
      },
      () =>
        acknowledgeGooglePlaySubscription({
          packageName: ANDROID_PACKAGE_NAME,
          productId,
          purchaseToken,
          accessToken,
        }),
      () =>
        serviceRpc(
          config,
          "reconcile_google_play_subscription",
          buildSubscriptionReconciliationArgs({
            purchaseTokenHash: tokenHash,
            productId,
            status,
            isActive: lineItem.active,
            autoRenews: lineItem.autoRenews,
            orderId,
            expiryTimeMs: lineItem.expiryTimeMs,
            providerObservedAt,
            subscriptionState: play.subscriptionState,
            acknowledgementState: play.acknowledgementState,
            lineageSource: lineage?.source ?? null,
          }),
        ),
    );
    if (authority.status === "acknowledgement_unsupported") {
      return jsonResponse(req, {
        valid: false,
        retryable: true,
        productId,
        error: "purchase_acknowledgement_state_retryable",
      }, 503);
    }
    if (authority.status === "acknowledgement_retryable") {
      return jsonResponse(req, {
        valid: false,
        retryable: true,
        productId,
        error: "purchase_acknowledgement_retryable",
      }, 503);
    }
    const applied = authority.value;
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
        retryable: true,
        productId,
        error: "purchase_application_retryable",
      }, 503);
    }
    return jsonResponse(req, {
      valid: true,
      acknowledged: true,
      expiryTimeMs: lineItem.expiryTimeMs,
      status: responseStatus,
      orderId: orderId ?? undefined,
      productId,
      planId: applied.planId,
      eventType: applied.eventType,
    });
  } catch {
    return jsonResponse(req, {
      valid: false,
      retryable: true,
      error: "request_failed_retryable",
    }, 503);
  }
});
