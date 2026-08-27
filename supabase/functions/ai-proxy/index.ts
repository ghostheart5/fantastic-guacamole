/// <reference lib="deno.ns" />

import {
  aiCreditCost,
  aiReservationFailureStatus,
  validatedAiRequestId,
} from "../_shared/ai_billing.ts";
import {
  authenticatedUserId,
  type BillingBackendConfig,
  consumeDurableRateLimits,
  serviceRpc,
  sha256Hex,
} from "../_shared/billing_backend.ts";

const config: BillingBackendConfig = {
  supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
  publishableKey: Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
  secretKey: Deno.env.get("SUPABASE_SECRET_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
};
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const ANTHROPIC_API = "https://api.anthropic.com/v1/messages";
const DEFAULT_MODEL = "claude-sonnet-4-6";
const MAX_TOKENS = 1024;
const ALLOWED_ORIGINS = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ??
    "https://chronospark.app,https://www.chronospark.app")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
);

interface ProxyRequest {
  prompt?: string;
  message?: string;
  history?: Array<{ role: "user" | "assistant"; content: string }>;
  system?: string;
  maxTokens?: number;
  allowExternalAi?: boolean;
  requestId?: string;
}

interface ProxyResponse {
  message?: string;
  model?: string;
  inputTokens?: number;
  outputTokens?: number;
  requestId?: string;
  creditsCharged?: number;
  remainingCredits?: number;
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
    "X-ChronoSpark-Contract": "ai-proxy-v2",
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
  return await serviceRpc(config, "settle_ai_usage", {
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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors(req) });
  }
  if (req.method !== "POST") {
    return jsonResponse(req, { error: "method_not_allowed" }, 405);
  }
  if (
    !config.supabaseUrl || !config.publishableKey || !config.secretKey ||
    !ANTHROPIC_API_KEY
  ) return jsonResponse(req, { error: "ai_proxy_not_configured" }, 503);

  const userId = await authenticatedUserId(req, config);
  if (!userId) return jsonResponse(req, { error: "unauthorized" }, 401);
  if (
    !await consumeDurableRateLimits(req, config, userId, {
      bucket: "ai_proxy",
      userLimit: 20,
      ipLimit: 60,
    })
  ) return jsonResponse(req, { error: "rate_limit_exceeded" }, 429);

  let reservation: { userId: string; requestId: string } | null = null;
  try {
    const body = await req.json() as ProxyRequest;
    const requestId = validatedAiRequestId(body.requestId);
    const prompt = (body.prompt ?? body.message ?? "").trim();
    const history = Array.isArray(body.history) ? body.history : [];
    const maxTokens = Number(body.maxTokens ?? MAX_TOKENS);
    if (body.allowExternalAi !== true) {
      return jsonResponse(req, {
        requestId: requestId ?? undefined,
        error: "external_ai_disabled",
      }, 403);
    }
    if (
      !requestId || !prompt || prompt.length > 8000 || history.length > 8 ||
      !Number.isInteger(maxTokens) || maxTokens < 1 || maxTokens > MAX_TOKENS ||
      history.some((item) =>
        !item || (item.role !== "user" && item.role !== "assistant") ||
        typeof item.content !== "string" || item.content.length > 4000
      )
    ) {
      return jsonResponse(req, {
        requestId: requestId ?? undefined,
        error: "invalid_request_body",
      }, 400);
    }

    const cost = aiCreditCost(prompt);
    const reserved = await serviceRpc(config, "reserve_ai_usage", {
      p_user_id: userId,
      p_request_key: requestId,
      p_credit_amount: cost,
      p_prompt_hash: await sha256Hex(prompt),
    });
    if (!reserved) {
      return jsonResponse(req, {
        requestId,
        error: "credit_reservation_failed",
      }, 503);
    }
    if (reserved.duplicate === true) {
      const cached = reserved.responsePayload;
      const cachedResponse = cached && typeof cached === "object" &&
          !Array.isArray(cached)
        ? cached as Record<string, unknown>
        : null;
      if (
        reserved.state === "completed" && cachedResponse &&
        typeof cachedResponse.message === "string"
      ) return jsonResponse(req, cachedResponse as ProxyResponse);
      return jsonResponse(req, {
        requestId,
        remainingCredits: Number(reserved.balance ?? 0),
        error: `request_${reserved.state ?? "unknown"}`,
      }, 409);
    }
    if (reserved.allowed !== true) {
      const reason = String(reserved.reason ?? "credits_unavailable");
      return jsonResponse(req, {
        requestId,
        remainingCredits: Number(reserved.balance ?? 0),
        error: reason,
      }, aiReservationFailureStatus(reason));
    }
    reservation = { userId, requestId };

    const recentHistory = history.slice(-6);
    const messages = recentHistory.at(-1)?.role === "user" &&
        recentHistory.at(-1)?.content === prompt
      ? recentHistory
      : [...recentHistory, { role: "user" as const, content: prompt }];
    const upstreamBody: Record<string, unknown> = {
      model: DEFAULT_MODEL,
      max_tokens: maxTokens,
      messages,
    };
    if (typeof body.system === "string" && body.system.trim()) {
      upstreamBody.system = body.system.slice(0, 6000);
    }
    const upstream = await fetch(ANTHROPIC_API, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(upstreamBody),
    });
    if (!upstream.ok) {
      await upstream.body?.cancel();
      await settleReservation(userId, requestId, false, {
        failureCode: `provider_http_${upstream.status}`,
      });
      reservation = null;
      return jsonResponse(req, { requestId, error: "upstream_ai_error" }, 502);
    }
    const data = await upstream.json();
    const message = typeof data?.content?.[0]?.text === "string"
      ? data.content[0].text.trim()
      : "";
    const inputTokens = Number(data?.usage?.input_tokens ?? 0);
    const outputTokens = Number(data?.usage?.output_tokens ?? 0);
    if (!message) {
      await settleReservation(userId, requestId, false, {
        inputTokens,
        outputTokens,
        providerRequestId: typeof data?.id === "string" ? data.id : undefined,
        failureCode: "empty_provider_output",
      });
      reservation = null;
      return jsonResponse(
        req,
        { requestId, error: "empty_upstream_response" },
        502,
      );
    }
    const responsePayload: ProxyResponse = {
      message,
      model: typeof data?.model === "string" ? data.model : DEFAULT_MODEL,
      inputTokens,
      outputTokens,
      requestId,
      creditsCharged: cost,
      remainingCredits: Number(reserved.balance ?? 0),
    };
    const settled = await settleReservation(userId, requestId, true, {
      inputTokens,
      outputTokens,
      providerRequestId: typeof data?.id === "string" ? data.id : undefined,
      responsePayload: responsePayload as Record<string, unknown>,
    });
    if (settled?.state !== "completed") {
      return jsonResponse(
        req,
        { requestId, error: "credit_settlement_failed" },
        503,
      );
    }
    reservation = null;
    return jsonResponse(req, responsePayload);
  } catch {
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
    return jsonResponse(req, { error: "request_failed" }, 500);
  }
});
