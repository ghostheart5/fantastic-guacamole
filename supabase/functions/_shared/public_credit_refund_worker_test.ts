import { sha256Hex } from "./billing_backend.ts";
import { reconcilePublicCreditRefunds } from "./public_credit_refund_worker.ts";

const token = "one-verified-play-purchase-token";
const candidate = {
  tokenHash: await sha256Hex(token),
  orderId: "GPA.1111-2222-3333-44444",
  productId: "chronospark_credits_100",
  refundAttempted: false,
};
const config = {
  supabaseUrl: "https://example.supabase.co",
  publishableKey: "",
  secretKey: "service-test-key",
};
const input = {
  config,
  packageName: "com.ghostheart5.chronospark",
  accessToken: "play-access-token",
};

function order(state: string, purchaseToken = token) {
  return {
    orderId: candidate.orderId,
    purchaseToken,
    state,
    lineItems: [{
      productId: candidate.productId,
      oneTimePurchaseDetails: { quantity: 1 },
    }],
  };
}

Deno.test("verified unfulfilled order is claimed before one Google refund POST", async () => {
  const calls: string[] = [];
  const fetcher = (url: RequestInfo | URL, init?: RequestInit) => {
    const path = String(url);
    calls.push(path);
    if (path.endsWith("/list_public_credit_refund_candidates")) {
      return Promise.resolve(Response.json({ candidates: [candidate] }));
    }
    if (path.endsWith("/note_public_credit_refund_readback")) {
      return Promise.resolve(Response.json({ touched: true }));
    }
    if (path.endsWith("/claim_public_credit_refund_attempt")) {
      return Promise.resolve(Response.json({ claimed: true }));
    }
    if (path.endsWith(encodeURIComponent(candidate.orderId))) {
      return Promise.resolve(Response.json(order("PROCESSED")));
    }
    if (
      path.endsWith(
        encodeURIComponent(candidate.orderId) + ":refund?revoke=true",
      ) &&
      init?.method === "POST"
    ) {
      return Promise.resolve(new Response(null, { status: 200 }));
    }
    throw new Error("unexpected request");
  };
  const result = await reconcilePublicCreditRefunds(input, fetcher);
  if (
    result?.requested !== 1 || result.refunded !== 0 ||
    calls.filter((url) => url.includes(":refund")).length !== 1 ||
    calls.findIndex((url) =>
        url.includes("claim_public_credit_refund_attempt")
      ) >
      calls.findIndex((url) => url.includes(":refund"))
  ) throw new Error("refund request was absent, repeated, or unclaimed");
});

Deno.test("only a provider-confirmed full refund closes the resolution", async () => {
  const calls: string[] = [];
  const fetcher = (url: RequestInfo | URL) => {
    const path = String(url);
    calls.push(path);
    if (path.endsWith("/list_public_credit_refund_candidates")) {
      return Promise.resolve(Response.json({
        candidates: [{ ...candidate, refundAttempted: true }],
      }));
    }
    if (path.endsWith("/note_public_credit_refund_readback")) {
      return Promise.resolve(Response.json({ touched: true }));
    }
    if (path.endsWith(encodeURIComponent(candidate.orderId))) {
      return Promise.resolve(Response.json(order("REFUNDED")));
    }
    if (path.endsWith("/revoke_verified_credit_topup")) {
      return Promise.resolve(Response.json({ handled: true }));
    }
    throw new Error("unexpected request");
  };
  const result = await reconcilePublicCreditRefunds(input, fetcher);
  if (
    result?.refunded !== 1 || calls.length !== 4 ||
    calls.some((url) => url.includes(":refund"))
  ) throw new Error("confirmed refund was not reconciled safely");
});

Deno.test("mismatched, partial, and uncertain orders never repeat refunds", async () => {
  for (
    const providerOrder of [
      order("PROCESSED", "other-token"),
      order("PARTIALLY_REFUNDED"),
      order("PROCESSED"),
    ]
  ) {
    const attempted = providerOrder.purchaseToken === token &&
      providerOrder.state === "PROCESSED";
    let refundPosts = 0;
    const fetcher = (url: RequestInfo | URL) => {
      const path = String(url);
      if (path.endsWith("/list_public_credit_refund_candidates")) {
        return Promise.resolve(Response.json({
          candidates: [{ ...candidate, refundAttempted: attempted }],
        }));
      }
      if (path.endsWith("/note_public_credit_refund_readback")) {
        return Promise.resolve(Response.json({ touched: true }));
      }
      if (path.endsWith(encodeURIComponent(candidate.orderId))) {
        return Promise.resolve(Response.json(providerOrder));
      }
      if (path.includes(":refund")) refundPosts++;
      throw new Error("unexpected mutation");
    };
    const result = await reconcilePublicCreditRefunds(input, fetcher);
    if (result?.manualReview !== 1 || refundPosts !== 0) {
      throw new Error("unsafe order attempted a refund");
    }
  }
});

Deno.test("one failed order read does not hide another queued refund", async () => {
  const other = {
    ...candidate,
    orderId: "GPA.9999-8888-7777-66666",
    refundAttempted: true,
  };
  const calls: string[] = [];
  const fetcher = (url: RequestInfo | URL) => {
    const path = String(url);
    calls.push(path);
    if (path.endsWith("/list_public_credit_refund_candidates")) {
      return Promise.resolve(Response.json({
        candidates: [candidate, other],
      }));
    }
    if (path.endsWith("/note_public_credit_refund_readback")) {
      return Promise.resolve(Response.json({ touched: true }));
    }
    if (path.endsWith(encodeURIComponent(candidate.orderId))) {
      return Promise.reject(new Error("provider read timed out"));
    }
    if (path.endsWith(encodeURIComponent(other.orderId))) {
      return Promise.resolve(Response.json({
        ...order("REFUNDED"),
        orderId: other.orderId,
      }));
    }
    if (path.endsWith("/revoke_verified_credit_topup")) {
      return Promise.resolve(Response.json({ handled: true }));
    }
    throw new Error("unexpected request");
  };
  const result = await reconcilePublicCreditRefunds(input, fetcher);
  if (
    result?.scanned !== 2 || result.retryLater !== 1 ||
    result.refunded !== 1 || calls.length !== 6
  ) throw new Error("one provider outage stopped the entire refund batch");
});
