export const aiRequestIdPattern = /^[A-Za-z0-9._:=+-]{8,200}$/;

export function validatedAiRequestId(value: unknown): string | null {
  return typeof value === "string" && aiRequestIdPattern.test(value)
    ? value
    : null;
}

export function aiCreditCost(prompt: string): number {
  return 1 + (prompt.length > 120 ? 1 : 0);
}

export function aiReservationFailureStatus(reason: string): number {
  if (reason === "idempotency_mismatch") return 409;
  if (reason === "daily_budget_exceeded") return 429;
  return 402;
}
