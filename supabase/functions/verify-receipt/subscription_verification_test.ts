import {
  buildPurchaseBindingArgs,
  buildSubscriptionReconciliationArgs,
  classifyVerificationReconciliation,
  readLinkedPurchaseToken,
  verifySubscriptionLineItem,
} from "../_shared/subscription_verification.ts";

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
  if (cancelled?.status !== "canceled") {
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

Deno.test("receipt reconciliation builds timestamped authority arguments", () => {
  const observedAt = new Date("2026-08-27T00:00:05.000Z");
  const expiryTimeMs = Date.parse("2026-09-27T00:00:00.000Z");
  const args = buildSubscriptionReconciliationArgs({
    purchaseTokenHash: "token-hash",
    productId: "chronospark_premium_monthly",
    status: "active",
    autoRenews: true,
    orderId: "order-123",
    expiryTimeMs,
    providerObservedAt: observedAt,
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
  });
  if (args.p_provider_event_time !== observedAt.toISOString()) {
    throw new Error("provider observation time was not forwarded exactly");
  }
  if (args.p_expires_at !== "2026-09-27T00:00:00.000Z") {
    throw new Error("verified expiry was not forwarded exactly");
  }
  if (args.p_event_key !== `verify:token-hash:${expiryTimeMs}:order-123`) {
    throw new Error("receipt reconciliation event key changed");
  }
});

Deno.test("linked purchase token builds immutable timestamped lineage args", () => {
  const linkedToken = readLinkedPurchaseToken({
    linkedPurchaseToken: " predecessor-token ",
  });
  if (linkedToken !== "predecessor-token") {
    throw new Error("linked purchase token was not consumed");
  }
  const boundAt = new Date("2026-08-27T00:00:05.000Z");
  const args = buildPurchaseBindingArgs({
    purchaseTokenHash: "successor-hash",
    userId: "user-id",
    productId: "chronospark_premium_annual",
    boundAt,
    predecessorTokenHash: "predecessor-hash",
  });
  if (args.p_bound_at !== boundAt.toISOString()) {
    throw new Error("binding observation time was not forwarded exactly");
  }
  if (args.p_predecessor_token_hash !== "predecessor-hash") {
    throw new Error("predecessor lineage was not forwarded");
  }
});

Deno.test("terminal reconciliation wins over duplicate acceptance", () => {
  const terminalDuplicate = classifyVerificationReconciliation({
    duplicate: true,
    reason: "terminal_token",
  });
  if (terminalDuplicate !== "terminal") {
    throw new Error("terminal duplicate receipt was accepted");
  }
  if (classifyVerificationReconciliation({ duplicate: true }) !== "accepted") {
    throw new Error("non-terminal duplicate receipt was rejected");
  }
  if (classifyVerificationReconciliation(null) !== "retry") {
    throw new Error("missing reconciliation result was acknowledged");
  }
});
