export interface VerifiedSubscriptionLineItem {
  productId: string;
  expiryTimeMs: number;
  status: "active" | "grace" | "cancelled";
}

const accessStatusBySubscriptionState = new Map<string, VerifiedSubscriptionLineItem["status"]>([
  ["SUBSCRIPTION_STATE_ACTIVE", "active"],
  ["SUBSCRIPTION_STATE_IN_GRACE_PERIOD", "grace"],
  ["SUBSCRIPTION_STATE_CANCELED", "cancelled"],
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
