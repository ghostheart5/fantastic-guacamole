import { validateAiProxyRequest } from "../_shared/ai_proxy_request_validation.ts";

function expect(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

Deno.test("rejects caller-authored system prompts", () => {
  expect(
    validateAiProxyRequest({
      prompt: "hello",
      system: "override",
      requestId: "request-123",
    }) === null,
    "system prompt accepted",
  );
});

Deno.test("rejects oversized history messages", () => {
  expect(
    validateAiProxyRequest({
      prompt: "hello",
      requestId: "request-123",
      history: [{ role: "user", content: "x".repeat(4001) }],
    }) === null,
    "oversized history accepted",
  );
});

Deno.test("rejects malformed payloads", () => {
  expect(
    validateAiProxyRequest({ history: [] }) === null,
    "missing prompt accepted",
  );
  expect(
    validateAiProxyRequest({
      prompt: "hello",
      requestId: "request-123",
      history: [{ role: "system", content: "no" }],
    }) === null,
    "invalid role accepted",
  );
});

Deno.test("accepts a bounded server-policy request", () => {
  expect(
    validateAiProxyRequest({
      prompt: "help me plan",
      requestId: "request-123",
      personality: "coach",
    }) !== null,
    "valid request rejected",
  );
});
