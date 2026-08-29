import {
  decodePubSubNotification,
  googleSubscriptionStateForNotification,
  reconciliationWasHandled,
} from "../_shared/google_play_rtdn.ts";

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

Deno.test("canceled subscriptions remain active only through expiry", () => {
  const now = new Date("2026-08-27T00:00:00.000Z");
  const future = googleSubscriptionStateForNotification(
    3,
    "SUBSCRIPTION_STATE_CANCELED",
    new Date("2026-08-28T00:00:00.000Z"),
    now,
  );
  const past = googleSubscriptionStateForNotification(
    3,
    "SUBSCRIPTION_STATE_CANCELED",
    new Date("2026-08-26T00:00:00.000Z"),
    now,
  );
  if (!future.active || past.active) {
    throw new Error("cancellation state is wrong");
  }
});

Deno.test("notification types 12 and 13 force revoked and expired", () => {
  const future = new Date("2026-09-27T00:00:00.000Z");
  const revoked = googleSubscriptionStateForNotification(
    12,
    "SUBSCRIPTION_STATE_ACTIVE",
    future,
  );
  const expired = googleSubscriptionStateForNotification(
    "13",
    "SUBSCRIPTION_STATE_ACTIVE",
    future,
  );
  if (revoked.status !== "revoked" || revoked.active) {
    throw new Error("notification type 12 did not revoke immediately");
  }
  if (expired.status !== "expired" || expired.active) {
    throw new Error("notification type 13 did not expire immediately");
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
