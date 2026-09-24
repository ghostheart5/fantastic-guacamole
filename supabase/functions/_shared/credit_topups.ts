import {
  type BillingBackendConfig,
  serviceRpc,
  sha256Hex,
} from "./billing_backend.ts";

export const CREDIT_TOPUPS = new Map([
  ["chronospark_credits_100", 100],
  ["chronospark_credits_300", 300],
]);
type Fetcher = typeof fetch;

// A pending token is authority only after the backend reads PENDING from
// Google. This records a time-limited checkout binding without granting,
// consuming or acknowledging the purchase.
export async function registerPendingCreditTopup(input: {
  config: BillingBackendConfig;
  userId: string;
  packageName: string;
  productId: string;
  token: string;
  accessToken: string;
  requireTest: boolean;
}, fetcher: Fetcher = fetch): Promise<Record<string, unknown>> {
  if (!CREDIT_TOPUPS.has(input.productId)) {
    return { valid: false, error: "unsupported_product" };
  }
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(input.packageName)
    }/purchases/products/${encodeURIComponent(input.productId)}/tokens/${
      encodeURIComponent(input.token)
    }`;
  const response = await fetcher(url, {
    headers: { Authorization: `Bearer ${input.accessToken}` },
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) {
    await response.body?.cancel();
    return {
      valid: false,
      retryable: response.status >= 500 || response.status === 429,
      error: "provider_verification_failed",
    };
  }
  const purchase = await response.json() as Record<string, unknown>;
  if (purchase.purchaseState !== 2) {
    return { valid: false, error: "purchase_not_pending" };
  }
  if (
    (purchase.quantity ?? 1) !== 1 ||
    (purchase.productId !== undefined &&
      purchase.productId !== input.productId) ||
    purchase.obfuscatedExternalAccountId !== await sha256Hex(input.userId) ||
    typeof purchase.obfuscatedExternalProfileId !== "string" ||
    (input.requireTest && purchase.purchaseType !== 0) ||
    (!input.requireTest && purchase.purchaseType !== undefined &&
      purchase.purchaseType !== 0)
  ) {
    return { valid: false, error: "pending_proof_mismatch" };
  }
  const registered = await serviceRpc(
    input.config,
    "register_verified_pending_credit_topup",
    {
      p_user_id: input.userId,
      p_token_hash: await sha256Hex(input.token),
      p_product_id: input.productId,
      p_admission_id: purchase.obfuscatedExternalProfileId,
    },
    fetcher,
  );
  if (registered?.registered !== true) {
    return {
      valid: false,
      retryable: registered === null,
      error: registered?.reason ?? "pending_registration_retryable",
    };
  }
  return {
    valid: true,
    pendingRegistered: true,
    duplicate: registered.duplicate === true,
  };
}

export async function validateTopupProof(
  purchase: Record<string, unknown>,
  userId: string,
  requireTest: boolean,
): Promise<string | null> {
  if (purchase.purchaseState !== 0) return "purchase_not_completed";
  if ((purchase.quantity ?? 1) !== 1) return "unsupported_quantity";
  if (requireTest && purchase.purchaseType !== 0) {
    return "test_purchase_required";
  }
  if (
    !requireTest && purchase.purchaseType !== undefined &&
    purchase.purchaseType !== 0
  ) return "unsupported_purchase_type";
  if (purchase.obfuscatedExternalAccountId !== await sha256Hex(userId)) {
    return "ownership_mismatch";
  }
  if (
    typeof purchase.orderId !== "string" || !purchase.orderId.trim() ||
    purchase.orderId.length > 1024
  ) return "invalid_order";
  if (purchase.consumptionState !== 0 && purchase.consumptionState !== 1) {
    return "invalid_consumption_state";
  }
  return null;
}

export async function verifyCreditTopup(input: {
  config: BillingBackendConfig;
  userId: string;
  packageName: string;
  productId: string;
  token: string;
  accessToken: string;
  requireTest: boolean;
}, fetcher: Fetcher = fetch): Promise<Record<string, unknown>> {
  if (!CREDIT_TOPUPS.has(input.productId)) {
    return { valid: false, error: "unsupported_product" };
  }
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(input.packageName)
    }/purchases/products/${encodeURIComponent(input.productId)}/tokens/${
      encodeURIComponent(input.token)
    }`;
  const headers = { Authorization: `Bearer ${input.accessToken}` };
  const response = await fetcher(url, {
    headers,
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) {
    await response.body?.cancel();
    return {
      valid: false,
      retryable: response.status >= 500 || response.status === 429,
      error: "provider_verification_failed",
    };
  }
  const purchase = await response.json() as Record<string, unknown>;
  const error = await validateTopupProof(
    purchase,
    input.userId,
    input.requireTest,
  );
  if (error) return { valid: false, error };
  const isLicenseTest = purchase.purchaseType === 0;
  // The internal license-test flow does not attach an admission profile.
  // An authenticated server-owned cohort gates requireTest at the HTTP edge;
  // other public-client tests are never exempt when Play omits their profile.
  // A profile on a test receipt also forces the public admission path.
  const requiresAdmission = !isLicenseTest || !input.requireTest ||
    purchase.obfuscatedExternalProfileId !== undefined;
  if (
    requiresAdmission &&
    (typeof purchase.obfuscatedExternalProfileId !== "string" ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        purchase.obfuscatedExternalProfileId,
      ) ||
      typeof purchase.purchaseTimeMillis !== "string" ||
      !/^[0-9]{13}$/.test(purchase.purchaseTimeMillis) ||
      Number(purchase.purchaseTimeMillis) < 1600000000000 ||
      Number(purchase.purchaseTimeMillis) > 4102444800000)
  ) {
    const queued = await serviceRpc(
      input.config,
      "queue_unadmitted_credit_topup",
      {
        p_user_id: input.userId,
        p_token_hash: await sha256Hex(input.token),
        p_product_id: input.productId,
        p_order_id: purchase.orderId,
      },
      fetcher,
    );
    if (queued?.resolutionQueued === true) {
      return {
        valid: false,
        error: "customer_resolution_required",
        resolutionQueued: true,
      };
    }
    return {
      valid: false,
      retryable: queued === null,
      error: queued?.reason ?? "customer_resolution_retryable",
    };
  }
  const grant = await serviceRpc(
    input.config,
    "grant_verified_credit_topup_v2",
    {
      p_user_id: input.userId,
      p_token_hash: await sha256Hex(input.token),
      p_product_id: input.productId,
      p_order_id: purchase.orderId,
      p_admission_exempt: !requiresAdmission,
      p_admission_id: !requiresAdmission
        ? null
        : purchase.obfuscatedExternalProfileId,
      p_purchase_time_ms: !requiresAdmission
        ? null
        : Number(purchase.purchaseTimeMillis),
    },
    fetcher,
  );
  if (grant?.granted !== true) {
    if (
      grant?.reason === "customer_resolution_required" &&
      grant.resolutionQueued === true
    ) {
      // The paid Google order is durably recorded for a refund/fulfillment
      // decision. It must not be consumed or represented as delivered.
      return {
        valid: false,
        error: "customer_resolution_required",
        resolutionQueued: true,
      };
    }
    return {
      valid: false,
      error: grant?.reason ?? "grant_retryable",
      retryable: grant === null,
    };
  }
  // Grant is idempotent before consumption. A lost response can safely retry.
  if (purchase.consumptionState !== 1) {
    const consumed = await fetcher(url + ":consume", {
      method: "POST",
      headers,
      signal: AbortSignal.timeout(15000),
    });
    if (!consumed.ok) {
      await consumed.body?.cancel();
      // RTDN and the client may both verify before either consumes. Confirm
      // Google's current state instead of treating the losing consume as a
      // failed purchase. Never infer completion from an error message alone.
      const current = await fetcher(url, { headers });
      if (!current.ok) {
        await current.body?.cancel();
        return { valid: false, retryable: true, error: "consumption_pending" };
      }
      const proof = await current.json();
      if (
        proof.consumptionState !== 1 || proof.orderId !== purchase.orderId ||
        await validateTopupProof(proof, input.userId, input.requireTest) !==
          null
      ) {
        return { valid: false, retryable: true, error: "consumption_pending" };
      }
    }
    await consumed.body?.cancel();
  }
  return {
    valid: true,
    consumed: true,
    testPurchase: purchase.purchaseType === 0,
    publicAdmissionVerified: requiresAdmission,
    productId: input.productId,
    creditsGranted: CREDIT_TOPUPS.get(input.productId),
    duplicate: grant.duplicate === true,
  };
}
