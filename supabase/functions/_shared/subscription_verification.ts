export interface VerifiedSubscriptionLineItem {
  productId: string;
  expiryTimeMs: number;
  status: "active" | "grace" | "canceled";
  active: boolean;
  autoRenews: boolean;
  orderId: string | null;
}

export interface ProviderSubscriptionLineItem {
  raw: Record<string, unknown>;
  productId: string;
  expiryTimeMs: number | null;
  autoRenews: boolean;
  orderId: string | null;
  successfulLineOrderId: string | null;
}

export type ExternalAccountBindingResult =
  | {
    accepted: true;
    mode: "hashed_match" | "legacy_existing_binding_required";
  }
  | {
    accepted: false;
    reason: "invalid" | "missing" | "mismatch" | "raw_identifier";
  };

export type GooglePlayAcknowledgementState =
  | "acknowledged"
  | "pending"
  | "unsupported";

export type GooglePlayProviderFailure = "terminal" | "retryable";

export type GooglePlayAuthorityApplication<T> =
  | { status: "applied"; value: T }
  | { status: "acknowledgement_unsupported" }
  | { status: "acknowledgement_retryable" };

export type PurchaseLineageSource =
  | "linked_purchase"
  | "out_of_app_resubscribe";

export interface PurchaseLineage {
  purchaseToken: string;
  source: PurchaseLineageSource;
}

export type ExistingPurchaseRecoveryBindingResult =
  | "same_user"
  | "detached_current"
  | "detached_predecessor"
  | "mismatch"
  | "retryable";

export type ExistingPurchaseProofPolicy =
  | "not_required"
  | "required"
  | "forbidden";

type FetchLike = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export interface SubscriptionReconciliationInput {
  purchaseTokenHash: string;
  productId: string;
  status: VerifiedSubscriptionLineItem["status"];
  isActive: boolean;
  autoRenews: boolean;
  orderId?: string | null;
  expiryTimeMs: number;
  providerObservedAt: Date;
  subscriptionState: unknown;
  acknowledgementState: unknown;
  lineageSource?: PurchaseLineageSource | null;
}

export interface PurchaseBindingInput {
  purchaseTokenHash: string;
  userId: string;
  productId: string;
  boundAt: Date;
  predecessorTokenHash: string | null;
}

export type VerificationReconciliationOutcome =
  | "accepted"
  | "terminal"
  | "retry";

export type PurchaseBindingOutcome = "accepted" | "terminal" | "retry";

const accessStatusBySubscriptionState = new Map<
  string,
  VerifiedSubscriptionLineItem["status"]
>([
  ["SUBSCRIPTION_STATE_ACTIVE", "active"],
  ["SUBSCRIPTION_STATE_IN_GRACE_PERIOD", "grace"],
  ["SUBSCRIPTION_STATE_CANCELED", "canceled"],
]);

const activeSubscriptionStates = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
]);

const terminalPurchaseBindingReasons = new Set([
  "binding_mismatch",
  "binding_owned",
  "lineage_cycle",
  "lineage_mismatch",
  "predecessor_principal_mismatch",
  "principal_retired",
  "user_principal_mismatch",
]);

function invalidAuthority(message: string): never {
  throw new Error(`subscription_authority_${message}`);
}

function readOptionalNonEmptyString(
  value: unknown,
  fieldName: string,
  maxLength: number,
): string | null {
  if (value === undefined) return null;
  if (typeof value !== "string") {
    throw new Error(`invalid ${fieldName}`);
  }
  const normalized = value.trim();
  if (!normalized || normalized.length > maxLength) {
    throw new Error(`invalid ${fieldName}`);
  }
  return normalized;
}

export function readLatestSuccessfulOrderId(
  purchase: Record<string, unknown>,
  lineItem: Record<string, unknown>,
  maxLength = 1024,
): string | null {
  const lineItemOrderId = readOptionalNonEmptyString(
    lineItem.latestSuccessfulOrderId,
    "latest successful order id",
    maxLength,
  );
  if (lineItemOrderId !== null) return lineItemOrderId;
  return readOptionalNonEmptyString(
    purchase.latestOrderId,
    "legacy latest order id",
    maxLength,
  );
}

function parseProviderLineItem(
  purchase: Record<string, unknown>,
  lineItem: Record<string, unknown>,
): ProviderSubscriptionLineItem {
  const productId = typeof lineItem.productId === "string"
    ? lineItem.productId.trim()
    : "";
  if (!productId) invalidAuthority("product_invalid");

  let expiryTimeMs: number | null = null;
  if (lineItem.expiryTime !== undefined) {
    if (typeof lineItem.expiryTime !== "string") {
      invalidAuthority("expiry_invalid");
    }
    const normalizedExpiry = lineItem.expiryTime.trim();
    expiryTimeMs = Date.parse(normalizedExpiry);
    if (!normalizedExpiry || !Number.isFinite(expiryTimeMs)) {
      invalidAuthority("expiry_invalid");
    }
  }

  const autoRenewingPlan = lineItem.autoRenewingPlan;
  if (
    autoRenewingPlan !== undefined &&
    (autoRenewingPlan === null || typeof autoRenewingPlan !== "object" ||
      Array.isArray(autoRenewingPlan))
  ) {
    invalidAuthority("auto_renew_invalid");
  }
  const autoRenewEnabled = autoRenewingPlan === undefined
    ? undefined
    : (autoRenewingPlan as Record<string, unknown>).autoRenewEnabled;
  if (
    autoRenewEnabled !== undefined && typeof autoRenewEnabled !== "boolean"
  ) {
    invalidAuthority("auto_renew_invalid");
  }

  const successfulLineOrderId = readOptionalNonEmptyString(
    lineItem.latestSuccessfulOrderId,
    "latest successful order id",
    1024,
  );
  return {
    raw: lineItem,
    productId,
    expiryTimeMs,
    autoRenews: autoRenewEnabled === true,
    orderId: successfulLineOrderId ?? readOptionalNonEmptyString(
      purchase.latestOrderId,
      "legacy latest order id",
      1024,
    ),
    successfulLineOrderId,
  };
}

export function selectSubscriptionAuthorityLine(
  purchase: Record<string, unknown>,
  recognizedProductIds: ReadonlySet<string>,
  nowMs = Date.now(),
): ProviderSubscriptionLineItem {
  if (!Number.isFinite(nowMs)) invalidAuthority("clock_invalid");
  if (!Array.isArray(purchase.lineItems)) {
    invalidAuthority("line_items_missing");
  }

  const recognized: ProviderSubscriptionLineItem[] = [];
  for (const item of purchase.lineItems) {
    if (!item || typeof item !== "object" || Array.isArray(item)) continue;
    const raw = item as Record<string, unknown>;
    if (
      typeof raw.productId !== "string" ||
      !recognizedProductIds.has(raw.productId.trim())
    ) {
      continue;
    }
    recognized.push(parseProviderLineItem(purchase, raw));
  }
  if (recognized.length === 0) invalidAuthority("product_missing");

  const future = recognized.filter((line) =>
    line.expiryTimeMs !== null && line.expiryTimeMs > nowMs
  );
  const subscriptionState = String(purchase.subscriptionState ?? "");
  if (activeSubscriptionStates.has(subscriptionState)) {
    if (future.length !== 1) {
      invalidAuthority(
        future.length === 0 ? "active_expiry_missing" : "active_ambiguous",
      );
    }
    return future[0];
  }
  if (subscriptionState === "SUBSCRIPTION_STATE_CANCELED") {
    if (future.length > 1) invalidAuthority("canceled_ambiguous");
    if (future.length === 1) return future[0];
  }

  const dated = recognized
    .filter((line) => line.expiryTimeMs !== null)
    .sort((left, right) => right.expiryTimeMs! - left.expiryTimeMs!);
  if (dated.length > 0) {
    if (
      dated.length > 1 && dated[0].expiryTimeMs === dated[1].expiryTimeMs
    ) {
      invalidAuthority("inactive_ambiguous");
    }
    return dated[0];
  }
  if (recognized.length === 1) return recognized[0];
  return invalidAuthority("inactive_ambiguous");
}

export function verifySubscriptionLineItem(
  purchase: Record<string, unknown>,
  claimedProductId: string,
  nowMs = Date.now(),
  recognizedProductIds: ReadonlySet<string> = new Set([claimedProductId]),
): VerifiedSubscriptionLineItem | null {
  const status = accessStatusBySubscriptionState.get(
    String(purchase.subscriptionState ?? ""),
  );
  if (!status) {
    return null;
  }
  const selected = selectSubscriptionAuthorityLine(
    purchase,
    recognizedProductIds,
    nowMs,
  );
  if (
    selected.productId !== claimedProductId ||
    selected.expiryTimeMs === null || selected.expiryTimeMs <= nowMs
  ) {
    return null;
  }
  return {
    productId: claimedProductId,
    expiryTimeMs: selected.expiryTimeMs,
    status,
    active: true,
    autoRenews: selected.autoRenews,
    orderId: selected.orderId,
  };
}

function lowercaseSha256(value: string): Promise<string> {
  return crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  ).then((digest) =>
    Array.from(new Uint8Array(digest))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("")
  );
}

function constantTimeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

export async function verifyExternalAccountBinding(
  purchase: Record<string, unknown>,
  authenticatedUserId: string,
  legacyMissingBefore: Date | null,
): Promise<ExternalAccountBindingResult> {
  const normalizedUserId = authenticatedUserId.trim();
  if (!normalizedUserId || normalizedUserId.length > 128) {
    return { accepted: false, reason: "invalid" };
  }

  const outOfAppContext = purchase.outOfAppPurchaseContext;
  if (
    outOfAppContext !== undefined &&
    (outOfAppContext === null || typeof outOfAppContext !== "object" ||
      Array.isArray(outOfAppContext))
  ) {
    return { accepted: false, reason: "invalid" };
  }
  const expiredIdentifiers = outOfAppContext === undefined
    ? undefined
    : (outOfAppContext as Record<string, unknown>)
      .expiredExternalAccountIdentifiers;
  if (
    expiredIdentifiers !== undefined &&
    (expiredIdentifiers === null || typeof expiredIdentifiers !== "object" ||
      Array.isArray(expiredIdentifiers))
  ) {
    return { accepted: false, reason: "invalid" };
  }
  if (
    purchase.externalAccountIdentifiers !== undefined &&
    expiredIdentifiers !== undefined
  ) {
    return { accepted: false, reason: "invalid" };
  }

  const identifiers = purchase.externalAccountIdentifiers ??
    expiredIdentifiers;
  if (
    identifiers !== undefined &&
    (identifiers === null || typeof identifiers !== "object" ||
      Array.isArray(identifiers))
  ) {
    return { accepted: false, reason: "invalid" };
  }
  const obfuscated = identifiers === undefined
    ? undefined
    : (identifiers as Record<string, unknown>).obfuscatedExternalAccountId;

  if (obfuscated === undefined) {
    const startTime = purchase.startTime;
    const startTimeMs = typeof startTime === "string"
      ? Date.parse(startTime.trim())
      : Number.NaN;
    if (
      legacyMissingBefore !== null &&
      Number.isFinite(legacyMissingBefore.getTime()) &&
      Number.isFinite(startTimeMs) &&
      startTimeMs < legacyMissingBefore.getTime()
    ) {
      return {
        accepted: true,
        mode: "legacy_existing_binding_required",
      };
    }
    return { accepted: false, reason: "missing" };
  }
  if (typeof obfuscated !== "string") {
    return { accepted: false, reason: "invalid" };
  }
  const normalizedIdentifier = obfuscated.trim();
  if (normalizedIdentifier.toLowerCase() === normalizedUserId.toLowerCase()) {
    return { accepted: false, reason: "raw_identifier" };
  }
  if (!/^[0-9a-f]{64}$/.test(normalizedIdentifier)) {
    return { accepted: false, reason: "invalid" };
  }

  const expected = await lowercaseSha256(normalizedUserId);
  return constantTimeEqual(normalizedIdentifier, expected)
    ? { accepted: true, mode: "hashed_match" }
    : { accepted: false, reason: "mismatch" };
}

export function existingPurchaseProofPolicy(
  binding: ExternalAccountBindingResult,
): ExistingPurchaseProofPolicy {
  if (binding.accepted) {
    return binding.mode === "legacy_existing_binding_required"
      ? "required"
      : "not_required";
  }
  return binding.reason === "missing" || binding.reason === "mismatch"
    ? "required"
    : "forbidden";
}

export async function verifyExistingPurchaseRecoveryBinding(
  input: {
    supabaseUrl: string;
    secretKey: string;
    purchaseTokenHash: string;
    predecessorTokenHash: string | null;
    userId: string;
    productId: string;
    allowedProductIds: ReadonlySet<string>;
  },
  fetcher: FetchLike = fetch,
): Promise<ExistingPurchaseRecoveryBindingResult> {
  const candidates: Array<{
    tokenHash: string;
    current: boolean;
  }> = [{ tokenHash: input.purchaseTokenHash, current: true }];
  if (
    input.predecessorTokenHash !== null &&
    input.predecessorTokenHash !== input.purchaseTokenHash
  ) {
    candidates.push({
      tokenHash: input.predecessorTokenHash,
      current: false,
    });
  }

  try {
    for (const candidate of candidates) {
      const bindingResponse = await fetcher(
        `${input.supabaseUrl}/rest/v1/purchase_bindings?select=user_id,product_id,billing_principal_id&token_hash=eq.${
          encodeURIComponent(candidate.tokenHash)
        }&limit=2`,
        {
          headers: {
            apikey: input.secretKey,
            Authorization: `Bearer ${input.secretKey}`,
            "Content-Type": "application/json",
          },
        },
      );
      if (!bindingResponse.ok) {
        await bindingResponse.body?.cancel();
        return "retryable";
      }
      const decodedBinding: unknown = await bindingResponse.json();
      if (!Array.isArray(decodedBinding)) return "retryable";
      if (decodedBinding.length === 0) continue;
      if (decodedBinding.length !== 1) return "retryable";
      const rawBinding = decodedBinding[0];
      if (
        !rawBinding || typeof rawBinding !== "object" ||
        Array.isArray(rawBinding)
      ) {
        return "retryable";
      }
      const binding = rawBinding as Record<string, unknown>;
      const bindingProductId = typeof binding.product_id === "string"
        ? binding.product_id.trim()
        : "";
      if (
        !input.allowedProductIds.has(bindingProductId) ||
        (candidate.current && bindingProductId !== input.productId)
      ) {
        return "mismatch";
      }
      const principalId = typeof binding.billing_principal_id === "string"
        ? binding.billing_principal_id.trim()
        : "";
      if (!principalId || principalId.length > 128) return "retryable";

      const principalResponse = await fetcher(
        `${input.supabaseUrl}/rest/v1/billing_principals?select=current_user_id,retired_at&billing_principal_id=eq.${
          encodeURIComponent(principalId)
        }&limit=2`,
        {
          headers: {
            apikey: input.secretKey,
            Authorization: `Bearer ${input.secretKey}`,
            "Content-Type": "application/json",
          },
        },
      );
      if (!principalResponse.ok) {
        await principalResponse.body?.cancel();
        return "retryable";
      }
      const decodedPrincipal: unknown = await principalResponse.json();
      if (!Array.isArray(decodedPrincipal) || decodedPrincipal.length !== 1) {
        return "retryable";
      }
      const rawPrincipal = decodedPrincipal[0];
      if (
        !rawPrincipal || typeof rawPrincipal !== "object" ||
        Array.isArray(rawPrincipal)
      ) {
        return "retryable";
      }
      const principal = rawPrincipal as Record<string, unknown>;
      if (principal.retired_at !== null) return "mismatch";
      if (
        binding.user_id === input.userId &&
        principal.current_user_id === input.userId && candidate.current
      ) {
        return "same_user";
      }
      if (binding.user_id === null && principal.current_user_id === null) {
        return candidate.current ? "detached_current" : "detached_predecessor";
      }
      return "mismatch";
    }
    return "mismatch";
  } catch {
    return "retryable";
  }
}

export function googlePlayAcknowledgementState(
  value: unknown,
): GooglePlayAcknowledgementState {
  if (value === "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED") return "acknowledged";
  if (value === "ACKNOWLEDGEMENT_STATE_PENDING") return "pending";
  return "unsupported";
}

export async function acknowledgeGooglePlaySubscription(
  input: {
    packageName: string;
    productId: string;
    purchaseToken: string;
    accessToken: string;
  },
  fetcher: FetchLike = fetch,
): Promise<boolean> {
  const packageName = input.packageName.trim();
  const productId = input.productId.trim();
  const purchaseToken = input.purchaseToken.trim();
  const accessToken = input.accessToken.trim();
  if (!packageName || !productId || !purchaseToken || !accessToken) {
    throw new Error("invalid_google_play_acknowledgement_input");
  }

  const response = await fetcher(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(packageName)
    }/purchases/subscriptions/${encodeURIComponent(productId)}/tokens/${
      encodeURIComponent(purchaseToken)
    }:acknowledge`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: "{}",
    },
  );
  await response.body?.cancel();
  return response.ok;
}

export async function applyGooglePlayAuthorityAfterAcknowledgement<T>(
  input: { active: boolean; acknowledgementState: unknown },
  acknowledge: () => Promise<boolean>,
  applyAuthority: () => Promise<T>,
): Promise<GooglePlayAuthorityApplication<T>> {
  if (input.active) {
    const acknowledgementState = googlePlayAcknowledgementState(
      input.acknowledgementState,
    );
    if (acknowledgementState === "unsupported") {
      return { status: "acknowledgement_unsupported" };
    }
    if (acknowledgementState === "pending" && !await acknowledge()) {
      return { status: "acknowledgement_retryable" };
    }
  }
  return { status: "applied", value: await applyAuthority() };
}

export function classifyGooglePlayProviderFailure(
  status: number,
): GooglePlayProviderFailure {
  return status === 404 || status === 410 ? "terminal" : "retryable";
}

export function readLinkedPurchaseToken(
  purchase: Record<string, unknown>,
  maxLength = 4096,
): string | null {
  if (purchase.linkedPurchaseToken === undefined) return null;
  if (typeof purchase.linkedPurchaseToken !== "string") {
    throw new Error("invalid linked purchase token");
  }
  const token = purchase.linkedPurchaseToken.trim();
  if (!token || token.length > maxLength) {
    throw new Error("invalid linked purchase token");
  }
  return token;
}

export function readPurchaseLineage(
  purchase: Record<string, unknown>,
  maxLength = 4096,
): PurchaseLineage | null {
  const linkedPurchaseToken = readLinkedPurchaseToken(purchase, maxLength);
  const rawContext = purchase.outOfAppPurchaseContext;
  if (rawContext === undefined) {
    return linkedPurchaseToken === null
      ? null
      : { purchaseToken: linkedPurchaseToken, source: "linked_purchase" };
  }
  if (
    rawContext === null || typeof rawContext !== "object" ||
    Array.isArray(rawContext)
  ) {
    throw new Error("invalid out-of-app purchase context");
  }
  if (linkedPurchaseToken !== null) {
    throw new Error("ambiguous purchase lineage");
  }
  const context = rawContext as Record<string, unknown>;
  if (typeof context.expiredPurchaseToken !== "string") {
    throw new Error("invalid expired purchase token");
  }
  const expiredPurchaseToken = context.expiredPurchaseToken.trim();
  if (!expiredPurchaseToken || expiredPurchaseToken.length > maxLength) {
    throw new Error("invalid expired purchase token");
  }
  const expiredIdentifiers = context.expiredExternalAccountIdentifiers;
  if (
    expiredIdentifiers !== undefined &&
    (expiredIdentifiers === null || typeof expiredIdentifiers !== "object" ||
      Array.isArray(expiredIdentifiers))
  ) {
    throw new Error("invalid expired external account identifiers");
  }
  return {
    purchaseToken: expiredPurchaseToken,
    source: "out_of_app_resubscribe",
  };
}

export function buildPurchaseBindingArgs(
  input: PurchaseBindingInput,
): Record<string, unknown> {
  return {
    p_purchase_token_hash: input.purchaseTokenHash,
    p_user_id: input.userId,
    p_product_id: input.productId,
    p_bound_at: input.boundAt.toISOString(),
    p_predecessor_token_hash: input.predecessorTokenHash,
  };
}

export function classifyVerificationReconciliation(
  result: Record<string, unknown> | null,
): VerificationReconciliationOutcome {
  if (result?.reason === "terminal_token" || result?.reason === "old_token") {
    return "terminal";
  }
  if (result?.applied === true || result?.duplicate === true) {
    return "accepted";
  }
  return "retry";
}

export function classifyPurchaseBinding(
  result: Record<string, unknown> | null,
  expectedUserId: string,
): PurchaseBindingOutcome {
  if (result?.bound === true) {
    return result.userId === expectedUserId ? "accepted" : "terminal";
  }
  return typeof result?.reason === "string" &&
      terminalPurchaseBindingReasons.has(result.reason)
    ? "terminal"
    : "retry";
}

export function buildSubscriptionReconciliationArgs(
  input: SubscriptionReconciliationInput,
): Record<string, unknown> {
  const expiresAt = new Date(input.expiryTimeMs).toISOString();
  const providerEventTime = input.providerObservedAt.toISOString();
  const orderId = input.orderId ?? null;

  return {
    p_purchase_token_hash: input.purchaseTokenHash,
    p_product_id: input.productId,
    p_status: input.status,
    p_is_active: input.isActive,
    p_auto_renews: input.autoRenews,
    p_order_id: orderId,
    p_expires_at: expiresAt,
    p_provider_event_time: providerEventTime,
    p_event_key: [
      "verify",
      input.purchaseTokenHash,
      encodeURIComponent(input.productId),
      input.status,
      input.isActive ? "active" : "inactive",
      input.autoRenews ? "auto-renew" : "no-auto-renew",
      input.expiryTimeMs,
      orderId === null
        ? "order:null"
        : `order:value:${encodeURIComponent(orderId)}`,
    ].join(":"),
    p_payload: {
      source: "client_verification",
      subscriptionState: input.subscriptionState,
      acknowledgementState: input.acknowledgementState,
      lineageSource: input.lineageSource ?? null,
      cause: {
        notificationType: null,
        eventName: "CLIENT_VERIFICATION",
        paidRenewal: false,
      },
    },
  };
}
