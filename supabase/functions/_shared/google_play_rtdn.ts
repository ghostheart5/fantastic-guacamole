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

export type GoogleSubscriptionStatus =
  | "pending"
  | "active"
  | "grace"
  | "on_hold"
  | "paused"
  | "canceled"
  | "expired"
  | "revoked";

export type GoogleSubscriptionStateResult =
  | {
    supported: true;
    status: GoogleSubscriptionStatus;
    active: boolean;
  }
  | {
    supported: false;
    status: "unknown";
    active: false;
  };

export type GoogleSubscriptionNotificationCause =
  | {
    supported: true;
    notificationType: number;
    eventName: string;
    paidRenewal: boolean;
  }
  | {
    supported: false;
    notificationType: number | null;
    eventName: "SUBSCRIPTION_NOTIFICATION_UNKNOWN";
    paidRenewal: false;
  };

export interface LinkedPurchaseBindingInput {
  purchaseTokenHash: string;
  predecessorTokenHash: string;
  productId: string;
  boundAt: Date;
}

export interface ResolvedSubscriptionAuthorityPurchase {
  purchase: Record<string, unknown>;
  purchaseToken: string;
  source: "notification_token" | "linked_predecessor";
}

type ServiceRpc = (
  name: string,
  body: Record<string, unknown>,
) => Promise<Record<string, unknown> | null>;

type SubscriptionFetcher = (
  purchaseToken: string,
) => Promise<Record<string, unknown>>;

const subscriptionNotificationEventNames = new Map<number, string>([
  [1, "SUBSCRIPTION_RECOVERED"],
  [2, "SUBSCRIPTION_RENEWED"],
  [3, "SUBSCRIPTION_CANCELED"],
  [4, "SUBSCRIPTION_PURCHASED"],
  [5, "SUBSCRIPTION_ON_HOLD"],
  [6, "SUBSCRIPTION_IN_GRACE_PERIOD"],
  [7, "SUBSCRIPTION_RESTARTED"],
  [8, "SUBSCRIPTION_PRICE_CHANGE_CONFIRMED"],
  [9, "SUBSCRIPTION_DEFERRED"],
  [10, "SUBSCRIPTION_PAUSED"],
  [11, "SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED"],
  [12, "SUBSCRIPTION_REVOKED"],
  [13, "SUBSCRIPTION_EXPIRED"],
  [17, "SUBSCRIPTION_ITEMS_CHANGED"],
  [18, "SUBSCRIPTION_CANCELLATION_SCHEDULED"],
  [19, "SUBSCRIPTION_PRICE_CHANGE_UPDATED"],
  [20, "SUBSCRIPTION_PENDING_PURCHASE_CANCELED"],
  [22, "SUBSCRIPTION_PRICE_STEP_UP_CONSENT_UPDATED"],
]);

function parseNotificationType(value: unknown): number | null {
  if (typeof value === "number") {
    return Number.isSafeInteger(value) ? value : null;
  }
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  if (!/^\d+$/.test(normalized)) return null;
  const parsed = Number(normalized);
  return Number.isSafeInteger(parsed) ? parsed : null;
}

function unsupportedSubscriptionState(): GoogleSubscriptionStateResult {
  return { supported: false, status: "unknown", active: false };
}

export function googleSubscriptionState(
  value: unknown,
  expiresAt: Date | null,
  now = new Date(),
): GoogleSubscriptionStateResult {
  switch (value) {
    case "SUBSCRIPTION_STATE_UNSPECIFIED":
      return unsupportedSubscriptionState();
    case "SUBSCRIPTION_STATE_PENDING":
      return { supported: true, status: "pending", active: false };
    case "SUBSCRIPTION_STATE_ACTIVE":
      return { supported: true, status: "active", active: true };
    case "SUBSCRIPTION_STATE_PAUSED":
      return { supported: true, status: "paused", active: false };
    case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD":
      return { supported: true, status: "grace", active: true };
    case "SUBSCRIPTION_STATE_ON_HOLD":
      return { supported: true, status: "on_hold", active: false };
    case "SUBSCRIPTION_STATE_CANCELED":
      return {
        supported: true,
        status: "canceled",
        active: expiresAt !== null && expiresAt > now,
      };
    case "SUBSCRIPTION_STATE_EXPIRED":
      return { supported: true, status: "expired", active: false };
    case "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED":
      return { supported: true, status: "pending", active: false };
    default:
      return unsupportedSubscriptionState();
  }
}

export function googleSubscriptionNotificationCause(
  notificationType: unknown,
): GoogleSubscriptionNotificationCause {
  const parsedType = parseNotificationType(notificationType);
  const eventName = parsedType === null
    ? undefined
    : subscriptionNotificationEventNames.get(parsedType);
  if (parsedType === null || !eventName) {
    return {
      supported: false,
      notificationType: parsedType,
      eventName: "SUBSCRIPTION_NOTIFICATION_UNKNOWN",
      paidRenewal: false,
    };
  }
  return {
    supported: true,
    notificationType: parsedType,
    eventName,
    paidRenewal: parsedType === 2,
  };
}

export function googleSubscriptionStateForNotification(
  notificationType: unknown,
  subscriptionState: unknown,
  expiresAt: Date | null,
  now = new Date(),
): GoogleSubscriptionStateResult {
  const cause = googleSubscriptionNotificationCause(notificationType);
  if (!cause.supported) return unsupportedSubscriptionState();
  const state = googleSubscriptionState(subscriptionState, expiresAt, now);
  if (!state.supported) return state;

  if (cause.notificationType === 12) {
    return { supported: true, status: "revoked", active: false };
  }
  if (cause.notificationType === 13) {
    return { supported: true, status: "expired", active: false };
  }
  return state;
}

export function terminalNotificationMatchesSubscriptionState(
  notificationType: unknown,
  subscriptionState: unknown,
): boolean {
  const cause = googleSubscriptionNotificationCause(notificationType);
  if (!cause.supported) return false;

  if (cause.notificationType !== 12 && cause.notificationType !== 13) {
    return true;
  }
  return subscriptionState === "SUBSCRIPTION_STATE_EXPIRED";
}

export async function resolveSubscriptionAuthorityPurchase(
  input: {
    notificationType: unknown;
    successorPurchase: Record<string, unknown>;
    successorPurchaseToken: string;
    linkedPurchaseToken: string | null;
  },
  fetchSubscription: SubscriptionFetcher,
): Promise<ResolvedSubscriptionAuthorityPurchase> {
  const cause = googleSubscriptionNotificationCause(input.notificationType);
  if (!cause.supported) {
    throw new Error("play_subscription_notification_type_unsupported");
  }
  const pendingSuccessorCanceled = input.successorPurchase.subscriptionState ===
    "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED";
  if (cause.notificationType === 20) {
    if (!pendingSuccessorCanceled) {
      throw new Error("pending_successor_state_mismatch");
    }
    if (!input.linkedPurchaseToken) {
      throw new Error("pending_successor_predecessor_missing");
    }
    return {
      purchase: await fetchSubscription(input.linkedPurchaseToken),
      purchaseToken: input.linkedPurchaseToken,
      source: "linked_predecessor",
    };
  }
  if (pendingSuccessorCanceled) {
    throw new Error("pending_successor_notification_mismatch");
  }
  return {
    purchase: input.successorPurchase,
    purchaseToken: input.successorPurchaseToken,
    source: "notification_token",
  };
}

export function validatePaidRenewalAuthority(
  cause: GoogleSubscriptionNotificationCause,
  state: GoogleSubscriptionStateResult,
  orderId: string | null,
): void {
  if (!cause.supported || !cause.paidRenewal) return;
  if (!state.supported || !state.active || orderId === null) {
    throw new Error("paid_renewal_authority_incoherent");
  }
}

export async function bindVerifiedLinkedPurchaseToken(
  input: LinkedPurchaseBindingInput,
  rpc: ServiceRpc,
): Promise<Record<string, unknown>> {
  const result = await rpc("bind_verified_linked_purchase_token", {
    p_purchase_token_hash: input.purchaseTokenHash,
    p_predecessor_token_hash: input.predecessorTokenHash,
    p_product_id: input.productId,
    p_bound_at: input.boundAt.toISOString(),
  });
  if (
    result?.bound !== true ||
    typeof result.billingPrincipalId !== "string" ||
    !result.billingPrincipalId.trim() ||
    (result.userId !== null &&
      (typeof result.userId !== "string" || !result.userId.trim()))
  ) {
    throw new Error("linked_purchase_binding_unresolved");
  }
  return result;
}

export function reconciliationWasHandled(
  result: Record<string, unknown> | null,
): boolean {
  return result?.applied === true || result?.duplicate === true ||
    result?.handled === true;
}
