import { verifySubscriptionLineItem } from "../_shared/subscription_verification.ts";

const nowMs = Date.parse("2026-08-27T00:00:00.000Z");

function purchase(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    lineItems: [{
      productId: "chronospark_premium_monthly",
      expiryTime: "2026-09-27T00:00:00.000Z",
    }],
    ...overrides,
  };
}

Deno.test("active matching subscription is accepted", () => {
  const verified = verifySubscriptionLineItem(
    purchase(),
    "chronospark_premium_monthly",
    nowMs,
  );
  if (verified?.expiryTimeMs !== Date.parse("2026-09-27T00:00:00.000Z")) {
    throw new Error("matching subscription was rejected");
  }
});

Deno.test("initial and cancelled subscriptions retain access through expiry", () => {
  const initial = verifySubscriptionLineItem(
    purchase({ acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING" }),
    "chronospark_premium_monthly",
    nowMs,
  );
  if (initial?.status !== "active") {
    throw new Error("initial unacknowledged purchase was rejected");
  }
  const cancelled = verifySubscriptionLineItem(
    purchase({ subscriptionState: "SUBSCRIPTION_STATE_CANCELED" }),
    "chronospark_premium_monthly",
    nowMs,
  );
  if (cancelled?.status !== "cancelled") {
    throw new Error("cancelled subscription lost access before expiry");
  }
});

Deno.test("mismatched and expired subscriptions fail", () => {
  if (
    verifySubscriptionLineItem(purchase(), "chronospark_premium_annual", nowMs)
  ) {
    throw new Error("mismatched product accepted");
  }
  if (
    verifySubscriptionLineItem(
      purchase({
        lineItems: [{
          productId: "chronospark_premium_monthly",
          expiryTime: "2026-08-26T00:00:00.000Z",
        }],
      }),
      "chronospark_premium_monthly",
      nowMs,
    )
  ) throw new Error("expired purchase accepted");
});
