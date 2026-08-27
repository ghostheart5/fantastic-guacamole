import {
  decodePubSubNotification,
  googleSubscriptionState,
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
  const future = googleSubscriptionState(
    "SUBSCRIPTION_STATE_CANCELED",
    new Date("2026-08-28T00:00:00.000Z"),
    now,
  );
  const past = googleSubscriptionState(
    "SUBSCRIPTION_STATE_CANCELED",
    new Date("2026-08-26T00:00:00.000Z"),
    now,
  );
  if (!future.active || past.active) {
    throw new Error("cancellation state is wrong");
  }
});
