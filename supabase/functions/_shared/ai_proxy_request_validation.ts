export interface AiProxyRequest {
  prompt: string;
  history: Array<{ role: "user" | "assistant"; content: string }>;
  system?: string;
  maxTokens: number;
}

const maxPromptLength = 8000;
const maxSystemLength = 4000;
const maxHistoryItems = 8;
const maxHistoryItemLength = 4000;
const maxHistoryLength = 12000;
const maxOutputTokens = 1024;

export function validateAiProxyRequest(value: unknown): AiProxyRequest | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  const prompt = typeof record.prompt === "string"
    ? record.prompt
    : typeof record.message === "string" ? record.message : "";
  const system = record.system;
  const history = record.history ?? [];
  const maxTokens = record.maxTokens ?? maxOutputTokens;

  if (!prompt.trim() || prompt.length > maxPromptLength ||
      (system !== undefined && (typeof system !== "string" || system.length > maxSystemLength)) ||
      !Array.isArray(history) || history.length > maxHistoryItems ||
      !Number.isInteger(maxTokens) || (maxTokens as number) < 1 || (maxTokens as number) > maxOutputTokens) {
    return null;
  }

  let historyLength = 0;
  const validatedHistory: Array<{ role: "user" | "assistant"; content: string }> = [];
  for (const item of history) {
    if (!item || typeof item !== "object") return null;
    const message = item as Record<string, unknown>;
    if ((message.role !== "user" && message.role !== "assistant") ||
        typeof message.content !== "string" || !message.content.trim() ||
        message.content.length > maxHistoryItemLength) return null;
    historyLength += message.content.length;
    if (historyLength > maxHistoryLength) return null;
    validatedHistory.push({ role: message.role, content: message.content });
  }

  return {
    prompt,
    history: validatedHistory,
    ...(typeof system === "string" ? { system } : {}),
    maxTokens: maxTokens as number,
  };
}