import { type BillingBackendConfig } from "./billing_backend.ts";
import { type GoogleServiceAccount } from "./google_auth.ts";
import { type CreditRefundReconcileCounts } from "./public_credit_refund_worker.ts";

const PROJECT_URL = "https://qpwhuckyirnqtmvhpede.supabase.co";
const PACKAGE_NAME = "com.ghostheart5.chronospark";

export function refundBackendServiceKey(
  readEnv: (name: string) => string | undefined,
): string {
  return readEnv("SUPABASE_SECRET_KEY") ??
    readEnv("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

export interface RefundHandlerConfig {
  secret: string;
  enabled: boolean;
  supabaseUrl: string;
  secretKey: string;
  serviceAccount: GoogleServiceAccount | null;
}

interface RefundHandlerDependencies {
  getAccessToken: (account: GoogleServiceAccount) => Promise<string>;
  reconcile: (input: {
    config: BillingBackendConfig;
    packageName: string;
    accessToken: string;
  }) => Promise<CreditRefundReconcileCounts | null>;
}

function secureEquals(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const l = encoder.encode(left), r = encoder.encode(right);
  let difference = l.length ^ r.length;
  for (let i = 0; i < Math.max(l.length, r.length); i++) {
    difference |= (l[i] ?? 0) ^ (r[i] ?? 0);
  }
  return difference === 0;
}

function response(body: Record<string, unknown>, status: number): Response {
  return Response.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

export function createRefundReconcileHandler(
  config: RefundHandlerConfig,
  dependencies: RefundHandlerDependencies,
): (req: Request) => Promise<Response> {
  return async (req: Request) => {
    if (req.method !== "POST") {
      return response({ error: "method_not_allowed" }, 405);
    }
    const supplied = req.headers.get("x-axiomara-refund-reconcile-secret") ??
      "";
    if (!config.secret || !supplied || !secureEquals(supplied, config.secret)) {
      return response({ error: "unauthorized" }, 401);
    }
    if (!config.enabled) {
      return response({ error: "refund_reconciliation_disabled" }, 503);
    }
    if (
      config.supabaseUrl !== PROJECT_URL || !config.secretKey ||
      !config.serviceAccount?.client_email ||
      !config.serviceAccount.private_key
    ) return response({ error: "not_configured" }, 503);
    try {
      const result = await dependencies.reconcile({
        config: {
          supabaseUrl: config.supabaseUrl,
          publishableKey: "",
          secretKey: config.secretKey,
        },
        packageName: PACKAGE_NAME,
        accessToken: await dependencies.getAccessToken(
          config.serviceAccount,
        ),
      });
      if (!result) return response({ error: "resolution_query_failed" }, 502);
      return response(
        result as unknown as Record<string, unknown>,
        result.manualReview > 0 || result.retryLater > 0 ? 502 : 200,
      );
    } catch (error) {
      console.error(
        "Credit refund reconciliation failed",
        error instanceof Error ? error.name : "unknown_error",
      );
      return response({ error: "refund_reconciliation_failed" }, 500);
    }
  };
}
