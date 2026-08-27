/// <reference lib="deno.ns" />
import {
  accountDeletionConfigured,
  authenticatedDeletionUser,
  deletionIdentifiers,
  getDeletionStatus,
  loadAccountDeletionConfig,
  processDeletionRequest,
  sha256Hex,
} from "../_shared/account_deletion_state_machine.ts";
import {
  DEFAULT_RECENT_SIGN_IN_SECONDS,
  hasRecentSignIn,
} from "./recent_sign_in_policy.ts";

const config = loadAccountDeletionConfig();
const configuredRecentSignInSeconds = Number.parseInt(
  Deno.env.get("ACCOUNT_DELETE_RECENT_SIGN_IN_SECONDS") ?? "",
  10,
);
const recentSignInSeconds = Number.isFinite(configuredRecentSignInSeconds) &&
    configuredRecentSignInSeconds > 0
  ? configuredRecentSignInSeconds
  : DEFAULT_RECENT_SIGN_IN_SECONDS;
const allowedOrigins = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ??
    "https://chronospark.app,https://www.chronospark.app")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
);

function headers(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  return {
    ...(allowedOrigins.has(origin)
      ? { "Access-Control-Allow-Origin": origin }
      : {}),
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Cache-Control": "no-store",
    "Content-Type": "application/json",
    "Vary": "Origin",
    "X-Content-Type-Options": "nosniff",
    "X-ChronoSpark-Contract": "account-delete-v2",
  };
}

function json(
  req: Request,
  body: object,
  status: number,
): Response {
  return new Response(JSON.stringify(body), { status, headers: headers(req) });
}

interface DeletionInput {
  action: "delete" | "status";
  requestId?: string;
  receipt?: string;
}

async function readInput(req: Request): Promise<DeletionInput | null> {
  const text = await req.text();
  if (!text.trim()) return { action: "delete" };
  try {
    const value = JSON.parse(text);
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      return null;
    }
    const body = value as Record<string, unknown>;
    const action = body.action === undefined || body.action === "delete"
      ? "delete"
      : body.action === "status"
      ? "status"
      : null;
    if (!action) return null;
    return {
      action,
      requestId: typeof body.requestId === "string"
        ? body.requestId.trim()
        : undefined,
      receipt: typeof body.receipt === "string"
        ? body.receipt.trim()
        : undefined,
    };
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: headers(req) });
  }
  if (req.method !== "POST") {
    return json(req, { error: "method_not_allowed" }, 405);
  }
  if (!accountDeletionConfigured(config)) {
    return json(req, { error: "not_configured" }, 503);
  }

  try {
    const input = await readInput(req);
    if (!input) return json(req, { error: "invalid_request_body" }, 400);

    if (input.action === "status" && input.requestId && input.receipt) {
      if (
        !/^[0-9a-f]{64}$/.test(input.requestId) ||
        !/^[0-9a-f]{64}$/.test(input.receipt)
      ) {
        return json(req, { error: "invalid_status_capability" }, 400);
      }
      const status = await getDeletionStatus(
        input.requestId,
        await sha256Hex(input.receipt),
        config,
      );
      return status
        ? json(req, status, 200)
        : json(req, { error: "deletion_request_not_found" }, 404);
    }

    const authorization = req.headers.get("authorization") ?? "";
    const user = await authenticatedDeletionUser(authorization, config);
    if (!user) return json(req, { error: "unauthorized" }, 401);
    const identifiers = await deletionIdentifiers(user.id, authorization);

    if (input.action === "status") {
      const status = await getDeletionStatus(
        identifiers.requestId,
        identifiers.receiptHash,
        config,
      );
      return status
        ? json(req, status, 200)
        : json(req, { error: "deletion_request_not_found" }, 404);
    }

    if (!hasRecentSignIn(user.lastSignInAt, { recentSignInSeconds })) {
      return json(req, { error: "recent_sign_in_required" }, 428);
    }
    const result = await processDeletionRequest({
      requestId: identifiers.requestId,
      receiptHash: identifiers.receiptHash,
      authenticatedUserId: user.id,
      config,
    });
    const responseBody = {
      ...result,
      requestId: identifiers.requestId,
      receipt: identifiers.receipt,
    };
    if (result.completed) return json(req, responseBody, 200);
    if (result.accepted && result.retry) return json(req, responseBody, 202);
    if (result.retry) {
      return json(req, { error: "temporarily_unavailable" }, 503);
    }
    return json(req, { error: "deletion_request_rejected" }, 409);
  } catch (error) {
    console.error(
      "Account deletion request failed",
      error instanceof Error ? error.name : "unknown_error",
    );
    return json(req, { error: "request_failed" }, 500);
  }
});
