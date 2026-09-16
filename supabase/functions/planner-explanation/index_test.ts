// Verify deployed entrypoint wiring, including the read-only cohort preflight.
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

Deno.test("served Planner GET reports trusted cohort without a quote or provider call", async () => {
  if (!handler) throw new Error("handler was not registered");
  const originalFetch = globalThis.fetch;
  globalThis.fetch = () => {
    throw new Error("GET preflight must never call backend/provider");
  };
  try {
    const response = await handler(
      new Request("https://local.example/planner-explanation"),
    );
    if (
      response.status !== 405 ||
      response.headers.get("x-chronospark-contract") !==
        "planner-explanation-v1" ||
      response.headers.get("x-chronospark-internal-ai-guard") !== "v1" ||
      !response.headers.get("x-chronospark-internal-ai-cohort-sha256")
    ) throw new Error("served guard marker missing");
    await response.body?.cancel();
  } finally {
    globalThis.fetch = originalFetch;
  }
});
