import {
  createRefundReconcileHandler,
  refundBackendServiceKey,
} from "./public_credit_refund_handler.ts";

Deno.test("refund worker uses the hosted service role key when no override exists", async () => {
  const hosted: Record<string, string> = {
    SUPABASE_SERVICE_ROLE_KEY: "hosted-service-key",
  };
  let reconciled = false;
  const handler = createRefundReconcileHandler({
    ...exactConfig,
    secretKey: refundBackendServiceKey((name) => hosted[name]),
  }, {
    getAccessToken: () => Promise.resolve("test-token"),
    reconcile: (input) => {
      if (input.config.secretKey !== hosted.SUPABASE_SERVICE_ROLE_KEY) {
        throw new Error(
          "hosted credential was not passed to the database client",
        );
      }
      reconciled = true;
      return Promise.resolve({
        scanned: 0,
        refunded: 0,
        requested: 0,
        pending: 0,
        manualReview: 0,
        retryLater: 0,
      });
    },
  });
  const response = await handler(req("POST", exactConfig.secret));
  await response.body?.cancel();
  if (response.status !== 200 || !reconciled) {
    throw new Error("hosted configuration remained unconfigured");
  }
});

Deno.test("refund credential override is preserved and missing keys fail closed", () => {
  const keys: Record<string, string> = {
    SUPABASE_SECRET_KEY: "explicit-service-key",
    SUPABASE_SERVICE_ROLE_KEY: "hosted-service-key",
  };
  if (
    refundBackendServiceKey((name) => keys[name]) !== keys.SUPABASE_SECRET_KEY
  ) {
    throw new Error("explicit credential was overridden");
  }
  if (refundBackendServiceKey(() => undefined) !== "") {
    throw new Error("missing credential did not fail closed");
  }
});

const exactConfig = {
  secret: "test-refund-key",
  enabled: true,
  supabaseUrl: "https://qpwhuckyirnqtmvhpede.supabase.co",
  secretKey: "test-service-key",
  serviceAccount: {
    client_email: "test@example.invalid",
    private_key: "test-private-key",
  },
};

const req = (method: string, supplied?: string) =>
  new Request("https://example.invalid/refund", {
    method,
    headers: supplied ? { "x-axiomara-refund-reconcile-secret": supplied } : {},
  });

Deno.test("refund endpoint fails closed before any provider call", async () => {
  let providerCalls = 0;
  const dependencies = {
    getAccessToken: () => {
      providerCalls++;
      return Promise.resolve("test-token");
    },
    reconcile: () => {
      providerCalls++;
      return Promise.resolve(null);
    },
  };
  for (
    const [config, request, status] of [
      [exactConfig, req("GET", exactConfig.secret), 405],
      [exactConfig, req("POST"), 401],
      [exactConfig, req("POST", "wrong-secret"), 401],
      [{ ...exactConfig, secret: "" }, req("POST", exactConfig.secret), 401],
      [
        { ...exactConfig, enabled: false },
        req("POST", exactConfig.secret),
        503,
      ],
      [
        { ...exactConfig, supabaseUrl: "https://other.supabase.co" },
        req("POST", exactConfig.secret),
        503,
      ],
    ] as const
  ) {
    const response = await createRefundReconcileHandler(config, dependencies)(
      request,
    );
    if (response.status !== status || providerCalls !== 0) {
      throw new Error(
        "refund endpoint crossed a disabled or unauthorized gate",
      );
    }
  }
});

Deno.test("authorized endpoint exposes only aggregate result", async () => {
  let providerCalls = 0;
  const handler = createRefundReconcileHandler(exactConfig, {
    getAccessToken: () => {
      providerCalls++;
      return Promise.resolve("test-token");
    },
    reconcile: (input) => {
      providerCalls++;
      if (
        input.packageName !== "com.ghostheart5.chronospark" ||
        input.config.supabaseUrl !== exactConfig.supabaseUrl ||
        input.accessToken !== "test-token"
      ) throw new Error("wrong target");
      return Promise.resolve({
        scanned: 1,
        refunded: 0,
        requested: 1,
        pending: 0,
        manualReview: 0,
        retryLater: 0,
      });
    },
  });
  const response = await handler(req("POST", exactConfig.secret));
  const body = await response.text();
  if (
    response.status !== 200 || providerCalls !== 2 ||
    body.includes(exactConfig.secret) || body.includes(exactConfig.secretKey) ||
    !body.includes('"requested":1')
  ) throw new Error("authorized refund readback was unsafe");
});
