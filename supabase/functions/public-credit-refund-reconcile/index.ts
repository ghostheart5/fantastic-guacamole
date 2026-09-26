/// <reference lib="deno.ns" />
import {
  getGoogleAccessToken,
  type GoogleServiceAccount,
} from "../_shared/google_auth.ts";
import {
  createRefundReconcileHandler,
  refundBackendServiceKey,
} from "../_shared/public_credit_refund_handler.ts";
import { reconcilePublicCreditRefunds } from "../_shared/public_credit_refund_worker.ts";

function readServiceAccount(): GoogleServiceAccount | null {
  try {
    const value = JSON.parse(
      Deno.env.get("GOOGLE_REFUND_SERVICE_ACCOUNT_JSON") ?? "null",
    );
    return value && typeof value === "object"
      ? value as GoogleServiceAccount
      : null;
  } catch {
    return null;
  }
}

Deno.serve(createRefundReconcileHandler({
  secret: Deno.env.get("PUBLIC_CREDIT_REFUND_RECONCILE_SECRET") ?? "",
  enabled: Deno.env.get("PUBLIC_CREDIT_AUTO_REFUND_ENABLED") === "true",
  supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
  secretKey: refundBackendServiceKey((name) => Deno.env.get(name)),
  serviceAccount: readServiceAccount(),
  testOnly: Deno.env.get("PUBLIC_CREDIT_REFUND_TEST_ONLY") === "true",
  testTokenHash: Deno.env.get("PUBLIC_CREDIT_REFUND_TEST_TOKEN_HASH"),
}, {
  getAccessToken: getGoogleAccessToken,
  reconcile: reconcilePublicCreditRefunds,
}));
