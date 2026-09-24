import {
  CREDIT_TOPUPS,
  validateTopupProof,
  verifyCreditTopup,
} from "./credit_topups.ts";
import { sha256Hex } from "./billing_backend.ts";
const assert = (value: unknown) => {
  if (!value) throw new Error("assertion failed");
};
Deno.test("only approved credit pack amounts exist", () => {
  assert(CREDIT_TOPUPS.size === 2);
  assert(CREDIT_TOPUPS.get("chronospark_credits_100") === 100);
  assert(CREDIT_TOPUPS.get("chronospark_credits_300") === 300);
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
      retry.creditsGranted === 100,
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
      assert(args.p_is_license_test === false);
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
  assert(events.join(",") === "verify,grant,consume");
});
Deno.test("standard receipt without a Play-echoed admission never reaches wallet grant", async () => {
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
    token: "unadmitted-token",
    accessToken: "test-access",
    requireTest: false,
  }, async () => {
    calls++;
    return Response.json({
      purchaseState: 0,
      quantity: 1,
      obfuscatedExternalAccountId: await sha256Hex("owner"),
      orderId: "GPA.unadmitted",
      consumptionState: 0,
      purchaseTimeMillis: "1780000000000",
    });
  });
  assert(result.valid === false && result.error === "admission_missing");
  assert(calls === 1);
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
