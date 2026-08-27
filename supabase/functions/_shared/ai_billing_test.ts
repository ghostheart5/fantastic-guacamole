import {
  aiCreditCost,
  aiReservationFailureStatus,
  validatedAiRequestId,
} from "./ai_billing.ts";

Deno.test("AI request identifiers accept candidate envelope IDs", () => {
  const requestId = "ai-user-si_console-c2ktY29uc29sZQ==-1770000000000-1";
  if (validatedAiRequestId(requestId) !== requestId) {
    throw new Error("valid candidate request id was rejected");
  }
});

Deno.test("AI request identifiers reject missing or unsafe values", () => {
  if (validatedAiRequestId(null) !== null) throw new Error("null accepted");
  if (validatedAiRequestId("short") !== null) {
    throw new Error("short id accepted");
  }
  if (validatedAiRequestId("request id with spaces") !== null) {
    throw new Error("unsafe id accepted");
  }
});

Deno.test("AI credit cost is bounded and deterministic", () => {
  if (aiCreditCost("brief") !== 1) throw new Error("brief prompt cost changed");
  if (aiCreditCost("x".repeat(121)) !== 2) {
    throw new Error("long prompt cost changed");
  }
});

Deno.test("idempotency mismatches map to conflict, not exhausted credits", () => {
  if (aiReservationFailureStatus("idempotency_mismatch") !== 409) {
    throw new Error("idempotency mismatch did not map to conflict");
  }
  if (aiReservationFailureStatus("daily_budget_exceeded") !== 429) {
    throw new Error("daily budget did not map to rate limiting");
  }
  if (aiReservationFailureStatus("insufficient_credits") !== 402) {
    throw new Error("credit exhaustion did not map to payment required");
  }
});
