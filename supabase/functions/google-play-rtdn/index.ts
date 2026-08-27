/// <reference lib="deno.ns" />

import {
  getGoogleAccessToken,
  type GoogleServiceAccount,
  sha256Hex,
  validateGoogleOidcPush,
} from "../_shared/google_auth.ts";
import {
  decodePubSubNotification,
  googleSubscriptionState,
} from "../_shared/google_play_rtdn.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANDROID_PACKAGE_NAME = Deno.env.get("ANDROID_PACKAGE_NAME") ??
  "com.ghostheart5.chronospark";
const RTDN_AUDIENCE = Deno.env.get("RTDN_AUDIENCE") ?? "";
const RTDN_SERVICE_ACCOUNT_EMAIL = Deno.env.get("RTDN_SERVICE_ACCOUNT_EMAIL") ??
  "";

interface PubSubEnvelope {
  message?: { data?: string; messageId?: string };
}

interface SubscriptionLineItem {
  productId?: string;
  expiryTime?: string;
  autoRenewingPlan?: { autoRenewEnabled?: boolean };
  offerDetails?: { basePlanId?: string; offerId?: string };
}

function readServiceAccount(): GoogleServiceAccount | null {
  try {
    const value = JSON.parse(
      Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON") ?? "null",
    );
    return value && typeof value === "object"
      ? value as GoogleServiceAccount
      : null;
  } catch {
    return null;
  }
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
  const value = await response.json();
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

async function readEvent(messageId: string): Promise<string | null> {
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/google_play_rtdn_events?message_id=eq.${
      encodeURIComponent(messageId)
    }&select=state`,
    { headers: serviceHeaders() },
  );
  if (!response.ok) return null;
  const rows = await response.json();
  return Array.isArray(rows) && typeof rows[0]?.state === "string"
    ? rows[0].state
    : null;
}

async function insertEvent(
  messageId: string,
  values: Record<string, unknown>,
): Promise<boolean> {
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/google_play_rtdn_events`,
    {
      method: "POST",
      headers: {
        ...serviceHeaders(),
        Prefer: "resolution=ignore-duplicates,return=minimal",
      },
      body: JSON.stringify({ message_id: messageId, ...values }),
    },
  );
  await response.body?.cancel();
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
  if (!response.ok) throw new Error("event_update_failed");
}

async function fetchSubscription(
  purchaseToken: string,
  serviceAccount: GoogleServiceAccount,
): Promise<Record<string, unknown>> {
  const accessToken = await getGoogleAccessToken(serviceAccount);
  const response = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(ANDROID_PACKAGE_NAME)
    }/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  if (!response.ok) throw new Error(`play_subscription_${response.status}`);
  return await response.json() as Record<string, unknown>;
}

async function processSubscription(
  messageId: string,
  notification: Record<string, unknown>,
  serviceAccount: GoogleServiceAccount,
): Promise<boolean> {
  const raw = notification.subscriptionNotification;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return false;
  const subscription = raw as Record<string, unknown>;
  const purchaseToken = typeof subscription.purchaseToken === "string"
    ? subscription.purchaseToken
    : "";
  if (!purchaseToken || purchaseToken.length > 4096) return false;
  const play = await fetchSubscription(purchaseToken, serviceAccount);
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
  const state = googleSubscriptionState(
    String(play.subscriptionState ?? ""),
    expiresAt,
  );
  const result = await serviceRpc("reconcile_google_play_subscription", {
    p_purchase_token_hash: await sha256Hex(purchaseToken),
    p_product_id: line.productId,
    p_status: state.status,
    p_is_active: state.active,
    p_auto_renews: line.autoRenewingPlan?.autoRenewEnabled === true,
    p_order_id: typeof play.latestOrderId === "string"
      ? play.latestOrderId
      : null,
    p_expires_at: expiresAt?.toISOString() ?? null,
    p_event_key: `rtdn:${messageId}`,
    p_payload: {
      source: "google_play_rtdn",
      notificationType: subscription.notificationType,
      subscriptionState: play.subscriptionState,
      acknowledgementState: play.acknowledgementState,
      basePlanId: line.offerDetails?.basePlanId,
      offerId: line.offerDetails?.offerId,
    },
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
  const purchaseToken = typeof voided.purchaseToken === "string"
    ? voided.purchaseToken
    : "";
  if (!purchaseToken || purchaseToken.length > 4096) return false;
  const result = await serviceRpc("reconcile_google_play_voided_purchase", {
    p_purchase_token_hash: await sha256Hex(purchaseToken),
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
    return new Response("Method not allowed", { status: 405 });
  }
  const serviceAccount = readServiceAccount();
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
  let messageId = "";
  try {
    const envelope = await req.json() as PubSubEnvelope;
    messageId = envelope.message?.messageId?.trim() ?? "";
    const encoded = envelope.message?.data ?? "";
    if (!messageId || messageId.length > 200 || !encoded) {
      return new Response("Invalid envelope", { status: 400 });
    }
    const existingState = await readEvent(messageId);
    if (existingState === "processed" || existingState === "ignored") {
      return new Response(null, { status: 204 });
    }
    const notification = decodePubSubNotification(encoded);
    if (!notification || notification.packageName !== ANDROID_PACKAGE_NAME) {
      return new Response("Invalid notification", { status: 400 });
    }
    const eventTime = new Date(Number(notification.eventTimeMillis ?? 0));
    if (!Number.isFinite(eventTime.getTime())) {
      return new Response("Invalid event time", { status: 400 });
    }
    const eventType = notification.subscriptionNotification
      ? "subscription"
      : notification.voidedPurchaseNotification
      ? "voided_purchase"
      : notification.testNotification
      ? "test"
      : "unsupported";
    if (
      !existingState && !await insertEvent(messageId, {
        package_name: ANDROID_PACKAGE_NAME,
        event_time: eventTime.toISOString(),
        event_type: eventType,
        payload: { source: "google_play_rtdn" },
        state: "received",
      })
    ) throw new Error("event_insert_failed");

    if (eventType === "unsupported") {
      await updateEvent(messageId, {
        state: "ignored",
        failure_code: "unsupported_event",
      });
      return new Response(null, { status: 204 });
    }
    const processed = eventType === "subscription"
      ? await processSubscription(messageId, notification, serviceAccount)
      : eventType === "voided_purchase"
      ? await processVoided(messageId, notification)
      : true;
    if (!processed) throw new Error("reconciliation_not_applied");
    await updateEvent(messageId, { state: "processed", failure_code: null });
    return new Response(null, { status: 204 });
  } catch (error) {
    if (messageId) {
      try {
        await updateEvent(messageId, {
          state: "failed",
          failure_code: error instanceof Error
            ? error.message.slice(0, 100)
            : "unknown_failure",
        });
      } catch {
        // Pub/Sub will retry the original failure.
      }
    }
    return new Response("RTDN processing failed", { status: 500 });
  }
});
