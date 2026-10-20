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

Deno.test("scoped refund selects one provider-confirmed license purchase only", async () => {
  const other = {
    ...candidate,
    tokenHash: "b".repeat(64),
    orderId: "GPA.other",
  };
  const calls: string[] = [];
  let proofRead = false;
  let claimed = false;
  const fetcher = (url: RequestInfo | URL, init?: RequestInit) => {
    const path = String(url);
    calls.push(path);
    if (path.endsWith("/list_public_credit_refund_candidates")) {
      return Promise.resolve(Response.json({ candidates: [other, candidate] }));
    }
    if (path.endsWith(`/orders/${candidate.orderId}`)) {
      return Promise.resolve(Response.json(order("PROCESSED")));
    }
    if (path.endsWith(`/products/${candidate.productId}/tokens/${token}`)) {
      if (init?.redirect !== "error") throw new Error("redirect not rejected");
      proofRead = true;
      return Promise.resolve(Response.json({
        purchaseType: 0,
        orderId: candidate.orderId,
        purchaseState: 0,
        consumptionState: 0,
      }));
    }
    if (!proofRead) throw new Error("mutation before test proof");
    if (path.endsWith("/note_public_credit_refund_readback")) {
      return Promise.resolve(Response.json({ touched: true }));
    }
    if (path.endsWith("/claim_public_credit_refund_attempt")) {
      claimed = true;
      return Promise.resolve(Response.json({ claimed: true }));
    }
    if (path.endsWith(`${candidate.orderId}:refund?revoke=true`) && claimed) {
      return Promise.resolve(new Response(null, { status: 200 }));
    }
    throw new Error("unexpected scoped request");
  };
  const result = await reconcilePublicCreditRefunds({
    ...input,
    testTokenHash: candidate.tokenHash,
  }, fetcher);
  if (
    result?.scanned !== 1 || result.requested !== 1 || calls.length !== 6 ||
    calls.some((url) => url.includes("GPA.other"))
  ) {
    throw new Error("scope was broadened or test refund was not requested");
  }
});

Deno.test("scoped refund fails closed for absent duplicated and malformed targets", async () => {
  let calls = 0;
  const malformed = await reconcilePublicCreditRefunds({
    ...input,
    testTokenHash: "",
  }, () => {
    calls++;
    throw new Error("invalid target reached transport");
  });
  if (malformed !== null || calls !== 0) {
    throw new Error("invalid scope accepted");
  }
  for (
    const candidates of [[], [{ ...candidate, tokenHash: "b".repeat(64) }], [
      candidate,
      candidate,
    ]]
  ) {
    calls = 0;
    const result = await reconcilePublicCreditRefunds({
      ...input,
      testTokenHash: candidate.tokenHash,
    }, (url) => {
      calls++;
      if (!String(url).endsWith("/list_public_credit_refund_candidates")) {
        throw new Error("missing or ambiguous target reached mutation");
      }
      return Promise.resolve(Response.json({ candidates }));
    });
    if (result !== null || calls !== 1) {
      throw new Error("false successful test run");
    }
  }
});

Deno.test("scoped refund rejects non-test consumed pending and mismatched proof before mutation", async () => {
  const proof = {
    purchaseType: 0,
    orderId: candidate.orderId,
    purchaseState: 0,
    consumptionState: 0,
  };
  for (
    const patch of [
      { purchaseType: undefined },
      { purchaseType: 1 },
      { purchaseType: 2 },
      { purchaseType: "0" },
      { orderId: "GPA.other" },
      { consumptionState: 1 },
      { purchaseState: 2 },
      { productId: "chronospark_credits_300" },
      { purchaseToken: "other-token" },
      { quantity: 2 },
    ]
  ) {
    const mutations: string[] = [];
    const result = await reconcilePublicCreditRefunds({
      ...input,
      testTokenHash: candidate.tokenHash,
    }, (url) => {
      const path = String(url);
      if (path.endsWith("/list_public_credit_refund_candidates")) {
        return Promise.resolve(Response.json({ candidates: [candidate] }));
      }
      if (path.endsWith(`/orders/${candidate.orderId}`)) {
        return Promise.resolve(Response.json(order("PROCESSED")));
      }
      if (path.includes("/purchases/products/")) {
        return Promise.resolve(Response.json({ ...proof, ...patch }));
      }
      mutations.push(path);
      throw new Error("unproven test order reached mutation");
    });
    if (result?.manualReview !== 1 || mutations.length !== 0) {
      throw new Error("unsafe license-test proof accepted");
    }
  }
});

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
