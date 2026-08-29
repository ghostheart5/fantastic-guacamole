import {
  decodePubSubNotification,
  googleSubscriptionStateForNotification,
  reconciliationWasHandled,
  terminalNotificationMatchesSubscriptionState,
} from "../_shared/google_play_rtdn.ts";

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
