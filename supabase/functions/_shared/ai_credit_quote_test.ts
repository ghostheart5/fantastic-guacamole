import { buildServerSystemPrompt } from "./ai_proxy_policy.ts";
import {
  createCreditQuote,
  CREDIT_POLICY,
  CUSTOMER_QUOTE_MICROUSD_PER_CREDIT,
  MAX_PROVIDER_MICROUSD_PER_CREDIT,
  quotedCreditCost,
  quotedProviderCostMicrousd,
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
      credits: quote.credits + 1,
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
Deno.test("provider reserve exposes the conservative pre-rounding cost", () => {
  const providerCost = quotedProviderCostMicrousd(request);
  assert(providerCost > 0);
  assert(
    quotedCreditCost(request) ===
      Math.ceil(providerCost / CUSTOMER_QUOTE_MICROUSD_PER_CREDIT),
  );
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

// Mirrors the normal conversation factory's context shape with synthetic data. Uses
// the real server policy, not a shortened policy that hides the base price.
Deno.test("normal server-policy Chat quote changes from thirteen credits to five", () => {
  const upstream = {
    model: "claude-sonnet-4-6",
    max_tokens: 1024,
    temperature: 0,
    messages: [{
      role: "user",
      content:
        "Compare two fictional options for ten quiet minutes reading a story or sketching and name one possible downside of each",
    }],
    system: buildServerSystemPrompt("planner", {
      language: "en",
      nowLocal: "2026-10-20T19:30:00.000",
      utcOffsetMinutes: -300,
      taskTimeZoneId: "America/Chicago",
      mode: "compare",
      timeRange: "all",
      selectedSources: ["milestones"],
      entityFilter: "QA Fictional Only 20261020",
      scenarioAssumption: "",
      evidenceRevision: "synthetic-revision",
      tasks: [{
        id: "fictional-task-01",
        title: "Choose a quiet break",
        priority: 1,
        scheduledStart: null,
        deadline: null,
        goalId: null,
        description:
          "These are fictional options for a short break. Reading a story could be absorbing but difficult to stop. Sketching could be relaxing but require finding supplies. Compare the options without scheduling or changing anything.",
        estimatedDurationMinutes: 10,
      }],
      omittedRecordCount: 0,
      unavailableSources: [],
      goals: [],
      milestones: [],
      timeline: [],
    }),
  };
  assert(upstream.system !== null);
  const providerCost = quotedProviderCostMicrousd(upstream);
  assert(MAX_PROVIDER_MICROUSD_PER_CREDIT === 3000);
  assert(Math.ceil(providerCost / MAX_PROVIDER_MICROUSD_PER_CREDIT) === 13);
  assert(quotedCreditCost(upstream) === 5);
  assert(
    quotedCreditCost({
      ...upstream,
      system: upstream.system + "x".repeat(8000),
    }) > 5,
  );
});

Deno.test("lower customer conversion never raises any valid previous quote", () => {
  for (const max_tokens of [1, 64, 256, 1024]) {
    for (const size of [0, 1, 100, 1000, 8000, 50000]) {
      const upstream = { ...request, max_tokens, system: "x".repeat(size) };
      const old = Math.max(
        1,
        Math.ceil(
          quotedProviderCostMicrousd(upstream) /
            MAX_PROVIDER_MICROUSD_PER_CREDIT,
        ),
      );
      assert(quotedCreditCost(upstream) <= old);
      assert(quotedCreditCost(upstream) >= 1);
    }
  }
});

Deno.test("prior signed policy and tampered cheaper quote are rejected", async () => {
  const q = await createCreditQuote(
    "secret",
    "owner",
    "request-01",
    request,
    1000,
  );
  assert(q.policy === CREDIT_POLICY);
  for (
    const change of [
      { policy: "monthly-credits-v2-sonnet46-20260908" },
      { credits: q.credits + 1 },
      { credits: q.credits - 1 },
      { proof: "0".repeat(q.proof.length) },
    ]
  ) {
    assert(
      !await verifyCreditQuote("secret", "owner", "request-01", request, {
        ...q,
        ...change,
      }, 1001),
    );
  }
});
