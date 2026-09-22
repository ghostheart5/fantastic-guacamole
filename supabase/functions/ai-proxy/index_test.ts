// Exercise the actual served handler, including its reservation/refund order.
// Only transport/configuration are substituted; no network or credentials.
type Handler = (request: Request) => Promise<Response>;
let handler: Handler | undefined;
let remainingProviderTimeoutMs:
  | ((startedAtMs: number, nowMs?: number) => number)
  | undefined;
const originalServe = Deno.serve;
const originalEnvGet = Deno.env.get;
try {
  Reflect.set(Deno.env, "get", (name: string) => {
    if (name === "SUPABASE_URL") return "https://backend.example";
    if (name === "CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS") {
      return "6c360d206728b8cc03034e9f3e803a817fcba5fcfa20c218c7a94744d1a76313";
    }
    return "synthetic-test-value";
  });
  Reflect.set(Deno, "serve", (value: Handler) => {
    handler = value;
  });
  const module = await import("./index.ts");
  remainingProviderTimeoutMs = module.remainingProviderTimeoutMs;
} finally {
  Reflect.set(Deno, "serve", originalServe);
  Reflect.set(Deno.env, "get", originalEnvGet);
}

Deno.test("provider retries share one bounded deadline", () => {
  if (!remainingProviderTimeoutMs) {
    throw new Error("provider deadline helper was not exported");
  }
  const startedAtMs = 1_000_000;
  if (remainingProviderTimeoutMs(startedAtMs, startedAtMs) !== 20_000) {
    throw new Error("first provider call did not keep its 20 second cap");
  }
  if (
    remainingProviderTimeoutMs(startedAtMs, startedAtMs + 12_000) !== 8_000
  ) {
    throw new Error("repair call did not inherit the remaining flow budget");
  }
  if (remainingProviderTimeoutMs(startedAtMs, startedAtMs + 20_000) !== 0) {
    throw new Error("expired provider flow received another timeout window");
  }
});

Deno.test("served AI GET reports the configured cohort without transport, quotes or spending", async () => {
  if (!handler) throw new Error("handler was not registered");
  const originalFetch = globalThis.fetch;
  globalThis.fetch = () => {
    throw new Error("GET preflight must never call backend/provider");
  };
  try {
    const response = await handler(
      new Request("https://local.example/ai-proxy"),
    );
    if (
      response.status !== 405 ||
      response.headers.get("x-chronospark-internal-ai-guard") !== "v1" ||
      !response.headers.get("x-chronospark-internal-ai-cohort-sha256")
    ) throw new Error("served guard marker missing");
    await response.body?.cancel();
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("duplicate denied AI request preserves its original budget reason", async () => {
  if (!handler) throw new Error("handler was not registered");
  const originalFetch = globalThis.fetch;
  let providerCalls = 0;
  globalThis.fetch = ((url) => {
    const path = String(url);
    if (path.endsWith("/auth/v1/user")) {
      return Promise.resolve(
        Response.json({ id: "11111111-1111-4111-8111-111111111111" }),
      );
    }
    if (path.endsWith("/consume_backend_rate_limit")) {
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/reserve_ai_usage")) {
      return Promise.resolve(Response.json({
        allowed: false,
        duplicate: true,
        state: "denied",
        reason: "daily_budget_exceeded",
        balance: 42,
      }));
    }
    if (path === "https://api.anthropic.com/v1/messages") providerCalls++;
    throw new Error("unexpected transport target");
  }) as typeof fetch;
  try {
    const input = {
      requestId: "synthetic-denied-duplicate",
      prompt: "Plan a fictional errand.",
      personality: "planner",
      context: {},
      allowExternalAi: true,
    };
    const request = (extra: Record<string, unknown>) =>
      new Request("https://local.example/ai-proxy", {
        method: "POST",
        headers: { authorization: "Bearer synthetic-session" },
        body: JSON.stringify({ ...input, ...extra }),
      });
    const quoted = await handler(request({ quoteOnly: true }));
    const { quote } = await quoted.json();
    const response = await handler(request({ quote }));
    const body = await response.json();
    if (
      response.status !== 429 || body.error !== "daily_budget_exceeded" ||
      body.remainingCredits !== 42 || providerCalls !== 0
    ) throw new Error("duplicate denial lost its original reason");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("contradictory Planner verdict is repaired before one settled response", async () => {
  if (!handler) throw new Error("handler was not registered");
  const originalFetch = globalThis.fetch;
  let providerCalls = 0;
  let reservations = 0;
  let settlements = 0;
  globalThis.fetch = ((url, init) => {
    const path = String(url);
    if (path.endsWith("/auth/v1/user")) {
      return Promise.resolve(
        Response.json({ id: "11111111-1111-4111-8111-111111111111" }),
      );
    }
    if (path.endsWith("/consume_backend_rate_limit")) {
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/reserve_ai_usage")) {
      reservations++;
      return Promise.resolve(
        Response.json({ allowed: true, duplicate: false, balance: 84 }),
      );
    }
    if (path.endsWith("/reserve_ai_repair_budget")) {
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/settle_ai_usage")) {
      const body = JSON.parse(String(init?.body));
      if (
        body.p_succeeded !== true || body.p_input_tokens !== 30 ||
        body.p_output_tokens !== 17
      ) throw new Error("repaired usage was not settled once in full");
      settlements++;
      return Promise.resolve(Response.json({ state: "completed" }));
    }
    if (path === "https://api.anthropic.com/v1/messages") {
      providerCalls++;
      const repaired = providerCalls === 2;
      return Promise.resolve(Response.json({
        id: repaired ? "provider-repair" : "provider-first",
        model: "claude-sonnet-4-6",
        stop_reason: "end_turn",
        content: [{
          type: "text",
          text: repaired
            ? "Review release evidence first. The grocery window has passed, and release review fits now."
            : "Groceries first, then release evidence. Neither grocery task is actionable right now.",
        }],
        usage: repaired
          ? { input_tokens: 20, output_tokens: 7 }
          : { input_tokens: 10, output_tokens: 10 },
      }));
    }
    throw new Error(`unexpected transport target: ${path}`);
  }) as typeof fetch;
  try {
    const input = {
      requestId: "synthetic-contradiction-repair",
      prompt: "Should I buy groceries or review release evidence first?",
      personality: "planner",
      context: {},
      allowExternalAi: true,
    };
    const request = (extra: Record<string, unknown>) =>
      new Request("https://local.example/ai-proxy", {
        method: "POST",
        headers: { authorization: "Bearer synthetic-session" },
        body: JSON.stringify({ ...input, ...extra }),
      });
    const quoted = await handler(request({ quoteOnly: true }));
    const { quote } = await quoted.json();
    const response = await handler(request({ quote }));
    const body = await response.json();
    if (
      response.status !== 200 ||
      body.message !==
        "Review release evidence first. The grocery window has passed, and release review fits now." ||
      providerCalls !== 2 || reservations !== 1 || settlements !== 1
    ) throw new Error("contradictory response was not repaired exactly once");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("served SI repairs task-start departure confusion before settlement", async () => {
  if (!handler) throw new Error("handler was not registered");
  const originalFetch = globalThis.fetch;
  let providerCalls = 0;
  let settlements = 0;
  globalThis.fetch = ((url, init) => {
    const path = String(url);
    if (path.endsWith("/auth/v1/user")) {
      return Promise.resolve(Response.json({
        id: "11111111-1111-4111-8111-111111111111",
      }));
    }
    if (path.endsWith("/consume_backend_rate_limit")) {
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/reserve_ai_usage")) {
      return Promise.resolve(Response.json({
        allowed: true,
        duplicate: false,
        balance: 84,
      }));
    }
    if (path.endsWith("/reserve_ai_repair_budget")) {
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/settle_ai_usage")) {
      if (JSON.parse(String(init?.body)).p_succeeded !== true) {
        throw new Error("corrected response was not settled as success");
      }
      settlements++;
      return Promise.resolve(Response.json({ state: "completed" }));
    }
    if (path === "https://api.anthropic.com/v1/messages") {
      providerCalls++;
      const request = JSON.parse(String(init?.body));
      const repaired = providerCalls === 2;
      if (
        repaired &&
        !request.messages.at(-1).content.includes(
          "scheduled start as a travel departure",
        )
      ) throw new Error("repair did not explain the captured error");
      return Promise.resolve(Response.json({
        id: repaired ? "provider-repair" : "provider-first",
        model: "claude-sonnet-4-6",
        stop_reason: "end_turn",
        content: [{
          type: "text",
          text: repaired
            ? "If 7:13 PM is your shopping start, leave by 6:58 PM, then finish by 7:43 PM before the hypothetical 8 PM close. If the saved task is only list preparation, its start does not set your store departure."
            : "Scheduled start: 7:13 PM. Depart | 7:13 PM. Arrive at store | 7:28 PM. Shopping complete | 7:58 PM.",
        }],
        usage: repaired
          ? { input_tokens: 20, output_tokens: 7 }
          : { input_tokens: 10, output_tokens: 10 },
      }));
    }
    throw new Error(`unexpected transport target: ${path}`);
  }) as typeof fetch;
  try {
    const input = {
      requestId: "synthetic-si-task-start-repair",
      prompt: "Does this task conflict with an 8 PM store closing?",
      personality: "strategist",
      context: {
        mode: "findConflict",
        scenarioAssumption: "Store closes 8 PM tomorrow. Travel 15 minutes.",
        tasks: [{
          title: "QA Grocery List 3080",
          scheduledStart: "2026-09-23T19:13:00.000",
        }],
      },
      allowExternalAi: true,
    };
    const request = (extra: Record<string, unknown>) =>
      new Request("https://local.example/ai-proxy", {
        method: "POST",
        headers: { authorization: "Bearer synthetic-session" },
        body: JSON.stringify({ ...input, ...extra }),
      });
    const { quote } = await (await handler(request({ quoteOnly: true })))
      .json();
    const response = await handler(request({ quote }));
    const body = await response.json();
    if (
      response.status !== 200 ||
      !body.message.startsWith("If 7:13 PM is your shopping start") ||
      providerCalls !== 2 || settlements !== 1
    ) throw new Error("task-start confusion was not repaired exactly once");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("blocked repair output refunds with both provider calls accounted", async () => {
  if (!handler) throw new Error("handler was not registered");
  const originalFetch = globalThis.fetch;
  let providerCalls = 0;
  let settlements = 0;
  globalThis.fetch = ((url, init) => {
    const path = String(url);
    if (path.endsWith("/auth/v1/user")) {
      return Promise.resolve(
        Response.json({ id: "11111111-1111-4111-8111-111111111111" }),
      );
    }
    if (path.endsWith("/consume_backend_rate_limit")) {
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/reserve_ai_usage")) {
      return Promise.resolve(
        Response.json({ allowed: true, duplicate: false, balance: 84 }),
      );
    }
    if (path.endsWith("/reserve_ai_repair_budget")) {
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/settle_ai_usage")) {
      const body = JSON.parse(String(init?.body));
      if (
        body.p_succeeded !== false || body.p_input_tokens !== 30 ||
        body.p_output_tokens !== 17 ||
        body.p_provider_request_id !== "provider-blocked-repair"
      ) throw new Error("repair usage was omitted from refund accounting");
      settlements++;
      return Promise.resolve(Response.json({ state: "refunded" }));
    }
    if (path === "https://api.anthropic.com/v1/messages") {
      providerCalls++;
      const repaired = providerCalls === 2;
      return Promise.resolve(Response.json({
        id: repaired ? "provider-blocked-repair" : "provider-first",
        model: "claude-sonnet-4-6",
        stop_reason: "end_turn",
        content: [{
          type: "text",
          text: repaired
            ? "Axiomara has already updated your plan."
            : "Groceries first, then release evidence. Neither grocery task is actionable right now.",
        }],
        usage: repaired
          ? { input_tokens: 20, output_tokens: 7 }
          : { input_tokens: 10, output_tokens: 10 },
      }));
    }
    throw new Error(`unexpected transport target: ${path}`);
  }) as typeof fetch;
  try {
    const input = {
      requestId: "synthetic-blocked-repair-accounting",
      prompt: "Should I buy groceries or review release evidence first?",
      personality: "planner",
      context: {},
      allowExternalAi: true,
    };
    const request = (extra: Record<string, unknown>) =>
      new Request("https://local.example/ai-proxy", {
        method: "POST",
        headers: { authorization: "Bearer synthetic-session" },
        body: JSON.stringify({ ...input, ...extra }),
      });
    const quoted = await handler(request({ quoteOnly: true }));
    const { quote } = await quoted.json();
    const response = await handler(request({ quote }));
    const body = await response.json();
    if (
      response.status !== 502 ||
      body.error !== "inconsistent_upstream_response" ||
      providerCalls !== 2 || settlements !== 1
    ) throw new Error("blocked repair did not refund exactly once");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("unknown repair usage preserves the expanded provider reservation", async () => {
  if (!handler) throw new Error("handler was not registered");
  const originalFetch = globalThis.fetch;
  let providerCalls = 0;
  let settlements = 0;
  globalThis.fetch = ((url, init) => {
    const path = String(url);
    if (path.endsWith("/auth/v1/user")) {
      return Promise.resolve(
        Response.json({ id: "11111111-1111-4111-8111-111111111111" }),
      );
    }
    if (path.endsWith("/consume_backend_rate_limit")) {
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/reserve_ai_usage")) {
      return Promise.resolve(
        Response.json({ allowed: true, duplicate: false, balance: 84 }),
      );
    }
    if (path.endsWith("/reserve_ai_repair_budget")) {
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/settle_ai_usage")) {
      const body = JSON.parse(String(init?.body));
      if (
        body.p_succeeded !== false || body.p_input_tokens !== null ||
        body.p_output_tokens !== null ||
        body.p_failure_code !== "inconsistent_provider_output"
      ) throw new Error("unknown repair usage did not retain its reservation");
      settlements++;
      return Promise.resolve(Response.json({ state: "refunded" }));
    }
    if (path === "https://api.anthropic.com/v1/messages") {
      providerCalls++;
      if (providerCalls === 2) {
        return Promise.resolve(
          new Response("{", {
            status: 200,
            headers: { "Content-Type": "application/json" },
          }),
        );
      }
      return Promise.resolve(Response.json({
        id: "provider-first-before-unknown-repair",
        model: "claude-sonnet-4-6",
        stop_reason: "end_turn",
        content: [{
          type: "text",
          text:
            "Groceries first, then release evidence. Neither grocery task is actionable right now.",
        }],
        usage: { input_tokens: 10, output_tokens: 10 },
      }));
    }
    throw new Error(`unexpected transport target: ${path}`);
  }) as typeof fetch;
  try {
    const input = {
      requestId: "synthetic-unknown-repair-usage",
      prompt: "Should I buy groceries or review release evidence first?",
      personality: "planner",
      context: {},
      allowExternalAi: true,
    };
    const request = (extra: Record<string, unknown>) =>
      new Request("https://local.example/ai-proxy", {
        method: "POST",
        headers: { authorization: "Bearer synthetic-session" },
        body: JSON.stringify({ ...input, ...extra }),
      });
    const quoted = await handler(request({ quoteOnly: true }));
    const { quote } = await quoted.json();
    const response = await handler(request({ quote }));
    const body = await response.json();
    if (
      response.status !== 502 ||
      body.error !== "inconsistent_upstream_response" ||
      providerCalls !== 2 || settlements !== 1
    ) throw new Error("unknown repair usage was not refunded once");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

for (
  const budgetFailure of [
    "denied",
    "unavailable",
    "network",
    "timeout",
  ] as const
) {
  Deno.test(`repair call stops and returns a terminal refund when budget is ${budgetFailure}`, async () => {
    if (!handler) throw new Error("handler was not registered");
    const originalFetch = globalThis.fetch;
    let providerCalls = 0;
    let repairBudgetCalls = 0;
    let settlements = 0;
    const failureCode = budgetFailure === "denied"
      ? "provider_cost_budget_exceeded"
      : "repair_budget_check_failed";
    globalThis.fetch = ((url, init) => {
      const path = String(url);
      if (path.endsWith("/auth/v1/user")) {
        return Promise.resolve(
          Response.json({ id: "11111111-1111-4111-8111-111111111111" }),
        );
      }
      if (path.endsWith("/consume_backend_rate_limit")) {
        return Promise.resolve(Response.json({ allowed: true }));
      }
      if (path.endsWith("/reserve_ai_usage")) {
        return Promise.resolve(
          Response.json({ allowed: true, duplicate: false, balance: 84 }),
        );
      }
      if (path.endsWith("/reserve_ai_repair_budget")) {
        repairBudgetCalls++;
        if (budgetFailure === "timeout") {
          if (!init?.signal) {
            throw new Error("repair budget timeout is missing");
          }
          return Promise.reject(
            new DOMException("synthetic repair budget timeout", "TimeoutError"),
          );
        }
        return budgetFailure === "denied"
          ? Promise.resolve(Response.json({
            allowed: false,
            reason: failureCode,
          }))
          : budgetFailure === "unavailable"
          ? Promise.resolve(new Response(null, { status: 503 }))
          : Promise.reject(new TypeError("synthetic lost repair response"));
      }
      if (path.endsWith("/settle_ai_usage")) {
        const body = JSON.parse(String(init?.body));
        if (
          body.p_succeeded !== false || body.p_input_tokens !== 10 ||
          body.p_output_tokens !== 10 || body.p_failure_code !== failureCode
        ) throw new Error("repair budget failure lost first-call accounting");
        settlements++;
        return Promise.resolve(Response.json({ state: "refunded" }));
      }
      if (path === "https://api.anthropic.com/v1/messages") {
        providerCalls++;
        return Promise.resolve(Response.json({
          id: "provider-first-only",
          model: "claude-sonnet-4-6",
          stop_reason: "end_turn",
          content: [{
            type: "text",
            text:
              "Groceries first, then release evidence. Neither grocery task is actionable right now.",
          }],
          usage: { input_tokens: 10, output_tokens: 10 },
        }));
      }
      throw new Error(`unexpected transport target: ${path}`);
    }) as typeof fetch;
    try {
      const input = {
        requestId: `synthetic-repair-budget-${budgetFailure}`,
        prompt: "Should I buy groceries or review release evidence first?",
        personality: "planner",
        context: {},
        allowExternalAi: true,
      };
      const request = (extra: Record<string, unknown>) =>
        new Request("https://local.example/ai-proxy", {
          method: "POST",
          headers: { authorization: "Bearer synthetic-session" },
          body: JSON.stringify({ ...input, ...extra }),
        });
      const quoted = await handler(request({ quoteOnly: true }));
      const { quote } = await quoted.json();
      const response = await handler(request({ quote }));
      const body = await response.json();
      if (
        response.status !== 409 || body.error !== "request_refunded" ||
        providerCalls !== 1 || repairBudgetCalls !== 1 || settlements !== 1
      ) throw new Error("repair budget failure did not terminate its quote");
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
}

Deno.test("expired repair flow settles only first provider usage", async () => {
  if (!handler) throw new Error("handler was not registered");
  const originalFetch = globalThis.fetch;
  const originalDateNow = Date.now;
  let flowExpired = false;
  let providerCalls = 0;
  let settlements = 0;
  Date.now = () => flowExpired ? 21_000 : 0;
  globalThis.fetch = ((url, init) => {
    const path = String(url);
    if (path.endsWith("/auth/v1/user")) {
      return Promise.resolve(
        Response.json({ id: "11111111-1111-4111-8111-111111111111" }),
      );
    }
    if (path.endsWith("/consume_backend_rate_limit")) {
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/reserve_ai_usage")) {
      return Promise.resolve(
        Response.json({ allowed: true, duplicate: false, balance: 84 }),
      );
    }
    if (path.endsWith("/reserve_ai_repair_budget")) {
      flowExpired = true;
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/settle_ai_usage")) {
      const body = JSON.parse(String(init?.body));
      if (
        body.p_succeeded !== false || body.p_input_tokens !== 10 ||
        body.p_output_tokens !== 10 ||
        body.p_failure_code !== "inconsistent_provider_output"
      ) throw new Error("pre-fetch expiry lost first-call accounting");
      settlements++;
      return Promise.resolve(Response.json({ state: "refunded" }));
    }
    if (path === "https://api.anthropic.com/v1/messages") {
      providerCalls++;
      if (providerCalls > 1) {
        throw new Error("repair provider call started after flow expiry");
      }
      return Promise.resolve(Response.json({
        id: "provider-first-before-flow-expiry",
        model: "claude-sonnet-4-6",
        stop_reason: "end_turn",
        content: [{
          type: "text",
          text:
            "Groceries first, then release evidence. Neither grocery task is actionable right now.",
        }],
        usage: { input_tokens: 10, output_tokens: 10 },
      }));
    }
    throw new Error(`unexpected transport target: ${path}`);
  }) as typeof fetch;
  try {
    const input = {
      requestId: "synthetic-expired-before-repair-provider",
      prompt: "Should I buy groceries or review release evidence first?",
      personality: "planner",
      context: {},
      allowExternalAi: true,
    };
    const request = (extra: Record<string, unknown>) =>
      new Request("https://local.example/ai-proxy", {
        method: "POST",
        headers: { authorization: "Bearer synthetic-session" },
        body: JSON.stringify({ ...input, ...extra }),
      });
    const quoted = await handler(request({ quoteOnly: true }));
    const { quote } = await quoted.json();
    const response = await handler(request({ quote }));
    const body = await response.json();
    if (
      response.status !== 502 ||
      body.error !== "inconsistent_upstream_response" ||
      providerCalls !== 1 || settlements !== 1
    ) throw new Error("pre-fetch expiry was not refunded exactly once");
  } finally {
    globalThis.fetch = originalFetch;
    Date.now = originalDateNow;
  }
});

Deno.test("failure settlement outage preserves deterministic client error", async () => {
  if (!handler) throw new Error("handler was not registered");
  const originalFetch = globalThis.fetch;
  let settlementCalls = 0;
  globalThis.fetch = ((url) => {
    const path = String(url);
    if (path.endsWith("/auth/v1/user")) {
      return Promise.resolve(
        Response.json({ id: "11111111-1111-4111-8111-111111111111" }),
      );
    }
    if (path.endsWith("/consume_backend_rate_limit")) {
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/reserve_ai_usage")) {
      return Promise.resolve(
        Response.json({ allowed: true, duplicate: false, balance: 84 }),
      );
    }
    if (path.endsWith("/settle_ai_usage")) {
      settlementCalls++;
      return Promise.resolve(new Response(null, { status: 503 }));
    }
    if (path === "https://api.anthropic.com/v1/messages") {
      return Promise.reject(new TypeError("synthetic provider outage"));
    }
    throw new Error(`unexpected transport target: ${path}`);
  }) as typeof fetch;
  try {
    const input = {
      requestId: "synthetic-failure-settlement-outage",
      prompt: "Review my visible plan.",
      personality: "planner",
      context: {},
      allowExternalAi: true,
    };
    const request = (extra: Record<string, unknown>) =>
      new Request("https://local.example/ai-proxy", {
        method: "POST",
        headers: { authorization: "Bearer synthetic-session" },
        body: JSON.stringify({ ...input, ...extra }),
      });
    const quoted = await handler(request({ quoteOnly: true }));
    const { quote } = await quoted.json();
    const response = await handler(request({ quote }));
    const body = await response.json();
    if (
      response.status !== 500 || body.error !== "request_failed" ||
      settlementCalls !== 1
    ) {
      throw new Error(
        "settlement outage replaced deterministic client failure",
      );
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});

for (const settlementFailure of ["timeout", "network"] as const) {
  Deno.test(`${settlementFailure} success settlement failure is reconciled before reply`, async () => {
    if (!handler) throw new Error("handler was not registered");
    const originalFetch = globalThis.fetch;
    let settlementCalls = 0;
    globalThis.fetch = ((url, init) => {
      const path = String(url);
      if (path.endsWith("/auth/v1/user")) {
        return Promise.resolve(
          Response.json({ id: "11111111-1111-4111-8111-111111111111" }),
        );
      }
      if (path.endsWith("/consume_backend_rate_limit")) {
        return Promise.resolve(Response.json({ allowed: true }));
      }
      if (path.endsWith("/reserve_ai_usage")) {
        return Promise.resolve(
          Response.json({ allowed: true, duplicate: false, balance: 84 }),
        );
      }
      if (path.endsWith("/settle_ai_usage")) {
        const body = JSON.parse(String(init?.body));
        if (body.p_succeeded !== true) {
          throw new Error("uncertain success was incorrectly refunded");
        }
        settlementCalls++;
        if (!init?.signal) {
          throw new Error("success settlement attempt is missing its deadline");
        }
        if (settlementCalls === 1) {
          return Promise.reject(
            settlementFailure === "timeout"
              ? new DOMException("synthetic settlement timeout", "TimeoutError")
              : new TypeError("synthetic settlement connection reset"),
          );
        }
        return Promise.resolve(Response.json({ state: "completed" }));
      }
      if (path === "https://api.anthropic.com/v1/messages") {
        return Promise.resolve(Response.json({
          id: "provider-settlement-reconcile",
          model: "claude-sonnet-4-6",
          stop_reason: "end_turn",
          content: [{ type: "text", text: "Review the visible plan." }],
          usage: { input_tokens: 10, output_tokens: 5 },
        }));
      }
      throw new Error(`unexpected transport target: ${path}`);
    }) as typeof fetch;
    try {
      const input = {
        requestId: "synthetic-settlement-reconcile",
        prompt: "Review my visible plan.",
        personality: "planner",
        context: {},
        allowExternalAi: true,
      };
      const request = (extra: Record<string, unknown>) =>
        new Request("https://local.example/ai-proxy", {
          method: "POST",
          headers: { authorization: "Bearer synthetic-session" },
          body: JSON.stringify({ ...input, ...extra }),
        });
      const quoted = await handler(request({ quoteOnly: true }));
      const { quote } = await quoted.json();
      const response = await handler(request({ quote }));
      const body = await response.json();
      if (
        response.status !== 200 ||
        body.message !== "Review the visible plan." ||
        settlementCalls !== 2
      ) {
        throw new Error(
          `${settlementFailure} settlement was not reconciled exactly once`,
        );
      }
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
}

Deno.test("a lost reconciliation response is retried to an authoritative settlement", async () => {
  if (!handler) throw new Error("handler was not registered");
  const originalFetch = globalThis.fetch;
  let settlementCalls = 0;
  let refunds = 0;
  globalThis.fetch = ((url, init) => {
    const path = String(url);
    if (path.endsWith("/auth/v1/user")) {
      return Promise.resolve(
        Response.json({ id: "11111111-1111-4111-8111-111111111111" }),
      );
    }
    if (path.endsWith("/consume_backend_rate_limit")) {
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/reserve_ai_usage")) {
      return Promise.resolve(
        Response.json({ allowed: true, duplicate: false, balance: 83 }),
      );
    }
    if (path.endsWith("/settle_ai_usage")) {
      const body = JSON.parse(String(init?.body));
      settlementCalls++;
      if (body.p_succeeded !== true) {
        refunds++;
        return Promise.resolve(Response.json({ state: "refunded" }));
      }
      if (settlementCalls === 1) {
        return Promise.reject(
          new TypeError("synthetic lost settlement response"),
        );
      }
      if (settlementCalls === 2) {
        return Promise.resolve(
          Response.json({ error: "synthetic proxy failure" }, { status: 503 }),
        );
      }
      return Promise.resolve(Response.json({ state: "completed" }));
    }
    if (path === "https://api.anthropic.com/v1/messages") {
      return Promise.resolve(Response.json({
        id: "provider-double-settlement-reconcile",
        model: "claude-sonnet-4-6",
        stop_reason: "end_turn",
        content: [{ type: "text", text: "Review the visible plan." }],
        usage: { input_tokens: 10, output_tokens: 5 },
      }));
    }
    throw new Error(`unexpected transport target: ${path}`);
  }) as typeof fetch;
  try {
    const input = {
      requestId: "synthetic-double-settlement-reconcile",
      prompt: "Review my visible plan.",
      personality: "planner",
      context: {},
      allowExternalAi: true,
    };
    const request = (extra: Record<string, unknown>) =>
      new Request("https://local.example/ai-proxy", {
        method: "POST",
        headers: { authorization: "Bearer synthetic-session" },
        body: JSON.stringify({ ...input, ...extra }),
      });
    const quoted = await handler(request({ quoteOnly: true }));
    const { quote } = await quoted.json();
    const response = await handler(request({ quote }));
    const body = await response.json();
    if (
      response.status !== 200 ||
      body.message !== "Review the visible plan." ||
      settlementCalls !== 3 || refunds !== 0
    ) {
      throw new Error("lost reconciliation response was not recovered");
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("an ambiguous settlement survives a later deterministic reconciliation failure", async () => {
  if (!handler) throw new Error("handler was not registered");
  const originalFetch = globalThis.fetch;
  let settlementCalls = 0;
  let refunds = 0;
  let authorityReads = 0;
  globalThis.fetch = ((url, init) => {
    const path = String(url);
    if (path.endsWith("/auth/v1/user")) {
      return Promise.resolve(
        Response.json({ id: "11111111-1111-4111-8111-111111111111" }),
      );
    }
    if (path.endsWith("/consume_backend_rate_limit")) {
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/reserve_ai_usage")) {
      return Promise.resolve(
        Response.json({ allowed: true, duplicate: false, balance: 82 }),
      );
    }
    if (path.endsWith("/settle_ai_usage")) {
      const body = JSON.parse(String(init?.body));
      settlementCalls++;
      if (body.p_succeeded !== true) {
        refunds++;
        return Promise.resolve(Response.json({ state: "refunded" }));
      }
      if (settlementCalls === 1) {
        return Promise.reject(
          new TypeError("synthetic lost initial settlement response"),
        );
      }
      return Promise.resolve(
        Response.json(
          { error: "synthetic deterministic reconciliation failure" },
          { status: 400 },
        ),
      );
    }
    if (path.includes("/rest/v1/ai_usage_requests?")) {
      authorityReads++;
      return Promise.resolve(Response.json([{ state: "completed" }]));
    }
    if (path === "https://api.anthropic.com/v1/messages") {
      return Promise.resolve(Response.json({
        id: "provider-ambiguous-then-deterministic",
        model: "claude-sonnet-4-6",
        stop_reason: "end_turn",
        content: [{ type: "text", text: "Review the visible plan." }],
        usage: { input_tokens: 10, output_tokens: 5 },
      }));
    }
    throw new Error(`unexpected transport target: ${path}`);
  }) as typeof fetch;
  try {
    const input = {
      requestId: "synthetic-ambiguous-then-deterministic",
      prompt: "Review my visible plan.",
      personality: "planner",
      context: {},
      allowExternalAi: true,
    };
    const request = (extra: Record<string, unknown>) =>
      new Request("https://local.example/ai-proxy", {
        method: "POST",
        headers: { authorization: "Bearer synthetic-session" },
        body: JSON.stringify({ ...input, ...extra }),
      });
    const quoted = await handler(request({ quoteOnly: true }));
    const { quote } = await quoted.json();
    const response = await handler(request({ quote }));
    const body = await response.json();
    if (
      response.status !== 200 ||
      body.message !== "Review the visible plan." || settlementCalls !== 2 ||
      authorityReads !== 1 || refunds !== 0
    ) {
      throw new Error(
        "later deterministic failure erased settlement ambiguity",
      );
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("an exhausted ambiguous settlement still delivers the paid reply", async () => {
  if (!handler) throw new Error("handler was not registered");
  const originalFetch = globalThis.fetch;
  let settlementCalls = 0;
  let refunds = 0;
  globalThis.fetch = ((url, init) => {
    const path = String(url);
    if (path.endsWith("/auth/v1/user")) {
      return Promise.resolve(
        Response.json({ id: "11111111-1111-4111-8111-111111111111" }),
      );
    }
    if (path.endsWith("/consume_backend_rate_limit")) {
      return Promise.resolve(Response.json({ allowed: true }));
    }
    if (path.endsWith("/reserve_ai_usage")) {
      return Promise.resolve(
        Response.json({ allowed: true, duplicate: false, balance: 82 }),
      );
    }
    if (path.endsWith("/settle_ai_usage")) {
      const body = JSON.parse(String(init?.body));
      settlementCalls++;
      if (body.p_succeeded !== true) refunds++;
      return Promise.reject(
        new TypeError("synthetic persistent settlement response loss"),
      );
    }
    if (path.includes("/rest/v1/ai_usage_requests?")) {
      return Promise.resolve(Response.json([{ state: "reserved" }]));
    }
    if (path === "https://api.anthropic.com/v1/messages") {
      return Promise.resolve(Response.json({
        id: "provider-ambiguous-settlement-delivery",
        model: "claude-sonnet-4-6",
        stop_reason: "end_turn",
        content: [{ type: "text", text: "Review the visible plan." }],
        usage: { input_tokens: 10, output_tokens: 5 },
      }));
    }
    throw new Error(`unexpected transport target: ${path}`);
  }) as typeof fetch;
  try {
    const input = {
      requestId: "synthetic-ambiguous-settlement-delivery",
      prompt: "Review my visible plan.",
      personality: "planner",
      context: {},
      allowExternalAi: true,
    };
    const request = (extra: Record<string, unknown>) =>
      new Request("https://local.example/ai-proxy", {
        method: "POST",
        headers: { authorization: "Bearer synthetic-session" },
        body: JSON.stringify({ ...input, ...extra }),
      });
    const quoted = await handler(request({ quoteOnly: true }));
    const { quote } = await quoted.json();
    const response = await handler(request({ quote }));
    const body = await response.json();
    if (
      response.status !== 200 ||
      body.message !== "Review the visible plan." ||
      settlementCalls !== 3 || refunds !== 0
    ) {
      throw new Error("ambiguous settlement hid or refunded the paid reply");
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});

for (const deterministicStatus of [400, 401, 404] as const) {
  Deno.test(`deterministic settlement HTTP ${deterministicStatus} preserves the generated reply`, async () => {
    if (!handler) throw new Error("handler was not registered");
    const originalFetch = globalThis.fetch;
    let successSettlements = 0;
    let refunds = 0;
    let authorityReads = 0;
    globalThis.fetch = ((url, init) => {
      const path = String(url);
      if (path.endsWith("/auth/v1/user")) {
        return Promise.resolve(
          Response.json({ id: "11111111-1111-4111-8111-111111111111" }),
        );
      }
      if (path.endsWith("/consume_backend_rate_limit")) {
        return Promise.resolve(Response.json({ allowed: true }));
      }
      if (path.endsWith("/reserve_ai_usage")) {
        return Promise.resolve(
          Response.json({ allowed: true, duplicate: false, balance: 81 }),
        );
      }
      if (path.endsWith("/settle_ai_usage")) {
        const body = JSON.parse(String(init?.body));
        if (body.p_succeeded === true) {
          successSettlements++;
          return Promise.resolve(
            Response.json(
              { error: "synthetic deterministic settlement failure" },
              { status: deterministicStatus },
            ),
          );
        }
        refunds++;
        return Promise.resolve(Response.json({ state: "refunded" }));
      }
      if (path.includes("/rest/v1/ai_usage_requests?")) {
        authorityReads++;
        return Promise.resolve(Response.json([{ state: "reserved" }]));
      }
      if (path === "https://api.anthropic.com/v1/messages") {
        return Promise.resolve(Response.json({
          id: `provider-deterministic-settlement-${deterministicStatus}`,
          model: "claude-sonnet-4-6",
          stop_reason: "end_turn",
          content: [{ type: "text", text: "Review the visible plan." }],
          usage: { input_tokens: 10, output_tokens: 5 },
        }));
      }
      throw new Error(`unexpected transport target: ${path}`);
    }) as typeof fetch;
    try {
      const input = {
        requestId: `synthetic-deterministic-settlement-${deterministicStatus}`,
        prompt: "Review my visible plan.",
        personality: "planner",
        context: {},
        allowExternalAi: true,
      };
      const request = (extra: Record<string, unknown>) =>
        new Request("https://local.example/ai-proxy", {
          method: "POST",
          headers: { authorization: "Bearer synthetic-session" },
          body: JSON.stringify({ ...input, ...extra }),
        });
      const quoted = await handler(request({ quoteOnly: true }));
      const { quote } = await quoted.json();
      const response = await handler(request({ quote }));
      const body = await response.json();
      if (
        response.status !== 200 ||
        body.message !== "Review the visible plan." ||
        successSettlements !== 1 || refunds !== 0 || authorityReads !== 1
      ) {
        throw new Error(
          `deterministic settlement HTTP ${deterministicStatus} hid the generated reply`,
        );
      }
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
}

for (
  const failure of [
    401,
    429,
    500,
    503,
    "network",
    "timeout",
    "json",
    "empty",
    "truncated",
  ] as const
) {
  Deno.test(`AI handler refunds once after provider ${failure} and refuses duplicate debit`, async () => {
    if (!handler) throw new Error("handler was not registered");
    const originalFetch = globalThis.fetch;
    let balance = 20;
    let state = "new";
    let debits = 0;
    let refunds = 0;
    let providerCalls = 0;
    let charged = 0;
    const json = (value: unknown) => Response.json(value);
    globalThis.fetch = ((url, init) => {
      const path = String(url);
      if (path.endsWith("/auth/v1/user")) {
        return Promise.resolve(
          json({ id: "11111111-1111-4111-8111-111111111111" }),
        );
      }
      if (path.endsWith("/consume_backend_rate_limit")) {
        return Promise.resolve(json({ allowed: true }));
      }
      if (path.endsWith("/reserve_ai_usage")) {
        if (state !== "new") {
          return Promise.resolve(json({ duplicate: true, state, balance }));
        }
        charged = JSON.parse(String(init?.body)).p_credit_amount;
        balance -= charged;
        debits++;
        state = "reserved";
        return Promise.resolve(json({ allowed: true, balance }));
      }
      if (path.endsWith("/settle_ai_usage")) {
        const body = JSON.parse(String(init?.body));
        if (body.p_succeeded !== false || state !== "reserved") {
          throw new Error("failure settled as success or out of sequence");
        }
        state = "refunded";
        balance += charged;
        refunds++;
        return Promise.resolve(json({ state, balance }));
      }
      if (path === "https://api.anthropic.com/v1/messages") {
        if (state !== "reserved" || balance !== 20 - charged) {
          throw new Error("upstream invoked before reservation");
        }
        providerCalls++;
        if (failure === "network") {
          return Promise.reject(new TypeError("synthetic network failure"));
        }
        if (failure === "timeout") {
          const signal = init?.signal;
          if (!signal) throw new Error("upstream timeout is missing");
          return new Promise<Response>((_resolve, reject) => {
            signal.addEventListener("abort", () => reject(signal.reason), {
              once: true,
            });
          });
        }
        if (failure === "json") {
          return Promise.resolve(new Response("invalid JSON"));
        }
        if (failure === "empty") {
          return Promise.resolve(json({ content: [] }));
        }
        if (failure === "truncated") {
          return Promise.resolve(
            json({
              stop_reason: "max_tokens",
              content: [{ text: "An unfinished recommendation" }],
            }),
          );
        }
        return Promise.resolve(
          new Response("do-not-expose-provider-body", { status: failure }),
        );
      }
      throw new Error("unexpected transport target");
    }) as typeof fetch;
    try {
      const input = {
        requestId: `synthetic-provider-${failure}`,
        prompt: "Arrange a fictional tool shelf.",
        personality: "planner",
        context: {},
        allowExternalAi: true,
      };
      const request = (extra: Record<string, unknown>) =>
        new Request("https://local.example/ai-proxy", {
          method: "POST",
          headers: { authorization: "Bearer synthetic-session" },
          body: JSON.stringify({ ...input, ...extra }),
        });
      const quoted = await handler(request({ quoteOnly: true }));
      const { quote } = await quoted.json();
      if (quoted.status !== 200 || debits || providerCalls || balance !== 20) {
        throw new Error("quote spent credits or called provider");
      }
      const response = await handler(request({ quote }));
      const body = await response.text();
      if (response.status < 500 || body.includes("do-not-expose")) {
        throw new Error(
          `provider failure not safely reported: ${response.status} ${body}`,
        );
      }
      const duplicate = await handler(request({ quote }));
      await duplicate.body?.cancel();
      if (
        duplicate.status !== 409 || balance !== 20 || debits !== 1 ||
        refunds !== 1 || providerCalls !== 1
      ) throw new Error("failure/retry did not preserve exactly one refund");
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
}

Deno.test("AI handler rejects noncohort and anonymous accounts before quote, debit or provider", async () => {
  if (!handler) throw new Error("handler was not registered");
  const originalFetch = globalThis.fetch;
  try {
    for (
      const user of [
        {
          id: "22222222-2222-4222-8222-222222222222",
          user_metadata: { chronospark_admin: true, internal_ai: true },
        },
        { id: "11111111-1111-4111-8111-111111111111", is_anonymous: true },
      ]
    ) {
      let authCalls = 0;
      globalThis.fetch = ((url) => {
        if (!String(url).endsWith("/auth/v1/user")) {
          throw new Error(
            "unauthorized account reached quote, rate-limit, reservation or provider transport",
          );
        }
        authCalls++;
        return Promise.resolve(Response.json(user));
      }) as typeof fetch;
      for (const quoteOnly of [true, false]) {
        const response = await handler(
          new Request("https://local.example/ai-proxy", {
            method: "POST",
            headers: { authorization: "Bearer synthetic-session" },
            body: JSON.stringify({
              quoteOnly,
              requestId: "synthetic-cohort-test",
              prompt: "Plan a task.",
              allowExternalAi: true,
              quote: {},
              userId: "11111111-1111-4111-8111-111111111111",
              internalAccountDigests:
                "6c360d206728b8cc03034e9f3e803a817fcba5fcfa20c218c7a94744d1a76313",
            }),
          }),
        );
        const expected = user.is_anonymous === true ? 401 : 403;
        if (
          response.status !== expected ||
          (await response.json()).quote !== undefined
        ) {
          throw new Error("client-controlled cohort hints authorized AI use");
        }
      }
      if (authCalls !== 2) {
        throw new Error("each request must refresh trusted Auth identity");
      }
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});
