/** Neutral chargeback review: no entitlement changes or inferred consumption. */
export async function respondToGooglePlayRefundReview(
  notification: Record<string, unknown>,
  packageName: string,
  accessToken: string,
  request: typeof fetch = fetch,
): Promise<void> {
  const raw = notification.pendingRefundReviewNotification;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new Error("invalid_refund_review");
  }
  const review = raw as Record<string, unknown>;
  const token = review.pendingRefundToken;
  const order = review.orderId;
  if (
    review.version !== "1.0" ||
    typeof token !== "string" || !token.trim() || token.length > 4096 ||
    typeof order !== "string" ||
    !/^GPA\.\d{4}-\d{4}-\d{4}-\d{5}(?:\.\.\d+)?$/.test(order)
  ) throw new Error("invalid_refund_review");
  // Unknown future reasons stay retryable/visible instead of silently using
  // a policy intended only for Google's currently documented chargebacks.
  if (review.refundReason !== 7) {
    throw new Error("unsupported_refund_review_reason");
  }
  const response = await request(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(packageName)
    }/orders/${encodeURIComponent(order)}:reviewrefund`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        pendingRefundToken: token,
        // The paywall explains the plan's functionality before checkout.
        sampleContentProvided: true,
        refundPreference: "NEUTRAL",
        // Credits can span allowance periods. Do not invent an order-specific
        // consumption percentage or disclose unrelated activity/personal data.
      }),
      signal: AbortSignal.timeout(20_000),
    },
  );
  await response.body?.cancel();
  // Google records only the first response for a token and accepts replays.
  // If recording completion fails, Pub/Sub may safely retry the same policy.
  if (!response.ok) throw new Error(`play_refund_review_${response.status}`);
}
