export interface VerifiedSubscriptionLineItem {
  productId: string;
  expiryTimeMs: number;
  status: "active" | "grace" | "canceled";
}

export interface SubscriptionReconciliationInput {
  purchaseTokenHash: string;
  productId: string;
  status: VerifiedSubscriptionLineItem["status"];
  autoRenews: boolean;
  orderId?: string;
  expiryTimeMs: number;
  providerObservedAt: Date;
  subscriptionState: unknown;
  acknowledgementState: unknown;
}

export interface PurchaseBindingInput {
  purchaseTokenHash: string;
  userId: string;
  productId: string;
  boundAt: Date;
  predecessorTokenHash: string | null;
}

export type VerificationReconciliationOutcome =
  | "accepted"
  | "terminal"
  | "retry";

const accessStatusBySubscriptionState = new Map<
  string,
  VerifiedSubscriptionLineItem["status"]
>([
  ["SUBSCRIPTION_STATE_ACTIVE", "active"],
  ["SUBSCRIPTION_STATE_IN_GRACE_PERIOD", "grace"],
  ["SUBSCRIPTION_STATE_CANCELED", "canceled"],
]);

export function verifySubscriptionLineItem(
  purchase: Record<string, unknown>,
  claimedProductId: string,
  nowMs = Date.now(),
): VerifiedSubscriptionLineItem | null {
  const status = accessStatusBySubscriptionState.get(
    String(purchase.subscriptionState ?? ""),
  );
  if (!status) {
    return null;
  }
  if (!Array.isArray(purchase.lineItems)) return null;
  for (const item of purchase.lineItems) {
    if (!item || typeof item !== "object" || Array.isArray(item)) continue;
    const lineItem = item as Record<string, unknown>;
    if (lineItem.productId !== claimedProductId) continue;
    const expiryTimeMs = Date.parse(String(lineItem.expiryTime ?? ""));
    if (!Number.isFinite(expiryTimeMs) || expiryTimeMs <= nowMs) return null;
    return { productId: claimedProductId, expiryTimeMs, status };
  }
  return null;
}

export function readLinkedPurchaseToken(
  purchase: Record<string, unknown>,
  maxLength = 4096,
): string | null {
  if (purchase.linkedPurchaseToken === undefined) return null;
  if (typeof purchase.linkedPurchaseToken !== "string") {
    throw new Error("invalid linked purchase token");
  }
  const token = purchase.linkedPurchaseToken.trim();
  if (!token || token.length > maxLength) {
    throw new Error("invalid linked purchase token");
  }
  return token;
}

export function buildPurchaseBindingArgs(
  input: PurchaseBindingInput,
): Record<string, unknown> {
  return {
    p_purchase_token_hash: input.purchaseTokenHash,
    p_user_id: input.userId,
    p_product_id: input.productId,
    p_bound_at: input.boundAt.toISOString(),
    p_predecessor_token_hash: input.predecessorTokenHash,
  };
}

export function classifyVerificationReconciliation(
  result: Record<string, unknown> | null,
): VerificationReconciliationOutcome {
  if (result?.reason === "terminal_token" || result?.reason === "old_token") {
    return "terminal";
  }
  if (result?.applied === true || result?.duplicate === true) {
    return "accepted";
  }
  return "retry";
}

export function buildSubscriptionReconciliationArgs(
  input: SubscriptionReconciliationInput,
): Record<string, unknown> {
  const expiresAt = new Date(input.expiryTimeMs).toISOString();
  const providerEventTime = input.providerObservedAt.toISOString();
  const orderId = input.orderId ?? null;

  return {
    p_purchase_token_hash: input.purchaseTokenHash,
    p_product_id: input.productId,
    p_status: input.status,
    p_is_active: true,
    p_auto_renews: input.autoRenews,
    p_order_id: orderId,
    p_expires_at: expiresAt,
    p_provider_event_time: providerEventTime,
    p_event_key: `verify:${input.purchaseTokenHash}:${input.expiryTimeMs}:${
      orderId ?? "none"
    }`,
    p_payload: {
      source: "client_verification",
      subscriptionState: input.subscriptionState,
      acknowledgementState: input.acknowledgementState,
    },
  };
}
