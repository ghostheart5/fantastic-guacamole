// Exercise the actual served handler, including its reservation/refund order.
// Only transport/configuration are substituted; no network or credentials.
type Handler = (request: Request) => Promise<Response>;
let handler: Handler | undefined;
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
  await import("./index.ts");
} finally {
  Reflect.set(Deno, "serve", originalServe);
  Reflect.set(Deno.env, "get", originalEnvGet);
}

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
