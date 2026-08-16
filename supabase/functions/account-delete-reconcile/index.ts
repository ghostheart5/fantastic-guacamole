/// <reference lib="deno.ns" />
import {
  accountDeletionConfigured,
  listReconcileCandidates,
  processDeletionRequest,
} from "../_shared/account_deletion_state_machine.ts";
import { runBackendMaintenance } from "../_shared/backend_maintenance.ts";
import { logEdgeEvent } from "../_shared/edge_http.ts";

const RECONCILE_SECRET = Deno.env.get("ACCOUNT_DELETE_RECONCILE_SECRET") ?? "";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405,
      headers: { "X-ChronoSpark-Contract": "account-delete-reconcile-v1" },
    });
  }
  const supplied = req.headers.get("x-chronospark-reconcile-secret") ?? "";
  if (!RECONCILE_SECRET || supplied !== RECONCILE_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }
  if (!accountDeletionConfigured()) {
    return new Response("Not configured", { status: 503 });
  }

  try {
    let maintenance: Record<string, unknown> = { completed: false };
    try {
      maintenance = { completed: true, ...await runBackendMaintenance() };
    } catch (error) {
      logEdgeEvent("warn", "backend_maintenance_failed", {
        code: error instanceof Error ? error.message.slice(0, 100) : "unknown",
      });
    }
    const candidates = await listReconcileCandidates(1);
    let completed = 0;
    let advanced = 0;
    for (const input of candidates) {
      const result = await processDeletionRequest({
        input,
        allowInternal: true,
      });
      if (result.completed === true) completed += 1;
      if (result.accepted === true) advanced += 1;
    }
    return Response.json({
      scanned: candidates.length,
      advanced,
      completed,
      maintenance,
    });
  } catch (error) {
    logEdgeEvent("error", "account_deletion_reconciliation_failed", {
      code: error instanceof Error ? error.message.slice(0, 100) : "unknown",
    });
    return new Response("Reconciliation failed", { status: 500 });
  }
});

