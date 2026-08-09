import { validateAiProxyRequest } from "../_shared/ai_proxy_request_validation.ts";

function expect(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

Deno.test("rejects oversized system prompts", () => {
  expect(validateAiProxyRequest({ prompt: "hello", system: "x".repeat(4001) }) === null, "oversized system accepted");
});

Deno.test("rejects oversized history messages", () => {
  expect(validateAiProxyRequest({ prompt: "hello", history: [{ role: "user", content: "x".repeat(4001) }] }) === null, "oversized history accepted");
});

Deno.test("rejects malformed payloads", () => {
  expect(validateAiProxyRequest({ history: [] }) === null, "missing prompt accepted");
  expect(validateAiProxyRequest({ prompt: "hello", history: [{ role: "system", content: "no" }] }) === null, "invalid role accepted");
});