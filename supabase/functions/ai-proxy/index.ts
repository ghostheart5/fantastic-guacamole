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

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_PUBLISHABLE_KEY = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const ANTHROPIC_API = "https://api.anthropic.com/v1/messages";
const DEFAULT_MODEL = "claude-sonnet-4-6";
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

async function authenticatedUserId(req: Request): Promise<string | null> {
  const authorization = req.headers.get("authorization") ?? "";
  if (
    !authorization.startsWith("Bearer ") || !SUPABASE_URL ||
    !SUPABASE_PUBLISHABLE_KEY
  ) return null;
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: authorization, apikey: SUPABASE_PUBLISHABLE_KEY },
  });
  if (!response.ok) return null;
  const user = await response.json();
  return typeof user?.id === "string" ? user.id : null;
}

async function consumeRateLimit(req: Request): Promise<boolean> {
  const authorization = req.headers.get("authorization") ?? "";
  const response = await fetch(
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
  );
  return response.ok;
}

async function serviceRpc(
  name: string,
  body: Record<string, unknown>,
): Promise<Record<string, unknown> | null> {
  if (!SUPABASE_URL || !SUPABASE_SECRET_KEY) return null;
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: SUPABASE_SECRET_KEY,
      Authorization: `Bearer ${SUPABASE_SECRET_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
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
  return await serviceRpc("settle_ai_usage", {
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

  const userId = await authenticatedUserId(req);
  if (!userId) return jsonResponse(req, { error: "unauthorized" }, 401);
  if (!await consumeRateLimit(req)) {
    return jsonResponse(req, { error: "rate_limit_exceeded" }, 429);
  }

  let reservation: { userId: string; requestId: string } | null = null;
  try {
    const body = validateAiProxyRequest(await req.json());
    if (!body) return jsonResponse(req, { error: "invalid_request_body" }, 400);

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
    const promptHash = await sha256(body.prompt);
    const reserved = await serviceRpc("reserve_ai_usage", {
      p_user_id: userId,
      p_request_key: body.requestId,
      p_credit_amount: cost,
      p_prompt_hash: promptHash,
    });
    if (!reserved) {
      return jsonResponse(req, { error: "credit_reservation_failed" }, 503);
    }
    if (reserved.duplicate === true) {
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

    const upstream = await fetch(ANTHROPIC_API, {
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
    });

    if (!upstream.ok) {
      await upstream.body?.cancel();
      await settleReservation(userId, body.requestId, false, {
        failureCode: `provider_http_${upstream.status}`,
      });
      reservation = null;
      console.error("Anthropic API request failed");
      return jsonResponse(req, { error: "upstream_ai_error" }, 502);
    }

    const data = await upstream.json();
    const providerMessage = typeof data?.content?.[0]?.text === "string"
      ? data.content[0].text.trim()
      : "";
    const inputTokens = Number(data?.usage?.input_tokens ?? 0);
    const outputTokens = Number(data?.usage?.output_tokens ?? 0);
    const providerRequestId = typeof data?.id === "string"
      ? data.id
      : undefined;

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
      model: typeof data?.model === "string" ? data.model : DEFAULT_MODEL,
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
    console.error("AI proxy request failed");
    return jsonResponse(req, { error: "request_failed" }, 500);
  }
});
