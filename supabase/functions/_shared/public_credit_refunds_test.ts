import {
  classifyQueuedCreditOrder,
  readGoogleCreditOrder,
  requestGoogleFullCreditRefund,
} from "./public_credit_refunds.ts";
import { sha256Hex } from "./billing_backend.ts";

const token = "play-token-for-one-paid-order";
const queued = {
  orderId: "GPA.1234-5678-9012-34567",
  productId: "chronospark_credits_100",
  tokenHash: await sha256Hex(token),
  refundAttempted: false,
};
const order = {
  orderId: queued.orderId,
  purchaseToken: token,
  state: "PROCESSED",
  lineItems: [{
    productId: queued.productId,
    oneTimePurchaseDetails: { quantity: 1 },
  }],
};

Deno.test("only the exact unrefunded credit order can request one full refund", async () => {
  if (
    await classifyQueuedCreditOrder(order, queued) !== "request_full_refund"
  ) {
    throw new Error("verified queued order was not eligible");
  }
  for (
    const changed of [
      { ...order, orderId: "GPA.other" },
      { ...order, purchaseToken: "other-token" },
      {
        ...order,
        lineItems: [{
          productId: "chronospark_credits_300",
          oneTimePurchaseDetails: { quantity: 1 },
        }],
      },
      {
        ...order,
        lineItems: [{
          productId: queued.productId,
          oneTimePurchaseDetails: { quantity: 2 },
        }],
      },
      { ...order, lineItems: [...order.lineItems, ...order.lineItems] },
      { ...order, state: "CANCELED" },
      { ...order, state: "PARTIALLY_REFUNDED" },
    ]
  ) {
    if (await classifyQueuedCreditOrder(changed, queued) !== "manual_review") {
      throw new Error("mismatched or partial order was accepted");
    }
  }
  if (
    await classifyQueuedCreditOrder(order, {
      ...queued,
      refundAttempted: true,
    }) !==
      "manual_review"
  ) throw new Error("ambiguous prior refund was retried");
});

Deno.test("provider refund states require readback before queue closure", async () => {
  if (
    await classifyQueuedCreditOrder(
      { ...order, state: "PENDING_REFUND" },
      queued,
    ) !==
      "await_provider_refund"
  ) throw new Error("pending refund was treated as final");
  if (
    await classifyQueuedCreditOrder({ ...order, state: "REFUNDED" }, queued) !==
      "confirmed_full_refund"
  ) throw new Error("full refund was not recognized");
});

Deno.test("order readback and refund use exact identity without retry", async () => {
  const calls: Array<{ url: string; method: string }> = [];
  const fetcher = (input: RequestInfo | URL, init?: RequestInit) => {
    calls.push({ url: String(input), method: init?.method ?? "GET" });
    return Promise.resolve(
      new Response(
        init?.method === "POST" ? null : JSON.stringify(order),
        { status: 200 },
      ),
    );
  };
  const read = await readGoogleCreditOrder(
    "com.ghostheart5.chronospark",
    queued.orderId,
    "access-token",
    fetcher,
  );
  if (read?.orderId !== queued.orderId) throw new Error("wrong order read");
  if (
    !await requestGoogleFullCreditRefund(
      "com.ghostheart5.chronospark",
      queued.orderId,
      "access-token",
      fetcher,
    )
  ) throw new Error("refund request failed");
  if (
    calls.length !== 2 || calls[0].method !== "GET" ||
    calls[1].method !== "POST" ||
    !calls[1].url.endsWith(
      encodeURIComponent(queued.orderId) + ":refund?revoke=true",
    )
  ) throw new Error("refund request was repeated or misdirected");

  const failed = await requestGoogleFullCreditRefund(
    "com.ghostheart5.chronospark",
    queued.orderId,
    "access-token",
    () => Promise.reject(new Error("unknown transport result")),
  );
  if (failed) throw new Error("unknown refund result was treated as confirmed");
});
