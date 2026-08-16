/// <reference lib="deno.ns" />
import { validateAiProxyRequest } from "../_shared/ai_proxy_request_validation.ts";
import {
  containsCrisisLanguage,
  crisisResponse,
  isProviderOutputSafe,
  redactSensitiveText,
  safeFallbackResponse,
  serverSystemPrompt,
} from "../_shared/ai_safety.ts";
import {
  EdgeHttpError,
  fetchWithDeadline,
  logEdgeEvent,
  readBoundedJson,
  readBoundedResponseJson,
  safeCorrelationId,
} from "../_shared/edge_http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_PUBLISHABLE_KEY = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const ANTHROPIC_API = "https://api.anthropic.com/v1/messages";
const CONTRACT_VERSION = "ai-proxy-v3";
const SAFETY_POLICY_VERSION = "chronospark-safety-v2";
const configuredModel = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-6";
const DEFAULT_MODEL = /^[A-Za-z0-9._-]{3,80}$/.test(configuredModel)
  ? configuredModel
  : "claude-sonnet-4-6";
const ALLOWED_ORIGINS = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ??
    "https://chronospark.app,https://www.chronospark.app")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
);

interface ProxyResponse {
  message?: string;
  model?: string;
  inputTokens?: number;
  outputTokens?: number;
  requestId?: string;
  creditsCharged?: number;
  remainingCredits?: number;
  safety?: "standard" | "crisis" | "filtered";
  error?: string;
}

function cors(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  return {
    ...(ALLOWED_ORIGINS.has(origin)
      ? { "Access-Control-Allow-Origin": origin }
      : {}),
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Cache-Control": "no-store",
    "Vary": "Origin",
    "X-Content-Type-Options": "nosniff",
    "X-ChronoSpark-Contract": CONTRACT_VERSION,
  };
}

function jsonResponse(
  req: Request,
  body: ProxyResponse,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors(req), "Content-Type": "application/json" },
  });
}

async function authenticatedUserId(req: Request): Promise<string | null> {
  const authorization = req.headers.get("authorization") ?? "";
  if (
    !authorization.startsWith("Bearer ") || !SUPABASE_URL ||
    !SUPABASE_PUBLISHABLE_KEY
  ) return null;
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/auth/v1/user`,
    {
      headers: {
        Authorization: authorization,
        apikey: SUPABASE_PUBLISHABLE_KEY,
      },
    },
    { timeoutMs: 5_000, dependency: "supabase_auth_user" },
  );
  if (!response.ok) return null;
  const user = await response.json();
  return typeof user?.id === "string" ? user.id : null;
}

async function consumeRateLimit(req: Request): Promise<boolean> {
  const authorization = req.headers.get("authorization") ?? "";
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/rest/v1/rpc/consume_ai_proxy_rate_limit`,
    {
      method: "POST",
      headers: {
        Authorization: authorization,
        apikey: SUPABASE_PUBLISHABLE_KEY,
        "Content-Type": "application/json",
      },
      body: "{}",
    },
    { timeoutMs: 5_000, dependency: "ai_rate_limit" },
  );
  return response.ok;
}

async function serviceRpc(
  name: string,
  body: Record<string, unknown>,
): Promise<Record<string, unknown> | null> {
  if (!SUPABASE_URL || !SUPABASE_SECRET_KEY) return null;
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/rest/v1/rpc/${name}`,
    {
      method: "POST",
      headers: {
        apikey: SUPABASE_SECRET_KEY,
        Authorization: `Bearer ${SUPABASE_SECRET_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    },
    { timeoutMs: 5_000, dependency: `supabase_rpc_${name}` },
  );
  if (!response.ok) {
    await response.body?.cancel();
    return null;
  }
  const value = await response.json();
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function creditCost(prompt: string, personality: string): number {
  return 1 + (prompt.length > 120 ? 1 : 0) +
    (personality === "strict" ? 1 : 0);
}

async function settleReservation(
  userId: string,
  requestId: string,
  succeeded: boolean,
  details: {
    inputTokens?: number;
    outputTokens?: number;
    providerRequestId?: string;
    failureCode?: string;
    responsePayload?: Record<string, unknown>;
  } = {},
): Promise<Record<string, unknown> | null> {
  return await serviceRpc("settle_ai_usage_v2", {
    p_user_id: userId,
    p_request_key: requestId,
    p_succeeded: succeeded,
    p_input_tokens: details.inputTokens ?? null,
    p_output_tokens: details.outputTokens ?? null,
    p_provider_request_id: details.providerRequestId ?? null,
    p_failure_code: details.failureCode ?? null,
    p_response_payload: details.responsePayload ?? {},
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors(req) });
  }
  if (req.method !== "POST") {
    return jsonResponse(req, { error: "method_not_allowed" }, 405);
  }
  if (
    !SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY || !SUPABASE_SECRET_KEY ||
    !ANTHROPIC_API_KEY
  ) {
    return jsonResponse(req, { error: "ai_proxy_not_configured" }, 503);
  }

  let userId: string | null;
  try {
    userId = await authenticatedUserId(req);
    if (!userId) return jsonResponse(req, { error: "unauthorized" }, 401);
    if (!await consumeRateLimit(req)) {
      return jsonResponse(req, { error: "rate_limit_exceeded" }, 429);
    }
  } catch (error) {
    const status = error instanceof EdgeHttpError ? error.status : 503;
    const code = error instanceof EdgeHttpError
      ? error.code
      : "auth_unavailable";
    return jsonResponse(req, { error: code }, status);
  }

  let reservation: { userId: string; requestId: string } | null = null;
  try {
    const body = validateAiProxyRequest(
      await readBoundedJson(req, { maxBytes: 24_576 }),
    );
    if (!body) return jsonResponse(req, { error: "invalid_request_body" }, 400);
    const correlationId = safeCorrelationId(body.requestId);

    const combinedInput = [
      body.prompt,
      ...body.history.map((item) => item.content),
    ]
      .join("\n");
    if (containsCrisisLanguage(combinedInput)) {
      return jsonResponse(req, {
        message: crisisResponse(),
        model: "chronospark-safety",
        inputTokens: 0,
        outputTokens: 0,
        requestId: body.requestId,
        creditsCharged: 0,
        safety: "crisis",
      });
    }

    const cost = creditCost(body.prompt, body.personality);
    const requestFingerprint = await sha256(JSON.stringify({
      contract: CONTRACT_VERSION,
      safetyPolicy: SAFETY_POLICY_VERSION,
      model: DEFAULT_MODEL,
      prompt: body.prompt,
      history: body.history,
      personality: body.personality,
      maxTokens: body.maxTokens,
    }));
    const reserved = await serviceRpc("reserve_ai_usage_v2", {
      p_user_id: userId,
      p_request_key: body.requestId,
      p_credit_amount: cost,
      p_request_fingerprint: requestFingerprint,
      p_contract_version: CONTRACT_VERSION,
    });
    if (!reserved) {
      return jsonResponse(req, { error: "credit_reservation_failed" }, 503);
    }
    if (reserved.duplicate === true) {
      if (reserved.conflict === true) {
        return jsonResponse(
          req,
          { requestId: body.requestId, error: "idempotency_conflict" },
          409,
        );
      }
      const state = reserved.state?.toString() ?? "unknown";
      const cached = reserved.responsePayload;
      const cachedResponse = cached && typeof cached === "object" &&
          !Array.isArray(cached)
        ? cached as Record<string, unknown>
        : null;
      if (
        state === "completed" && cachedResponse &&
        typeof cachedResponse.message === "string"
      ) {
        return jsonResponse(req, cachedResponse as ProxyResponse);
      }
      return jsonResponse(
        req,
        { requestId: body.requestId, error: `request_${state}` },
        409,
      );
    }
    if (reserved.allowed !== true) {
      const reason = reserved.reason?.toString() ?? "credits_unavailable";
      const status = reason === "daily_budget_exceeded" ? 429 : 402;
      return jsonResponse(req, {
        requestId: body.requestId,
        remainingCredits: Number(reserved.balance ?? 0),
        error: reason,
      }, status);
    }
    reservation = { userId, requestId: body.requestId };

    const recentHistory = body.history.slice(-6).map((item) => ({
      role: item.role,
      content: redactSensitiveText(item.content),
    }));
    const safePrompt = redactSensitiveText(body.prompt);
    const messages = recentHistory.at(-1)?.role === "user" &&
        recentHistory.at(-1)?.content === safePrompt
      ? recentHistory
      : [...recentHistory, { role: "user" as const, content: safePrompt }];

    const upstream = await fetchWithDeadline(
      ANTHROPIC_API,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: DEFAULT_MODEL,
          max_tokens: Math.max(128, body.maxTokens),
          system: serverSystemPrompt(body.personality),
          messages,
        }),
      },
      { timeoutMs: 20_000, dependency: "anthropic_messages" },
    );

    if (!upstream.ok) {
      await upstream.body?.cancel();
      await settleReservation(userId, body.requestId, false, {
        failureCode: `provider_http_${upstream.status}`,
      });
      reservation = null;
      logEdgeEvent("warn", "ai_provider_http_failure", {
        requestId: correlationId,
        status: upstream.status,
      });
      return jsonResponse(req, { error: "upstream_ai_error" }, 502);
    }

    const rawData = await readBoundedResponseJson(upstream, {
      maxBytes: 262_144,
    });
    const data =
      rawData && typeof rawData === "object" && !Array.isArray(rawData)
        ? rawData as Record<string, unknown>
        : {};
    const usage = data.usage && typeof data.usage === "object" &&
        !Array.isArray(data.usage)
      ? data.usage as Record<string, unknown>
      : {};
    const contentBlocks = Array.isArray(data.content) ? data.content : [];
    const providerMessage = contentBlocks
      .flatMap((block: unknown) => {
        if (!block || typeof block !== "object" || Array.isArray(block)) {
          return [];
        }
        const record = block as Record<string, unknown>;
        return record.type === "text" && typeof record.text === "string"
          ? [record.text]
          : [];
      })
      .join("\n")
      .trim();
    const stopReason = typeof data.stop_reason === "string"
      ? data.stop_reason
      : "unknown";
    const inputTokens = Number(usage.input_tokens ?? 0);
    const outputTokens = Number(usage.output_tokens ?? 0);
    const providerRequestId = typeof data.id === "string" ? data.id : undefined;

    if (
      stopReason === "refusal" || stopReason === "max_tokens" ||
      !providerMessage
    ) {
      await settleReservation(userId, body.requestId, false, {
        inputTokens,
        outputTokens,
        providerRequestId,
        failureCode: stopReason === "refusal"
          ? "provider_refusal"
          : stopReason === "max_tokens"
          ? "provider_incomplete"
          : "provider_empty_output",
      });
      reservation = null;
      return jsonResponse(req, {
        message: stopReason === "refusal" ? safeFallbackResponse() : undefined,
        requestId: body.requestId,
        creditsCharged: 0,
        safety: stopReason === "refusal" ? "filtered" : undefined,
        error: stopReason === "max_tokens" ? "incomplete_response" : undefined,
      }, stopReason === "max_tokens" ? 502 : 200);
    }

    if (!isProviderOutputSafe(providerMessage)) {
      await settleReservation(userId, body.requestId, false, {
        inputTokens,
        outputTokens,
        providerRequestId,
        failureCode: "unsafe_provider_output",
      });
      reservation = null;
      return jsonResponse(req, {
        message: safeFallbackResponse(),
        model: "chronospark-safety",
        inputTokens,
        outputTokens,
        requestId: body.requestId,
        creditsCharged: 0,
        safety: "filtered",
      });
    }

    const safeProviderMessage = redactSensitiveText(providerMessage);
    const responsePayload: ProxyResponse = {
      message: safeProviderMessage,
      model: typeof data.model === "string" ? data.model : DEFAULT_MODEL,
      inputTokens,
      outputTokens,
      requestId: body.requestId,
      creditsCharged: cost,
      remainingCredits: Number(reserved.balance ?? 0),
      safety: "standard",
    };
    const settled = await settleReservation(userId, body.requestId, true, {
      inputTokens,
      outputTokens,
      providerRequestId,
      responsePayload: responsePayload as Record<string, unknown>,
    });
    if (!settled || settled.state !== "completed") {
      return jsonResponse(req, { error: "credit_settlement_failed" }, 503);
    }
    reservation = null;

    return jsonResponse(req, responsePayload);
  } catch (error) {
    if (reservation) {
      await settleReservation(
        reservation.userId,
        reservation.requestId,
        false,
        {
          failureCode: "unhandled_proxy_failure",
        },
      );
    }
    const status = error instanceof EdgeHttpError ? error.status : 500;
    const code = error instanceof EdgeHttpError ? error.code : "request_failed";
    logEdgeEvent("error", "ai_proxy_request_failed", { code, status });
    return jsonResponse(req, { error: code }, status);
  }
});

