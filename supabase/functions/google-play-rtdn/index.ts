/// <reference lib="deno.ns" />
import {
  getGoogleAccessToken,
  type GoogleServiceAccount,
  sha256Hex,
  validateGoogleOidcPush,
} from "../_shared/google_auth.ts";
import {
  completeGooglePlayDelivery,
  googlePlayProductConfig,
} from "../_shared/google_play_product.ts";
import {
  EdgeHttpError,
  fetchWithDeadline,
  logEdgeEvent,
  readBoundedJson,
} from "../_shared/edge_http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANDROID_PACKAGE_NAME = Deno.env.get("ANDROID_PACKAGE_NAME") ??
  "com.ghostheart5.chronospark";
const RTDN_AUDIENCE = Deno.env.get("RTDN_AUDIENCE") ?? "";
const RTDN_SERVICE_ACCOUNT_EMAIL = Deno.env.get("RTDN_SERVICE_ACCOUNT_EMAIL") ??
  "";
const configuredRefundPreference =
  Deno.env.get("RTDN_REFUND_REVIEW_PREFERENCE") ?? "NEUTRAL";
const REFUND_REVIEW_PREFERENCE = new Set(["APPROVE", "DECLINE", "NEUTRAL"])
    .has(configuredRefundPreference)
  ? configuredRefundPreference
  : "NEUTRAL";
const serviceAccount = JSON.parse(
  Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON") ?? "null",
) as GoogleServiceAccount | null;

interface PubSubEnvelope {
  message?: {
    data?: string;
    messageId?: string;
  };
  subscription?: string;
}

interface SubscriptionLineItem {
  productId?: string;
  expiryTime?: string;
  autoRenewingPlan?: { autoRenewEnabled?: boolean };
  offerDetails?: { basePlanId?: string; offerId?: string };
}

function serviceHeaders(): Record<string, string> {
  return {
    apikey: SUPABASE_SECRET_KEY,
    Authorization: `Bearer ${SUPABASE_SECRET_KEY}`,
    "Content-Type": "application/json",
  };
}

async function serviceRpc(
  name: string,
  body: Record<string, unknown>,
): Promise<Record<string, unknown> | null> {
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/rest/v1/rpc/${name}`,
    { method: "POST", headers: serviceHeaders(), body: JSON.stringify(body) },
    { timeoutMs: 5_000, dependency: `supabase_rpc_${name}` },
  );
  if (!response.ok) {
    await response.body?.cancel();
    return null;
  }
  const data = await response.json();
  return data && typeof data === "object" && !Array.isArray(data)
    ? data as Record<string, unknown>
    : null;
}

async function serviceBooleanRpc(
  name: string,
  body: Record<string, unknown>,
): Promise<boolean> {
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/rest/v1/rpc/${name}`,
    { method: "POST", headers: serviceHeaders(), body: JSON.stringify(body) },
    { timeoutMs: 5_000, dependency: `supabase_rpc_${name}` },
  );
  if (!response.ok) {
    await response.body?.cancel();
    return false;
  }
  return await response.json() === true;
}

async function readEvent(
  messageId: string,
): Promise<Record<string, unknown> | null> {
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/rest/v1/google_play_rtdn_events?message_id=eq.${
      encodeURIComponent(messageId)
    }&select=state`,
    { headers: serviceHeaders() },
    { timeoutMs: 5_000, dependency: "rtdn_event_read" },
  );
  if (!response.ok) return null;
  const rows = await response.json();
  return Array.isArray(rows) && rows[0] && typeof rows[0] === "object"
    ? rows[0] as Record<string, unknown>
    : null;
}

async function insertEvent(
  messageId: string,
  event: Record<string, unknown>,
): Promise<boolean> {
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/rest/v1/google_play_rtdn_events`,
    {
      method: "POST",
      headers: {
        ...serviceHeaders(),
        Prefer: "resolution=ignore-duplicates,return=minimal",
      },
      body: JSON.stringify({ message_id: messageId, ...event }),
    },
    { timeoutMs: 5_000, dependency: "rtdn_event_insert" },
  );
  return response.ok;
}

async function markEvent(
  messageId: string,
  expectedState: string,
  nextState: string,
  failureCode?: string,
): Promise<boolean> {
  return await serviceBooleanRpc("mark_google_play_rtdn_event", {
    p_message_id: messageId,
    p_expected_state: expectedState,
    p_next_state: nextState,
    p_failure_code: failureCode ?? null,
  });
}

function decodeNotification(encoded: string): Record<string, unknown> | null {
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

function subscriptionState(value: string, expiresAt: Date | null): {
  status: string;
  active: boolean;
} {
  switch (value) {
    case "SUBSCRIPTION_STATE_ACTIVE":
      return { status: "active", active: true };
    case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD":
      return { status: "grace", active: true };
    case "SUBSCRIPTION_STATE_CANCELED":
      return {
        status: "canceled",
        active: expiresAt !== null && expiresAt > new Date(),
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

async function fetchSubscription(
  token: string,
): Promise<{ data: Record<string, unknown>; accessToken: string }> {
  if (!serviceAccount) throw new Error("service_account_missing");
  const accessToken = await getGoogleAccessToken(serviceAccount);
  const response = await fetchWithDeadline(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(ANDROID_PACKAGE_NAME)
    }/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
    { timeoutMs: 10_000, dependency: "google_play_subscription_lookup" },
  );
  if (!response.ok) throw new Error(`play_subscription_${response.status}`);
  return {
    data: await response.json() as Record<string, unknown>,
    accessToken,
  };
}

async function processSubscription(
  messageId: string,
  notification: Record<string, unknown>,
): Promise<boolean> {
  const raw = notification.subscriptionNotification;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return false;
  const subscription = raw as Record<string, unknown>;
  const token = typeof subscription.purchaseToken === "string"
    ? subscription.purchaseToken
    : "";
  if (!token) return false;
  const tokenHash = await sha256Hex(token);
  const fetched = await fetchSubscription(token);
  const play = fetched.data;
  const lineItems = Array.isArray(play.lineItems)
    ? play.lineItems as SubscriptionLineItem[]
    : [];
  const line = lineItems.find((item) =>
    item.productId === "chronospark_premium_monthly" ||
    item.productId === "chronospark_premium_annual"
  );
  if (!line?.productId) throw new Error("play_subscription_product_missing");
  const linkedPurchaseToken = typeof play.linkedPurchaseToken === "string"
    ? play.linkedPurchaseToken
    : "";
  if (linkedPurchaseToken) {
    const migration = await serviceRpc("migrate_google_play_purchase_binding", {
      p_old_purchase_token_hash: await sha256Hex(linkedPurchaseToken),
      p_new_purchase_token_hash: tokenHash,
      p_product_id: line.productId,
    });
    if (
      migration?.migrated !== true &&
      migration?.reason !== "old_binding_not_found"
    ) {
      throw new Error("play_subscription_binding_migration_failed");
    }
  }
  const expiresAt = line.expiryTime ? new Date(line.expiryTime) : null;
  if (expiresAt !== null && !Number.isFinite(expiresAt.getTime())) {
    throw new Error("play_subscription_expiry_invalid");
  }
  const state = subscriptionState(
    play.subscriptionState?.toString() ?? "",
    expiresAt,
  );
  const payload = {
    source: "google_play_rtdn",
    notificationType: subscription.notificationType,
    subscriptionState: play.subscriptionState,
    acknowledgementState: play.acknowledgementState,
    basePlanId: line.offerDetails?.basePlanId,
    offerId: line.offerDetails?.offerId,
  };
  const result = await serviceRpc("reconcile_google_play_subscription", {
    p_purchase_token_hash: tokenHash,
    p_product_id: line.productId,
    p_status: state.status,
    p_is_active: state.active,
    p_auto_renews: line.autoRenewingPlan?.autoRenewEnabled === true,
    p_order_id: typeof play.latestOrderId === "string"
      ? play.latestOrderId
      : null,
    p_expires_at: expiresAt?.toISOString() ?? null,
    p_event_key: `rtdn:${messageId}`,
    p_payload: payload,
  });
  const applied = result?.applied === true || result?.duplicate === true;
  if (!applied) return false;
  return await completeGooglePlayDelivery({
    accessToken: fetched.accessToken,
    packageName: ANDROID_PACKAGE_NAME,
    productId: line.productId,
    purchaseToken: token,
    kind: "subscription",
    alreadyAcknowledged:
      play.acknowledgementState === "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
  });
}

async function processOneTime(
  messageId: string,
  notification: Record<string, unknown>,
): Promise<boolean> {
  const raw = notification.oneTimeProductNotification;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return false;
  const oneTime = raw as Record<string, unknown>;
  const token = typeof oneTime.purchaseToken === "string"
    ? oneTime.purchaseToken
    : "";
  const productId = typeof oneTime.sku === "string" ? oneTime.sku : "";
  const notificationType = Number(oneTime.notificationType ?? 0);
  const config = googlePlayProductConfig(productId);
  if (!token || !config || config.purchaseType !== "inapp") return false;
  // A canceled pending purchase never granted entitlement and requires no
  // revocation. It is still recorded as successfully reconciled.
  if (notificationType === 2) return true;
  if (notificationType !== 1 || !serviceAccount) return false;

  const accessToken = await getGoogleAccessToken(serviceAccount);
  const response = await fetchWithDeadline(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(ANDROID_PACKAGE_NAME)
    }/purchases/products/${encodeURIComponent(productId)}/tokens/${
      encodeURIComponent(token)
    }`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
    { timeoutMs: 10_000, dependency: "google_play_product_lookup" },
  );
  if (!response.ok) throw new Error(`play_product_${response.status}`);
  const play = await response.json() as Record<string, unknown>;
  if (play.purchaseState !== 0) return false;
  if (play.quantity !== undefined && play.quantity !== 1) {
    throw new Error("multi_quantity_purchase_not_supported");
  }
  const tokenHash = await sha256Hex(token);
  const result = await serviceRpc("reconcile_google_play_one_time", {
    p_purchase_token_hash: tokenHash,
    p_product_id: productId,
    p_order_id: typeof play.orderId === "string" ? play.orderId : null,
    p_event_key: `rtdn:${messageId}`,
    p_payload: {
      source: "google_play_rtdn",
      purchaseState: play.purchaseState,
      acknowledgementState: play.acknowledgementState,
      consumptionState: play.consumptionState,
    },
  });
  if (result?.applied !== true && result?.duplicate !== true) return false;
  return await completeGooglePlayDelivery({
    accessToken,
    packageName: ANDROID_PACKAGE_NAME,
    productId,
    purchaseToken: token,
    kind: config.kind,
    alreadyAcknowledged: play.acknowledgementState === 1,
    alreadyConsumed: play.consumptionState === 1,
  });
}

async function processPendingRefundReview(
  notification: Record<string, unknown>,
): Promise<boolean> {
  const raw = notification.pendingRefundReviewNotification;
  if (
    !raw || typeof raw !== "object" || Array.isArray(raw) || !serviceAccount
  ) {
    return false;
  }
  const review = raw as Record<string, unknown>;
  const pendingRefundToken = typeof review.pendingRefundToken === "string"
    ? review.pendingRefundToken
    : "";
  const orderId = typeof review.orderId === "string" ? review.orderId : "";
  if (
    !pendingRefundToken || pendingRefundToken.length > 4_096 || !orderId ||
    orderId.length > 200
  ) return false;
  const accessToken = await getGoogleAccessToken(serviceAccount);
  const response = await fetchWithDeadline(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(ANDROID_PACKAGE_NAME)
    }/orders/${encodeURIComponent(orderId)}:reviewrefund`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        pendingRefundToken,
        sampleContentProvided: false,
        refundPreference: REFUND_REVIEW_PREFERENCE,
      }),
    },
    { timeoutMs: 10_000, dependency: "google_play_refund_review" },
  );
  const accepted = response.ok;
  await response.body?.cancel();
  return accepted;
}

async function processVoided(
  messageId: string,
  notification: Record<string, unknown>,
): Promise<boolean> {
  const raw = notification.voidedPurchaseNotification;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return false;
  const voided = raw as Record<string, unknown>;
  const token = typeof voided.purchaseToken === "string"
    ? voided.purchaseToken
    : "";
  if (!token) return false;
  if (Number(voided.refundType ?? 1) === 2) {
    // ChronoSpark deliberately rejects multi-quantity purchases at verification,
    // so a partial-quantity refund is never safe to turn into a full reversal.
    throw new Error("partial_refund_requires_manual_reconciliation");
  }
  const tokenHash = await sha256Hex(token);
  const result = await serviceRpc("reconcile_google_play_voided_purchase", {
    p_purchase_token_hash: tokenHash,
    p_event_key: `rtdn:${messageId}`,
    p_order_id: typeof voided.orderId === "string" ? voided.orderId : null,
    p_payload: {
      source: "google_play_rtdn",
      productType: voided.productType,
      refundType: voided.refundType,
    },
  });
  return result?.applied === true || result?.duplicate === true;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405,
      headers: { "X-ChronoSpark-Contract": "google-play-rtdn-v2" },
    });
  }
  if (!SUPABASE_URL || !SUPABASE_SECRET_KEY || !serviceAccount) {
    return new Response("Not configured", { status: 503 });
  }
  let messageId = "";
  let eventState = "received";
  try {
    if (
      !await validateGoogleOidcPush(
        req,
        RTDN_AUDIENCE,
        RTDN_SERVICE_ACCOUNT_EMAIL,
      )
    ) return new Response("Unauthorized", { status: 401 });
    const envelope = await readBoundedJson(req, {
      maxBytes: 32_768,
    }) as PubSubEnvelope;
    messageId = envelope.message?.messageId?.trim() ?? "";
    const encoded = envelope.message?.data ?? "";
    if (!messageId || messageId.length > 200 || !encoded) {
      return new Response("Invalid envelope", { status: 400 });
    }
    const existing = await readEvent(messageId);
    if (existing?.state === "processed" || existing?.state === "ignored") {
      return new Response(null, { status: 204 });
    }
    eventState = existing?.state === "failed" ? "failed" : "received";
    const notification = decodeNotification(encoded);
    if (!notification || notification.packageName !== ANDROID_PACKAGE_NAME) {
      return new Response("Invalid notification", { status: 400 });
    }
    const eventTimeMs = Number(notification.eventTimeMillis ?? 0);
    const eventTime = new Date(eventTimeMs);
    if (!Number.isFinite(eventTime.getTime())) {
      return new Response("Invalid event time", { status: 400 });
    }
    const eventType = notification.subscriptionNotification
      ? "subscription"
      : notification.voidedPurchaseNotification
      ? "voided_purchase"
      : notification.oneTimeProductNotification
      ? "one_time_product"
      : notification.pendingRefundReviewNotification
      ? "pending_refund_review"
      : notification.testNotification
      ? "test"
      : "unknown";

    if (
      !existing && !await insertEvent(messageId, {
        package_name: ANDROID_PACKAGE_NAME,
        event_time: eventTime.toISOString(),
        event_type: eventType,
        payload: { source: "google_play_rtdn" },
        state: "received",
      })
    ) {
      throw new Error("event_insert_failed");
    }

    let processed = false;
    if (eventType === "subscription") {
      processed = await processSubscription(messageId, notification);
    } else if (eventType === "voided_purchase") {
      processed = await processVoided(messageId, notification);
    } else if (eventType === "one_time_product") {
      processed = await processOneTime(messageId, notification);
    } else if (eventType === "pending_refund_review") {
      processed = await processPendingRefundReview(notification);
    } else if (eventType === "test") {
      processed = true;
    } else {
      throw new Error("unsupported_event");
    }

    if (!processed) throw new Error("reconciliation_not_applied");
    if (!await markEvent(messageId, eventState, "processed")) {
      throw new Error("event_state_update_failed");
    }
    return new Response(null, { status: 204 });
  } catch (error) {
    const code = error instanceof EdgeHttpError
      ? error.code
      : error instanceof Error
      ? error.message.slice(0, 100)
      : "unknown_failure";
    if (messageId && /^[A-Za-z0-9._:-]{1,200}$/.test(messageId)) {
      try {
        await markEvent(messageId, eventState, "failed", code);
      } catch {
        // Non-2xx below preserves Pub/Sub retry when ledger persistence fails.
      }
    }
    logEdgeEvent("error", "google_play_rtdn_failed", { code });
    return new Response("processing_failed", { status: 500 });
  }
});

