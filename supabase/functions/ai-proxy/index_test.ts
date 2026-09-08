// Exercise the actual served handler, including its reservation/refund order.
// Only transport/configuration are substituted; no network or credentials.
type Handler = (request: Request) => Promise<Response>;
let handler: Handler | undefined;
const originalServe = Deno.serve;
const originalEnvGet = Deno.env.get;
try {
  Reflect.set(Deno.env, "get", (name: string) => {
    if (name === "SUPABASE_URL") return "https://backend.example";
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

for (
  const failure of [401, 429, 500, 503, "network", "json", "empty"] as const
) {
  Deno.test(`AI handler refunds once after provider ${failure} and refuses duplicate debit`, async () => {
    if (!handler) throw new Error("handler was not registered");
    const originalFetch = globalThis.fetch;
    let balance = 20;
    let state = "new";
    let debits = 0;
    let refunds = 0;
    let providerCalls = 0;
    const json = (value: unknown) => Response.json(value);
    globalThis.fetch = ((url, init) => {
      const path = String(url);
      if (path.endsWith("/auth/v1/user")) {
        return Promise.resolve(json({ id: "synthetic-user" }));
      }
      if (path.endsWith("/consume_backend_rate_limit")) {
        return Promise.resolve(json({ allowed: true }));
      }
      if (path.endsWith("/reserve_ai_usage")) {
        if (state !== "new") {
          return Promise.resolve(json({ duplicate: true, state, balance }));
        }
        balance--;
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
        balance++;
        refunds++;
        return Promise.resolve(json({ state, balance }));
      }
      if (path === "https://api.anthropic.com/v1/messages") {
        if (state !== "reserved" || balance !== 19) {
          throw new Error("upstream invoked before reservation");
        }
        providerCalls++;
        if (failure === "network") {
          return Promise.reject(new TypeError("synthetic network failure"));
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
      const request = () =>
        new Request("https://local.example/ai-proxy", {
          method: "POST",
          headers: { authorization: "Bearer synthetic-session" },
          body: JSON.stringify({
            requestId: `synthetic-provider-${failure}`,
            prompt: "Arrange a fictional tool shelf.",
            personality: "planner",
            context: {},
            allowExternalAi: true,
          }),
        });
      const response = await handler(request());
      const body = await response.text();
      if (response.status < 500 || body.includes("do-not-expose")) {
        throw new Error(
          `provider failure not safely reported: ${response.status} ${body}`,
        );
      }
      const duplicate = await handler(request());
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
