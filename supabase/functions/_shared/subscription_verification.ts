export interface VerifiedSubscriptionLineItem {
  productId: string;
  expiryTimeMs: number;
}

const activeSubscriptionStates = new Set<string>([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
]);

export function verifySubscriptionLineItem(
  purchase: Record<string, unknown>,
  claimedProductId: string,
  nowMs = Date.now(),
): VerifiedSubscriptionLineItem | null {
  if (!activeSubscriptionStates.has(String(purchase.subscriptionState ?? ""))) {
    return null;
  }
  if (
    purchase.acknowledgementState !== undefined &&
    purchase.acknowledgementState !== "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"
  ) return null;
  if (!Array.isArray(purchase.lineItems)) return null;
  for (const item of purchase.lineItems) {
    if (!item || typeof item !== "object" || Array.isArray(item)) continue;
    const lineItem = item as Record<string, unknown>;
    if (lineItem.productId !== claimedProductId) continue;
    const expiryTimeMs = Date.parse(String(lineItem.expiryTime ?? ""));
    if (!Number.isFinite(expiryTimeMs) || expiryTimeMs <= nowMs) return null;
    return { productId: claimedProductId, expiryTimeMs };
  }
  return null;
}
