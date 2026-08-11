/// <reference lib="deno.ns" />
import {
  accountDeletionConfigured,
  listReconcileCandidates,
  processDeletionRequest,
} from "../_shared/account_deletion_state_machine.ts";

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
    const candidates = await listReconcileCandidates(20);
    let completed = 0;
    for (const input of candidates) {
      const result = await processDeletionRequest({
        input,
        allowInternal: true,
      });
      if (result.completed === true) completed += 1;
    }
    return Response.json({ scanned: candidates.length, completed });
  } catch {
    console.error("Account deletion reconciliation failed");
    return new Response("Reconciliation failed", { status: 500 });
  }
});
