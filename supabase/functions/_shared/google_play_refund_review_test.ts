import { respondToGooglePlayRefundReview } from "./google_play_refund_review.ts";

const review = {
  version: "1.0",
  pendingRefundToken: "synthetic-refund-token",
  orderId: "GPA.1234-5678-9012-34567..2",
  refundReason: 7,
  obfuscatedAccountId: "must-not-be-forwarded",
};

Deno.test("refund review sends neutral minimal evidence to the order API", async () => {
  let calls = 0;
  await respondToGooglePlayRefundReview(
    { pendingRefundReviewNotification: review },
    "com.ghostheart5.chronospark",
    "synthetic-access-token",
    ((_url, init) => {
      calls++;
      if (
        String(_url) !==
          "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.ghostheart5.chronospark/orders/GPA.1234-5678-9012-34567..2:reviewrefund" ||
        init?.method !== "POST" ||
        new Headers(init.headers).get("authorization") !==
          "Bearer synthetic-access-token"
      ) throw new Error("incorrect authenticated order endpoint");
      const body = JSON.parse(String(init.body));
      if (
        body.refundPreference !== "NEUTRAL" ||
        body.sampleContentProvided !== true ||
        body.pendingRefundToken !== review.pendingRefundToken ||
        Object.keys(body).length !== 3
      ) throw new Error("invented usage or incorrect review policy");
      return Promise.resolve(new Response(null, { status: 200 }));
    }) as typeof fetch,
  );
  if (calls !== 1) throw new Error("wrong review call count");
});

for (
  const patch of [
    { pendingRefundToken: "" },
    { pendingRefundToken: "x".repeat(4097) },
    { orderId: "../../other-order" },
    { orderId: null },
    { version: "2.0" },
    { refundReason: 99 },
  ]
) {
  Deno.test(`refund review rejects invalid ${Object.keys(patch)[0]} ${String(Object.values(patch)[0]).slice(0, 12)}`, async () => {
    let called = false;
    let failed = false;
    try {
      await respondToGooglePlayRefundReview(
        { pendingRefundReviewNotification: { ...review, ...patch } },
        "com.ghostheart5.chronospark",
        "synthetic-access-token",
        (() => {
          called = true;
          return Promise.resolve(new Response(null));
        }) as typeof fetch,
      );
    } catch {
      failed = true;
    }
    if (!failed || called) throw new Error("invalid review reached Google");
  });
}

for (const status of [400, 401, 403, 429, 500, 503]) {
  Deno.test(`refund review preserves retry on Google ${status} without leaking body`, async () => {
    let error = "";
    try {
      await respondToGooglePlayRefundReview(
        { pendingRefundReviewNotification: review },
        "com.ghostheart5.chronospark",
        "synthetic-access-token",
        (() =>
          Promise.resolve(
            new Response("sensitive-provider-response", { status }),
          )) as typeof fetch,
      );
    } catch (value) {
      error = value instanceof Error ? value.message : "unexpected";
    }
    if (error !== `play_refund_review_${status}`) {
      throw new Error("provider failure was lost or sensitive body exposed");
    }
  });
}

Deno.test("refund review accepts Google's idempotent success on replay", async () => {
  let calls = 0;
  const request = (() => {
    calls++;
    return Promise.resolve(new Response(null, { status: 204 }));
  }) as typeof fetch;
  for (let i = 0; i < 2; i++) {
    await respondToGooglePlayRefundReview(
      { pendingRefundReviewNotification: review },
      "com.ghostheart5.chronospark",
      "synthetic-access-token",
      request,
    );
  }
  if (calls !== 2) throw new Error("replay was not completed");
});
