import { sha256Hex } from "./billing_backend.ts";
import { verifyCreditTopup } from "./credit_topups.ts";
import {
  creditAdmissionAllowed,
  parsePublicCreditTopupPolicy,
  privateCreditAdmissionQaRequired,
} from "./public_credit_topup_policy.ts";

// No client requireTestPurchase signal: this is the server-owned RTDN path.
// Provider/database transports are synthetic, not live Play evidence.
Deno.test("public launch preserves QA refund protection without restricting public customers", async () => {
  const tester = "11111111-1111-4111-8111-111111111111";
  const customer = "22222222-2222-4222-8222-222222222222";
  const cohort = new Set([
    "6c360d206728b8cc03034e9f3e803a817fcba5fcfa20c218c7a94744d1a76313",
  ]);
  for (
    const scenario of [
      { public: false, qa: true, user: tester, type: undefined, refund: true },
      { public: true, qa: true, user: tester, type: undefined, refund: true },
      { public: true, qa: true, user: tester, type: 0, refund: false },
      {
        public: true,
        qa: true,
        user: customer,
        type: undefined,
        refund: false,
      },
      { public: true, qa: false, user: tester, type: undefined, refund: false },
    ]
  ) {
    const assert = (value: unknown) => {
      if (!value) throw new Error("QA rollout outcome violated");
    };
    const policy = parsePublicCreditTopupPolicy(() =>
      scenario.public ? "true" : undefined
    );
    assert(
      await creditAdmissionAllowed(policy, scenario.qa, scenario.user, cohort),
    );
    const requireTest = await privateCreditAdmissionQaRequired(
      scenario.qa,
      scenario.user,
      cohort,
    );
    const events: string[] = [];
    const result = await verifyCreditTopup({
      config: {
        supabaseUrl: "https://backend.invalid",
        secretKey: "test",
        publishableKey: "test",
      },
      userId: scenario.user,
      packageName: "com.ghostheart5.chronospark",
      productId: "chronospark_credits_100",
      token: "rollout-token",
      accessToken: "test",
      requireTest,
    }, async (url, init) => {
      const path = String(url);
      if (path.endsWith("/queue_unadmitted_credit_topup")) {
        events.push("queue");
        const args = JSON.parse(String(init?.body));
        assert(args.p_user_id === scenario.user);
        return Response.json({ resolutionQueued: true });
      }
      if (path.endsWith("/grant_verified_credit_topup_v2")) {
        events.push("grant");
        const args = JSON.parse(String(init?.body));
        assert(args.p_admission_exempt === false);
        return Response.json({ granted: true, creditsGranted: 100 });
      }
      if (path.endsWith(":consume")) {
        events.push("consume");
        return new Response(null, { status: 204 });
      }
      events.push("verify");
      return Response.json({
        purchaseState: 0,
        quantity: 1,
        obfuscatedExternalAccountId: await sha256Hex(scenario.user),
        obfuscatedExternalProfileId: "123e4567-e89b-12d3-a456-426614174000",
        purchaseTimeMillis: "1780000000000",
        orderId: "GPA.rollout",
        consumptionState: 0,
        ...(scenario.type === undefined ? {} : { purchaseType: scenario.type }),
      });
    });
    assert(
      events.join(",") ===
        (scenario.refund ? "verify,queue" : "verify,grant,consume"),
    );
    assert(
      scenario.refund
        ? result.resolutionQueued === true && result.valid !== true
        : result.valid === true && result.consumed === true,
    );
  }
});
