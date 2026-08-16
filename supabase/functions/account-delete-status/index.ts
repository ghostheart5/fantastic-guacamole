/// <reference lib="deno.ns" />
import {
  accountDeletionConfigured,
  readDeletionInput,
  readDeletionStatus,
} from "../_shared/account_deletion_state_machine.ts";
import {
  EdgeHttpError,
  logEdgeEvent,
  readBoundedJson,
} from "../_shared/edge_http.ts";

const ALLOWED_ORIGINS = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ??
    "https://chronospark.app,https://www.chronospark.app")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
);

function headers(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  return {
    ...(ALLOWED_ORIGINS.has(origin)
      ? { "Access-Control-Allow-Origin": origin }
      : {}),
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "content-type, x-client-info, apikey",
    "Cache-Control": "no-store",
    "Content-Type": "application/json",
    "Vary": "Origin",
    "X-Content-Type-Options": "nosniff",
    "X-ChronoSpark-Contract": "account-delete-status-v1",
  };
}

function json(req: Request, body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), { status, headers: headers(req) });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: headers(req) });
  }
  if (req.method !== "POST") {
    return json(req, { error: "method_not_allowed" }, 405);
  }
  if (!accountDeletionConfigured()) {
    return json(req, { error: "not_configured" }, 503);
  }
  try {
    const input = readDeletionInput(
      await readBoundedJson(req, { maxBytes: 4_096 }),
    );
    if (!input || input.action !== "status") {
      return json(req, { error: "invalid_request_body" }, 400);
    }
    const result = await readDeletionStatus(input);
    if (!result) return json(req, { error: "deletion_request_not_found" }, 404);
    return json(req, result, 200);
  } catch (error) {
    const status = error instanceof EdgeHttpError ? error.status : 500;
    const code = error instanceof EdgeHttpError ? error.code : "request_failed";
    logEdgeEvent("error", "account_deletion_status_failed", { code, status });
    return json(req, { error: code }, status);
  }
});

