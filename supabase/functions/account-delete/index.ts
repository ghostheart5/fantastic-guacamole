/// <reference lib="deno.ns" />
import {
  accountDeletionConfigured,
  authenticatedDeletionUser,
  processDeletionRequest,
  readDeletionInput,
} from "../_shared/account_deletion_state_machine.ts";
import {
  EdgeHttpError,
  logEdgeEvent,
  readBoundedJson,
} from "../_shared/edge_http.ts";
import {
  DEFAULT_RECENT_SIGN_IN_SECONDS,
  hasRecentSignIn,
} from "./recent_sign_in_policy.ts";

const configuredRecentSignInSeconds = Number.parseInt(
  Deno.env.get("ACCOUNT_DELETE_RECENT_SIGN_IN_SECONDS") ?? "",
  10,
);
const RECENT_SIGN_IN_SECONDS = Number.isFinite(configuredRecentSignInSeconds) &&
    configuredRecentSignInSeconds > 0
  ? configuredRecentSignInSeconds
  : DEFAULT_RECENT_SIGN_IN_SECONDS;
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
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Cache-Control": "no-store",
    "Content-Type": "application/json",
    "Vary": "Origin",
    "X-Content-Type-Options": "nosniff",
    "X-ChronoSpark-Contract": "account-delete-v3",
  };
}

function json(
  req: Request,
  body: Record<string, unknown>,
  status: number,
): Response {
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
      await readBoundedJson(req, { maxBytes: 8_192 }),
    );
    if (!input) return json(req, { error: "invalid_request_body" }, 400);
    if (input.action !== "delete") {
      return json(req, { error: "status_endpoint_moved" }, 400);
    }
    const authorization = req.headers.get("authorization") ?? "";
    const authUser = authorization
      ? await authenticatedDeletionUser(authorization)
      : null;

    if (!authUser) return json(req, { error: "unauthorized" }, 401);
    if (input.userId !== authUser.id) {
      return json(req, { error: "user_mismatch" }, 403);
    }
    if (input.email && authUser.email && input.email !== authUser.email) {
      return json(req, { error: "email_mismatch" }, 403);
    }
    if (
      !hasRecentSignIn(authUser.lastSignInAt, {
        recentSignInSeconds: RECENT_SIGN_IN_SECONDS,
      })
    ) {
      return json(req, { error: "recent_sign_in_required" }, 428);
    }

    const result = await processDeletionRequest({
      input,
      authenticatedUserId: authUser.id,
    });
    if (result.completed === true) return json(req, result, 200);
    if (result.accepted === true) return json(req, result, 202);
    return json(req, { error: "deletion_request_not_found" }, 404);
  } catch (error) {
    const status = error instanceof EdgeHttpError ? error.status : 500;
    const code = error instanceof EdgeHttpError ? error.code : "request_failed";
    logEdgeEvent("error", "account_deletion_request_failed", { code, status });
    return json(req, { error: code }, status);
  }
});

