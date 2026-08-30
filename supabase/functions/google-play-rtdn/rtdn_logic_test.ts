import {
  bindVerifiedLinkedPurchaseToken,
  decodePubSubNotification,
  googleSubscriptionNotificationCause,
  googleSubscriptionStateForNotification,
  reconciliationWasHandled,
  resolveSubscriptionAuthorityPurchase,
  terminalNotificationMatchesSubscriptionState,
  validatePaidRenewalAuthority,
} from "../_shared/google_play_rtdn.ts";
import {
  readPurchaseLineage,
  selectSubscriptionAuthorityLine,
} from "../_shared/subscription_verification.ts";

const products = new Set([
  "chronospark_premium_monthly",
  "chronospark_premium_annual",
]);

function assertSubscriptionState(
  actual: { status: string; active: boolean },
  expected: { status: string; active: boolean },
  message: string,
): void {
  if (
    actual.status !== expected.status || actual.active !== expected.active
  ) {
    throw new Error(
      `${message}: expected ${JSON.stringify(expected)}, got ${
        JSON.stringify(actual)
      }`,
    );
  }
}

Deno.test("RTDN payload decoder rejects malformed input", () => {
  if (decodePubSubNotification("not-base64") !== null) {
    throw new Error("malformed Pub/Sub payload accepted");
  }
  const encoded = btoa(
    JSON.stringify({ packageName: "com.ghostheart5.chronospark" }),
  );
  if (
    decodePubSubNotification(encoded)?.packageName !==
      "com.ghostheart5.chronospark"
  ) {
    throw new Error("valid Pub/Sub payload rejected");
  }
});

Deno.test("unknown subscription states remain explicitly unsupported", () => {
  for (
    const subscriptionState of [
      "SUBSCRIPTION_STATE_UNSPECIFIED",
      "SUBSCRIPTION_STATE_FUTURE_VALUE",
      null,
    ]
  ) {
    const mapped = googleSubscriptionStateForNotification(
      12,
      subscriptionState,
      new Date("2026-09-27T00:00:00.000Z"),
    );
    if (
      mapped.supported || mapped.status !== "unknown" || mapped.active
    ) {
      throw new Error(
        `unknown state was treated as authoritative: ${subscriptionState}`,
      );
    }
  }
});

Deno.test("cancellation remains active strictly before expiry", () => {
  const now = new Date("2026-08-27T00:00:00.000Z");
  assertSubscriptionState(
    googleSubscriptionStateForNotification(
      3,
      "SUBSCRIPTION_STATE_CANCELED",
      new Date("2026-08-28T00:00:00.000Z"),
      now,
    ),
    { status: "canceled", active: true },
    "pre-expiry cancellation lost entitlement",
  );
});

Deno.test("cancellation is inactive at and after expiry", () => {
  const now = new Date("2026-08-27T00:00:00.000Z");
  for (
    const expiresAt of [
      new Date("2026-08-27T00:00:00.000Z"),
      new Date("2026-08-26T00:00:00.000Z"),
    ]
  ) {
    assertSubscriptionState(
      googleSubscriptionStateForNotification(
        3,
        "SUBSCRIPTION_STATE_CANCELED",
        expiresAt,
        now,
      ),
      { status: "canceled", active: false },
      `expired cancellation remained active at ${expiresAt.toISOString()}`,
    );
  }
});

Deno.test("grace-period subscriptions retain entitlement", () => {
  assertSubscriptionState(
    googleSubscriptionStateForNotification(
      6,
      "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
      new Date("2026-08-28T00:00:00.000Z"),
      new Date("2026-08-27T00:00:00.000Z"),
    ),
    { status: "grace", active: true },
    "grace period lost entitlement",
  );
});

Deno.test("pending, hold, and pause states remain explicit", () => {
  const cases: Array<{
    notificationType: number;
    subscriptionState: string;
    status: string;
  }> = [
    {
      notificationType: 20,
      subscriptionState: "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED",
      status: "pending",
    },
    {
      notificationType: 5,
      subscriptionState: "SUBSCRIPTION_STATE_ON_HOLD",
      status: "on_hold",
    },
    {
      notificationType: 10,
      subscriptionState: "SUBSCRIPTION_STATE_PAUSED",
      status: "paused",
    },
  ];
  for (const testCase of cases) {
    assertSubscriptionState(
      googleSubscriptionStateForNotification(
        testCase.notificationType,
        testCase.subscriptionState,
        null,
      ),
      { status: testCase.status, active: false },
      `${testCase.subscriptionState} was not mapped explicitly`,
    );
  }
});

Deno.test("RTDN causes identify lifecycle events and only type 2 is renewal", () => {
  const cases: Array<[number, string, boolean]> = [
    [1, "SUBSCRIPTION_RECOVERED", false],
    [2, "SUBSCRIPTION_RENEWED", true],
    [7, "SUBSCRIPTION_RESTARTED", false],
    [9, "SUBSCRIPTION_DEFERRED", false],
    [12, "SUBSCRIPTION_REVOKED", false],
    [13, "SUBSCRIPTION_EXPIRED", false],
    [20, "SUBSCRIPTION_PENDING_PURCHASE_CANCELED", false],
  ];
  for (const [notificationType, eventName, paidRenewal] of cases) {
    const cause = googleSubscriptionNotificationCause(notificationType);
    if (
      !cause.supported || cause.notificationType !== notificationType ||
      cause.eventName !== eventName || cause.paidRenewal !== paidRenewal
    ) {
      throw new Error(`incorrect cause for RTDN type ${notificationType}`);
    }
  }
  if (googleSubscriptionNotificationCause(999).supported) {
    throw new Error("unknown RTDN type was accepted");
  }
});

Deno.test("type 4 RTDN product identity comes from verified Play authority", () => {
  const notification = {
    version: "1.0",
    notificationType: 4,
    purchaseToken: "provider-token",
  };
  const cause = googleSubscriptionNotificationCause(
    notification.notificationType,
  );
  const line = selectSubscriptionAuthorityLine(
    {
      subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
      lineItems: [{
        productId: "chronospark_premium_monthly",
        expiryTime: "2026-09-30T00:00:00.000Z",
      }],
    },
    products,
    Date.parse("2026-08-30T00:00:00.000Z"),
  );
  if (
    !cause.supported || cause.notificationType !== 4 ||
    line.productId !== "chronospark_premium_monthly" ||
    "subscriptionId" in notification
  ) {
    throw new Error("type 4 authority depended on a non-contract RTDN field");
  }
});

Deno.test("deferred renewal selects the current line in either provider order", () => {
  const oldLine = {
    productId: "chronospark_premium_monthly",
    expiryTime: "2026-08-29T00:00:00.000Z",
    latestSuccessfulOrderId: "old-order",
    autoRenewingPlan: { autoRenewEnabled: false },
  };
  const currentLine = {
    productId: "chronospark_premium_annual",
    expiryTime: "2027-08-30T00:00:00.000Z",
    latestSuccessfulOrderId: "renewal-order",
    autoRenewingPlan: { autoRenewEnabled: true },
  };
  for (const lineItems of [[oldLine, currentLine], [currentLine, oldLine]]) {
    const selected = selectSubscriptionAuthorityLine(
      {
        subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
        lineItems,
      },
      products,
      Date.parse("2026-08-30T00:00:00.000Z"),
    );
    if (
      selected.productId !== "chronospark_premium_annual" ||
      selected.orderId !== "renewal-order" || !selected.autoRenews
    ) {
      throw new Error("deferred replacement selected the expired line");
    }
  }
});

Deno.test("initial deferred replacement keeps the existing entitlement in either order", () => {
  const existingLine = {
    productId: "chronospark_premium_monthly",
    expiryTime: "2026-09-30T00:00:00.000Z",
    latestSuccessfulOrderId: "existing-order",
    autoRenewingPlan: { autoRenewEnabled: false },
  };
  const futureLine = {
    productId: "chronospark_premium_annual",
  };
  for (
    const lineItems of [[existingLine, futureLine], [futureLine, existingLine]]
  ) {
    const selected = selectSubscriptionAuthorityLine(
      {
        subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
        lineItems,
      },
      products,
      Date.parse("2026-08-30T00:00:00.000Z"),
    );
    if (
      selected.productId !== "chronospark_premium_monthly" ||
      selected.orderId !== "existing-order" || selected.autoRenews
    ) {
      throw new Error("deferred purchase displaced existing paid authority");
    }
  }
});

Deno.test("multiple current recognized lines fail closed as ambiguous", () => {
  let failed = false;
  try {
    selectSubscriptionAuthorityLine(
      {
        subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
        lineItems: [
          {
            productId: "chronospark_premium_monthly",
            expiryTime: "2026-09-30T00:00:00.000Z",
          },
          {
            productId: "chronospark_premium_annual",
            expiryTime: "2027-08-30T00:00:00.000Z",
          },
        ],
      },
      products,
      Date.parse("2026-08-30T00:00:00.000Z"),
    );
  } catch (error) {
    failed = error instanceof Error &&
      error.message === "subscription_authority_active_ambiguous";
  }
  if (!failed) throw new Error("ambiguous active authority was accepted");
});

Deno.test("canceled pending successor rechecks the linked predecessor", async () => {
  const successor = {
    subscriptionState: "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED",
    linkedPurchaseToken: "predecessor-token",
  };
  const predecessor = {
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    lineItems: [{
      productId: "chronospark_premium_monthly",
      expiryTime: "2026-09-30T00:00:00.000Z",
    }],
  };
  let fetchedToken = "";
  const resolved = await resolveSubscriptionAuthorityPurchase({
    notificationType: 20,
    successorPurchase: successor,
    successorPurchaseToken: "successor-token",
    linkedPurchaseToken: "predecessor-token",
  }, (purchaseToken) => {
    fetchedToken = purchaseToken;
    return Promise.resolve(predecessor);
  });
  if (
    fetchedToken !== "predecessor-token" ||
    resolved.purchase !== predecessor ||
    resolved.purchaseToken !== "predecessor-token" ||
    resolved.source !== "linked_predecessor"
  ) {
    throw new Error(
      "canceled successor did not preserve predecessor authority",
    );
  }
  const predecessorLine = selectSubscriptionAuthorityLine(
    resolved.purchase,
    products,
    Date.parse("2026-08-30T00:00:00.000Z"),
  );
  if (predecessorLine.productId !== "chronospark_premium_monthly") {
    throw new Error("linked predecessor authority was not reconciliable");
  }

  for (
    const testCase of [
      { notificationType: 20, linkedPurchaseToken: null },
      { notificationType: 2, linkedPurchaseToken: "predecessor-token" },
    ]
  ) {
    let rejected = false;
    try {
      await resolveSubscriptionAuthorityPurchase({
        notificationType: testCase.notificationType,
        successorPurchase: successor,
        successorPurchaseToken: "successor-token",
        linkedPurchaseToken: testCase.linkedPurchaseToken,
      }, () => Promise.resolve(predecessor));
    } catch {
      rejected = true;
    }
    if (!rejected) {
      throw new Error("incoherent canceled-successor authority was accepted");
    }
  }
});

Deno.test("subscriptions-center resubscribe exposes the expired token lineage", () => {
  const lineage = readPurchaseLineage({
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING",
    outOfAppPurchaseContext: {
      expiredExternalAccountIdentifiers: {
        obfuscatedExternalAccountId: "a".repeat(64),
      },
      expiredPurchaseToken: " expired-token ",
    },
  });
  if (
    lineage?.source !== "out_of_app_resubscribe" ||
    lineage.purchaseToken !== "expired-token"
  ) {
    throw new Error("out-of-app re-subscription lineage was not resolved");
  }
  for (
    const value of [
      { outOfAppPurchaseContext: null },
      { outOfAppPurchaseContext: {} },
      {
        linkedPurchaseToken: "linked-token",
        outOfAppPurchaseContext: { expiredPurchaseToken: "expired-token" },
      },
    ]
  ) {
    let failed = false;
    try {
      readPurchaseLineage(value);
    } catch {
      failed = true;
    }
    if (!failed) throw new Error("invalid out-of-app lineage was accepted");
  }
});

Deno.test("paid renewal requires active authority and a successful order", () => {
  const renewal = googleSubscriptionNotificationCause(2);
  validatePaidRenewalAuthority(
    renewal,
    { supported: true, status: "active", active: true },
    "renewal-order",
  );
  for (
    const [state, orderId] of [
      [{ supported: true, status: "expired", active: false }, "order"],
      [{ supported: true, status: "active", active: true }, null],
    ] as const
  ) {
    let failed = false;
    try {
      validatePaidRenewalAuthority(renewal, state, orderId);
    } catch {
      failed = true;
    }
    if (!failed) throw new Error("incoherent paid renewal was accepted");
  }
  const legacyOnly = selectSubscriptionAuthorityLine(
    {
      subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
      latestOrderId: "legacy-top-level-order",
      lineItems: [{
        productId: "chronospark_premium_monthly",
        expiryTime: "2026-09-30T00:00:00.000Z",
      }],
    },
    products,
    Date.parse("2026-08-30T00:00:00.000Z"),
  );
  if (
    legacyOnly.orderId !== "legacy-top-level-order" ||
    legacyOnly.successfulLineOrderId !== null
  ) {
    throw new Error("line-level renewal evidence was not distinguished");
  }
  let legacyFallbackFailed = false;
  try {
    validatePaidRenewalAuthority(
      renewal,
      { supported: true, status: "active", active: true },
      legacyOnly.successfulLineOrderId,
    );
  } catch {
    legacyFallbackFailed = true;
  }
  if (!legacyFallbackFailed) {
    throw new Error("legacy top-level order was accepted as a paid renewal");
  }
  validatePaidRenewalAuthority(
    googleSubscriptionNotificationCause(9),
    { supported: true, status: "active", active: true },
    null,
  );
});

Deno.test("revocation and expiry notifications map coherently", () => {
  const future = new Date("2026-09-27T00:00:00.000Z");
  assertSubscriptionState(
    googleSubscriptionStateForNotification(
      12,
      "SUBSCRIPTION_STATE_EXPIRED",
      future,
    ),
    { status: "revoked", active: false },
    "notification type 12 did not revoke immediately",
  );
  assertSubscriptionState(
    googleSubscriptionStateForNotification(
      "13",
      "SUBSCRIPTION_STATE_EXPIRED",
      future,
    ),
    { status: "expired", active: false },
    "notification type 13 did not expire immediately",
  );
  if (
    !terminalNotificationMatchesSubscriptionState(
      12,
      "SUBSCRIPTION_STATE_EXPIRED",
    ) ||
    !terminalNotificationMatchesSubscriptionState(
      13,
      "SUBSCRIPTION_STATE_EXPIRED",
    )
  ) {
    throw new Error("coherent terminal notification and state were rejected");
  }
});

Deno.test("linked purchase lineage uses the hash-only binding RPC", async () => {
  let rpcName = "";
  let rpcArgs: Record<string, unknown> | null = null;
  const boundAt = new Date("2026-08-30T15:30:00.000Z");
  await bindVerifiedLinkedPurchaseToken({
    purchaseTokenHash: "successor-hash",
    predecessorTokenHash: "predecessor-hash",
    productId: "chronospark_premium_annual",
    boundAt,
  }, (name, args) => {
    rpcName = name;
    rpcArgs = args;
    return Promise.resolve({
      bound: true,
      reason: "linked_successor_bound",
      userId: "user-id",
      billingPrincipalId: "billing-principal-id",
    });
  });
  if (rpcName !== "bind_verified_linked_purchase_token") {
    throw new Error("linked token used the wrong RPC");
  }
  const expected = {
    p_purchase_token_hash: "successor-hash",
    p_predecessor_token_hash: "predecessor-hash",
    p_product_id: "chronospark_premium_annual",
    p_bound_at: boundAt.toISOString(),
  };
  if (JSON.stringify(rpcArgs) !== JSON.stringify(expected)) {
    throw new Error("linked binding RPC arguments changed");
  }

  await bindVerifiedLinkedPurchaseToken({
    purchaseTokenHash: "detached-successor-hash",
    predecessorTokenHash: "detached-predecessor-hash",
    productId: "chronospark_premium_monthly",
    boundAt,
  }, () =>
    Promise.resolve({
      bound: true,
      reason: "linked_successor_bound",
      userId: null,
      billingPrincipalId: "detached-billing-principal-id",
    }));

  let unresolvedFailed = false;
  try {
    await bindVerifiedLinkedPurchaseToken({
      purchaseTokenHash: "successor-hash",
      predecessorTokenHash: "predecessor-hash",
      productId: "chronospark_premium_annual",
      boundAt,
    }, () =>
      Promise.resolve({
        bound: false,
        reason: "predecessor_mismatch",
        userId: null,
        billingPrincipalId: null,
      }));
  } catch (error) {
    unresolvedFailed = error instanceof Error &&
      error.message === "linked_purchase_binding_unresolved";
  }
  if (!unresolvedFailed) {
    throw new Error("unresolved linked lineage would be acknowledged");
  }
});

Deno.test("terminal notifications reject contradictory Play states", () => {
  if (
    terminalNotificationMatchesSubscriptionState(
      12,
      "SUBSCRIPTION_STATE_ACTIVE",
    ) ||
    terminalNotificationMatchesSubscriptionState(
      13,
      "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    )
  ) {
    throw new Error("contradictory terminal notification and state accepted");
  }
});

Deno.test("stale and old-token reconciliation outcomes are handled", () => {
  if (!reconciliationWasHandled({ handled: true, reason: "stale_event" })) {
    throw new Error("stale reconciliation would be retried");
  }
  if (!reconciliationWasHandled({ handled: true, reason: "old_token" })) {
    throw new Error("old-token reconciliation would be retried");
  }
  if (!reconciliationWasHandled({ duplicate: true })) {
    throw new Error("duplicate reconciliation would be retried");
  }
  if (reconciliationWasHandled({ reason: "binding_not_found" })) {
    throw new Error("retryable reconciliation was acknowledged");
  }
});
