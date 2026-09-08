import {
  createCreditQuote,
  quotedCreditCost,
  verifyCreditQuote,
} from "./ai_credit_quote.ts";
const request = {
  model: "claude-sonnet-4-6",
  max_tokens: 256,
  system: "Plan safely.",
  messages: [{ role: "user", content: "Plan my next task." }],
};
const assert = (value: unknown) => {
  if (!value) throw new Error("assertion failed");
};
Deno.test("quote binds user, request identity, full context, output cap and policy", async () => {
  const quote = await createCreditQuote(
    "test-secret",
    "owner",
    "request-01",
    request,
    1000,
  );
  assert(
    await verifyCreditQuote(
      "test-secret",
      "owner",
      "request-01",
      request,
      quote,
      1001,
    ),
  );
  for (
    const [user, id, body] of [
      ["other", "request-01", request],
      ["owner", "request-02", request],
      ["owner", "request-01", { ...request, system: "Changed" }],
      ["owner", "request-01", { ...request, max_tokens: 1024 }],
    ] as const
  ) {
    assert(
      !await verifyCreditQuote("test-secret", user, id, body, quote, 1001),
    );
  }
  assert(
    !await verifyCreditQuote(
      "wrong-secret",
      "owner",
      "request-01",
      request,
      quote,
      1001,
    ),
  );
  assert(
    !await verifyCreditQuote("test-secret", "owner", "request-01", request, {
      ...quote,
      credits: 1,
    }, 1001),
  );
});
Deno.test("expired quotes cannot authorize a spend", async () => {
  const q = await createCreditQuote(
    "secret",
    "owner",
    "request-01",
    request,
    1000,
  );
  assert(
    !await verifyCreditQuote(
      "secret",
      "owner",
      "request-01",
      request,
      q,
      301000,
    ),
  );
});
Deno.test("long history and non-ASCII context increase the quoted budget", () => {
  const short = quotedCreditCost(request);
  const long = quotedCreditCost({ ...request, system: "🙂".repeat(2000) });
  assert(long > short);
  assert(quotedCreditCost({ ...request, max_tokens: 1024 }) > short);
});
Deno.test("invalid output budgets are rejected", () => {
  for (const max_tokens of [0, -1, 1025, NaN, 1.5, "256"]) {
    let rejected = false;
    try {
      quotedCreditCost({ ...request, max_tokens });
    } catch {
      rejected = true;
    }
    assert(rejected);
  }
});
