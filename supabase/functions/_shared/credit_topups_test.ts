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
    if (path.endsWith("/grant_verified_credit_topup")) {
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
  assert(events.join(",") === "verify,grant,consume,verify,grant,consume");
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
      String(url).endsWith("/grant_verified_credit_topup")
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
