import {
  createCreditQuote,
  MAX_PROVIDER_MICROUSD_PER_CREDIT,
  quotedCreditCost,
  quotedProviderCostMicrousd,
  verifyCreditQuote,
} from "../_shared/ai_credit_quote.ts";
/// <reference lib="deno.ns" />

import {
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
import {
  buildServerSystemPrompt,
  containsBlockedAssistantClaim,
  containsRecommendationContradiction,
  containsScheduledStartDepartureConfusion,
} from "../_shared/ai_proxy_policy.ts";
import {
  internalAiAccountAllowed,
  internalAiPreflightResponse,
  parseInternalAiCohort,
} from "../_shared/internal_ai_cohort.ts";

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
const PROVIDER_FLOW_BUDGET_MS = 20_000;
const PROVIDER_CALL_CAP_MS = 20_000;
const SETTLEMENT_TIMEOUT_MS = 8_000;
const SUCCESS_SETTLEMENT_RECONCILIATION_ATTEMPTS = 2;
const internalAiCohort = parseInternalAiCohort(
  Deno.env.get("CHRONOSPARK_INTERNAL_ACCOUNT_DIGESTS"),
);
const ALLOWED_ORIGINS = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ??
    "https://chronospark.app,https://www.chronospark.app")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
);

interface ProxyRequest {
  quoteOnly?: boolean;
  quote?: unknown;
  prompt?: string;
  message?: string;
  history?: Array<{ role: "user" | "assistant"; content: string }>;
  personality?: string;
  context?: Record<string, unknown>;
  maxTokens?: number;
  allowExternalAi?: boolean;
  requestId?: string;
}

interface ProxyResponse {
  quote?: unknown;
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
  const body = {
    p_user_id: userId,
    p_request_key: requestId,
    p_succeeded: succeeded,
    p_input_tokens: details.inputTokens ?? null,
    p_output_tokens: details.outputTokens ?? null,
    p_provider_request_id: details.providerRequestId ?? null,
    p_failure_code: details.failureCode ?? null,
    p_response_payload: details.responsePayload ?? {},
  };
  if (!config.supabaseUrl || !config.secretKey) return null;
  const response = await fetch(
    `${config.supabaseUrl}/rest/v1/rpc/settle_ai_usage`,
    {
      method: "POST",
      headers: {
        apikey: config.secretKey,
        Authorization: `Bearer ${config.secretKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(SETTLEMENT_TIMEOUT_MS),
    },
  );
  if (!response.ok) {
    await response.body?.cancel();
    throw new SettlementHttpError(response.status);
  }
  const value = await response.json();
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("AI settlement returned an invalid response");
  }
  return value as Record<string, unknown>;
}

class SettlementHttpError extends Error {
  readonly ambiguous: boolean;

  constructor(readonly status: number) {
    super(`AI settlement HTTP ${status}`);
    this.name = "SettlementHttpError";
    this.ambiguous = status === 408 || status === 425 || status === 429 ||
      status >= 500;
  }
}

async function settleSuccessDefinitively(
  userId: string,
  requestId: string,
  details: Parameters<typeof settleReservation>[3],
): Promise<Record<string, unknown> | null> {
  let lastFailure: unknown = new Error(
    "AI success settlement returned no authoritative state",
  );
  let outcomeWasAmbiguous = false;
  try {
    const initialSettlement = await settleReservation(
      userId,
      requestId,
      true,
      details,
    );
    if (initialSettlement !== null) return initialSettlement;
  } catch (error) {
    lastFailure = error;
    outcomeWasAmbiguous = isAmbiguousSettlementTransportError(error);
  }
  // A timeout, abort, connection reset, or retryable HTTP/null result cannot
  // prove whether PostgreSQL committed. Reissue the idempotent settlement
  // with a fresh bounded request so the row lock can return its authoritative
  // state without allowing an unhealthy connection to hold the paid reply
  // forever. A reconciliation response can be lost too, so repeat it before
  // giving up certainty.
  if (outcomeWasAmbiguous) {
    for (
      let attempt = 0;
      attempt < SUCCESS_SETTLEMENT_RECONCILIATION_ATTEMPTS;
      attempt++
    ) {
      try {
        const reconciliation = await settleReservation(
          userId,
          requestId,
          true,
          details,
        );
        if (reconciliation !== null) return reconciliation;
        lastFailure = new Error(
          "AI success settlement reconciliation returned no authoritative state",
        );
      } catch (reconciliationError) {
        lastFailure = reconciliationError;
        if (!isAmbiguousSettlementTransportError(reconciliationError)) break;
      }
    }
  }
  const authoritativeState = await loadAiUsageSettlementState(
    userId,
    requestId,
  );
  if (authoritativeState === "completed") {
    return { state: "completed", duplicate: true };
  }
  if (outcomeWasAmbiguous) {
    throw new SuccessSettlementStillAmbiguousError(lastFailure);
  }
  throw new SuccessSettlementUnavailableError(lastFailure);
}

async function loadAiUsageSettlementState(
  userId: string,
  requestId: string,
): Promise<string | null> {
  if (!config.supabaseUrl || !config.secretKey) return null;
  const url = new URL(`${config.supabaseUrl}/rest/v1/ai_usage_requests`);
  url.searchParams.set("user_id", `eq.${userId}`);
  url.searchParams.set("request_key", `eq.${requestId}`);
  url.searchParams.set("select", "state");
  url.searchParams.set("limit", "1");
  try {
    const response = await fetch(url, {
      headers: {
        apikey: config.secretKey,
        Authorization: `Bearer ${config.secretKey}`,
      },
      signal: AbortSignal.timeout(SETTLEMENT_TIMEOUT_MS),
    });
    if (!response.ok) {
      await response.body?.cancel();
      return null;
    }
    const value = await response.json();
    if (!Array.isArray(value) || value.length !== 1) return null;
    const state = value[0]?.state;
    return typeof state === "string" ? state : null;
  } catch (_) {
    return null;
  }
}

class SuccessSettlementStillAmbiguousError extends Error {
  constructor(override readonly cause: unknown) {
    super("AI success settlement remained transport-ambiguous");
    this.name = "SuccessSettlementStillAmbiguousError";
  }
}

class SuccessSettlementUnavailableError extends Error {
  constructor(override readonly cause: unknown) {
    super("AI success settlement was unavailable");
    this.name = "SuccessSettlementUnavailableError";
  }
}

function isAmbiguousSettlementTransportError(error: unknown): boolean {
  return (error instanceof SettlementHttpError && error.ambiguous) ||
    error instanceof TypeError ||
    (error instanceof DOMException &&
      ["TimeoutError", "AbortError", "NetworkError"].includes(error.name));
}

Deno.serve(async (req: Request) => {
  const providerFlowStartedAt = Date.now();
  const preflight = await internalAiPreflightResponse(
    req,
    internalAiCohort,
    "ai-proxy-v2",
    Boolean(
      config.supabaseUrl && config.publishableKey && config.secretKey &&
        ANTHROPIC_API_KEY,
    ),
  );
  if (preflight) return preflight;
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
  if (!await internalAiAccountAllowed(userId, internalAiCohort)) {
    return jsonResponse(req, { error: "internal_ai_access_required" }, 403);
  }
  if (
    !await consumeDurableRateLimits(req, config, userId, {
      bucket: "ai_proxy",
      userLimit: 20,
      ipLimit: 60,
    })
  ) return jsonResponse(req, { error: "rate_limit_exceeded" }, 429);

  let reservation: { userId: string; requestId: string } | null = null;
  try {
    const contentLength = Number(req.headers.get("content-length") ?? 0);
    if (contentLength > 32_000) {
      return jsonResponse(req, { error: "request_too_large" }, 413);
    }
    const body = await req.json() as ProxyRequest;
    if (JSON.stringify(body).length > 32_000) {
      return jsonResponse(req, { error: "request_too_large" }, 413);
    }
    const requestId = validatedAiRequestId(body.requestId);
    const prompt = (body.prompt ?? body.message ?? "").trim();
    const history = Array.isArray(body.history) ? body.history : [];
    const maxTokens = Number(body.maxTokens ?? MAX_TOKENS);
    const system = buildServerSystemPrompt(body.personality, body.context);
    if (body.allowExternalAi !== true) {
      return jsonResponse(req, {
        requestId: requestId ?? undefined,
        error: "external_ai_disabled",
      }, 403);
    }
    if (
      !requestId || !prompt || prompt.length > 8000 || history.length > 8 ||
      system === null ||
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

    const recentHistory = history.slice(-6);
    const messages = recentHistory.at(-1)?.role === "user" &&
        recentHistory.at(-1)?.content === prompt
      ? recentHistory
      : [...recentHistory, { role: "user" as const, content: prompt }];
    const upstreamBody: Record<string, unknown> = {
      model: DEFAULT_MODEL,
      max_tokens: maxTokens,
      temperature: 0,
      messages,
    };
    upstreamBody.system = system;
    const cost = quotedCreditCost(upstreamBody);
    if (body.quoteOnly === true) {
      return jsonResponse(req, {
        requestId,
        quote: await createCreditQuote(
          config.secretKey,
          userId,
          requestId,
          upstreamBody,
        ),
      });
    }
    if (
      !await verifyCreditQuote(
        config.secretKey,
        userId,
        requestId,
        upstreamBody,
        body.quote,
      )
    ) {
      return jsonResponse(
        req,
        { requestId, error: "credit_quote_required" },
        409,
      );
    }
    const reserved = await serviceRpc(config, "reserve_ai_usage", {
      p_user_id: userId,
      p_request_key: requestId,
      p_credit_amount: cost,
      p_prompt_hash: await sha256Hex(JSON.stringify(upstreamBody)),
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
      const state = String(reserved.state ?? "unknown");
      const error = state === "denied" &&
          typeof reserved.reason === "string" && reserved.reason.length > 0
        ? reserved.reason
        : `request_${state}`;
      return jsonResponse(req, {
        requestId,
        remainingCredits: Number(reserved.balance ?? 0),
        error,
      }, state === "denied" ? aiReservationFailureStatus(error) : 409);
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

    const upstreamTimeoutMs = remainingProviderTimeoutMs(providerFlowStartedAt);
    if (upstreamTimeoutMs <= 0) {
      throw new DOMException("Provider flow deadline exceeded", "TimeoutError");
    }
    const upstream = await fetch(ANTHROPIC_API, {
      method: "POST",
      // Leave time to refund a reservation before the edge request expires.
      signal: AbortSignal.timeout(upstreamTimeoutMs),
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
    if (data?.stop_reason === "max_tokens") {
      await settleReservation(userId, requestId, false, {
        failureCode: "truncated_provider_output",
      });
      reservation = null;
      return jsonResponse(req, {
        requestId,
        error: "truncated_upstream_response",
      }, 502);
    }
    const message = typeof data?.content?.[0]?.text === "string"
      ? data.content[0].text.trim()
      : "";
    const inputTokens = data?.usage?.input_tokens;
    const outputTokens = data?.usage?.output_tokens;
    if (
      !Number.isSafeInteger(inputTokens) || inputTokens <= 0 ||
      !Number.isSafeInteger(outputTokens) || outputTokens < 0 ||
      outputTokens > maxTokens
    ) {
      await settleReservation(userId, requestId, false, {
        failureCode: "invalid_provider_usage",
      });
      reservation = null;
      return jsonResponse(req, {
        requestId,
        error: "invalid_upstream_response",
      }, 502);
    }
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
    if (containsBlockedAssistantClaim(message)) {
      await settleReservation(userId, requestId, false, {
        inputTokens,
        outputTokens,
        providerRequestId: typeof data?.id === "string" ? data.id : undefined,
        failureCode: "unsafe_provider_output",
      });
      reservation = null;
      return jsonResponse(
        req,
        { requestId, error: "unsafe_upstream_response" },
        502,
      );
    }
    let finalMessage = message;
    let finalModel = typeof data?.model === "string"
      ? data.model
      : DEFAULT_MODEL;
    let finalProviderRequestId = typeof data?.id === "string"
      ? data.id
      : undefined;
    let totalInputTokens = inputTokens;
    let totalOutputTokens = outputTokens;
    const confusedTaskStart = containsScheduledStartDepartureConfusion(
      message,
      body.context,
      prompt,
    );
    if (containsRecommendationContradiction(message) || confusedTaskStart) {
      const repairBody: Record<string, unknown> = {
        ...upstreamBody,
        messages: [
          ...messages,
          { role: "assistant", content: message },
          {
            role: "user",
            content: confusedTaskStart
              ? "Rewrite the answer once. You treated a saved task's scheduled start as a travel departure. It only marks the start of the named task; a grocery list may be list preparation, not shopping. Do not assume it is shopping start unless the person explicitly linked them. Keep saved facts separate from hypothetical store hours, recalculate any conditional travel and shopping timeline and the actual closing-time buffer, then return only the corrected answer."
              : "Rewrite the answer once. Its opening recommendation conflicts with its own evidence. Preserve the grounded facts, make the first verdict match the reasoning, and return only the corrected answer.",
          },
        ],
      };
      let repairBudget: Record<string, unknown> | null = null;
      try {
        repairBudget = await serviceRpc(
          config,
          "reserve_ai_repair_budget",
          {
            p_user_id: userId,
            p_request_key: requestId,
            p_required_provider_cost_microusd:
              cost * MAX_PROVIDER_MICROUSD_PER_CREDIT +
              quotedProviderCostMicrousd(repairBody),
          },
          fetch,
          AbortSignal.timeout(SETTLEMENT_TIMEOUT_MS),
        );
      } catch (error) {
        // A lost RPC response can follow a committed repair-budget expansion.
        // The refund settlement below includes the first provider usage so the
        // database accounts only work that actually occurred.
        console.error("AI repair budget check failed", error);
      }
      if (!repairBudget) {
        await settleReservation(userId, requestId, false, {
          inputTokens,
          outputTokens,
          providerRequestId: finalProviderRequestId,
          failureCode: "repair_budget_check_failed",
        });
        reservation = null;
        return jsonResponse(
          req,
          {
            requestId,
            error: "request_refunded",
          },
          409,
        );
      }
      if (repairBudget.allowed !== true) {
        const reason = String(
          repairBudget.reason ?? "provider_cost_budget_exceeded",
        );
        await settleReservation(userId, requestId, false, {
          inputTokens,
          outputTokens,
          providerRequestId: finalProviderRequestId,
          failureCode: reason,
        });
        reservation = null;
        return jsonResponse(
          req,
          { requestId, error: "request_refunded" },
          409,
        );
      }
      let repaired: unknown;
      let repairProviderCallStarted = false;
      try {
        const repairTimeoutMs = remainingProviderTimeoutMs(
          providerFlowStartedAt,
        );
        if (repairTimeoutMs <= 0) {
          throw new DOMException(
            "Provider repair deadline exceeded",
            "TimeoutError",
          );
        }
        repairProviderCallStarted = true;
        const response = await fetch(ANTHROPIC_API, {
          method: "POST",
          signal: AbortSignal.timeout(repairTimeoutMs),
          headers: {
            "Content-Type": "application/json",
            "x-api-key": ANTHROPIC_API_KEY,
            "anthropic-version": "2023-06-01",
          },
          body: JSON.stringify(repairBody),
        });
        if (!response.ok) {
          await response.body?.cancel();
          throw new Error(`repair_http_${response.status}`);
        }
        repaired = await response.json();
      } catch {
        await settleReservation(userId, requestId, false, {
          ...(!repairProviderCallStarted
            ? {
              inputTokens: totalInputTokens,
              outputTokens: totalOutputTokens,
            }
            : {}),
          providerRequestId: finalProviderRequestId,
          failureCode: "inconsistent_provider_output",
        });
        reservation = null;
        return jsonResponse(
          req,
          { requestId, error: "inconsistent_upstream_response" },
          502,
        );
      }
      const repairedRecord = asRecord(repaired);
      const repairedContent = Array.isArray(repairedRecord?.content)
        ? repairedRecord.content
        : [];
      const repairedBlock = asRecord(repairedContent[0]);
      const repairedUsage = asRecord(repairedRecord?.usage);
      const repairedMessage = typeof repairedBlock?.text === "string"
        ? repairedBlock.text.trim()
        : "";
      const repairedInputTokens = Number.isSafeInteger(
          repairedUsage?.input_tokens,
        )
        ? repairedUsage!.input_tokens as number
        : null;
      const repairedOutputTokens = Number.isSafeInteger(
          repairedUsage?.output_tokens,
        )
        ? repairedUsage!.output_tokens as number
        : null;
      const repairedUsageIsValid = repairedInputTokens !== null &&
        repairedInputTokens > 0 &&
        repairedOutputTokens !== null &&
        repairedOutputTokens >= 0 &&
        repairedOutputTokens <= maxTokens;
      if (
        repairedRecord?.stop_reason !== "end_turn" ||
        !repairedMessage ||
        !repairedUsageIsValid ||
        containsBlockedAssistantClaim(repairedMessage) ||
        containsRecommendationContradiction(repairedMessage) ||
        containsScheduledStartDepartureConfusion(
          repairedMessage,
          body.context,
          prompt,
        )
      ) {
        await settleReservation(userId, requestId, false, {
          ...(repairedUsageIsValid
            ? {
              inputTokens: totalInputTokens + repairedInputTokens,
              outputTokens: totalOutputTokens + repairedOutputTokens,
            }
            : {}),
          providerRequestId: typeof repairedRecord?.id === "string"
            ? repairedRecord.id
            : finalProviderRequestId,
          failureCode: "inconsistent_provider_output",
        });
        reservation = null;
        return jsonResponse(
          req,
          { requestId, error: "inconsistent_upstream_response" },
          502,
        );
      }
      finalMessage = repairedMessage;
      finalModel = typeof repairedRecord?.model === "string"
        ? repairedRecord.model
        : DEFAULT_MODEL;
      finalProviderRequestId = typeof repairedRecord?.id === "string"
        ? repairedRecord.id
        : finalProviderRequestId;
      totalInputTokens += repairedInputTokens!;
      totalOutputTokens += repairedOutputTokens!;
    }
    const responsePayload: ProxyResponse = {
      message: finalMessage,
      model: finalModel,
      inputTokens: totalInputTokens,
      outputTokens: totalOutputTokens,
      requestId,
      creditsCharged: cost,
      remainingCredits: Number(reserved.balance ?? 0),
    };
    let settled: Record<string, unknown> | null;
    try {
      settled = await settleSuccessDefinitively(userId, requestId, {
        inputTokens: totalInputTokens,
        outputTokens: totalOutputTokens,
        providerRequestId: finalProviderRequestId,
        // The billing ledger keeps usage metadata only. Conversation content is
        // returned to the caller but is never persisted for idempotent replay.
        responsePayload: {},
      });
    } catch (error) {
      if (
        !(error instanceof SuccessSettlementStillAmbiguousError) &&
        !(error instanceof SuccessSettlementUnavailableError)
      ) throw error;
      // The wallet was already debited by the reservation and every success
      // settlement attempt may have committed. Never hide the generated paid
      // reply or retry a broken settlement endpoint as a refund. If the row is
      // still reserved, the scheduled stale-reservation job refunds it.
      reservation = null;
      console.error(error.message);
      return jsonResponse(req, responsePayload);
    }
    if (settled?.state !== "completed") {
      return jsonResponse(
        req,
        { requestId, error: "credit_settlement_failed" },
        503,
      );
    }
    reservation = null;
    return jsonResponse(req, responsePayload);
  } catch (error) {
    if (reservation) {
      try {
        await settleReservation(
          reservation.userId,
          reservation.requestId,
          false,
          {
            failureCode: error instanceof DOMException &&
                error.name === "TimeoutError"
              ? "provider_timeout"
              : "unhandled_proxy_failure",
          },
        );
      } catch (settlementError) {
        // Cleanup must never replace the deterministic client failure. The
        // stale-reservation job remains the refund backstop when settlement is
        // temporarily unavailable.
        console.error("AI failure settlement failed", settlementError);
      }
    }
    return jsonResponse(req, { error: "request_failed" }, 500);
  }
});

function asRecord(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

export function remainingProviderTimeoutMs(
  startedAtMs: number,
  nowMs = Date.now(),
): number {
  const elapsedMs = Math.max(0, nowMs - startedAtMs);
  return Math.max(
    0,
    Math.min(PROVIDER_CALL_CAP_MS, PROVIDER_FLOW_BUDGET_MS - elapsedMs),
  );
}
