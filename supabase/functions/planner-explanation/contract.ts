export const PLANNER_EXPLANATION_SCHEMA_VERSION = 1;
export const PLANNER_EXPLANATION_DISCLOSURE_VERSION = 1;
export const PLANNER_EXPLANATION_RESPONSE_SCHEMA_VERSION = 1;
export const PLANNER_EXPLANATION_SURFACE = "smart_planner_explanation";
export const PLANNER_EXPLANATION_PROVIDER = "Anthropic";
export const PLANNER_EXPLANATION_PROMPT_VERSION =
  "smart-planner-explanation-v1";
export const PLANNER_EXPLANATION_REPLAY_WINDOW_SECONDS = 240;
export const PLANNER_EXPLANATION_PROVIDER_RETENTION_STATUS =
  "verified_external_gate";
export const PLANNER_EXPLANATION_TRANSMITTED_DATA_CATEGORIES = Object.freeze([
  "planner_response_digest",
  "visible_clause_identifiers",
  "visible_clause_text",
]);

const REQUEST_ID_PATTERN = /^[A-Za-z0-9._:=+-]{8,200}$/;
const DIGEST_PATTERN = /^[0-9a-f]{64}$/;
const CLAUSE_ID_PATTERN = /^[a-z0-9_]{1,64}$/;
const QUOTE_ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const MAX_CLAUSES = 12;
const MAX_CLAUSE_LENGTH = 500;
const MAX_TOTAL_CLAUSE_LENGTH = 5000;
const MAX_EXPLANATION_LENGTH = 1200;

const COMMON_KEYS = [
  "schemaVersion",
  "operation",
  "surface",
  "requestId",
  "responseDigest",
  "clauses",
] as const;
const EXECUTE_KEYS = [
  ...COMMON_KEYS,
  "quoteId",
  "expectedCredits",
  "disclosureVersion",
  "consentAccepted",
] as const;
const PROVIDER_OUTPUT_KEYS = [
  "schemaVersion",
  "responseDigest",
  "explanation",
  "sourceClauseIds",
] as const;
const CLIENT_AUTHORITY_FIELDS = new Set([
  "system",
  "model",
  "modelId",
  "modelLabel",
  "account",
  "accountId",
  "user",
  "userId",
  "action",
  "actions",
  "tool",
  "tools",
  "prompt",
  "message",
  "history",
  "maxTokens",
  "question",
  "userQuestion",
]);

export interface PlannerClause {
  id: string;
  text: string;
}

interface CommonPlannerRequest {
  schemaVersion: 1;
  surface: typeof PLANNER_EXPLANATION_SURFACE;
  requestId: string;
  responseDigest: string;
  clauses: PlannerClause[];
}

export interface PlannerQuoteRequest extends CommonPlannerRequest {
  operation: "quote";
}

export interface PlannerExecuteRequest extends CommonPlannerRequest {
  operation: "execute";
  quoteId: string;
  expectedCredits: number;
  disclosureVersion: 1;
  consentAccepted: boolean;
}

export type PlannerRequest = PlannerQuoteRequest | PlannerExecuteRequest;

export interface ValidatedProviderOutput {
  schemaVersion: 1;
  responseDigest: string;
  explanation: string;
  sourceClauseIds: string[];
}

export interface ModelPolicy {
  id: string;
  label: string;
  allowlisted: boolean;
  evaluationApproved: boolean;
}

export class ContractFailure extends Error {
  constructor(
    readonly code: string,
    readonly status: number,
  ) {
    super(code);
    this.name = "ContractFailure";
  }
}

export class ProviderOutputFailure extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "ProviderOutputFailure";
  }
}

export function isExplicitlyEnabled(value: string | undefined): boolean {
  return value === "true";
}

export function requestIdFromUnknown(value: unknown): string | undefined {
  if (!isRecord(value)) return undefined;
  const requestId = value.requestId;
  return typeof requestId === "string" && REQUEST_ID_PATTERN.test(requestId)
    ? requestId
    : undefined;
}

export async function parsePlannerRequest(
  value: unknown,
): Promise<PlannerRequest> {
  if (!isRecord(value)) {
    throw new ContractFailure("invalid_request_schema", 400);
  }
  const keys = Object.keys(value);
  if (keys.some((key) => CLIENT_AUTHORITY_FIELDS.has(key))) {
    throw new ContractFailure("client_authority_forbidden", 400);
  }
  const operation = value.operation;
  if (operation !== "quote" && operation !== "execute") {
    throw new ContractFailure("invalid_request_schema", 400);
  }
  requireExactKeys(
    value,
    operation === "quote" ? COMMON_KEYS : EXECUTE_KEYS,
    "unexpected_request_fields",
  );
  if (
    value.schemaVersion !== PLANNER_EXPLANATION_SCHEMA_VERSION ||
    value.surface !== PLANNER_EXPLANATION_SURFACE ||
    typeof value.requestId !== "string" ||
    !REQUEST_ID_PATTERN.test(value.requestId) ||
    typeof value.responseDigest !== "string" ||
    !DIGEST_PATTERN.test(value.responseDigest)
  ) {
    throw new ContractFailure("invalid_request_schema", 400);
  }

  const clauses = parseClauses(value.clauses);
  const calculatedDigest = await digestVisibleClauses(clauses);
  if (calculatedDigest !== value.responseDigest) {
    throw new ContractFailure("response_digest_mismatch", 400);
  }
  assertRoutineUntrustedInput(clauses);

  const common = {
    schemaVersion: PLANNER_EXPLANATION_SCHEMA_VERSION,
    surface: PLANNER_EXPLANATION_SURFACE,
    requestId: value.requestId,
    responseDigest: value.responseDigest,
    clauses,
  } as const;
  if (operation === "quote") {
    return { ...common, operation };
  }
  if (
    typeof value.quoteId !== "string" ||
    !QUOTE_ID_PATTERN.test(value.quoteId) ||
    !Number.isInteger(value.expectedCredits) ||
    (value.expectedCredits as number) < 1 ||
    (value.expectedCredits as number) > 3 ||
    value.disclosureVersion !== PLANNER_EXPLANATION_DISCLOSURE_VERSION ||
    typeof value.consentAccepted !== "boolean"
  ) {
    throw new ContractFailure("invalid_request_schema", 400);
  }
  return {
    ...common,
    operation,
    quoteId: value.quoteId,
    expectedCredits: value.expectedCredits as number,
    disclosureVersion: PLANNER_EXPLANATION_DISCLOSURE_VERSION,
    consentAccepted: value.consentAccepted,
  };
}

export function expectedCreditsFor(clauses: PlannerClause[]): number {
  return 1 + (JSON.stringify(clauses).length > 120 ? 1 : 0);
}

export async function fullEnvelopeFingerprint(
  request: PlannerRequest,
): Promise<string> {
  return await sha256Hex(canonicalJson(request));
}

export async function plannerInputFingerprint(
  request: PlannerRequest,
): Promise<string> {
  return await sha256Hex(canonicalJson({
    schemaVersion: request.schemaVersion,
    surface: request.surface,
    requestId: request.requestId,
    responseDigest: request.responseDigest,
    clauses: request.clauses,
  }));
}

export async function digestVisibleClauses(
  clauses: PlannerClause[],
): Promise<string> {
  const digestShape = clauses.map(({ id, text }) => ({ id, text }));
  return await sha256Hex(JSON.stringify(digestShape));
}

export function providerPayload(
  request: PlannerRequest,
): Record<string, unknown> {
  return {
    schemaVersion: PLANNER_EXPLANATION_RESPONSE_SCHEMA_VERSION,
    responseDigest: request.responseDigest,
    clauses: request.clauses.map(({ id, text }) => ({ id, text })),
  };
}

export function validateProviderOutput(
  rawText: string,
  request: PlannerExecuteRequest,
): ValidatedProviderOutput {
  const text = rawText.trim();
  if (looksLikeRefusal(text)) {
    throw new ProviderOutputFailure("provider_refusal");
  }
  let decoded: unknown;
  try {
    decoded = JSON.parse(text);
  } catch {
    throw new ProviderOutputFailure("provider_output_invalid");
  }
  if (!isRecord(decoded)) {
    throw new ProviderOutputFailure("provider_output_invalid");
  }
  try {
    requireExactKeys(
      decoded,
      PROVIDER_OUTPUT_KEYS,
      "provider_output_invalid",
    );
  } catch {
    throw new ProviderOutputFailure("provider_output_invalid");
  }
  if (
    decoded.schemaVersion !== PLANNER_EXPLANATION_RESPONSE_SCHEMA_VERSION ||
    decoded.responseDigest !== request.responseDigest ||
    typeof decoded.explanation !== "string" ||
    decoded.explanation !== decoded.explanation.trim() ||
    decoded.explanation.length < 1 ||
    decoded.explanation.length > MAX_EXPLANATION_LENGTH ||
    hasDisallowedControlCharacters(decoded.explanation, true) ||
    !Array.isArray(decoded.sourceClauseIds) ||
    decoded.sourceClauseIds.length < 1 ||
    decoded.sourceClauseIds.length > request.clauses.length ||
    decoded.sourceClauseIds.some((id) => typeof id !== "string")
  ) {
    throw new ProviderOutputFailure("provider_output_invalid");
  }

  const sourceClauseIds = decoded.sourceClauseIds as string[];
  const uniqueIds = new Set(sourceClauseIds);
  const allowedIds = new Set(request.clauses.map((clause) => clause.id));
  if (
    uniqueIds.size !== sourceClauseIds.length ||
    sourceClauseIds.some((id) => !allowedIds.has(id))
  ) {
    throw new ProviderOutputFailure("provider_output_unsafe");
  }
  if (looksLikeRefusal(decoded.explanation)) {
    throw new ProviderOutputFailure("provider_refusal");
  }
  assertSafeExplanation(
    decoded.explanation,
    sourceClauseIds,
    request.clauses,
  );
  return {
    schemaVersion: PLANNER_EXPLANATION_RESPONSE_SCHEMA_VERSION,
    responseDigest: request.responseDigest,
    explanation: decoded.explanation,
    sourceClauseIds: [...sourceClauseIds],
  };
}

export function canonicalJson(value: unknown): string {
  if (
    value === null || typeof value === "boolean" ||
    typeof value === "string"
  ) {
    return JSON.stringify(value);
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new ContractFailure("invalid_request_schema", 400);
    }
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(",")}]`;
  }
  if (isRecord(value)) {
    const entries = Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${canonicalJson(value[key])}`
    );
    return `{${entries.join(",")}}`;
  }
  throw new ContractFailure("invalid_request_schema", 400);
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function parseClauses(value: unknown): PlannerClause[] {
  if (!Array.isArray(value) || value.length < 1 || value.length > MAX_CLAUSES) {
    throw new ContractFailure("invalid_clauses", 400);
  }
  let totalLength = 0;
  const ids = new Set<string>();
  const clauses = value.map((candidate) => {
    if (!isRecord(candidate)) {
      throw new ContractFailure("invalid_clauses", 400);
    }
    requireExactKeys(candidate, ["id", "text"], "invalid_clauses");
    const id = candidate.id;
    const text = candidate.text;
    if (
      typeof id !== "string" || !CLAUSE_ID_PATTERN.test(id) ||
      typeof text !== "string" || text !== text.trim() || text.length < 1 ||
      text.length > MAX_CLAUSE_LENGTH ||
      hasDisallowedControlCharacters(text, false) || ids.has(id)
    ) {
      throw new ContractFailure("invalid_clauses", 400);
    }
    ids.add(id);
    totalLength += text.length;
    return { id, text };
  });
  if (totalLength > MAX_TOTAL_CLAUSE_LENGTH) {
    throw new ContractFailure("invalid_clauses", 400);
  }
  return clauses;
}

function assertRoutineUntrustedInput(clauses: PlannerClause[]): void {
  const joined = clauses.map((clause) => clause.text).join("\n");
  const normalized = safetyNormalized(joined);
  const compact = normalized.replace(/[^a-z0-9]+/g, "");
  const distressPatterns = [
    /\b(?:suicide|suicidal|self harm|self harming)\b/,
    /\b(?:kill|hurt|harm) (?:myself|me)\b/,
    /\b(?:end|take) my (?:own )?life\b/,
    /\b(?:want|wish|plan|planning|ready) to die\b/,
    /\b(?:cannot|cant) go on\b/,
    /\bbetter off without me\b/,
    /\b(?:overdose|overdosed|overdosing|poisoned myself)\b/,
    /\b(?:not safe|in danger|threatened to kill me)\b/,
    /\b(?:panic attack|panicking|cannot breathe|cant breathe)\b/,
    /\b(?:abuse|abused|assault|violence|coercion|coerced|forced me)\b/,
    /\b(?:voices? telling me|commanding me) to (?:hurt|kill|harm)\b/,
    /\b(?:hearing voices|seeing things|hallucinat(?:e|ed|ing|ion|ions))\b/,
    /\b(?:grief|grieving|bereavement|mourning)\b/,
    /\b(?:died|passed away|lost) (?:my |a )?(?:child|parent|partner|spouse|friend|family member|loved one)\b/,
    /\b(?:breakup|broke up|partner left me|relationship is over)\b/,
    /\b(?:hopeless|worthless|cannot cope|cant cope|falling apart)\b/,
    /\b(?:suicidio|suicida|autolesion|quiero morir|matarme)\b/,
  ];
  const compactDistress = [
    "killmyself",
    "endmylife",
    "hurtmyself",
    "selfharm",
    "wanttodie",
    "quitarmeelavida",
    "quieromorir",
  ];
  if (
    distressPatterns.some((pattern) => pattern.test(normalized)) ||
    compactDistress.some((marker) => compact.includes(marker))
  ) {
    throw new ContractFailure("distress_input_rejected", 422);
  }

  const instructionPatterns = [
    /\bignore (?:all|any|the|my|previous|prior|above) instructions?\b/,
    /\b(?:system prompt|developer message|hidden instructions?)\b/,
    /\b(?:act|behave|respond) as (?:the )?(?:system|developer|assistant)\b/,
    /\b(?:reveal|show|print|repeat) (?:the |your )?(?:prompt|instructions?|secrets?)\b/,
    /\b(?:call|invoke|use) (?:a |the )?(?:tool|function|api)\b/,
    /\b(?:execute|run) (?:this |the )?(?:command|code|script)\b/,
    /\b(?:override|bypass|disable) (?:the )?(?:rules?|safety|deterministic plan)\b/,
    /\b(?:send|exfiltrate|upload) (?:account|user|private|secret) data\b/,
    /(?:^|\s)(?:system|developer|assistant)\s*:/,
  ];
  if (instructionPatterns.some((pattern) => pattern.test(normalized))) {
    throw new ContractFailure("untrusted_clause_rejected", 422);
  }
}

function assertSafeExplanation(
  explanation: string,
  sourceClauseIds: string[],
  clauses: PlannerClause[],
): void {
  const normalized = safetyNormalized(explanation);
  const unsafePatterns = [
    /\b(?:diagnos(?:e|ed|is|tic)|disorder|mental illness|medical condition)\b/,
    /\b(?:as your therapist|i am your therapist|therapy|treatment plan)\b/,
    /\b(?:you are|youre|you feel|you seem|you sound|you must be|you have)\b/,
    /\b(?:your identity is|as a person who|the kind of person you are)\b/,
    /\b(?:i|we|chronospark|the planner|the system) (?:have )?(?:saved|moved|changed|created|deleted|completed|scheduled|sent|booked|updated|executed)\b/,
    /\b(?:was|has been|is now) (?:saved|moved|changed|created|deleted|completed|scheduled|sent|booked|updated|executed)\b/,
    /\b(?:you must|you should|you need to|you have to)\b/,
    /\b(?:urgent|immediately|right now|only choice|no excuse|before it is too late|guaranteed)\b/,
    /\b(?:override|ignore|bypass) (?:the )?deterministic\b/,
    /\b(?:confirmation is unnecessary|without confirmation|consent is unnecessary)\b/,
  ];
  if (unsafePatterns.some((pattern) => pattern.test(normalized))) {
    throw new ProviderOutputFailure("provider_output_unsafe");
  }

  const sourceIdSet = new Set(sourceClauseIds);
  const sourceText = clauses
    .filter((clause) => sourceIdSet.has(clause.id))
    .map((clause) => clause.text)
    .join(" ");
  const sourceNumbers = extractNumericClaims(sourceText);
  const outputNumbers = extractNumericClaims(explanation);
  if ([...outputNumbers].some((claim) => !sourceNumbers.has(claim))) {
    throw new ProviderOutputFailure("provider_output_unsafe");
  }
}

function extractNumericClaims(value: string): Set<string> {
  const claims = new Set<string>();
  for (const match of value.toLowerCase().matchAll(/\b\d+(?:\.\d+)?%?\b/g)) {
    claims.add(normalizeNumericClaim(match[0]));
  }
  const wordNumbers: Record<string, string> = {
    zero: "0",
    one: "1",
    first: "1",
    two: "2",
    second: "2",
    three: "3",
    third: "3",
    four: "4",
    fourth: "4",
    five: "5",
    fifth: "5",
    six: "6",
    sixth: "6",
    seven: "7",
    seventh: "7",
    eight: "8",
    eighth: "8",
    nine: "9",
    ninth: "9",
    ten: "10",
    tenth: "10",
  };
  for (
    const match of value.toLowerCase().matchAll(
      /\b(?:zero|one|first|two|second|three|third|four|fourth|five|fifth|six|sixth|seven|seventh|eight|eighth|nine|ninth|ten|tenth)\b/g,
    )
  ) {
    claims.add(wordNumbers[match[0]]);
  }
  return claims;
}

function normalizeNumericClaim(value: string): string {
  const percent = value.endsWith("%");
  const numberText = percent ? value.slice(0, -1) : value;
  const numeric = Number(numberText);
  return `${Number.isFinite(numeric) ? numeric.toString() : numberText}${
    percent ? "%" : ""
  }`;
}

function looksLikeRefusal(value: string): boolean {
  const normalized = safetyNormalized(value);
  return /^(?:\{\s*)?(?:i (?:cannot|cant|wont|will not|am unable)|sorry[, ]|unable to comply|request refused)\b/
    .test(normalized);
}

function safetyNormalized(value: string): string {
  return value
    .normalize("NFKC")
    .toLowerCase()
    .replace(/[\u200b-\u200d\ufeff]/g, "")
    .replaceAll("0", "o")
    .replaceAll("1", "i")
    .replaceAll("3", "e")
    .replaceAll("4", "a")
    .replaceAll("5", "s")
    .replaceAll("7", "t")
    .replace(/[’']/g, "")
    .replace(/[^a-z0-9%]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function hasDisallowedControlCharacters(
  value: string,
  allowLayoutWhitespace: boolean,
): boolean {
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index);
    if (code === 127) return true;
    if (code < 32 && (!allowLayoutWhitespace || ![9, 10, 13].includes(code))) {
      return true;
    }
  }
  return false;
}

function requireExactKeys(
  value: Record<string, unknown>,
  expectedKeys: readonly string[],
  code: string,
): void {
  const actual = Object.keys(value).sort();
  const expected = [...expectedKeys].sort();
  if (
    actual.length !== expected.length ||
    actual.some((key, index) => key !== expected[index])
  ) {
    throw new ContractFailure(code, 400);
  }
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
