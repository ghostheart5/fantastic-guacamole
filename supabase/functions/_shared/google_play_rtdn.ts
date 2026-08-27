export function decodePubSubNotification(
  encoded: string,
): Record<string, unknown> | null {
  try {
    const bytes = Uint8Array.from(atob(encoded), (char) => char.charCodeAt(0));
    const value = JSON.parse(new TextDecoder().decode(bytes));
    return value && typeof value === "object" && !Array.isArray(value)
      ? value as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

export function googleSubscriptionState(
  value: string,
  expiresAt: Date | null,
  now = new Date(),
): { status: string; active: boolean } {
  switch (value) {
    case "SUBSCRIPTION_STATE_ACTIVE":
      return { status: "active", active: true };
    case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD":
      return { status: "grace", active: true };
    case "SUBSCRIPTION_STATE_CANCELED":
      return {
        status: "canceled",
        active: expiresAt !== null && expiresAt > now,
      };
    case "SUBSCRIPTION_STATE_ON_HOLD":
      return { status: "on_hold", active: false };
    case "SUBSCRIPTION_STATE_PAUSED":
      return { status: "paused", active: false };
    case "SUBSCRIPTION_STATE_EXPIRED":
      return { status: "expired", active: false };
    case "SUBSCRIPTION_STATE_PENDING":
    case "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED":
      return { status: "pending", active: false };
    default:
      return { status: "revoked", active: false };
  }
}
