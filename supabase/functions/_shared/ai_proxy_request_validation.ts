export type AiProxyPersonality = "coach" | "strategist" | "strict";

export interface AiProxyRequest {
  prompt: string;
  history: Array<{ role: "user" | "assistant"; content: string }>;
  personality: AiProxyPersonality;
  requestId: string;
  maxTokens: number;
}

const maxPromptLength = 8000;
const maxHistoryItems = 8;
const maxHistoryItemLength = 4000;
const maxHistoryLength = 12000;
const maxOutputTokens = 1024;
const requestIdPattern = /^[A-Za-z0-9._:-]{8,128}$/;
const personalities = new Set<AiProxyPersonality>([
  "coach",
  "strategist",
  "strict",
]);

export function validateAiProxyRequest(value: unknown): AiProxyRequest | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  if (
    !hasOnlyKeys(
      record,
      new Set([
        "prompt",
        "message",
        "history",
        "personality",
        "requestId",
        "maxTokens",
      ]),
    )
  ) return null;
  const prompt = typeof record.prompt === "string"
    ? record.prompt
    : typeof record.message === "string"
    ? record.message
    : "";
  const history = record.history ?? [];
  const personality = record.personality ?? "coach";
  const requestId = record.requestId;
  const maxTokens = record.maxTokens ?? maxOutputTokens;

  // A caller-authored system prompt is intentionally not part of this contract.
  if (
    !prompt.trim() || prompt.length > maxPromptLength ||
    !Array.isArray(history) || history.length > maxHistoryItems ||
    typeof personality !== "string" ||
    !personalities.has(personality as AiProxyPersonality) ||
    typeof requestId !== "string" || !requestIdPattern.test(requestId) ||
    !Number.isInteger(maxTokens) || (maxTokens as number) < 1 ||
    (maxTokens as number) > maxOutputTokens ||
    "system" in record
  ) {
    return null;
  }

  let historyLength = 0;
  const validatedHistory: Array<{
    role: "user" | "assistant";
    content: string;
  }> = [];
  for (const item of history) {
    if (!item || typeof item !== "object") return null;
    const message = item as Record<string, unknown>;
    if (
      (message.role !== "user" && message.role !== "assistant") ||
      typeof message.content !== "string" || !message.content.trim() ||
      message.content.length > maxHistoryItemLength
    ) return null;
    historyLength += message.content.length;
    if (historyLength > maxHistoryLength) return null;
    validatedHistory.push({
      role: message.role,
      content: message.content,
    });
  }

  return {
    prompt: prompt.trim(),
    history: validatedHistory,
    personality: personality as AiProxyPersonality,
    requestId,
    maxTokens: maxTokens as number,
  };
}
import { hasOnlyKeys } from "./edge_http.ts";

