// Exercise the served ai-report handler. Only transport and configuration are
// substituted; no network or credentials.
type Handler = (request: Request) => Promise<Response>;
let handler: Handler | undefined;
const originalServe = Deno.serve;
const originalEnvGet = Deno.env.get;
try {
  Reflect.set(Deno.env, "get", (name: string) => {
    if (name === "SUPABASE_URL") return "https://backend.example";
    if (name === "ALLOWED_ORIGINS") return "";
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

const USER_ID = "11111111-1111-4111-8111-111111111111";

interface Scenario {
  user?: Record<string, unknown> | null;
  limits?: { user: boolean; ip: boolean };
  insertOk?: boolean;
}

async function report(
  body: Record<string, unknown>,
  scenario: Scenario = {},
  headers: Record<string, string> = { authorization: "Bearer synthetic" },
) {
  if (!handler) throw new Error("handler was not registered");
  const originalFetch = globalThis.fetch;
  const inserts: Array<Record<string, unknown>> = [];
  const buckets: string[] = [];
  const windows: number[] = [];
  globalThis.fetch = ((url, init) => {
    const path = String(url);
    if (path.endsWith("/auth/v1/user")) {
      const user = scenario.user === undefined
        ? { id: USER_ID }
        : scenario.user;
      return Promise.resolve(
        user === null
          ? new Response("{}", { status: 401 })
          : Response.json(user),
      );
    }
    if (path.endsWith("/consume_backend_rate_limit")) {
      const call = JSON.parse(String(init?.body));
      buckets.push(call.p_bucket);
      windows.push(call.p_window_seconds);
      const limits = scenario.limits ?? { user: true, ip: true };
      return Promise.resolve(Response.json({
        allowed: String(call.p_bucket).endsWith(":user")
          ? limits.user
          : limits.ip,
      }));
    }
    if (path.endsWith("/rest/v1/ai_content_reports")) {
      inserts.push(JSON.parse(String(init?.body)));
      return Promise.resolve(
        new Response(null, { status: scenario.insertOk === false ? 500 : 201 }),
      );
    }
    throw new Error(`unexpected transport target: ${path}`);
  }) as typeof fetch;
  try {
    const response = await handler(
      new Request("https://local.example/ai-report", {
        method: "POST",
        headers,
        body: JSON.stringify(body),
      }),
    );
    const text = await response.text();
    return { status: response.status, text, inserts, buckets, windows };
  } finally {
    globalThis.fetch = originalFetch;
  }
}

const valid = { reason: "other", content: "A reply that I want reviewed." };

Deno.test("old client without a surface is accepted and recorded as unspecified", async () => {
  const run = await report(valid);
  if (run.status !== 202 || run.inserts.length !== 1) {
    throw new Error(`old client was refused: ${run.status} ${run.text}`);
  }
  if (run.inserts[0].source !== "unspecified") {
    throw new Error(`unexpected source ${run.inserts[0].source}`);
  }
  if (run.inserts[0].user_id !== USER_ID) {
    throw new Error("report is not tied to the authenticated account");
  }
});

Deno.test("the real surface from the new client is recorded", async () => {
  for (const surface of ["chat", "si_console", "planner"]) {
    const run = await report({ ...valid, surface });
    if (run.status !== 202 || run.inserts[0]?.source !== surface) {
      throw new Error(`surface ${surface} not recorded: ${run.text}`);
    }
  }
});

Deno.test("a malformed surface is recorded as unspecified, not stored", async () => {
  for (
    const surface of [
      "anything_goes",
      "Chat Screen",
      "x".repeat(40),
      7,
      { a: 1 },
      "",
      "../x",
    ]
  ) {
    const run = await report({ ...valid, surface });
    if (run.status !== 202 || run.inserts[0]?.source !== "unspecified") {
      throw new Error(`bad surface was stored: ${JSON.stringify(surface)}`);
    }
  }
});

Deno.test("a missing or invalid session is refused before anything is stored", async () => {
  const noHeader = await report(valid, {}, {});
  const badToken = await report(valid, { user: null });
  for (const run of [noHeader, badToken]) {
    if (run.status !== 401 || run.inserts.length || run.buckets.length) {
      throw new Error(`unauthenticated report not refused: ${run.status}`);
    }
  }
});

Deno.test("an anonymous session is refused before the limiter or storage", async () => {
  const run = await report(valid, {
    user: { id: USER_ID, is_anonymous: true },
  });
  if (run.status !== 401 || run.inserts.length || run.buckets.length) {
    throw new Error(`anonymous report accepted: ${run.status} ${run.text}`);
  }
});

Deno.test("the durable limiter is consulted per account and per address, hourly", async () => {
  const run = await report(valid);
  if (
    run.buckets.join() !== "ai_report:user,ai_report:ip" ||
    run.windows.some((seconds) => seconds !== 3600)
  ) throw new Error(`unexpected limiter use: ${run.buckets} ${run.windows}`);
});

Deno.test("an account over its limit is refused with 429 and nothing is stored", async () => {
  const run = await report(valid, { limits: { user: false, ip: true } });
  if (run.status !== 429 || run.inserts.length) {
    throw new Error(`user limit not enforced: ${run.status}`);
  }
});

Deno.test("an address over its limit is refused with 429 and nothing is stored", async () => {
  const run = await report(valid, { limits: { user: true, ip: false } });
  if (run.status !== 429 || run.inserts.length) {
    throw new Error(`address limit not enforced: ${run.status}`);
  }
});

Deno.test("invalid reports are rejected without being stored", async () => {
  for (
    const body of [
      { reason: "nonsense", content: "x" },
      { reason: "other", content: "   " },
      { reason: "other", content: "x".repeat(4001) },
      { content: "x" },
    ]
  ) {
    const run = await report(body);
    if (run.status !== 400 || run.inserts.length) {
      throw new Error(`invalid report accepted: ${JSON.stringify(body)}`);
    }
  }
});

Deno.test("a failed insert is reported as 502", async () => {
  const run = await report(valid, { insertOk: false });
  if (run.status !== 502) throw new Error(`unexpected status ${run.status}`);
});

Deno.test("only the allowed methods are served", async () => {
  if (!handler) throw new Error("handler was not registered");
  const options = await handler(
    new Request("https://local.example/ai-report", { method: "OPTIONS" }),
  );
  await options.body?.cancel();
  const get = await handler(new Request("https://local.example/ai-report"));
  await get.body?.cancel();
  if (options.status !== 200 || get.status !== 405) {
    throw new Error("method handling changed");
  }
});
