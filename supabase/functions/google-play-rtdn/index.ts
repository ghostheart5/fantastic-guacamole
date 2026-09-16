/// <reference lib="deno.ns" />
import { CREDIT_TOPUPS, verifyCreditTopup } from "../_shared/credit_topups.ts";

import { respondToGooglePlayRefundReview } from "../_shared/google_play_refund_review.ts";

import {
  getGoogleAccessToken,
  type GoogleServiceAccount,
  sha256Hex,
  validateGoogleOidcPush,
} from "../_shared/google_auth.ts";
import {
  bindVerifiedLinkedPurchaseToken,
  decodePubSubNotification,
  googleSubscriptionNotificationCause,
  googleSubscriptionState,
  googleSubscriptionStateForNotification,
  reconciliationWasHandled,
  resolveSubscriptionAuthorityPurchase,
  terminalNotificationMatchesSubscriptionState,
  unboundTerminalReconciliationWasHandled,
  validatePaidRenewalAuthority,
} from "../_shared/google_play_rtdn.ts";
import {
  acknowledgeGooglePlaySubscription,
  applyGooglePlayAuthorityAfterAcknowledgement,
  isGooglePlayTestPurchase,
  readLatestSuccessfulOrderId,
  readLinkedPurchaseToken,
  readPurchaseLineage,
  selectSubscriptionAuthorityLine,
} from "../_shared/subscription_verification.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANDROID_PACKAGE_NAME = Deno.env.get("ANDROID_PACKAGE_NAME") ??
  "com.ghostheart5.chronospark";
const RTDN_AUDIENCE = Deno.env.get("RTDN_AUDIENCE") ?? "";
const RTDN_SERVICE_ACCOUNT_EMAIL = Deno.env.get("RTDN_SERVICE_ACCOUNT_EMAIL") ??
  "";
const ALLOWED_PRODUCT_IDS = new Set([
  "chronospark_premium_monthly",
  "chronospark_premium_annual",
]);

interface PubSubEnvelope {
  message?: { data?: string; messageId?: string };
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

async function claimEvent(
  messageId: string,
  values: Record<string, unknown>,
): Promise<{ claimed: boolean; completed: boolean }> {
  const result = await serviceRpc("claim_google_play_rtdn_event", {
    p_message_id: messageId,
    p_package_name: values.package_name,
    p_event_time: values.event_time,
    p_event_type: values.event_type,
    p_payload: values.payload,
  });
  if (!result) throw new Error("event_claim_failed");
  return {
    claimed: result.claimed === true,
    completed: result.completed === true,
  };
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
  accessToken: string,
): Promise<Record<string, unknown>> {
  const response = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(ANDROID_PACKAGE_NAME)
    }/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  if (!response.ok) throw new Error(`play_subscription_${response.status}`);
  return await response.json() as Record<string, unknown>;
}

async function finishUnboundTerminalEvent(
  result: Record<string, unknown> | null,
  messageId: string,
  tokenHash: string,
  status: string,
  active: boolean,
  providerConfirmedTerminal: boolean,
): Promise<boolean> {
  const handled = await unboundTerminalReconciliationWasHandled(
    result,
    status,
    active,
    async () => {
      const response = await fetch(
        `${SUPABASE_URL}/rest/v1/purchase_bindings?token_hash=eq.${
          encodeURIComponent(tokenHash)
        }&select=token_hash&limit=1`,
        { headers: serviceHeaders() },
      );
      if (!response.ok) {
        await response.body?.cancel();
        return null;
      }
      const rows = await response.json();
      return Array.isArray(rows) ? rows.length > 0 : null;
    },
    providerConfirmedTerminal,
  );
  if (handled) {
    await updateEvent(messageId, {
      payload: {
        source: "google_play_rtdn",
        resolution: "unbound_terminal_purchase",
        providerStatus: status,
      },
    });
  }
  return handled;
}

async function reconcileSubscriptionAuthority(input: {
  messageId: string;
  eventTime: Date;
  cause: ReturnType<typeof googleSubscriptionNotificationCause>;
  purchase: Record<string, unknown>;
  purchaseToken: string;
  authoritySource: "notification_token" | "linked_predecessor";
  lineageSource: "linked_purchase" | "out_of_app_resubscribe" | null;
  accessToken: string;
  expectedProductId: string | null;
}): Promise<boolean> {
  if (!input.cause.supported) {
    throw new Error("play_subscription_notification_type_unsupported");
  }
  const observedAt = new Date();
  const line = selectSubscriptionAuthorityLine(
    input.purchase,
    ALLOWED_PRODUCT_IDS,
    observedAt.getTime(),
  );
  if (
    input.expectedProductId !== null &&
    line.productId !== input.expectedProductId
  ) {
    throw new Error("play_subscription_notification_product_mismatch");
  }
  const expiresAt = line.expiryTimeMs === null
    ? null
    : new Date(line.expiryTimeMs);
  const subscriptionState = input.purchase.subscriptionState;
  if (
    input.authoritySource === "notification_token" &&
    !terminalNotificationMatchesSubscriptionState(
      input.cause.notificationType,
      subscriptionState,
    )
  ) {
    throw new Error("play_subscription_terminal_state_mismatch");
  }
  const state = input.authoritySource === "notification_token"
    ? googleSubscriptionStateForNotification(
      input.cause.notificationType,
      subscriptionState,
      expiresAt,
      observedAt,
    )
    : googleSubscriptionState(subscriptionState, expiresAt, observedAt);
  if (!state.supported) {
    throw new Error("play_subscription_state_unsupported");
  }
  if (state.active && expiresAt === null) {
    throw new Error("play_subscription_active_expiry_missing");
  }

  const orderId = readLatestSuccessfulOrderId(input.purchase, line.raw);
  validatePaidRenewalAuthority(
    input.cause,
    state,
    line.successfulLineOrderId,
  );
  const offerDetails = line.raw.offerDetails !== null &&
      typeof line.raw.offerDetails === "object" &&
      !Array.isArray(line.raw.offerDetails)
    ? line.raw.offerDetails as Record<string, unknown>
    : null;
  const purchaseTokenHash = await sha256Hex(input.purchaseToken);
  const authority = await applyGooglePlayAuthorityAfterAcknowledgement(
    {
      active: state.active,
      acknowledgementState: input.purchase.acknowledgementState,
    },
    () =>
      acknowledgeGooglePlaySubscription({
        packageName: ANDROID_PACKAGE_NAME,
        productId: line.productId,
        purchaseToken: input.purchaseToken,
        accessToken: input.accessToken,
      }),
    () =>
      serviceRpc("reconcile_google_play_subscription", {
        p_purchase_token_hash: purchaseTokenHash,
        p_product_id: line.productId,
        p_status: state.status,
        p_is_active: state.active,
        p_auto_renews: line.autoRenews,
        p_order_id: orderId,
        p_expires_at: expiresAt?.toISOString() ?? null,
        p_provider_event_time: observedAt.toISOString(),
        p_event_key: input.authoritySource === "notification_token"
          ? `rtdn:${input.messageId}`
          : `rtdn:${input.messageId}:linked-predecessor`,
        p_payload: {
          source: "google_play_rtdn",
          authoritySource: input.authoritySource,
          lineageSource: input.lineageSource,
          notificationEventTime: input.eventTime.toISOString(),
          notificationType: input.cause.notificationType,
          subscriptionState,
          acknowledgementState: input.purchase.acknowledgementState,
          basePlanId: offerDetails?.basePlanId,
          prepaidPlan: line.raw.prepaidPlan !== null &&
            typeof line.raw.prepaidPlan === "object" &&
            !Array.isArray(line.raw.prepaidPlan),
          testPurchase: isGooglePlayTestPurchase(input.purchase),
          offerId: offerDetails?.offerId,
          cause: {
            notificationType: input.cause.notificationType,
            eventName: input.cause.eventName,
            paidRenewal: input.cause.paidRenewal,
          },
        },
      }),
  );
  if (authority.status === "acknowledgement_unsupported") {
    throw new Error("play_subscription_acknowledgement_state_unsupported");
  }
  if (authority.status === "acknowledgement_retryable") {
    throw new Error("play_subscription_acknowledgement_retryable");
  }
  const result = authority.value;
  if (reconciliationWasHandled(result)) return true;
  return await finishUnboundTerminalEvent(
    result,
    input.messageId,
    purchaseTokenHash,
    state.status,
    state.active,
    true,
  );
}

async function processSubscription(
  messageId: string,
  notification: Record<string, unknown>,
  serviceAccount: GoogleServiceAccount,
  eventTime: Date,
): Promise<boolean> {
  const raw = notification.subscriptionNotification;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return false;
  const subscription = raw as Record<string, unknown>;
  const purchaseToken = typeof subscription.purchaseToken === "string"
    ? subscription.purchaseToken.trim()
    : "";
  if (!purchaseToken || purchaseToken.length > 4096) return false;
  const cause = googleSubscriptionNotificationCause(
    subscription.notificationType,
  );
  if (!cause.supported) {
    throw new Error("play_subscription_notification_type_unsupported");
  }
  const accessToken = await getGoogleAccessToken(serviceAccount);
  const play = await fetchSubscription(purchaseToken, accessToken);
  const observedAt = new Date();
  const providerProductId = selectSubscriptionAuthorityLine(
    play,
    ALLOWED_PRODUCT_IDS,
    observedAt.getTime(),
  ).productId;
  const purchaseTokenHash = await sha256Hex(purchaseToken);
  const linkedPurchaseToken = readLinkedPurchaseToken(play);
  const lineage = readPurchaseLineage(play);
  if (
    lineage?.source === "out_of_app_resubscribe" &&
    cause.notificationType !== 4
  ) {
    throw new Error("out_of_app_resubscribe_notification_mismatch");
  }
  const resolved = await resolveSubscriptionAuthorityPurchase({
    notificationType: cause.notificationType,
    successorPurchase: play,
    successorPurchaseToken: purchaseToken,
    linkedPurchaseToken,
  }, (token) => fetchSubscription(token, accessToken));
  if (lineage !== null) {
    const predecessorTokenHash = await sha256Hex(lineage.purchaseToken);
    if (predecessorTokenHash === purchaseTokenHash) {
      throw new Error("purchase_lineage_matches_successor");
    }
    await bindVerifiedLinkedPurchaseToken({
      purchaseTokenHash,
      predecessorTokenHash,
      productId: providerProductId,
      boundAt: observedAt,
    }, serviceRpc);
  }
  return await reconcileSubscriptionAuthority({
    messageId,
    eventTime,
    cause,
    purchase: resolved.purchase,
    purchaseToken: resolved.purchaseToken,
    authoritySource: resolved.source,
    lineageSource: lineage?.source ?? null,
    accessToken,
    expectedProductId: resolved.source === "notification_token"
      ? providerProductId
      : null,
  });
}

async function processVoided(
  messageId: string,
  notification: Record<string, unknown>,
  eventTime: Date,
): Promise<boolean> {
  const raw = notification.voidedPurchaseNotification;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return false;
  const voided = raw as Record<string, unknown>;
  const purchaseToken = typeof voided.purchaseToken === "string"
    ? voided.purchaseToken
    : "";
  if (!purchaseToken || purchaseToken.length > 4096) return false;
  if (voided.productType === 2) {
    const result = await serviceRpc("revoke_verified_credit_topup", {
      p_token_hash: await sha256Hex(purchaseToken),
      p_product_id: null,
      p_order_id: typeof voided.orderId === "string" ? voided.orderId : null,
    });
    // A trusted voided token can be tombstoned before its product is known.
    return result?.handled === true;
  }
  const result = await serviceRpc("reconcile_google_play_voided_purchase", {
    p_purchase_token_hash: await sha256Hex(purchaseToken),
    p_provider_event_time: eventTime.toISOString(),
    p_event_key: `rtdn:${messageId}`,
    p_order_id: typeof voided.orderId === "string" ? voided.orderId : null,
    p_payload: {
      source: "google_play_rtdn",
      productType: voided.productType,
      refundType: voided.refundType,
    },
  });
  if (reconciliationWasHandled(result)) return true;
  return await finishUnboundTerminalEvent(
    result,
    messageId,
    await sha256Hex(purchaseToken),
    "revoked",
    false,
    // A voided notification alone cannot close an absent binding. Client
    // verification may still be binding this token using an earlier snapshot.
    // Keep Pub/Sub retrying until revocation is durably reconciled.
    false,
  );
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
  let eventClaimed = false;
  try {
    const envelope = await req.json() as PubSubEnvelope;
    messageId = envelope.message?.messageId?.trim() ?? "";
    const encoded = envelope.message?.data ?? "";
    if (!messageId || messageId.length > 200 || !encoded) {
      return new Response("Invalid envelope", { status: 400 });
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
      : notification.oneTimeProductNotification
      ? "one_time_product"
      : notification.voidedPurchaseNotification
      ? "voided_purchase"
      : notification.pendingRefundReviewNotification
      ? "pending_refund_review"
      : notification.testNotification
      ? "test"
      : "unsupported";
    const claim = await claimEvent(messageId, {
      package_name: ANDROID_PACKAGE_NAME,
      event_time: eventTime.toISOString(),
      event_type: eventType,
      payload: { source: "google_play_rtdn" },
    });
    if (claim.completed) return new Response(null, { status: 204 });
    if (!claim.claimed) {
      return new Response("RTDN processing already in progress", {
        status: 500,
      });
    }
    eventClaimed = true;

    if (eventType === "one_time_product") {
      const event = notification.oneTimeProductNotification as Record<
        string,
        unknown
      >;
      const sku = String(event.sku ?? ""),
        token = String(event.purchaseToken ?? "");
      if (
        !CREDIT_TOPUPS.has(sku) || !token || token.length > 4096 ||
        ![1, 2].includes(Number(event.notificationType))
      ) {
        throw new Error("invalid_credit_notification");
      }
      const accessToken = await getGoogleAccessToken(serviceAccount);
      const url =
        `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
          encodeURIComponent(ANDROID_PACKAGE_NAME)
        }/purchases/products/${encodeURIComponent(sku)}/tokens/${
          encodeURIComponent(token)
        }`;
      const response = await fetch(url, {
        headers: { Authorization: `Bearer ${accessToken}` },
        signal: AbortSignal.timeout(15000),
      });
      if (!response.ok) {
        await response.body?.cancel();
        throw new Error("credit_provider_retry");
      }
      const purchase = await response.json() as Record<string, unknown>;
      if (purchase.purchaseState === 1) {
        const revoked = await serviceRpc("revoke_verified_credit_topup", {
          p_token_hash: await sha256Hex(token),
          p_product_id: sku,
          p_order_id: purchase.orderId ?? null,
        });
        if (revoked?.handled !== true) throw new Error("credit_revoke_retry");
      } else if (purchase.purchaseState === 0) {
        const owner = await serviceRpc("credit_topup_owner", {
          p_fingerprint: purchase.obfuscatedExternalAccountId ?? "",
        });
        if (typeof owner?.userId !== "string") {
          throw new Error("credit_owner_unresolved");
        }
        const result = await verifyCreditTopup({
          config: {
            supabaseUrl: SUPABASE_URL,
            publishableKey: "",
            secretKey: SUPABASE_SECRET_KEY,
          },
          userId: owner.userId,
          packageName: ANDROID_PACKAGE_NAME,
          productId: sku,
          token,
          accessToken,
          requireTest: true,
        });
        if (result.valid !== true) throw new Error("credit_grant_retry");
      } else if (purchase.purchaseState !== 2) {
        throw new Error("credit_state_invalid");
      }
      await updateEvent(messageId, { state: "processed", failure_code: null });
      return new Response(null, { status: 204 });
    }

    if (eventType === "pending_refund_review") {
      await respondToGooglePlayRefundReview(
        notification,
        ANDROID_PACKAGE_NAME,
        await getGoogleAccessToken(serviceAccount),
      );
      await updateEvent(messageId, {
        state: "processed",
        failure_code: null,
        payload: {
          source: "google_play_rtdn",
          reviewResponse: "accepted",
          refundPreference: "NEUTRAL",
          sampleContentProvided: true,
          consumptionEvidence: "omitted_not_order_attributable",
        },
      });
      return new Response(null, { status: 204 });
    }

    if (eventType === "unsupported") {
      await updateEvent(messageId, {
        state: "ignored",
        failure_code: "unsupported_event",
      });
      return new Response(null, { status: 204 });
    }
    const processed = eventType === "subscription"
      ? await processSubscription(
        messageId,
        notification,
        serviceAccount,
        eventTime,
      )
      : eventType === "voided_purchase"
      ? await processVoided(messageId, notification, eventTime)
      : true;
    if (!processed) throw new Error("reconciliation_not_applied");
    await updateEvent(messageId, { state: "processed", failure_code: null });
    return new Response(null, { status: 204 });
  } catch (error) {
    if (messageId && eventClaimed) {
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
