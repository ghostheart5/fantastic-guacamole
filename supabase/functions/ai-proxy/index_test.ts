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

Deno.test("timed-out success settlement is reconciled before reply", async () => {
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
      if (settlementCalls === 1) {
        return Promise.reject(
          new DOMException("synthetic settlement timeout", "TimeoutError"),
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
      response.status !== 200 || body.message !== "Review the visible plan." ||
      settlementCalls !== 2
    ) throw new Error("timed-out settlement was not reconciled exactly once");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

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
