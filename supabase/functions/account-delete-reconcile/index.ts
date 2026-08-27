/// <reference lib="deno.ns" />
import {
  accountDeletionConfigured,
  listReconcileCandidates,
  loadAccountDeletionConfig,
  processDeletionRequest,
} from "../_shared/account_deletion_state_machine.ts";

const config = loadAccountDeletionConfig();
const reconcileSecret = Deno.env.get("ACCOUNT_DELETE_RECONCILE_SECRET") ?? "";

function secureEquals(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  const length = Math.max(leftBytes.length, rightBytes.length);
  let difference = leftBytes.length ^ rightBytes.length;
  for (let index = 0; index < length; index += 1) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return difference === 0;
}

function response(body: Record<string, unknown>, status: number): Response {
  return Response.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      "X-ChronoSpark-Contract": "account-delete-reconcile-v1",
    },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return response({ error: "method_not_allowed" }, 405);
  }
  const suppliedSecret = req.headers.get("x-chronospark-reconcile-secret") ??
    "";
  if (
    !reconcileSecret || !suppliedSecret ||
    !secureEquals(suppliedSecret, reconcileSecret)
  ) {
    return response({ error: "unauthorized" }, 401);
  }
  if (!accountDeletionConfigured(config, false)) {
    return response({ error: "not_configured" }, 503);
  }

  try {
    const candidates = await listReconcileCandidates(config, 5);
    if (candidates === null) {
      return response({ error: "candidate_query_failed" }, 502);
    }
    let completed = 0;
    let deferred = 0;
    for (const requestId of candidates) {
      const result = await processDeletionRequest({
        requestId,
        allowInternal: true,
        config,
      });
      if (result.completed) {
        completed += 1;
      } else {
        deferred += 1;
      }
    }
    return response(
      { scanned: candidates.length, completed, deferred },
      deferred === 0 ? 200 : 502,
    );
  } catch (error) {
    console.error(
      "Account deletion reconciliation failed",
      error instanceof Error ? error.name : "unknown_error",
    );
    return response({ error: "reconciliation_failed" }, 500);
  }
});
