import { verifySubscriptionLineItem } from "../_shared/subscription_verification.ts";

function expect(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

const nowMs = Date.parse("2026-08-04T00:00:00.000Z");

function purchase(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    lineItems: [
      {
        productId: "chronospark_premium_monthly",
        expiryTime: "2026-09-04T00:00:00.000Z",
      },
    ],
    ...overrides,
  };
}

Deno.test("matching active product token succeeds", () => {
  const verified = verifySubscriptionLineItem(
    purchase(),
    "chronospark_premium_monthly",
    nowMs,
  );
  expect(verified?.productId === "chronospark_premium_monthly", "expected matching product");
});

Deno.test("lower-tier token cannot claim a higher-tier product", () => {
  const verified = verifySubscriptionLineItem(
    purchase(),
    "chronospark_premium_annual",
    nowMs,
  );
  expect(verified === null, "mismatched product must be rejected");
});

Deno.test("missing subscription line items fail", () => {
  const verified = verifySubscriptionLineItem(
    purchase({ lineItems: undefined }),
    "chronospark_premium_monthly",
    nowMs,
  );
  expect(verified === null, "missing line items must be rejected");
});

Deno.test("expired subscriptions fail", () => {
  const verified = verifySubscriptionLineItem(
    purchase({
      lineItems: [
        {
          productId: "chronospark_premium_monthly",
          expiryTime: "2026-08-03T00:00:00.000Z",
        },
      ],
    }),
    "chronospark_premium_monthly",
    nowMs,
  );
  expect(verified === null, "expired subscription must be rejected");
});

Deno.test("invalid subscription states fail", () => {
  const verified = verifySubscriptionLineItem(
    purchase({ subscriptionState: "SUBSCRIPTION_STATE_EXPIRED" }),
    "chronospark_premium_monthly",
    nowMs,
  );
  expect(verified === null, "invalid subscription state must be rejected");
});