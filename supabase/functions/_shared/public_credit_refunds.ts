import { sha256Hex } from "./billing_backend.ts";

export interface QueuedCreditOrder {
  orderId: string;
  productId: string;
  tokenHash: string;
  refundAttempted: boolean;
}

export type RefundOrderDecision =
  | "request_full_refund"
  | "await_provider_refund"
  | "confirmed_full_refund"
  | "manual_review";

// An Orders API readback may settle a queued exception, but its createTime is
// not evidence of when a pending checkout began. Only use this response to
// verify the exact paid order and its current refund state.
export async function classifyQueuedCreditOrder(
  order: Record<string, unknown>,
  queued: QueuedCreditOrder,
): Promise<RefundOrderDecision> {
  if (
    typeof queued.orderId !== "string" || !queued.orderId ||
    typeof queued.productId !== "string" || !queued.productId ||
    !/^[0-9a-f]{64}$/.test(queued.tokenHash) ||
    order.orderId !== queued.orderId ||
    typeof order.purchaseToken !== "string" || !order.purchaseToken ||
    await sha256Hex(order.purchaseToken) !== queued.tokenHash ||
    !Array.isArray(order.lineItems) || order.lineItems.length !== 1
  ) return "manual_review";

  const item = order.lineItems[0];
  if (
    !item || typeof item !== "object" ||
    item.productId !== queued.productId ||
    !item.oneTimePurchaseDetails ||
    typeof item.oneTimePurchaseDetails !== "object" ||
    (item.oneTimePurchaseDetails.quantity ?? 1) !== 1 ||
    item.subscriptionDetails !== undefined ||
    item.paidAppDetails !== undefined
  ) return "manual_review";

  switch (order.state) {
    case "REFUNDED":
      return "confirmed_full_refund";
    case "PENDING_REFUND":
      return "await_provider_refund";
    case "PROCESSED":
      // A request may have reached Google even when its response was lost.
      // Never submit a second refund automatically after an attempted call.
      return queued.refundAttempted ? "manual_review" : "request_full_refund";
    default:
      return "manual_review";
  }
}

// Orders alone do not identify license-test purchases. Read Google's product
// purchase resource for the same exact token before a scoped test can mutate
// any financial state. Never infer test status from a price or order prefix.
export async function verifyGoogleLicenseTestCreditOrder(
  packageName: string,
  queued: QueuedCreditOrder,
  order: Record<string, unknown>,
  accessToken: string,
  fetcher: typeof fetch = fetch,
): Promise<boolean> {
  const token = order.purchaseToken;
  if (
    !packageName || !accessToken || typeof token !== "string" || !token ||
    token.length > 16384 || order.orderId !== queued.orderId ||
    await sha256Hex(token) !== queued.tokenHash
  ) return false;
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(packageName)
    }/purchases/products/${encodeURIComponent(queued.productId)}/tokens/${
      encodeURIComponent(token)
    }`;
  const response = await fetcher(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
    redirect: "error",
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) {
    await response.body?.cancel();
    return false;
  }
  const purchase = await response.json();
  return !!purchase && typeof purchase === "object" &&
    !Array.isArray(purchase) && purchase.purchaseType === 0 &&
    purchase.orderId === queued.orderId && purchase.consumptionState === 0 &&
    (purchase.purchaseState === 0 || purchase.purchaseState === 1) &&
    (purchase.quantity ?? 1) === 1 &&
    (purchase.productId === undefined ||
      purchase.productId === queued.productId) &&
    (purchase.purchaseToken === undefined || purchase.purchaseToken === token);
}

export async function readGoogleCreditOrder(
  packageName: string,
  orderId: string,
  accessToken: string,
  fetcher: typeof fetch = fetch,
): Promise<Record<string, unknown> | null> {
  if (!packageName || !orderId || !accessToken || orderId.length > 1024) {
    return null;
  }
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(packageName)
    }/orders/${encodeURIComponent(orderId)}`;
  const response = await fetcher(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) {
    await response.body?.cancel();
    return null;
  }
  const order = await response.json();
  return order && typeof order === "object" && !Array.isArray(order)
    ? order as Record<string, unknown>
    : null;
}

// The caller must first atomically record a one-time refund attempt under the
// purchase-token lock. A failed or timed-out POST is uncertain, never a reason
// to repeat it without a new provider readback and human review.
export async function requestGoogleFullCreditRefund(
  packageName: string,
  orderId: string,
  accessToken: string,
  fetcher: typeof fetch = fetch,
): Promise<boolean> {
  if (!packageName || !orderId || !accessToken || orderId.length > 1024) {
    return false;
  }
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(packageName)
    }/orders/${encodeURIComponent(orderId)}:refund?revoke=true`;
  try {
    const response = await fetcher(url, {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}` },
      signal: AbortSignal.timeout(15000),
    });
    await response.body?.cancel();
    return response.ok;
  } catch {
    return false;
  }
}
