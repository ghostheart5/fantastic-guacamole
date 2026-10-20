import {
  CREDIT_TOPUPS,
  registerPendingCreditTopup,
  validateTopupProof,
  verifyCreditTopup,
} from "./credit_topups.ts";
import { sha256Hex } from "./billing_backend.ts";
const assert = (value: unknown) => {
  if (!value) throw new Error("assertion failed");
};

Deno.test("stale pending inventory recovers only from owner-verified cancellation", async () => {
  const input = {
    config: {
      supabaseUrl: "https://backend.invalid",
      secretKey: "test-secret",
      publishableKey: "test-public",
    },
    userId: "owner",
    packageName: "com.ghostheart5.chronospark",
    productId: "chronospark_credits_100",
    token: "canceled-token",
    accessToken: "test-access",
    requireTest: true,
  };
  const proof = {
    purchaseState: 1,
    quantity: 1,
    purchaseType: 0,
    productId: input.productId,
    obfuscatedExternalAccountId: await sha256Hex(input.userId),
    obfuscatedExternalProfileId: "123e4567-e89b-12d3-a456-426614174000",
  };
  for (const invalid of [false, true]) {
    const calls: string[] = [];
    const result = await registerPendingCreditTopup(
      input,
      async (url, init) => {
        if (
          new URL(String(url)).origin ===
            "https://androidpublisher.googleapis.com"
        ) {
          calls.push("provider");
          return Response.json({
            ...proof,
            ...(invalid ? { obfuscatedExternalAccountId: "other-owner" } : {}),
          });
        }
        assert(String(url).endsWith("/revoke_verified_credit_topup"));
        calls.push("revoke");
        const body = JSON.parse(String(init?.body));
        assert(body.p_token_hash === await sha256Hex(input.token));
        assert(body.p_product_id === input.productId);
        return Response.json({ handled: true });
      },
    );
    assert(result.valid === !invalid);
    assert((result.purchaseCanceled === true) === !invalid);
    assert(calls.join(",") === (invalid ? "provider" : "provider,revoke"));
    if (!invalid) {
      assert(result.productId === input.productId);
      assert(result.tokenHash === await sha256Hex(input.token));
      assert(result.pendingRegistered !== true);
    }
  }
  const unavailable = await registerPendingCreditTopup(
    input,
    (url) =>
      Promise.resolve(
        new URL(String(url)).origin ===
            "https://androidpublisher.googleapis.com"
          ? Response.json(proof)
          : new Response(null, { status: 503 }),
      ),
  );
  assert(unavailable.valid === false && unavailable.purchaseCanceled !== true);
});
Deno.test("only approved credit pack amounts exist", () => {
  assert(CREDIT_TOPUPS.size === 2);
  assert(CREDIT_TOPUPS.get("chronospark_credits_100") === 100);
  assert(CREDIT_TOPUPS.get("chronospark_credits_300") === 300);
});

Deno.test("Google-verified pending credit token binds admission without grant or consume", async () => {
  const events: string[] = [];
  const admissionId = "123e4567-e89b-12d3-a456-426614174000";
  const input = {
    config: {
      supabaseUrl: "https://backend.invalid",
      secretKey: "test-secret",
      publishableKey: "test-public",
    },
    userId: "owner",
    packageName: "com.ghostheart5.chronospark",
    productId: "chronospark_credits_100",
    token: "pending-token",
    accessToken: "test-access",
    requireTest: false,
  };
  const transport: typeof fetch = async (url, init) => {
    const path = String(url);
    if (path.endsWith("/register_verified_pending_credit_topup")) {
      events.push("register");
      const args = JSON.parse(String(init?.body));
      assert(args.p_user_id === input.userId);
      assert(args.p_token_hash === await sha256Hex(input.token));
      assert(args.p_product_id === input.productId);
      assert(args.p_admission_id === admissionId);
      return Response.json({ registered: true, duplicate: false });
    }
    events.push("verify-pending");
    return Response.json({
      purchaseState: 2,
      quantity: 1,
      productId: input.productId,
      obfuscatedExternalAccountId: await sha256Hex(input.userId),
      obfuscatedExternalProfileId: admissionId,
    });
  };
  const result = await registerPendingCreditTopup(input, transport);
  assert(result.valid === true && result.pendingRegistered === true);
  assert(events.join(",") === "verify-pending,register");
});

Deno.test("license QA may bind a pending token without a purchase type, but not grant it", async () => {
  const input = {
    config: {
      supabaseUrl: "https://backend.invalid",
      secretKey: "test-secret",
      publishableKey: "test-public",
    },
    userId: "owner",
    packageName: "com.ghostheart5.chronospark",
    productId: "chronospark_credits_100",
    token: "pending-test-token",
    accessToken: "test-access",
    requireTest: true,
  };
  let registrations = 0;
  const transport: typeof fetch = async (url) => {
    if (String(url).endsWith("/register_verified_pending_credit_topup")) {
      registrations++;
      return Response.json({ registered: true, duplicate: false });
    }
    return Response.json({
      purchaseState: 2,
      quantity: 1,
      productId: input.productId,
      obfuscatedExternalAccountId: await sha256Hex(input.userId),
      obfuscatedExternalProfileId: "123e4567-e89b-12d3-a456-426614174000",
    });
  };
  const result = await registerPendingCreditTopup(input, transport);
  assert(result.pendingRegistered === true && registrations === 1);
});

Deno.test("unverified or mismatched pending credit tokens never reach admission RPC", async () => {
  const base = {
    purchaseState: 2,
    quantity: 1,
    productId: "chronospark_credits_100",
    obfuscatedExternalAccountId: await sha256Hex("owner"),
    obfuscatedExternalProfileId: "123e4567-e89b-12d3-a456-426614174000",
  };
  const input = {
    config: {
      supabaseUrl: "https://backend.invalid",
      secretKey: "test-secret",
      publishableKey: "test-public",
    },
    userId: "owner",
    packageName: "com.ghostheart5.chronospark",
    productId: "chronospark_credits_100",
    token: "pending-token",
    accessToken: "test-access",
    requireTest: false,
  };
  for (
    const patch of [
      { purchaseState: 0 },
      { quantity: 2 },
      { productId: "chronospark_credits_300" },
      { obfuscatedExternalAccountId: "other-account" },
      { obfuscatedExternalProfileId: null },
      { purchaseType: 1 },
    ]
  ) {
    let calls = 0;
    const result = await registerPendingCreditTopup(input, () => {
      calls++;
      return Promise.resolve(Response.json({ ...base, ...patch }));
    });
    assert(result.valid === false && calls === 1);
  }
});

Deno.test("credit purchase grants once before consume and retries safely after consume failure", async () => {
  const events: string[] = [];
  let grants = 0;
  let consumeAttempts = 0;
  const proof = {
    purchaseState: 0,
    quantity: 1,
    purchaseType: 0,
    obfuscatedExternalAccountId: await sha256Hex("owner"),
    orderId: "GPA.test",
    consumptionState: 0,
  };
  const input = {
    config: {
      supabaseUrl: "https://backend.invalid",
      secretKey: "test-secret",
      publishableKey: "test-public",
    },
    userId: "owner",
    packageName: "com.ghostheart5.chronospark",
    productId: "chronospark_credits_100",
    token: "test-token",
    accessToken: "test-access",
    requireTest: true,
  };
  const transport: typeof fetch = async (url, init) => {
    const path = String(url);
    if (path.endsWith("/grant_verified_credit_topup_v2")) {
      events.push("grant");
      const args = JSON.parse(String(init?.body));
      assert(args.p_token_hash === await sha256Hex(input.token));
      assert(args.p_admission_exempt === true);
      const duplicate = grants > 0;
      grants = 1;
      return Response.json({ granted: true, duplicate });
    }
    if (path.endsWith(":consume")) {
      events.push("consume");
      consumeAttempts++;
      assert(grants === 1 && init?.method === "POST");
      return new Response(null, { status: consumeAttempts === 1 ? 503 : 204 });
    }
    events.push("verify");
    return Response.json(proof);
  };
  const first = await verifyCreditTopup(input, transport);
  assert(first.valid === false && first.retryable === true);
  const retry = await verifyCreditTopup(input, transport);
  assert(
    retry.valid === true && retry.duplicate === true &&
      retry.creditsGranted === 100 &&
      retry.publicAdmissionVerified === false,
  );
  assert(
    events.join(",") === "verify,grant,consume,verify,verify,grant,consume",
  );
  proof.consumptionState = 1;
  const completedRetry = await verifyCreditTopup(input, transport);
  assert(
    completedRetry.valid === true && consumeAttempts === 2 && grants === 1,
  );
});

Deno.test("failed database grant never consumes the Google purchase", async () => {
  const fingerprint = await sha256Hex("owner");
  let calls = 0;
  const transport: typeof fetch = (url) => {
    calls++;
    assert(!String(url).endsWith(":consume"));
    return Promise.resolve(
      String(url).endsWith("/grant_verified_credit_topup_v2")
        ? new Response(null, { status: 503 })
        : Response.json({
          purchaseState: 0,
          purchaseType: 0,
          obfuscatedExternalAccountId: fingerprint,
          orderId: "GPA.test",
          consumptionState: 0,
        }),
    );
  };
  const result = await verifyCreditTopup({
    config: {
      supabaseUrl: "https://backend.invalid",
      secretKey: "test",
      publishableKey: "test",
    },
    userId: "owner",
    packageName: "com.ghostheart5.chronospark",
    productId: "chronospark_credits_300",
    token: "test-token",
    accessToken: "test",
    requireTest: true,
  }, transport);
  assert(result.valid === false && result.retryable === true && calls === 2);
});
Deno.test("purchased license-test credit receipt accepts its bound account", async () => {
  const p = {
    purchaseState: 0,
    quantity: 1,
    purchaseType: 0,
    obfuscatedExternalAccountId: await sha256Hex("owner"),
    orderId: "GPA.test",
    consumptionState: 0,
  };
  assert(await validateTopupProof(p, "owner", true) === null);
  assert(
    await validateTopupProof({ ...p, consumptionState: 1 }, "owner", true) ===
      null,
  );
});

Deno.test("public credit proof accepts standard Play sales but rejects promo or rewarded types", async () => {
  const purchase = {
    purchaseState: 0,
    quantity: 1,
    obfuscatedExternalAccountId: await sha256Hex("owner"),
    orderId: "GPA.real",
    consumptionState: 0,
  };
  assert(await validateTopupProof(purchase, "owner", false) === null);
  assert(
    await validateTopupProof(
      { ...purchase, purchaseType: 0 },
      "owner",
      false,
    ) ===
      null,
  );
  for (const purchaseType of [1, 2, 3, "0", null]) {
    assert(
      await validateTopupProof(
        { ...purchase, purchaseType },
        "owner",
        false,
      ) === "unsupported_purchase_type",
    );
  }
  assert(
    await validateTopupProof(purchase, "owner", true) ===
      "test_purchase_required",
  );
});

Deno.test("mock standard Play credit sale grants once and consumes only after account-bound proof", async () => {
  const events: string[] = [];
  const proof = {
    purchaseState: 0,
    quantity: 1,
    obfuscatedExternalAccountId: await sha256Hex("owner"),
    obfuscatedExternalProfileId: "123e4567-e89b-12d3-a456-426614174000",
    purchaseTimeMillis: "1780000000000",
    orderId: "GPA.standard",
    consumptionState: 0,
  };
  const transport: typeof fetch = (url, init) => {
    const path = String(url);
    if (path.endsWith("/grant_verified_credit_topup_v2")) {
      events.push("grant");
      const args = JSON.parse(String(init?.body));
      assert(args.p_user_id === "owner");
      assert(args.p_product_id === "chronospark_credits_100");
      assert(args.p_order_id === proof.orderId);
      assert(args.p_admission_exempt === false);
      assert(args.p_admission_id === proof.obfuscatedExternalProfileId);
      assert(args.p_purchase_time_ms === Number(proof.purchaseTimeMillis));
      return Promise.resolve(
        Response.json({ granted: true, duplicate: false }),
      );
    }
    if (path.endsWith(":consume")) {
      events.push("consume");
      return Promise.resolve(new Response(null, { status: 204 }));
    }
    events.push("verify");
    return Promise.resolve(Response.json(proof));
  };
  const result = await verifyCreditTopup({
    config: {
      supabaseUrl: "https://backend.invalid",
      secretKey: "test-secret",
      publishableKey: "test-public",
    },
    userId: "owner",
    packageName: "com.ghostheart5.chronospark",
    productId: "chronospark_credits_100",
    token: "mock-standard-token",
    accessToken: "test-access",
    requireTest: false,
  }, transport);
  assert(result.valid === true && result.testPurchase === false);
  assert(result.creditsGranted === 100 && result.consumed === true);
  assert(result.publicAdmissionVerified === true);
  assert(events.join(",") === "verify,grant,consume");
});
Deno.test("public-client license-test credit checkout exercises the admission grant", async () => {
  const admissionId = "123e4567-e89b-12d3-a456-426614174000";
  const proof = {
    purchaseState: 0,
    purchaseType: 0,
    quantity: 1,
    obfuscatedExternalAccountId: await sha256Hex("owner"),
    obfuscatedExternalProfileId: admissionId,
    purchaseTimeMillis: "1780000000000",
    orderId: "GPA.public-test",
    consumptionState: 0,
  };
  for (const requireTest of [false, true]) {
    const events: string[] = [];
    const result = await verifyCreditTopup({
      config: {
        supabaseUrl: "https://backend.invalid",
        secretKey: "test-secret",
        publishableKey: "test-public",
      },
      userId: "owner",
      packageName: "com.ghostheart5.chronospark",
      productId: "chronospark_credits_100",
      token: "public-license-token",
      accessToken: "test-access",
      requireTest,
    }, (url, init) => {
      const path = String(url);
      if (path.endsWith("/grant_verified_credit_topup_v2")) {
        events.push("grant");
        const args = JSON.parse(String(init?.body));
        assert(args.p_admission_exempt === false);
        assert(args.p_admission_id === admissionId);
        assert(args.p_purchase_time_ms === Number(proof.purchaseTimeMillis));
        return Promise.resolve(Response.json({ granted: true }));
      }
      if (path.endsWith(":consume")) {
        events.push("consume");
        return Promise.resolve(new Response(null, { status: 204 }));
      }
      events.push("verify");
      return Promise.resolve(Response.json(proof));
    });
    assert(result.valid === true && result.testPurchase === true);
    assert(result.publicAdmissionVerified === true);
    assert(events.join(",") === "verify,grant,consume");
  }
});
Deno.test("unexpected real charge in license QA is queued for full refund, never consumed", async () => {
  for (const rightfulOwner of [true, false]) {
    const events: string[] = [];
    const result = await verifyCreditTopup({
      config: {
        supabaseUrl: "https://backend.invalid",
        secretKey: "test-secret",
        publishableKey: "test-public",
      },
      userId: "owner",
      packageName: "com.ghostheart5.chronospark",
      productId: "chronospark_credits_100",
      token: "unexpected-real-charge",
      accessToken: "test-access",
      requireTest: true,
    }, async (url, init) => {
      const path = String(url);
      if (path.endsWith("/queue_unadmitted_credit_topup")) {
        events.push("queue");
        const args = JSON.parse(String(init?.body));
        assert(args.p_order_id === "GPA.qa-real");
        assert(args.p_user_id === "owner");
        return Response.json({ resolutionQueued: true });
      }
      if (
        path.endsWith("/grant_verified_credit_topup_v2") ||
        path.endsWith(":consume")
      ) {
        throw new Error("real QA charge was granted or consumed");
      }
      events.push("verify");
      return Response.json({
        purchaseState: 0,
        quantity: 1,
        obfuscatedExternalAccountId: await sha256Hex(
          rightfulOwner ? "owner" : "other",
        ),
        obfuscatedExternalProfileId: "123e4567-e89b-12d3-a456-426614174000",
        purchaseTimeMillis: "1780000000000",
        orderId: "GPA.qa-real",
        consumptionState: 0,
      });
    });
    assert(events.join(",") === (rightfulOwner ? "verify,queue" : "verify"));
    if (rightfulOwner) {
      assert(result.error === "customer_resolution_required");
      assert(result.resolutionQueued === true);
    } else {
      assert(result.resolutionQueued !== true);
    }
  }
});
Deno.test("promo and rewarded QA receipts never enter the paid-order refund queue", async () => {
  for (const purchaseType of [1, 2]) {
    let calls = 0;
    const result = await verifyCreditTopup({
      config: {
        supabaseUrl: "https://backend.invalid",
        secretKey: "test-secret",
        publishableKey: "test-public",
      },
      userId: "owner",
      packageName: "com.ghostheart5.chronospark",
      productId: "chronospark_credits_100",
      token: "nonpaid-qa-token",
      accessToken: "test-access",
      requireTest: true,
    }, async () => {
      calls++;
      if (calls > 1) throw new Error("nonpaid purchase reached a mutation");
      return Response.json({
        purchaseState: 0,
        quantity: 1,
        purchaseType,
        obfuscatedExternalAccountId: await sha256Hex("owner"),
        orderId: "GPA.nonpaid",
        consumptionState: 0,
      });
    });
    assert(calls === 1 && result.error === "test_purchase_required");
    assert(result.resolutionQueued !== true);
  }
});
Deno.test("public-client license-test receipt without a valid profile cannot bypass admission", async () => {
  for (const profileId of [undefined, "not-an-admission"]) {
    const events: string[] = [];
    const result = await verifyCreditTopup({
      config: {
        supabaseUrl: "https://backend.invalid",
        secretKey: "test-secret",
        publishableKey: "test-public",
      },
      userId: "owner",
      packageName: "com.ghostheart5.chronospark",
      productId: "chronospark_credits_100",
      token: "unadmitted-public-test-token",
      accessToken: "test-access",
      requireTest: false,
    }, async (url) => {
      const path = String(url);
      if (path.endsWith("/queue_unadmitted_credit_topup")) {
        events.push("queue");
        return Response.json({ resolutionQueued: true });
      }
      if (
        path.endsWith("/grant_verified_credit_topup_v2") ||
        path.endsWith(":consume")
      ) {
        throw new Error(
          "missing or malformed public profile was granted or consumed",
        );
      }
      events.push("verify");
      return Response.json({
        purchaseState: 0,
        purchaseType: 0,
        quantity: 1,
        obfuscatedExternalAccountId: await sha256Hex("owner"),
        obfuscatedExternalProfileId: profileId,
        purchaseTimeMillis: "1780000000000",
        orderId: "GPA.malformed-public-test",
        consumptionState: 0,
      });
    });
    assert(result.valid === false && result.resolutionQueued === true);
    assert(events.join(",") === "verify,queue");
  }
});
Deno.test("standard paid receipt without admission is queued, never granted or consumed", async () => {
  const events: string[] = [];
  const result = await verifyCreditTopup({
    config: {
      supabaseUrl: "https://backend.invalid",
      secretKey: "test-secret",
      publishableKey: "test-public",
    },
    userId: "owner",
    packageName: "com.ghostheart5.chronospark",
    productId: "chronospark_credits_100",
    token: "unadmitted-token",
    accessToken: "test-access",
    requireTest: false,
  }, async (url, init) => {
    if (String(url).endsWith("/queue_unadmitted_credit_topup")) {
      events.push("queue");
      const args = JSON.parse(String(init?.body));
      assert(args.p_order_id === "GPA.unadmitted");
      assert(args.p_token_hash === await sha256Hex("unadmitted-token"));
      return Response.json({ resolutionQueued: true });
    }
    if (
      String(url).endsWith(":consume") ||
      String(url).endsWith("/grant_verified_credit_topup_v2")
    ) {
      throw new Error("unadmitted payment was delivered");
    }
    events.push("verify");
    return Response.json({
      purchaseState: 0,
      quantity: 1,
      obfuscatedExternalAccountId: await sha256Hex("owner"),
      orderId: "GPA.unadmitted",
      consumptionState: 0,
      purchaseTimeMillis: "1780000000000",
    });
  });
  assert(
    result.valid === false &&
      result.error === "customer_resolution_required" &&
      result.resolutionQueued === true,
  );
  assert(events.join(",") === "verify,queue");
});
Deno.test("rejected public admission never consumes a paid Google receipt", async () => {
  const proof = {
    purchaseState: 0,
    quantity: 1,
    obfuscatedExternalAccountId: await sha256Hex("owner"),
    obfuscatedExternalProfileId: "123e4567-e89b-12d3-a456-426614174000",
    purchaseTimeMillis: "1780000000000",
    orderId: "GPA.unapproved",
    consumptionState: 0,
  };
  let verifies = 0;
  let grants = 0;
  const result = await verifyCreditTopup({
    config: {
      supabaseUrl: "https://backend.invalid",
      secretKey: "test-secret",
      publishableKey: "test-public",
    },
    userId: "owner",
    packageName: "com.ghostheart5.chronospark",
    productId: "chronospark_credits_100",
    token: "unapproved-token",
    accessToken: "test-access",
    requireTest: false,
  }, (url) => {
    const path = String(url);
    if (path.endsWith("/grant_verified_credit_topup_v2")) {
      grants++;
      return Promise.resolve(Response.json({
        granted: false,
        reason: "admission_invalid",
      }));
    }
    if (path.endsWith(":consume")) {
      throw new Error("unapproved purchase was consumed");
    }
    verifies++;
    return Promise.resolve(Response.json(proof));
  });
  assert(result.valid === false && result.error === "admission_invalid");
  assert(verifies === 1 && grants === 1);
});
Deno.test("verified but unfulfilled paid order is queued and never consumed", async () => {
  const proof = {
    purchaseState: 0,
    quantity: 1,
    obfuscatedExternalAccountId: await sha256Hex("owner"),
    obfuscatedExternalProfileId: "123e4567-e89b-12d3-a456-426614174000",
    purchaseTimeMillis: "1780000000000",
    orderId: "GPA.unfulfilled",
    consumptionState: 0,
  };
  let grantCalls = 0;
  const result = await verifyCreditTopup({
    config: {
      supabaseUrl: "https://backend.invalid",
      secretKey: "test-secret",
      publishableKey: "test-public",
    },
    userId: "owner",
    packageName: "com.ghostheart5.chronospark",
    productId: "chronospark_credits_100",
    token: "unfulfilled-token",
    accessToken: "test-access",
    requireTest: false,
  }, (url) => {
    const path = String(url);
    if (path.endsWith("/grant_verified_credit_topup_v2")) {
      grantCalls++;
      return Promise.resolve(Response.json({
        granted: false,
        reason: "customer_resolution_required",
        resolutionQueued: true,
      }));
    }
    if (path.endsWith(":consume")) {
      throw new Error("unfulfilled paid order was consumed");
    }
    return Promise.resolve(Response.json(proof));
  });
  assert(result.valid === false && result.resolutionQueued === true);
  assert(result.error === "customer_resolution_required" && grantCalls === 1);
});
Deno.test("pending canceled real and other-account credit receipts never grant", async () => {
  const p = {
    purchaseState: 0,
    quantity: 1,
    purchaseType: 0,
    obfuscatedExternalAccountId: await sha256Hex("owner"),
    orderId: "GPA.test",
    consumptionState: 0,
  };
  for (
    const patch of [
      { purchaseState: 1 },
      { purchaseState: 2 },
      { quantity: 2 },
      { purchaseType: undefined },
      { obfuscatedExternalAccountId: await sha256Hex("other") },
      { obfuscatedExternalAccountId: "owner" },
      { orderId: "" },
      { consumptionState: 7 },
    ]
  ) {
    assert(
      await validateTopupProof({ ...p, ...patch }, "owner", true) !== null,
    );
  }
});

Deno.test("concurrent consumption needs fresh matching Google completion proof", async () => {
  for (
    const patch of [{}, { purchaseState: 1 }, { orderId: "GPA.other" }, {
      obfuscatedExternalAccountId: "other",
    }, { purchaseType: undefined }]
  ) {
    const proof = {
      purchaseState: 0,
      quantity: 1,
      purchaseType: 0,
      consumptionState: 0,
      obfuscatedExternalAccountId: await sha256Hex("owner"),
      orderId: "GPA.test",
    };
    let reads = 0, grants = 0;
    const transport: typeof fetch = (url) => {
      if (String(url).endsWith("/grant_verified_credit_topup_v2")) {
        grants++;
        return Promise.resolve(
          Response.json({ granted: true, duplicate: true }),
        );
      }
      if (String(url).endsWith(":consume")) {
        return Promise.resolve(new Response(null, { status: 409 }));
      }
      reads++;
      return Promise.resolve(
        Response.json(
          reads === 1 ? proof : { ...proof, consumptionState: 1, ...patch },
        ),
      );
    };
    const result = await verifyCreditTopup({
      config: {
        supabaseUrl: "https://backend.invalid",
        secretKey: "test",
        publishableKey: "test",
      },
      userId: "owner",
      packageName: "com.ghostheart5.chronospark",
      productId: "chronospark_credits_100",
      token: "token",
      accessToken: "access",
      requireTest: true,
    }, transport);
    assert(reads === 2 && grants === 1);
    assert(result.valid === (Object.keys(patch).length === 0));
  }
});
