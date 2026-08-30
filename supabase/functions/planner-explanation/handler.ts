import {
  ContractFailure,
  expectedCreditsFor,
  fullEnvelopeFingerprint,
  isRecord,
  type ModelPolicy,
  parsePlannerRequest,
  PLANNER_EXPLANATION_DISCLOSURE_VERSION,
  PLANNER_EXPLANATION_PROMPT_VERSION,
  PLANNER_EXPLANATION_PROVIDER,
  PLANNER_EXPLANATION_PROVIDER_RETENTION_STATUS,
  PLANNER_EXPLANATION_REPLAY_WINDOW_SECONDS,
  PLANNER_EXPLANATION_RESPONSE_SCHEMA_VERSION,
  PLANNER_EXPLANATION_SCHEMA_VERSION,
  PLANNER_EXPLANATION_SURFACE,
  PLANNER_EXPLANATION_TRANSMITTED_DATA_CATEGORIES,
  type PlannerExecuteRequest,
  plannerInputFingerprint,
  type PlannerRequest,
  ProviderOutputFailure,
  providerPayload,
  requestIdFromUnknown,
  validateProviderOutput,
} from "./contract.ts";

const MAX_REQUEST_BYTES = 16_384;

export interface ProviderCompletion {
  kind: "completed" | "refusal";
  text?: string;
  modelId?: string;
  providerRequestId?: string;
  inputTokens?: number;
  outputTokens?: number;
}

export interface ProviderClient {
  complete(
    input: Record<string, unknown>,
    signal: AbortSignal,
  ): Promise<ProviderCompletion>;
}

export interface QuoteIssueInput {
  userId: string;
  requestId: string;
  quoteFingerprint: string;
  inputFingerprint: string;
  expectedCredits: number;
  modelId: string;
  modelLabel: string;
  promptVersion: string;
}

export interface QuoteVerifyInput {
  userId: string;
  requestId: string;
  quoteId: string;
  inputFingerprint: string;
  expectedCredits: number;
  disclosureVersion: number;
  modelId: string;
  modelLabel: string;
  promptVersion: string;
}

export interface ReserveInput {
  userId: string;
  requestId: string;
  expectedCredits: number;
  envelopeFingerprint: string;
}

export interface SettleInput {
  userId: string;
  requestId: string;
  succeeded: boolean;
  inputTokens?: number;
  outputTokens?: number;
  providerRequestId?: string;
  failureCode?: string;
  responsePayload?: Record<string, unknown>;
  contentExpiresAt?: string;
}

export interface PlannerExplanationStore {
  issueQuote(input: QuoteIssueInput): Promise<Record<string, unknown> | null>;
  verifyQuote(input: QuoteVerifyInput): Promise<Record<string, unknown> | null>;
  reserveUsage(input: ReserveInput): Promise<Record<string, unknown> | null>;
  settleUsage(input: SettleInput): Promise<Record<string, unknown> | null>;
  loadReplay(
    userId: string,
    requestId: string,
  ): Promise<Record<string, unknown> | null>;
  scrubReplay(
    userId: string,
    requestId: string,
  ): Promise<Record<string, unknown> | null>;
}

export interface PlannerExplanationDependencies {
  authenticate(req: Request): Promise<string | null>;
  consumeRateLimit(req: Request, userId: string): Promise<boolean>;
  store: PlannerExplanationStore;
  provider: ProviderClient;
  externalAiEnabled: boolean;
  providerRetentionVerified: boolean;
  safetyReviewApproved: boolean;
  serviceConfigured: boolean;
  modelPolicy: ModelPolicy;
  now(): Date;
  providerTimeoutMs: number;
  allowedOrigins?: ReadonlySet<string>;
}

export class ProviderTransportFailure extends Error {
  constructor() {
    super("provider_failure");
    this.name = "ProviderTransportFailure";
  }
}

class ProviderTimeoutFailure extends Error {
  constructor() {
    super("provider_timeout");
    this.name = "ProviderTimeoutFailure";
  }
}

export function createPlannerExplanationHandler(
  dependencies: PlannerExplanationDependencies,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") {
      return new Response("ok", {
        headers: responseHeaders(req, dependencies),
      });
    }
    if (req.method !== "POST") {
      return errorResponse(
        req,
        dependencies,
        undefined,
        "method_not_allowed",
        405,
      );
    }

    let raw: unknown;
    try {
      raw = await readBoundedJson(req);
    } catch (error) {
      const failure = error instanceof ContractFailure
        ? error
        : new ContractFailure("invalid_json", 400);
      return errorResponse(
        req,
        dependencies,
        undefined,
        failure.code,
        failure.status,
      );
    }
    const requestId = requestIdFromUnknown(raw);

    let userId: string | null;
    try {
      userId = await dependencies.authenticate(req);
    } catch {
      userId = null;
    }
    if (!userId) {
      return errorResponse(req, dependencies, requestId, "unauthorized", 401);
    }
    let rateAllowed = false;
    try {
      rateAllowed = await dependencies.consumeRateLimit(req, userId);
    } catch {
      rateAllowed = false;
    }
    if (!rateAllowed) {
      return errorResponse(
        req,
        dependencies,
        requestId,
        "rate_limit_exceeded",
        429,
      );
    }
    if (!dependencies.externalAiEnabled) {
      return errorResponse(
        req,
        dependencies,
        requestId,
        "external_ai_disabled",
        403,
      );
    }
    if (!dependencies.providerRetentionVerified) {
      return errorResponse(
        req,
        dependencies,
        requestId,
        "provider_retention_unverified",
        503,
      );
    }
    if (!dependencies.safetyReviewApproved) {
      return errorResponse(
        req,
        dependencies,
        requestId,
        "safety_review_required",
        503,
      );
    }
    if (!dependencies.serviceConfigured) {
      return errorResponse(
        req,
        dependencies,
        requestId,
        "service_not_configured",
        503,
      );
    }
    if (
      !dependencies.modelPolicy.allowlisted ||
      !dependencies.modelPolicy.evaluationApproved
    ) {
      return errorResponse(
        req,
        dependencies,
        requestId,
        "model_not_approved",
        503,
      );
    }

    let request: PlannerRequest;
    try {
      request = await parsePlannerRequest(raw);
    } catch (error) {
      const failure = error instanceof ContractFailure
        ? error
        : new ContractFailure("invalid_request_schema", 400);
      return errorResponse(
        req,
        dependencies,
        requestId,
        failure.code,
        failure.status,
      );
    }

    if (request.operation === "quote") {
      return await handleQuote(req, dependencies, userId, request);
    }
    return await handleExecute(req, dependencies, userId, request);
  };
}

async function handleQuote(
  req: Request,
  dependencies: PlannerExplanationDependencies,
  userId: string,
  request: PlannerRequest & { operation: "quote" },
): Promise<Response> {
  const expectedCredits = expectedCreditsFor(request.clauses);
  const [quoteFingerprint, inputFingerprint] = await Promise.all([
    fullEnvelopeFingerprint(request),
    plannerInputFingerprint(request),
  ]);
  let issued: Record<string, unknown> | null;
  try {
    issued = await dependencies.store.issueQuote({
      userId,
      requestId: request.requestId,
      quoteFingerprint,
      inputFingerprint,
      expectedCredits,
      modelId: dependencies.modelPolicy.id,
      modelLabel: dependencies.modelPolicy.label,
      promptVersion: PLANNER_EXPLANATION_PROMPT_VERSION,
    });
  } catch {
    issued = null;
  }
  if (!issued) {
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      "quote_service_unavailable",
      503,
    );
  }
  if (issued.issued !== true) {
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      quoteFailureCode(issued.reason),
      409,
    );
  }
  const quoteId = typeof issued.quoteId === "string" ? issued.quoteId : "";
  const expiresAt = utcIso(issued.expiresAt);
  if (!quoteId || !expiresAt) {
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      "quote_service_unavailable",
      503,
    );
  }
  return jsonResponse(req, dependencies, {
    schemaVersion: PLANNER_EXPLANATION_SCHEMA_VERSION,
    operation: "quote",
    surface: PLANNER_EXPLANATION_SURFACE,
    requestId: request.requestId,
    quoteId,
    expectedCredits,
    provider: PLANNER_EXPLANATION_PROVIDER,
    modelLabel: dependencies.modelPolicy.label,
    promptVersion: PLANNER_EXPLANATION_PROMPT_VERSION,
    responseSchemaVersion: PLANNER_EXPLANATION_RESPONSE_SCHEMA_VERSION,
    disclosureVersion: PLANNER_EXPLANATION_DISCLOSURE_VERSION,
    transmittedDataCategories: [
      ...PLANNER_EXPLANATION_TRANSMITTED_DATA_CATEGORIES,
    ],
    replayWindowSeconds: PLANNER_EXPLANATION_REPLAY_WINDOW_SECONDS,
    providerRetentionStatus: PLANNER_EXPLANATION_PROVIDER_RETENTION_STATUS,
    expiresAt,
  });
}

async function handleExecute(
  req: Request,
  dependencies: PlannerExplanationDependencies,
  userId: string,
  request: PlannerExecuteRequest,
): Promise<Response> {
  const serverCost = expectedCreditsFor(request.clauses);
  if (request.expectedCredits !== serverCost) {
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      "expected_credits_mismatch",
      409,
    );
  }
  if (!request.consentAccepted) {
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      "explicit_consent_required",
      403,
    );
  }

  const inputFingerprint = await plannerInputFingerprint(request);
  let verified: Record<string, unknown> | null;
  try {
    verified = await dependencies.store.verifyQuote({
      userId,
      requestId: request.requestId,
      quoteId: request.quoteId,
      inputFingerprint,
      expectedCredits: serverCost,
      disclosureVersion: request.disclosureVersion,
      modelId: dependencies.modelPolicy.id,
      modelLabel: dependencies.modelPolicy.label,
      promptVersion: PLANNER_EXPLANATION_PROMPT_VERSION,
    });
  } catch {
    verified = null;
  }
  if (!verified) {
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      "quote_service_unavailable",
      503,
    );
  }
  if (verified.valid !== true) {
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      quoteFailureCode(verified.reason),
      409,
    );
  }

  const envelopeFingerprint = await fullEnvelopeFingerprint(request);
  let reservation: Record<string, unknown> | null;
  try {
    reservation = await dependencies.store.reserveUsage({
      userId,
      requestId: request.requestId,
      expectedCredits: serverCost,
      envelopeFingerprint,
    });
  } catch {
    reservation = null;
  }
  if (!reservation) {
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      "credit_reservation_failed",
      503,
    );
  }

  if (reservation.duplicate === true) {
    return await handleDuplicate(
      req,
      dependencies,
      userId,
      request,
      reservation,
    );
  }
  if (reservation.allowed !== true) {
    const reason = typeof reservation.reason === "string"
      ? reservation.reason
      : "credits_unavailable";
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      reservationFailureCode(reason),
      reservationFailureStatus(reason),
    );
  }

  const remainingCredits = nonnegativeInteger(reservation.balance);
  if (remainingCredits === null) {
    await safeRefund(
      dependencies,
      userId,
      request.requestId,
      "invalid_reservation_result",
    );
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      "credit_reservation_failed",
      503,
    );
  }

  let completion: ProviderCompletion;
  try {
    completion = await completeWithTimeout(
      dependencies.provider,
      providerPayload(request),
      dependencies.providerTimeoutMs,
    );
  } catch (error) {
    const timedOut = error instanceof ProviderTimeoutFailure;
    await safeRefund(
      dependencies,
      userId,
      request.requestId,
      timedOut ? "provider_timeout" : "provider_failure",
    );
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      timedOut ? "provider_timeout" : "provider_failure",
      timedOut ? 504 : 502,
    );
  }

  if (completion.kind === "refusal") {
    await safeRefund(
      dependencies,
      userId,
      request.requestId,
      "provider_refusal",
      completion,
    );
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      "provider_refusal",
      422,
    );
  }
  if (
    completion.modelId !== dependencies.modelPolicy.id ||
    typeof completion.text !== "string"
  ) {
    await safeRefund(
      dependencies,
      userId,
      request.requestId,
      "provider_output_invalid",
      completion,
    );
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      "provider_output_invalid",
      502,
    );
  }

  let output;
  try {
    output = validateProviderOutput(completion.text, request);
  } catch (error) {
    const code = error instanceof ProviderOutputFailure
      ? error.code
      : "provider_output_invalid";
    await safeRefund(
      dependencies,
      userId,
      request.requestId,
      code,
      completion,
    );
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      code,
      code === "provider_output_invalid" ? 502 : 422,
    );
  }

  const contentExpiresAt = new Date(
    dependencies.now().getTime() +
      PLANNER_EXPLANATION_REPLAY_WINDOW_SECONDS * 1000,
  ).toISOString();
  const responsePayload = {
    schemaVersion: PLANNER_EXPLANATION_SCHEMA_VERSION,
    operation: "execute",
    surface: PLANNER_EXPLANATION_SURFACE,
    requestId: request.requestId,
    status: "completed",
    responseDigest: output.responseDigest,
    explanation: output.explanation,
    sourceClauseIds: output.sourceClauseIds,
    provider: PLANNER_EXPLANATION_PROVIDER,
    modelLabel: dependencies.modelPolicy.label,
    promptVersion: PLANNER_EXPLANATION_PROMPT_VERSION,
    responseSchemaVersion: PLANNER_EXPLANATION_RESPONSE_SCHEMA_VERSION,
    expectedCredits: serverCost,
    creditsCharged: serverCost,
    remainingCredits,
    contentExpiresAt,
    replayState: "fresh",
  };

  let settled: Record<string, unknown> | null;
  try {
    settled = await dependencies.store.settleUsage({
      userId,
      requestId: request.requestId,
      succeeded: true,
      inputTokens: boundedTokenCount(completion.inputTokens),
      outputTokens: boundedTokenCount(completion.outputTokens),
      providerRequestId: completion.providerRequestId,
      responsePayload,
      contentExpiresAt,
    });
  } catch {
    settled = null;
  }
  if (settled?.state !== "completed") {
    await safeRefund(
      dependencies,
      userId,
      request.requestId,
      "completion_settlement_failed",
      completion,
    );
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      "completion_settlement_failed",
      503,
    );
  }
  return jsonResponse(req, dependencies, responsePayload);
}

async function handleDuplicate(
  req: Request,
  dependencies: PlannerExplanationDependencies,
  userId: string,
  request: PlannerExecuteRequest,
  reservation: Record<string, unknown>,
): Promise<Response> {
  const state = typeof reservation.state === "string"
    ? reservation.state
    : "unknown";
  if (state !== "completed") {
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      `request_${safeState(state)}`,
      409,
    );
  }
  let loaded: Record<string, unknown> | null;
  try {
    loaded = await dependencies.store.loadReplay(userId, request.requestId);
  } catch {
    loaded = null;
  }
  if (!loaded || loaded.found !== true) {
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      "replay_unavailable",
      503,
    );
  }
  const payload = loaded.responsePayload;
  const stored = validatedStoredResponse(payload, request);
  if (!stored) {
    return errorResponse(
      req,
      dependencies,
      request.requestId,
      "replay_unavailable",
      409,
    );
  }
  if (stored.status === "replay_expired") {
    return jsonResponse(req, dependencies, stored.payload);
  }
  if (stored.expiresAt.getTime() <= dependencies.now().getTime()) {
    let scrubbed: Record<string, unknown> | null;
    try {
      scrubbed = await dependencies.store.scrubReplay(
        userId,
        request.requestId,
      );
    } catch {
      scrubbed = null;
    }
    if (scrubbed?.scrubbed !== true) {
      return errorResponse(
        req,
        dependencies,
        request.requestId,
        "replay_scrub_failed",
        503,
      );
    }
    return jsonResponse(
      req,
      dependencies,
      scrubbedReplayPayload(stored.payload),
    );
  }
  return jsonResponse(req, dependencies, {
    ...stored.payload,
    creditsCharged: 0,
    replayState: "replayed",
  });
}

function validatedStoredResponse(
  value: unknown,
  request: PlannerExecuteRequest,
):
  | {
    status: "completed";
    expiresAt: Date;
    payload: Record<string, unknown>;
  }
  | {
    status: "replay_expired";
    payload: Record<string, unknown>;
  }
  | null {
  if (!isRecord(value)) return null;
  const baseValid =
    value.schemaVersion === PLANNER_EXPLANATION_SCHEMA_VERSION &&
    value.operation === "execute" &&
    value.surface === PLANNER_EXPLANATION_SURFACE &&
    value.requestId === request.requestId &&
    value.responseDigest === request.responseDigest &&
    value.provider === PLANNER_EXPLANATION_PROVIDER &&
    typeof value.modelLabel === "string" && value.modelLabel.length > 0 &&
    typeof value.promptVersion === "string" && value.promptVersion.length > 0 &&
    value.responseSchemaVersion ===
      PLANNER_EXPLANATION_RESPONSE_SCHEMA_VERSION &&
    value.expectedCredits === request.expectedCredits &&
    nonnegativeInteger(value.remainingCredits) !== null;
  if (!baseValid) return null;

  if (value.status === "replay_expired") {
    if (
      !hasExactKeys(value, [
        "schemaVersion",
        "operation",
        "surface",
        "requestId",
        "status",
        "responseDigest",
        "provider",
        "modelLabel",
        "promptVersion",
        "responseSchemaVersion",
        "expectedCredits",
        "creditsCharged",
        "remainingCredits",
        "replayState",
      ]) || value.creditsCharged !== 0 ||
      value.replayState !== "content_scrubbed"
    ) return null;
    return { status: "replay_expired", payload: { ...value } };
  }
  if (
    value.status !== "completed" ||
    !hasExactKeys(value, [
      "schemaVersion",
      "operation",
      "surface",
      "requestId",
      "status",
      "responseDigest",
      "explanation",
      "sourceClauseIds",
      "provider",
      "modelLabel",
      "promptVersion",
      "responseSchemaVersion",
      "expectedCredits",
      "creditsCharged",
      "remainingCredits",
      "contentExpiresAt",
      "replayState",
    ]) || value.creditsCharged !== request.expectedCredits ||
    value.replayState !== "fresh" || typeof value.explanation !== "string" ||
    !Array.isArray(value.sourceClauseIds)
  ) return null;
  try {
    validateProviderOutput(
      JSON.stringify({
        schemaVersion: PLANNER_EXPLANATION_RESPONSE_SCHEMA_VERSION,
        responseDigest: value.responseDigest,
        explanation: value.explanation,
        sourceClauseIds: value.sourceClauseIds,
      }),
      request,
    );
  } catch {
    return null;
  }
  const expiresAt = parseUtcDate(value.contentExpiresAt);
  if (!expiresAt) return null;
  return { status: "completed", expiresAt, payload: { ...value } };
}

export function scrubbedReplayPayload(
  completedPayload: Record<string, unknown>,
): Record<string, unknown> {
  return {
    schemaVersion: completedPayload.schemaVersion,
    operation: completedPayload.operation,
    surface: completedPayload.surface,
    requestId: completedPayload.requestId,
    status: "replay_expired",
    responseDigest: completedPayload.responseDigest,
    provider: completedPayload.provider,
    modelLabel: completedPayload.modelLabel,
    promptVersion: completedPayload.promptVersion,
    responseSchemaVersion: completedPayload.responseSchemaVersion,
    expectedCredits: completedPayload.expectedCredits,
    creditsCharged: 0,
    remainingCredits: completedPayload.remainingCredits,
    replayState: "content_scrubbed",
  };
}

async function safeRefund(
  dependencies: PlannerExplanationDependencies,
  userId: string,
  requestId: string,
  failureCode: string,
  completion?: ProviderCompletion,
): Promise<void> {
  try {
    await dependencies.store.settleUsage({
      userId,
      requestId,
      succeeded: false,
      inputTokens: boundedTokenCount(completion?.inputTokens),
      outputTokens: boundedTokenCount(completion?.outputTokens),
      providerRequestId: completion?.providerRequestId,
      failureCode,
    });
  } catch {
    // The stale-reservation database job is the final refund backstop.
  }
}

async function completeWithTimeout(
  provider: ProviderClient,
  input: Record<string, unknown>,
  timeoutMs: number,
): Promise<ProviderCompletion> {
  const controller = new AbortController();
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_resolve, reject) => {
    timer = setTimeout(() => {
      controller.abort();
      reject(new ProviderTimeoutFailure());
    }, timeoutMs);
  });
  try {
    return await Promise.race([
      provider.complete(input, controller.signal),
      timeout,
    ]);
  } finally {
    if (timer !== undefined) clearTimeout(timer);
  }
}

async function readBoundedJson(req: Request): Promise<unknown> {
  const contentType = req.headers.get("content-type")?.toLowerCase() ?? "";
  if (!contentType.startsWith("application/json")) {
    throw new ContractFailure("invalid_content_type", 415);
  }
  const contentLength = Number(req.headers.get("content-length") ?? "0");
  if (Number.isFinite(contentLength) && contentLength > MAX_REQUEST_BYTES) {
    throw new ContractFailure("request_too_large", 413);
  }
  const text = await req.text();
  if (new TextEncoder().encode(text).byteLength > MAX_REQUEST_BYTES) {
    throw new ContractFailure("request_too_large", 413);
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new ContractFailure("invalid_json", 400);
  }
}

function jsonResponse(
  req: Request,
  dependencies: PlannerExplanationDependencies,
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...responseHeaders(req, dependencies),
      "Content-Type": "application/json",
    },
  });
}

function errorResponse(
  req: Request,
  dependencies: PlannerExplanationDependencies,
  requestId: string | undefined,
  error: string,
  status: number,
): Response {
  return jsonResponse(
    req,
    dependencies,
    requestId ? { requestId, error } : { error },
    status,
  );
}

function responseHeaders(
  req: Request,
  dependencies: PlannerExplanationDependencies,
): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  return {
    ...(dependencies.allowedOrigins?.has(origin)
      ? { "Access-Control-Allow-Origin": origin }
      : {}),
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Cache-Control": "no-store",
    "Vary": "Origin",
    "X-Content-Type-Options": "nosniff",
    "X-ChronoSpark-Contract": "planner-explanation-v1",
  };
}

function quoteFailureCode(reason: unknown): string {
  if (reason === "idempotency_mismatch") return "quote_mismatch";
  if (reason === "quote_expired") return "quote_expired";
  if (reason === "quote_not_found") return "quote_not_found";
  return "quote_invalid";
}

function reservationFailureCode(reason: string): string {
  if (reason === "idempotency_mismatch") return "idempotency_mismatch";
  if (reason === "daily_budget_exceeded") return "daily_budget_exceeded";
  if (reason === "insufficient_credits") return "insufficient_credits";
  return "credits_unavailable";
}

function reservationFailureStatus(reason: string): number {
  if (reason === "idempotency_mismatch") return 409;
  if (reason === "daily_budget_exceeded") return 429;
  if (reason === "insufficient_credits") return 402;
  return 503;
}

function safeState(state: string): string {
  return /^[a-z_]{1,40}$/.test(state) ? state : "unavailable";
}

function boundedTokenCount(value: unknown): number | undefined {
  return Number.isInteger(value) && (value as number) >= 0 &&
      (value as number) <= 10_000_000
    ? value as number
    : undefined;
}

function nonnegativeInteger(value: unknown): number | null {
  return Number.isInteger(value) && (value as number) >= 0
    ? value as number
    : null;
}

function utcIso(value: unknown): string | null {
  const parsed = parseUtcDate(value);
  return parsed?.toISOString() ?? null;
}

function parseUtcDate(value: unknown): Date | null {
  if (typeof value !== "string" || !/(?:Z|[+-]00:00)$/.test(value)) {
    return null;
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function hasExactKeys(
  value: Record<string, unknown>,
  keys: readonly string[],
): boolean {
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  return actual.length === expected.length &&
    actual.every((key, index) => key === expected[index]);
}
