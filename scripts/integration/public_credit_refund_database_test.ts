import {
  serviceRpc,
  sha256Hex,
} from "../../supabase/functions/_shared/billing_backend.ts";
import { reconcilePublicCreditRefunds } from "../../supabase/functions/_shared/public_credit_refund_worker.ts";

// Disposable CI database only. Google responses are explicitly synthetic;
// database claims, queue transitions and HTTP requests are real integration I/O.
Deno.test("durable refund claim survives an uncertain response without a second refund", async () => {
  const assert = (condition: unknown, message: string) => {
    if (!condition) throw new Error(message);
  };
  const base = Deno.env.get("LOCAL_SUPABASE_URL");
  const key = Deno.env.get("LOCAL_SUPABASE_SERVICE_KEY");
  assert(
    Deno.env.get("AXIOMARA_DISPOSABLE_DB_GATE") === "true" &&
      base === "http://127.0.0.1:54321" && !!key,
    "Only the explicitly disposable loopback database is allowed",
  );
  const config = { supabaseUrl: base!, secretKey: key!, publishableKey: "" };
  const headers = {
    apikey: key!,
    Authorization: `Bearer ${key}`,
    "Content-Type": "application/json",
  };
  const rpc = (name: string, args: Record<string, unknown> = {}) =>
    serviceRpc(config, name, args);
  const health = await rpc("public_credit_checkout_resolution_health");
  assert(
    health?.awaiting === 0,
    "Disposable database must start with an empty queue",
  );

  const userResponse = await fetch(`${base}/auth/v1/admin/users`, {
    method: "POST",
    headers,
    body: JSON.stringify({
      email: `refund-integration-${crypto.randomUUID()}@example.invalid`,
      email_confirm: true,
    }),
  });
  assert(userResponse.ok, "Disposable fixture user could not be created");
  const user = await userResponse.json();
  const token = `synthetic-refund-${crypto.randomUUID()}`;
  const tokenHash = await sha256Hex(token);
  const orderId = "GPA.synthetic-database-integration";
  const productId = "chronospark_credits_100";
  const queued = await rpc("queue_unadmitted_credit_topup", {
    p_user_id: user.id,
    p_token_hash: tokenHash,
    p_product_id: productId,
    p_order_id: orderId,
  });
  assert(
    queued?.resolutionQueued === true,
    "Verified fixture was not durably queued",
  );

  let providerState = "PROCESSED";
  let refundPosts = 0;
  const provider = Deno.serve(
    { hostname: "127.0.0.1", port: 0, onListen() {} },
    async (req) => {
      const url = new URL(req.url);
      if (url.pathname.endsWith(":refund")) {
        assert(
          req.method === "POST" && url.search === "?revoke=true",
          "Unexpected refund request",
        );
        // Verify the actual database committed its claim before the external POST.
        const state = await rpc("list_public_credit_refund_candidates", {
          p_limit: 5,
        });
        const candidates = state?.candidates as Array<Record<string, unknown>>;
        assert(
          candidates?.length === 1 && candidates[0].refundAttempted === true,
          "Refund POST preceded durable claim",
        );
        refundPosts++;
        return new Response(null, { status: 200 });
      }
      assert(
        req.method === "GET" && url.pathname.endsWith(`/orders/${orderId}`),
        "Unexpected provider read",
      );
      return Response.json({
        orderId,
        purchaseToken: token,
        state: providerState,
        lineItems: [{ productId, oneTimePurchaseDetails: { quantity: 1 } }],
      });
    },
  );
  const transport: typeof fetch = async (url, init) => {
    const target = new URL(String(url));
    if (target.origin === base) return await fetch(url, init);
    assert(
      target.origin === "https://androidpublisher.googleapis.com",
      "Unexpected external destination",
    );
    const response = await fetch(
      `http://127.0.0.1:${provider.addr.port}${target.pathname}${target.search}`,
      init,
    );
    if (target.pathname.endsWith(":refund")) {
      await response.body?.cancel();
      throw new Error(
        "Synthetic response lost after provider accepted request",
      );
    }
    return response;
  };
  const input = {
    config,
    packageName: "com.ghostheart5.chronospark",
    accessToken: "synthetic-provider-token",
  };
  try {
    const uncertain = await reconcilePublicCreditRefunds(input, transport);
    assert(
      uncertain?.manualReview === 1 && uncertain.refunded === 0 &&
        refundPosts === 1,
      "Uncertain response was falsely confirmed or repeated",
    );
    const repeated = await reconcilePublicCreditRefunds(input, transport);
    assert(
      repeated?.manualReview === 1 && refundPosts === 1,
      "A later invocation did not preserve the durable claim",
    );
    providerState = "PENDING_REFUND";
    assert(
      (await reconcilePublicCreditRefunds(input, transport))?.pending === 1,
      "Pending refund was not retained",
    );
    providerState = "PARTIALLY_REFUNDED";
    assert(
      (await reconcilePublicCreditRefunds(input, transport))?.manualReview ===
        1,
      "Partial refund was incorrectly treated as full refund",
    );
    assert(
      (await rpc("public_credit_checkout_resolution_health"))?.awaiting === 1,
      "Unconfirmed refund prematurely closed the database queue",
    );
    const purchasesBefore = await fetch(
      `${base}/rest/v1/credit_topup_purchases?token_hash=eq.${tokenHash}&select=state`,
      { headers },
    );
    assert(
      purchasesBefore.ok && (await purchasesBefore.json()).length === 0,
      "Unfulfilled fixture was credited before provider confirmation",
    );
    providerState = "REFUNDED";
    assert(
      (await reconcilePublicCreditRefunds(input, transport))?.refunded === 1,
      "Confirmed full refund did not close the queue",
    );
    assert(
      (await reconcilePublicCreditRefunds(input, transport))?.scanned === 0 &&
        refundPosts === 1,
      "Resolved order reappeared or refund POST repeated",
    );
    assert(
      (await rpc("public_credit_checkout_resolution_health"))?.awaiting === 0,
      "Resolution queue remained open",
    );
    const purchasesAfter = await fetch(
      `${base}/rest/v1/credit_topup_purchases?token_hash=eq.${tokenHash}&select=state`,
      { headers },
    );
    const tombstones = await purchasesAfter.json();
    assert(
      purchasesAfter.ok && tombstones.length === 1 &&
        tombstones[0].state === "revoked",
      "Refund did not retain a revoked tombstone",
    );
  } finally {
    await provider.shutdown();
  }
});
