import { sha256Hex } from "./billing_backend.ts";
import {
  registerPendingCreditTopup,
  verifyCreditTopup,
} from "./credit_topups.ts";
import { reconcilePublicCreditRefunds } from "./public_credit_refund_worker.ts";

// Orchestration regression with an in-memory database/provider transport.
// The admission/queue SQL itself is covered by the disposable database gate.
for (const loseRefundResponse of [false, true]) {
  Deno.test(`offline late payment reaches confirmed refund without a false binding (lost response: ${loseRefundResponse})`, async () => {
    const assert = (condition: unknown) => {
      if (!condition) {
        throw new Error("late-payment resolution invariant failed");
      }
    };
    const input = {
      config: {
        supabaseUrl: "https://backend.invalid",
        secretKey: "test",
        publishableKey: "test",
      },
      userId: "owner",
      packageName: "com.ghostheart5.chronospark",
      productId: "chronospark_credits_100",
      token: "late-payment-token",
      accessToken: "test",
      requireTest: false,
    };
    const tokenHash = await sha256Hex(input.token);
    const issuedAt = 1790294400000;
    const orderId = "GPA.late-completion";
    const admissionId = "123e4567-e89b-12d3-a456-426614174000";
    let purchaseState = 2;
    let orderState = "PROCESSED";
    let queued = false, refundAttempted = false, closed = false;
    let registrationCalls = 0, refundPosts = 0, consumes = 0;
    const transport: typeof fetch = async (url, init) => {
      const path = String(url);
      if (path.endsWith("/register_verified_pending_credit_topup")) {
        registrationCalls++;
        // Google was reachable, but persistence failed before the app went offline.
        return new Response(null, { status: 503 });
      }
      if (path.endsWith("/grant_verified_credit_topup_v2")) {
        const args = JSON.parse(String(init?.body));
        assert(args.p_token_hash === tokenHash);
        assert(args.p_admission_id === admissionId);
        assert(args.p_admission_exempt === false);
        assert(args.p_purchase_time_ms > issuedAt + 30 * 60 * 1000);
        queued = true;
        return Response.json({
          granted: false,
          reason: "customer_resolution_required",
          resolutionQueued: true,
        });
      }
      if (path.endsWith("/list_public_credit_refund_candidates")) {
        return Response.json({
          candidates: queued && !closed
            ? [{
              tokenHash,
              orderId,
              productId: input.productId,
              refundAttempted,
            }]
            : [],
        });
      }
      if (path.endsWith("/note_public_credit_refund_readback")) {
        return Response.json({ touched: true });
      }
      if (path.endsWith("/claim_public_credit_refund_attempt")) {
        assert(queued && !closed && !refundAttempted);
        refundAttempted = true;
        return Response.json({ claimed: true });
      }
      if (path.endsWith(":refund?revoke=true")) {
        assert(refundAttempted && init?.method === "POST");
        refundPosts++;
        if (loseRefundResponse) throw new Error("synthetic lost response");
        return new Response(null, { status: 200 });
      }
      if (path.endsWith("/orders/" + orderId)) {
        return Response.json({
          orderId,
          purchaseToken: input.token,
          state: orderState,
          lineItems: [{
            productId: input.productId,
            oneTimePurchaseDetails: { quantity: 1 },
          }],
        });
      }
      if (path.endsWith("/revoke_verified_credit_topup")) {
        assert(orderState === "REFUNDED" && refundAttempted);
        closed = true;
        return Response.json({ handled: true });
      }
      if (path.endsWith(":consume")) {
        consumes++;
        throw new Error("unfulfilled order must never be consumed");
      }
      assert(path.includes("/purchases/products/"));
      return Response.json({
        purchaseState,
        consumptionState: 0,
        productId: input.productId,
        quantity: 1,
        obfuscatedExternalAccountId: await sha256Hex(input.userId),
        obfuscatedExternalProfileId: admissionId,
        purchaseTimeMillis: String(issuedAt + 60 * 60 * 1000),
        orderId,
      });
    };

    const pending = await registerPendingCreditTopup(input, transport);
    assert(pending.valid === false && pending.retryable === true && !queued);
    purchaseState = 0; // Offline payment completes after the admission window.
    const recovered = await verifyCreditTopup(input, transport);
    assert(recovered.valid === false && recovered.resolutionQueued === true);
    assert(registrationCalls === 1 && consumes === 0);

    const requested = await reconcilePublicCreditRefunds(input, transport);
    assert(requested?.refunded === 0 && refundPosts === 1 && !closed);
    assert(
      loseRefundResponse
        ? requested?.manualReview === 1
        : requested?.requested === 1,
    );
    const uncertain = await reconcilePublicCreditRefunds(input, transport);
    assert(uncertain?.manualReview === 1 && refundPosts === 1 && !closed);
    orderState = "PENDING_REFUND";
    assert(
      (await reconcilePublicCreditRefunds(input, transport))?.pending === 1,
    );
    assert(!closed && refundPosts === 1);
    orderState = "REFUNDED";
    assert(
      (await reconcilePublicCreditRefunds(input, transport))?.refunded === 1,
    );
    assert(closed && consumes === 0 && refundPosts === 1);
    assert(
      (await reconcilePublicCreditRefunds(input, transport))?.scanned === 0,
    );
  });
}
