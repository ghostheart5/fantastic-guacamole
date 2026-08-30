import {
  acknowledgeGooglePlaySubscription,
  applyGooglePlayAuthorityAfterAcknowledgement,
  buildPurchaseBindingArgs,
  buildSubscriptionReconciliationArgs,
  classifyGooglePlayProviderFailure,
  classifyPurchaseBinding,
  classifyVerificationReconciliation,
  existingPurchaseProofPolicy,
  googlePlayAcknowledgementState,
  readLatestSuccessfulOrderId,
  readLinkedPurchaseToken,
  readPurchaseLineage,
  verifyExistingPurchaseRecoveryBinding,
  verifyExternalAccountBinding,
  verifySubscriptionLineItem,
} from "../_shared/subscription_verification.ts";

const nowMs = Date.parse("2026-08-27T00:00:00.000Z");
const products = new Set([
  "chronospark_premium_monthly",
  "chronospark_premium_annual",
]);

function purchase(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    lineItems: [{
      productId: "chronospark_premium_monthly",
      expiryTime: "2026-09-27T00:00:00.000Z",
    }],
    ...overrides,
  };
}

Deno.test("active matching subscription is accepted", () => {
  const verified = verifySubscriptionLineItem(
    purchase(),
    "chronospark_premium_monthly",
    nowMs,
  );
  if (verified?.expiryTimeMs !== Date.parse("2026-09-27T00:00:00.000Z")) {
    throw new Error("matching subscription was rejected");
  }
});

Deno.test("initial and cancelled subscriptions retain access through expiry", () => {
  const initial = verifySubscriptionLineItem(
    purchase({ acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING" }),
    "chronospark_premium_monthly",
    nowMs,
  );
  if (initial?.status !== "active") {
    throw new Error("initial unacknowledged purchase was rejected");
  }
  const cancelled = verifySubscriptionLineItem(
    purchase({ subscriptionState: "SUBSCRIPTION_STATE_CANCELED" }),
    "chronospark_premium_monthly",
    nowMs,
  );
  if (cancelled?.status !== "canceled") {
    throw new Error("cancelled subscription lost access before expiry");
  }
});

Deno.test("mismatched and expired subscriptions fail closed", () => {
  if (
    verifySubscriptionLineItem(
      purchase(),
      "chronospark_premium_annual",
      nowMs,
      products,
    )
  ) {
    throw new Error("mismatched product accepted");
  }
  let incoherentActiveFailed = false;
  try {
    verifySubscriptionLineItem(
      purchase({
        lineItems: [{
          productId: "chronospark_premium_monthly",
          expiryTime: "2026-08-26T00:00:00.000Z",
        }],
      }),
      "chronospark_premium_monthly",
      nowMs,
    );
  } catch {
    incoherentActiveFailed = true;
  }
  if (!incoherentActiveFailed) {
    throw new Error(
      "active provider state with expired authority was accepted",
    );
  }
  if (
    verifySubscriptionLineItem(
      purchase({
        subscriptionState: "SUBSCRIPTION_STATE_EXPIRED",
        lineItems: [{
          productId: "chronospark_premium_monthly",
          expiryTime: "2026-08-26T00:00:00.000Z",
        }],
      }),
      "chronospark_premium_monthly",
      nowMs,
    )
  ) throw new Error("expired purchase accepted");
});

Deno.test("hashed external account identifiers bind only to the auth user", async () => {
  const userId = "123e4567-e89b-12d3-a456-426614174000";
  const expectedHash =
    "986c0dc956dc822b5d8f698661b9eb1ef880786ff9043c16744d2a420e99e9bb";
  const matched = await verifyExternalAccountBinding(
    {
      startTime: "2026-08-30T00:00:00.000Z",
      externalAccountIdentifiers: {
        obfuscatedExternalAccountId: expectedHash,
      },
    },
    userId,
    null,
  );
  if (!matched.accepted || matched.mode !== "hashed_match") {
    throw new Error("matching obfuscated account id was rejected");
  }

  const mismatched = await verifyExternalAccountBinding(
    {
      startTime: "2026-08-30T00:00:00.000Z",
      externalAccountIdentifiers: {
        obfuscatedExternalAccountId: "0".repeat(64),
      },
    },
    userId,
    null,
  );
  if (mismatched.accepted || mismatched.reason !== "mismatch") {
    throw new Error("mismatched obfuscated account id was accepted");
  }

  const raw = await verifyExternalAccountBinding(
    {
      startTime: "2026-08-30T00:00:00.000Z",
      externalAccountIdentifiers: {
        obfuscatedExternalAccountId: userId,
      },
    },
    userId,
    null,
  );
  if (raw.accepted || raw.reason !== "raw_identifier") {
    throw new Error("raw user id was accepted as an obfuscated identifier");
  }
});

Deno.test("out-of-app resubscribe context supplies account and lineage proof", async () => {
  const userId = "123e4567-e89b-12d3-a456-426614174000";
  const expectedHash =
    "986c0dc956dc822b5d8f698661b9eb1ef880786ff9043c16744d2a420e99e9bb";
  const providerPurchase = {
    startTime: "2026-08-30T00:00:00.000Z",
    outOfAppPurchaseContext: {
      expiredExternalAccountIdentifiers: {
        obfuscatedExternalAccountId: expectedHash,
      },
      expiredPurchaseToken: "expired-purchase-token",
    },
  };
  const binding = await verifyExternalAccountBinding(
    providerPurchase,
    userId,
    null,
  );
  const lineage = readPurchaseLineage(providerPurchase);
  if (!binding.accepted || binding.mode !== "hashed_match") {
    throw new Error("expired external account identifier was rejected");
  }
  if (
    lineage?.source !== "out_of_app_resubscribe" ||
    lineage.purchaseToken !== "expired-purchase-token"
  ) {
    throw new Error("out-of-app expired token lineage was not preserved");
  }

  let ambiguousFailed = false;
  try {
    readPurchaseLineage({
      ...providerPurchase,
      linkedPurchaseToken: "linked-token",
    });
  } catch {
    ambiguousFailed = true;
  }
  if (!ambiguousFailed) {
    throw new Error("ambiguous linked and out-of-app lineage was accepted");
  }
  const invalidIdentifiers = await verifyExternalAccountBinding(
    {
      ...providerPurchase,
      outOfAppPurchaseContext: {
        expiredExternalAccountIdentifiers: [],
        expiredPurchaseToken: "expired-purchase-token",
      },
    },
    userId,
    null,
  );
  if (invalidIdentifiers.accepted || invalidIdentifiers.reason !== "invalid") {
    throw new Error("malformed expired account identifiers were accepted");
  }
});

Deno.test("missing account identifier is legacy-only and still needs binding", async () => {
  const userId = "123e4567-e89b-12d3-a456-426614174000";
  const cutoff = new Date("2026-08-30T00:00:00.000Z");
  const legacy = await verifyExternalAccountBinding(
    {
      startTime: "2026-08-29T23:59:59.000Z",
    },
    userId,
    cutoff,
  );
  if (
    !legacy.accepted ||
    legacy.mode !== "legacy_existing_binding_required" ||
    existingPurchaseProofPolicy(legacy) !== "required"
  ) {
    throw new Error(
      "pre-cutoff legacy purchase was not routed to binding proof",
    );
  }
  for (
    const [label, value, policy] of [
      ["no cutoff", "2026-08-29T23:59:59.000Z", null],
      ["at cutoff", "2026-08-30T00:00:00.000Z", cutoff],
      ["after cutoff", "2026-08-30T00:00:01.000Z", cutoff],
    ] as const
  ) {
    const result = await verifyExternalAccountBinding(
      { startTime: value },
      userId,
      policy,
    );
    if (result.accepted || result.reason !== "missing") {
      throw new Error(`${label} missing identifier was accepted`);
    }
    if (existingPurchaseProofPolicy(result) !== "required") {
      throw new Error(`${label} missing identifier bypassed existing proof`);
    }
  }
});

Deno.test("purchase recovery accepts only same-user or detached durable bindings", async () => {
  const userId = "123e4567-e89b-12d3-a456-426614174000";
  const otherUserId = "223e4567-e89b-12d3-a456-426614174000";
  const principalId = "323e4567-e89b-12d3-a456-426614174000";
  const currentHash = "a".repeat(64);
  const predecessorHash = "b".repeat(64);
  const baseInput = {
    supabaseUrl: "https://example.supabase.co",
    secretKey: "server-secret",
    purchaseTokenHash: currentHash,
    predecessorTokenHash: null,
    userId,
    productId: "chronospark_premium_monthly",
    allowedProductIds: products,
  };
  const responseFor = (
    bindingUserId: string | null,
    principalUserId: string | null,
  ) =>
  (request: string | URL | Request): Promise<Response> => {
    const url = String(request);
    if (url.includes("purchase_bindings")) {
      return Promise.resolve(Response.json([{
        user_id: bindingUserId,
        product_id: baseInput.productId,
        billing_principal_id: principalId,
      }]));
    }
    return Promise.resolve(Response.json([{
      current_user_id: principalUserId,
      retired_at: null,
    }]));
  };

  const sameUser = await verifyExistingPurchaseRecoveryBinding(
    baseInput,
    responseFor(userId, userId),
  );
  if (sameUser !== "same_user") {
    throw new Error("same-user current binding was not recoverable");
  }
  const detachedCurrent = await verifyExistingPurchaseRecoveryBinding(
    baseInput,
    responseFor(null, null),
  );
  if (detachedCurrent !== "detached_current") {
    throw new Error("detached current purchase was not recoverable");
  }
  const detachedPredecessor = await verifyExistingPurchaseRecoveryBinding(
    { ...baseInput, predecessorTokenHash: predecessorHash },
    (request) => {
      const url = String(request);
      if (
        url.includes("purchase_bindings") &&
        url.includes(`token_hash=eq.${currentHash}`)
      ) {
        return Promise.resolve(Response.json([]));
      }
      return responseFor(null, null)(request);
    },
  );
  if (detachedPredecessor !== "detached_predecessor") {
    throw new Error("detached predecessor purchase was not recoverable");
  }
  const ownedElsewhere = await verifyExistingPurchaseRecoveryBinding(
    baseInput,
    responseFor(otherUserId, otherUserId),
  );
  if (ownedElsewhere !== "mismatch") {
    throw new Error("another account's attached purchase was recoverable");
  }
  const retryable = await verifyExistingPurchaseRecoveryBinding(
    baseInput,
    () => Promise.resolve(new Response(null, { status: 503 })),
  );
  if (retryable !== "retryable") {
    throw new Error("recovery backend failure became terminal");
  }
});

Deno.test("server acknowledgement uses the verified subscription authority", async () => {
  let requestUrl = "";
  let requestInit: RequestInit | undefined;
  const acknowledged = await acknowledgeGooglePlaySubscription({
    packageName: "com.ghostheart5.chronospark",
    productId: "chronospark_premium_monthly",
    purchaseToken: "purchase-token",
    accessToken: "access-token",
  }, (input, init) => {
    requestUrl = String(input);
    requestInit = init;
    return Promise.resolve(new Response(null, { status: 200 }));
  });
  if (!acknowledged) throw new Error("successful acknowledgement was rejected");
  if (
    requestUrl !==
      "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.ghostheart5.chronospark/purchases/subscriptions/chronospark_premium_monthly/tokens/purchase-token:acknowledge" ||
    requestInit?.method !== "POST" || requestInit?.body !== "{}" ||
    (requestInit?.headers as Record<string, string>)?.Authorization !==
      "Bearer access-token"
  ) {
    throw new Error(
      "acknowledgement request did not preserve verified authority",
    );
  }
  const retryable = await acknowledgeGooglePlaySubscription({
    packageName: "com.ghostheart5.chronospark",
    productId: "chronospark_premium_monthly",
    purchaseToken: "purchase-token",
    accessToken: "access-token",
  }, () => Promise.resolve(new Response(null, { status: 503 })));
  if (retryable) throw new Error("failed acknowledgement was claimed complete");
});

Deno.test("active authority is never applied before acknowledgement", async () => {
  const events: string[] = [];
  const blocked = await applyGooglePlayAuthorityAfterAcknowledgement(
    { active: true, acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING" },
    () => {
      events.push("acknowledge");
      return Promise.resolve(false);
    },
    () => {
      events.push("apply");
      return Promise.resolve("authority");
    },
  );
  if (
    blocked.status !== "acknowledgement_retryable" ||
    events.join(",") !== "acknowledge"
  ) {
    throw new Error("failed acknowledgement invoked authority reconciliation");
  }

  events.length = 0;
  const applied = await applyGooglePlayAuthorityAfterAcknowledgement(
    { active: true, acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING" },
    () => {
      events.push("acknowledge");
      return Promise.resolve(true);
    },
    () => {
      events.push("apply");
      return Promise.resolve("authority");
    },
  );
  if (
    applied.status !== "applied" || applied.value !== "authority" ||
    events.join(",") !== "acknowledge,apply"
  ) {
    throw new Error("authority did not follow successful acknowledgement");
  }
});

Deno.test("provider and acknowledgement failures stay distinguishable", () => {
  if (
    classifyGooglePlayProviderFailure(404) !== "terminal" ||
    classifyGooglePlayProviderFailure(410) !== "terminal"
  ) {
    throw new Error("terminal provider rejection became retryable");
  }
  for (const status of [400, 401, 403, 429, 500, 503]) {
    if (classifyGooglePlayProviderFailure(status) !== "retryable") {
      throw new Error(`ambiguous provider status ${status} became terminal`);
    }
  }
  if (
    googlePlayAcknowledgementState("ACKNOWLEDGEMENT_STATE_PENDING") !==
      "pending" ||
    googlePlayAcknowledgementState("ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED") !==
      "acknowledged" ||
    googlePlayAcknowledgementState("future") !== "unsupported"
  ) {
    throw new Error("acknowledgement authority state was misclassified");
  }
});

Deno.test("purchase binding separates owner conflicts from retryable gaps", () => {
  const userId = "123e4567-e89b-12d3-a456-426614174000";
  if (
    classifyPurchaseBinding({ bound: true, userId }, userId) !== "accepted"
  ) {
    throw new Error("verified same-user binding was rejected");
  }
  for (
    const result of [
      { bound: true, userId: "different-user" },
      { bound: false, reason: "binding_owned" },
      { bound: false, reason: "lineage_mismatch" },
    ]
  ) {
    if (classifyPurchaseBinding(result, userId) !== "terminal") {
      throw new Error("authoritative binding conflict became retryable");
    }
  }
  for (
    const result of [
      null,
      { bound: false, reason: "predecessor_unresolved" },
      { bound: false, reason: "principal_unresolved" },
    ]
  ) {
    if (classifyPurchaseBinding(result, userId) !== "retry") {
      throw new Error("ambiguous binding failure became terminal");
    }
  }
});

Deno.test("line-item successful order wins with validated legacy fallback", () => {
  const lineItem = {
    productId: "chronospark_premium_monthly",
    expiryTime: "2026-09-27T00:00:00.000Z",
    latestSuccessfulOrderId: " line-order-123 ",
  };
  if (
    readLatestSuccessfulOrderId({ latestOrderId: "legacy-order" }, lineItem) !==
      "line-order-123"
  ) {
    throw new Error("line-item order id did not take precedence");
  }
  if (
    readLatestSuccessfulOrderId(
      { latestOrderId: " legacy-order " },
      { productId: "chronospark_premium_monthly" },
    ) !== "legacy-order"
  ) {
    throw new Error("legacy top-level order fallback was not preserved");
  }
  for (const invalid of ["", "   ", 123, null]) {
    let failed = false;
    try {
      readLatestSuccessfulOrderId(
        { latestOrderId: "legacy-order" },
        { latestSuccessfulOrderId: invalid },
      );
    } catch {
      failed = true;
    }
    if (!failed) {
      throw new Error(`invalid line-item order was accepted: ${invalid}`);
    }
  }
});

Deno.test("receipt reconciliation builds timestamped authority arguments", () => {
  const observedAt = new Date("2026-08-27T00:00:05.000Z");
  const expiryTimeMs = Date.parse("2026-09-27T00:00:00.000Z");
  const args = buildSubscriptionReconciliationArgs({
    purchaseTokenHash: "token-hash",
    productId: "chronospark_premium_monthly",
    status: "active",
    isActive: true,
    autoRenews: true,
    orderId: "order-123",
    expiryTimeMs,
    providerObservedAt: observedAt,
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
  });
  if (args.p_provider_event_time !== observedAt.toISOString()) {
    throw new Error("provider observation time was not forwarded exactly");
  }
  if (args.p_expires_at !== "2026-09-27T00:00:00.000Z") {
    throw new Error("verified expiry was not forwarded exactly");
  }
  if (
    args.p_event_key !==
      `verify:token-hash:chronospark_premium_monthly:active:active:auto-renew:${expiryTimeMs}:order:value:order-123`
  ) {
    throw new Error("receipt reconciliation event key changed");
  }
  const payload = args.p_payload as Record<string, unknown>;
  const cause = payload.cause as Record<string, unknown>;
  if (
    cause.notificationType !== null ||
    cause.eventName !== "CLIENT_VERIFICATION" ||
    cause.paidRenewal !== false
  ) {
    throw new Error("client verification claimed a provider renewal cause");
  }
});

Deno.test("receipt event keys distinguish every authoritative state field", () => {
  type Input = Parameters<typeof buildSubscriptionReconciliationArgs>[0];
  const base: Input = {
    purchaseTokenHash: "token-hash",
    productId: "chronospark_premium_monthly",
    status: "active",
    isActive: true,
    autoRenews: true,
    orderId: "order-123",
    expiryTimeMs: Date.parse("2026-09-27T00:00:00.000Z"),
    providerObservedAt: new Date("2026-08-27T00:00:05.000Z"),
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
  };
  const variants: Input[] = [
    base,
    { ...base, status: "grace" },
    { ...base, isActive: false },
    { ...base, autoRenews: false },
    { ...base, expiryTimeMs: base.expiryTimeMs + 1 },
    { ...base, orderId: "order-456" },
    { ...base, orderId: null },
    { ...base, orderId: "null" },
    { ...base, productId: "chronospark_premium_annual" },
  ];
  const keys = variants.map((input) =>
    String(buildSubscriptionReconciliationArgs(input).p_event_key)
  );
  if (new Set(keys).size !== variants.length) {
    throw new Error("authoritative client states produced a duplicate key");
  }
});

Deno.test("linked purchase token builds immutable timestamped lineage args", () => {
  const linkedToken = readLinkedPurchaseToken({
    linkedPurchaseToken: " predecessor-token ",
  });
  if (linkedToken !== "predecessor-token") {
    throw new Error("linked purchase token was not consumed");
  }
  const boundAt = new Date("2026-08-27T00:00:05.000Z");
  const args = buildPurchaseBindingArgs({
    purchaseTokenHash: "successor-hash",
    userId: "user-id",
    productId: "chronospark_premium_annual",
    boundAt,
    predecessorTokenHash: "predecessor-hash",
  });
  if (args.p_bound_at !== boundAt.toISOString()) {
    throw new Error("binding observation time was not forwarded exactly");
  }
  if (args.p_predecessor_token_hash !== "predecessor-hash") {
    throw new Error("predecessor lineage was not forwarded");
  }
});

Deno.test("terminal reconciliation wins over duplicate acceptance", () => {
  const terminalDuplicate = classifyVerificationReconciliation({
    duplicate: true,
    reason: "terminal_token",
  });
  if (terminalDuplicate !== "terminal") {
    throw new Error("terminal duplicate receipt was accepted");
  }
  if (classifyVerificationReconciliation({ duplicate: true }) !== "accepted") {
    throw new Error("non-terminal duplicate receipt was rejected");
  }
  if (classifyVerificationReconciliation(null) !== "retry") {
    throw new Error("missing reconciliation result was acknowledged");
  }
});
