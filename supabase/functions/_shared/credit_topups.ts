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
  const grant = await serviceRpc(input.config, "grant_verified_credit_topup", {
    p_user_id: input.userId,
    p_token_hash: await sha256Hex(input.token),
    p_product_id: input.productId,
    p_order_id: purchase.orderId,
  }, fetcher);
  if (grant?.granted !== true) {
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
    productId: input.productId,
    creditsGranted: CREDIT_TOPUPS.get(input.productId),
    duplicate: grant.duplicate === true,
  };
}
