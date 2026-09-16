// Actual served handler; only platform registration/config and HTTP transport
// are substituted. No live account, deletion or receipt is used.
type Handler = (request: Request) => Promise<Response>;
let handler: Handler | undefined;
const originalServe = Deno.serve;
const originalEnvGet = Deno.env.get;
try {
  Reflect.set(Deno.env, "get", (name: string) => {
    if (name === "SUPABASE_URL") return "https://backend.example";
    if (name === "ACCOUNT_DELETE_RECENT_SIGN_IN_SECONDS") return "300";
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

const requestId = "a".repeat(64);
const receipt = "b".repeat(64);
const userId = "11111111-1111-4111-8111-111111111111";
const json = (body: unknown) => Response.json(body);
function post(body: unknown, authorization?: string, method = "POST"): Request {
  return new Request("https://local.example/account-delete", {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(authorization ? { authorization } : {}),
    },
    ...(method !== "GET" ? { body: JSON.stringify(body) } : {}),
  });
}
async function call(req: Request): Promise<Response> {
  if (!handler) throw new Error("handler was not registered");
  return await handler(req);
}
function bearer(
  ageSeconds = 10,
  overrides: Record<string, unknown> = {},
): string {
  const now = Math.floor(Date.now() / 1000);
  const claims = {
    sub: userId,
    role: "authenticated",
    is_anonymous: false,
    session_id: "22222222-2222-4222-8222-222222222222",
    iat: now,
    amr: [{ method: "password", timestamp: now - ageSeconds }],
    ...overrides,
  };
  return `Bearer eyJhbGciOiJIUzI1NiJ9.${
    btoa(JSON.stringify(claims)).replace(/=/g, "").replace(/\+/g, "-").replace(
      /\//g,
      "_",
    )
  }.c2lnbmF0dXJl`;
}

Deno.test("signed-out capability reads only its bound unexpired deletion status", async () => {
  const originalFetch = globalThis.fetch;
  try {
    for (const found of [true, false]) {
      let reads = 0;
      globalThis.fetch = (input, init) => {
        if (!String(input).endsWith("/rpc/read_account_deletion_status")) {
          throw new Error(
            "capability lookup attempted authentication, raw table access or mutation",
          );
        }
        reads++;
        const body = JSON.parse(String(init?.body));
        if (
          body.p_request_id !== requestId ||
          !/^[a-f0-9]{64}$/.test(body.p_receipt_hash) ||
          body.p_receipt_hash === receipt
        ) {
          throw new Error(
            "capability must bind request id and hash of receipt",
          );
        }
        return Promise.resolve(
          json(found ? { state: "completed", userId: "must-not-leak" } : null),
        );
      };
      const response = await call(
        post({ action: "status", requestId, receipt }),
      );
      const body = await response.json();
      if (
        response.status !== (found ? 200 : 404) || reads !== 1 ||
        body.userId !== undefined
      ) {
        throw new Error(
          "valid/unknown/expired capability status was not isolated",
        );
      }
      if (found && (body.completed !== true || body.state !== "completed")) {
        throw new Error("completion lost");
      }
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("malformed and partial status capability never falls through to deletion", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = () => {
    throw new Error("invalid capability must not reach transport");
  };
  try {
    for (
      const body of [
        { action: "status", requestId },
        { action: "status", receipt },
        { action: "status", requestId: "", receipt },
        { action: "status", requestId, receipt: "not-a-receipt" },
        { action: "status", requestId, receipt: receipt.toUpperCase() },
        { action: "unsupported", requestId, receipt },
      ]
    ) {
      const response = await call(post(body));
      if (response.status !== 400) {
        throw new Error("invalid input not rejected");
      }
      await response.body?.cancel();
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("receipt cannot authorize deletion, default delete or unsupported method", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = () => {
    throw new Error("missing bearer cannot reach transport");
  };
  try {
    for (
      const body of [{ action: "delete", requestId, receipt }, {}, {
        action: "status",
      }]
    ) {
      const response = await call(post(body));
      if (response.status !== 401) {
        throw new Error("missing bearer authorized action");
      }
      await response.body?.cancel();
    }
    const response = await call(post({}, undefined, "GET"));
    if (response.status !== 405) throw new Error("unsupported method accepted");
    await response.body?.cancel();
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("gateway-independent deletion still validates exact live Auth session and recent sign-in", async () => {
  const originalFetch = globalThis.fetch;
  try {
    for (
      const scenario of [
        { token: bearer(), authStatus: 401, expected: 401 },
        { token: bearer(), authStatus: 403, expected: 401 },
        { token: bearer(), authStatus: 500, expected: 401 },
        { token: bearer(3600), authStatus: 200, expected: 428 },
        {
          token: bearer(10, { is_anonymous: true }),
          authStatus: 200,
          expected: 401,
        },
        {
          token: bearer(10, { role: "service_role" }),
          authStatus: 200,
          expected: 401,
        },
        {
          token: bearer(10, { session_id: null }),
          authStatus: 200,
          expected: 401,
        },
        { token: bearer(), authStatus: 200, expected: 200 },
      ]
    ) {
      let authCalls = 0;
      let claims = 0;
      globalThis.fetch = (input, init) => {
        const path = String(input);
        if (path.endsWith("/auth/v1/user")) {
          authCalls++;
          if (
            new Headers(init?.headers).get("Authorization") !== scenario.token
          ) throw new Error("wrong token validated");
          return Promise.resolve(
            Response.json({ id: userId }, { status: scenario.authStatus }),
          );
        }
        if (
          path.endsWith("/claim_account_deletion_request") &&
          scenario.expected === 200 && authCalls === 1
        ) {
          claims++;
          const body = JSON.parse(String(init?.body));
          if (body.p_user_id !== userId || body.p_allow_internal !== false) {
            throw new Error("deletion identity altered");
          }
          return Promise.resolve(
            json({ claimed: false, completed: true, state: "completed" }),
          );
        }
        throw new Error("unauthorized deletion reached a mutating operation");
      };
      const response = await call(
        post({ action: "delete", requestId, receipt }, scenario.token),
      );
      if (
        response.status !== scenario.expected || authCalls !== 1 ||
        claims !== (scenario.expected === 200 ? 1 : 0)
      ) {
        throw new Error(
          `deletion authorization failed: ${response.status} expected ${scenario.expected}`,
        );
      }
      await response.body?.cancel();
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});
