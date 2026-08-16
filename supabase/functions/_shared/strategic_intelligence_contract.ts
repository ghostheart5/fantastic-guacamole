import { hasOnlyKeys } from "./edge_http.ts";

const inputKinds = new Set([
  "text",
  "voiceTranscript",
  "imageLabel",
  "uiState",
  "sensorSignal",
  "timeTrigger",
  "behaviorPattern",
  "contextDocument",
]);
const outputKinds = new Set([
  "answer",
  "recommendedActions",
  "planningOptions",
  "riskWarnings",
  "progressSignals",
  "trajectory",
  "followUpQuestions",
]);
const contextSources = new Set([
  "tasks",
  "goals",
  "calendar",
  "timeline",
  "progression",
  "plan",
  "memories",
]);
const requestKeys = new Set([
  "schemaVersion",
  "requestId",
  "inputs",
  "requestedOutputs",
  "allowedContextSources",
  "signals",
  "locale",
  "maxRecommendations",
  "occurredAt",
  "context",
]);

export interface StrategicIntelligenceInput {
  kind: string;
  value: string;
  confidence: number;
  attributes: Record<string, unknown>;
}

export interface StrategicIntelligenceFact {
  source: string;
  id: string;
  label: string;
  observedAt: string;
  relevance: number;
  attributes: Record<string, unknown>;
}

export interface StrategicIntelligenceRequest {
  schemaVersion: 1;
  requestId: string;
  inputs: StrategicIntelligenceInput[];
  requestedOutputs: string[];
  allowedContextSources: string[];
  signals: Record<string, number>;
  locale: string;
  maxRecommendations: number;
  occurredAt: string;
  context: {
    facts: StrategicIntelligenceFact[];
    metrics: Record<string, number>;
  };
}

function boundedObject(
  value: unknown,
  maxKeys: number,
): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  return Object.keys(record).length <= maxKeys ? record : null;
}

function validAttributes(value: unknown): Record<string, unknown> | null {
  const record = boundedObject(value ?? {}, 12);
  if (!record) return null;
  const serialized = JSON.stringify(record);
  return serialized.length <= 2_000 ? record : null;
}

function unitNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 &&
      value <= 1
    ? value
    : null;
}

export function validateStrategicIntelligenceRequest(
  value: unknown,
): StrategicIntelligenceRequest | null {
  const record = boundedObject(value, 11);
  if (
    !record || !hasOnlyKeys(record, requestKeys) || record.schemaVersion !== 1
  ) return null;
  if (
    typeof record.requestId !== "string" ||
    !/^[A-Za-z0-9._:-]{8,128}$/.test(record.requestId) ||
    !Array.isArray(record.inputs) || record.inputs.length < 1 ||
    record.inputs.length > 32 ||
    !Array.isArray(record.requestedOutputs) ||
    record.requestedOutputs.length < 1 ||
    record.requestedOutputs.length > outputKinds.size ||
    !Array.isArray(record.allowedContextSources) ||
    typeof record.locale !== "string" ||
    !/^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})?$/.test(record.locale) ||
    !Number.isInteger(record.maxRecommendations) ||
    (record.maxRecommendations as number) < 1 ||
    (record.maxRecommendations as number) > 12 ||
    typeof record.occurredAt !== "string" ||
    !Number.isFinite(Date.parse(record.occurredAt))
  ) return null;

  const requestedOutputs = [...new Set(record.requestedOutputs)];
  const allowedSources = [...new Set(record.allowedContextSources)];
  if (
    requestedOutputs.some((item) =>
      typeof item !== "string" || !outputKinds.has(item)
    ) ||
    allowedSources.some((item) =>
      typeof item !== "string" || !contextSources.has(item)
    )
  ) return null;

  let totalInputLength = 0;
  const inputs: StrategicIntelligenceInput[] = [];
  for (const rawInput of record.inputs) {
    const input = boundedObject(rawInput, 4);
    if (
      !input ||
      !hasOnlyKeys(
        input,
        new Set(["kind", "value", "confidence", "attributes"]),
      )
    ) return null;
    const confidence = unitNumber(input.confidence);
    const attributes = validAttributes(input.attributes);
    if (
      typeof input.kind !== "string" || !inputKinds.has(input.kind) ||
      typeof input.value !== "string" || !input.value.trim() ||
      input.value.length > 12_000 ||
      confidence === null || attributes === null
    ) return null;
    totalInputLength += input.value.length;
    if (totalInputLength > 24_000) return null;
    inputs.push({
      kind: input.kind,
      value: input.value.trim(),
      confidence,
      attributes,
    });
  }

  const signals = boundedObject(record.signals, 7);
  if (!signals) return null;
  const normalizedSignals: Record<string, number> = {};
  for (
    const key of [
      "energy",
      "fatigue",
      "frustration",
      "excitement",
      "confusion",
      "confidence",
      "hesitation",
    ]
  ) {
    const normalized = unitNumber(signals[key]);
    if (normalized === null) return null;
    normalizedSignals[key] = normalized;
  }

  const context = boundedObject(record.context, 2);
  if (!context || !Array.isArray(context.facts) || context.facts.length > 100) {
    return null;
  }
  const metrics = boundedObject(context.metrics, 50);
  if (!metrics) return null;
  const normalizedMetrics: Record<string, number> = {};
  for (const [key, raw] of Object.entries(metrics)) {
    if (
      !/^[A-Za-z0-9._:-]{1,80}$/.test(key) || typeof raw !== "number" ||
      !Number.isFinite(raw)
    ) return null;
    normalizedMetrics[key] = raw;
  }

  const facts: StrategicIntelligenceFact[] = [];
  let totalFactLength = 0;
  for (const rawFact of context.facts) {
    const fact = boundedObject(rawFact, 6);
    if (
      !fact ||
      !hasOnlyKeys(
        fact,
        new Set([
          "source",
          "id",
          "label",
          "observedAt",
          "relevance",
          "attributes",
        ]),
      )
    ) return null;
    const relevance = unitNumber(fact.relevance);
    const attributes = validAttributes(fact.attributes);
    if (
      typeof fact.source !== "string" || !contextSources.has(fact.source) ||
      !allowedSources.includes(fact.source) ||
      typeof fact.id !== "string" ||
      !/^[A-Za-z0-9._:-]{1,160}$/.test(fact.id) ||
      typeof fact.label !== "string" || !fact.label.trim() ||
      fact.label.length > 500 ||
      typeof fact.observedAt !== "string" ||
      !Number.isFinite(Date.parse(fact.observedAt)) ||
      relevance === null || attributes === null
    ) return null;
    totalFactLength += fact.label.length + JSON.stringify(attributes).length;
    if (totalFactLength > 30_000) return null;
    facts.push({
      source: fact.source,
      id: fact.id,
      label: fact.label.trim(),
      observedAt: fact.observedAt,
      relevance,
      attributes,
    });
  }

  return {
    schemaVersion: 1,
    requestId: record.requestId,
    inputs,
    requestedOutputs: requestedOutputs as string[],
    allowedContextSources: allowedSources as string[],
    signals: normalizedSignals,
    locale: record.locale,
    maxRecommendations: record.maxRecommendations as number,
    occurredAt: record.occurredAt,
    context: { facts, metrics: normalizedMetrics },
  };
}

export const strategicIntelligenceOutputSchema = {
  type: "object",
  properties: {
    status: {
      type: "string",
      enum: ["success", "degraded", "refused", "incomplete"],
    },
    message: { type: "string" },
    confidence: { type: "number" },
    recommendations: {
      type: "array",
      items: {
        type: "object",
        properties: {
          title: { type: "string" },
          rationale: { type: "string" },
          confidence: { type: "number" },
          relatedFactIds: { type: "array", items: { type: "string" } },
        },
        required: ["title", "rationale", "confidence", "relatedFactIds"],
        additionalProperties: false,
      },
    },
    actions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          kind: {
            type: "string",
            enum: [
              "openTask",
              "openGoal",
              "openCalendarEntry",
              "openTimeline",
              "askFollowUp",
            ],
          },
          label: { type: "string" },
          entityId: { type: "string" },
          requiresConfirmation: { type: "boolean" },
        },
        required: ["kind", "label", "entityId", "requiresConfirmation"],
        additionalProperties: false,
      },
    },
    signals: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          value: { type: "string" },
          confidence: { type: "number" },
        },
        required: ["name", "value", "confidence"],
        additionalProperties: false,
      },
    },
    warnings: { type: "array", items: { type: "string" } },
    followUpQuestions: { type: "array", items: { type: "string" } },
    usedFactIds: { type: "array", items: { type: "string" } },
  },
  required: [
    "status",
    "message",
    "confidence",
    "recommendations",
    "actions",
    "signals",
    "warnings",
    "followUpQuestions",
    "usedFactIds",
  ],
  additionalProperties: false,
} as const;

