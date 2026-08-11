/// <reference lib="deno.ns" />
import {
  getGoogleAccessToken,
  type GoogleServiceAccount,
  sha256Hex,
  validateGoogleOidcPush,
} from "../_shared/google_auth.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANDROID_PACKAGE_NAME = Deno.env.get("ANDROID_PACKAGE_NAME") ??
  "com.ghostheart5.chronospark";
const RTDN_AUDIENCE = Deno.env.get("RTDN_AUDIENCE") ?? "";
const RTDN_SERVICE_ACCOUNT_EMAIL = Deno.env.get("RTDN_SERVICE_ACCOUNT_EMAIL") ??
  "";
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
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: serviceHeaders(),
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    await response.body?.cancel();
    return null;
  }
  const data = await response.json();
  return data && typeof data === "object" && !Array.isArray(data)
    ? data as Record<string, unknown>
    : null;
}

async function readEvent(
  messageId: string,
): Promise<Record<string, unknown> | null> {
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/google_play_rtdn_events?message_id=eq.${
      encodeURIComponent(messageId)
    }&select=state`,
    { headers: serviceHeaders() },
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
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/google_play_rtdn_events`,
    {
      method: "POST",
      headers: {
        ...serviceHeaders(),
        Prefer: "resolution=ignore-duplicates,return=minimal",
      },
      body: JSON.stringify({ message_id: messageId, ...event }),
    },
  );
  return response.ok;
}

async function updateEvent(
  messageId: string,
  values: Record<string, unknown>,
): Promise<void> {
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/google_play_rtdn_events?message_id=eq.${
      encodeURIComponent(messageId)
    }`,
    {
      method: "PATCH",
      headers: serviceHeaders(),
      body: JSON.stringify({
        ...values,
        processed_at: new Date().toISOString(),
      }),
    },
  );
  await response.body?.cancel();
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
): Promise<Record<string, unknown>> {
  if (!serviceAccount) throw new Error("service_account_missing");
  const accessToken = await getGoogleAccessToken(serviceAccount);
  const response = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(ANDROID_PACKAGE_NAME)
    }/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  if (!response.ok) throw new Error(`play_subscription_${response.status}`);
  return await response.json() as Record<string, unknown>;
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
  const play = await fetchSubscription(token);
  const lineItems = Array.isArray(play.lineItems)
    ? play.lineItems as SubscriptionLineItem[]
    : [];
  const line = lineItems.find((item) =>
    item.productId === "chronospark_premium_monthly" ||
    item.productId === "chronospark_premium_annual"
  );
  if (!line?.productId) throw new Error("play_subscription_product_missing");
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
  return result?.applied === true || result?.duplicate === true;
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
      headers: { "X-ChronoSpark-Contract": "google-play-rtdn-v1" },
    });
  }
  if (!SUPABASE_URL || !SUPABASE_SECRET_KEY || !serviceAccount) {
    return new Response("Not configured", { status: 503 });
  }
  if (
    !await validateGoogleOidcPush(
      req,
      RTDN_AUDIENCE,
      RTDN_SERVICE_ACCOUNT_EMAIL,
    )
  ) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const envelope = await req.json() as PubSubEnvelope;
    const messageId = envelope.message?.messageId?.trim() ?? "";
    const encoded = envelope.message?.data ?? "";
    if (!messageId || messageId.length > 200 || !encoded) {
      return new Response("Invalid envelope", { status: 400 });
    }
    const existing = await readEvent(messageId);
    if (existing?.state === "processed" || existing?.state === "ignored") {
      return new Response(null, { status: 204 });
    }
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
    } else if (eventType === "test") {
      processed = true;
    } else {
      await updateEvent(messageId, {
        state: "ignored",
        failure_code: "unsupported_event",
      });
      return new Response(null, { status: 204 });
    }

    if (!processed) throw new Error("reconciliation_not_applied");
    await updateEvent(messageId, { state: "processed", failure_code: null });
    return new Response(null, { status: 204 });
  } catch (error) {
    console.error("Google Play RTDN processing failed");
    const message = error instanceof Error ? error.message : "unknown_failure";
    // Pub/Sub retries non-2xx responses. No raw purchase token is logged.
    return new Response(message.slice(0, 100), { status: 500 });
  }
});
