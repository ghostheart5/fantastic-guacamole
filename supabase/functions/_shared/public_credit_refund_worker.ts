import { type BillingBackendConfig, serviceRpc } from "./billing_backend.ts";
import {
  classifyQueuedCreditOrder,
  type QueuedCreditOrder,
  readGoogleCreditOrder,
  requestGoogleFullCreditRefund,
  verifyGoogleLicenseTestCreditOrder,
} from "./public_credit_refunds.ts";

export interface CreditRefundReconcileCounts {
  scanned: number;
  refunded: number;
  requested: number;
  pending: number;
  manualReview: number;
  retryLater: number;
}

function parseCandidate(value: unknown): QueuedCreditOrder | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const item = value as Record<string, unknown>;
  if (
    typeof item.orderId !== "string" || !item.orderId ||
    typeof item.productId !== "string" ||
    !["chronospark_credits_100", "chronospark_credits_300"].includes(
      item.productId,
    ) ||
    typeof item.tokenHash !== "string" ||
    !/^[0-9a-f]{64}$/.test(item.tokenHash) ||
    typeof item.refundAttempted !== "boolean"
  ) return null;
  return {
    orderId: item.orderId,
    productId: item.productId,
    tokenHash: item.tokenHash,
    refundAttempted: item.refundAttempted,
  };
}

export async function reconcilePublicCreditRefunds(input: {
  config: BillingBackendConfig;
  packageName: string;
  accessToken: string;
  testTokenHash?: string;
}, fetcher: typeof fetch = fetch): Promise<CreditRefundReconcileCounts | null> {
  if (
    input.testTokenHash !== undefined &&
    !/^[0-9a-f]{64}$/.test(input.testTokenHash)
  ) return null;
  const listed = await serviceRpc(
    input.config,
    "list_public_credit_refund_candidates",
    { p_limit: 5 },
    fetcher,
  );
  if (!listed || !Array.isArray(listed.candidates)) return null;
  const candidates = input.testTokenHash === undefined
    ? listed.candidates
    : listed.candidates.filter((raw) =>
      parseCandidate(raw)?.tokenHash === input.testTokenHash
    );
  // An absent or duplicated test target is not successful worker execution.
  if (input.testTokenHash !== undefined && candidates.length !== 1) return null;
  const counts: CreditRefundReconcileCounts = {
    scanned: 0,
    refunded: 0,
    requested: 0,
    pending: 0,
    manualReview: 0,
    retryLater: 0,
  };
  for (const raw of candidates) {
    const queued = parseCandidate(raw);
    counts.scanned++;
    if (!queued) {
      counts.manualReview++;
      continue;
    }
    try {
      // For a scoped run, prove test status before even rotating its queue
      // timestamp. Normal reconciliation retains its fairness rotation.
      const testOrder = input.testTokenHash === undefined
        ? undefined
        : await readGoogleCreditOrder(
          input.packageName,
          queued.orderId,
          input.accessToken,
          fetcher,
        );
      if (input.testTokenHash !== undefined) {
        if (!testOrder) {
          counts.retryLater++;
          continue;
        }
        if (
          await classifyQueuedCreditOrder(testOrder, queued) ===
            "manual_review" ||
          !await verifyGoogleLicenseTestCreditOrder(
            input.packageName,
            queued,
            testOrder,
            input.accessToken,
            fetcher,
          )
        ) {
          counts.manualReview++;
          continue;
        }
      }
      const rotated = await serviceRpc(
        input.config,
        "note_public_credit_refund_readback",
        {
          p_token_hash: queued.tokenHash,
          p_product_id: queued.productId,
          p_order_id: queued.orderId,
        },
        fetcher,
      );
      if (rotated?.touched !== true) {
        counts.retryLater++;
        continue;
      }
      const order = testOrder ?? await readGoogleCreditOrder(
        input.packageName,
        queued.orderId,
        input.accessToken,
        fetcher,
      );
      if (!order) {
        counts.retryLater++;
        continue;
      }
      const decision = await classifyQueuedCreditOrder(order, queued);
      if (decision === "confirmed_full_refund") {
        const revoked = await serviceRpc(
          input.config,
          "revoke_verified_credit_topup",
          {
            p_token_hash: queued.tokenHash,
            p_product_id: queued.productId,
            p_order_id: queued.orderId,
          },
          fetcher,
        );
        if (revoked?.handled === true) counts.refunded++;
        else counts.retryLater++;
      } else if (decision === "await_provider_refund") {
        counts.pending++;
      } else if (decision === "request_full_refund") {
        const claim = await serviceRpc(
          input.config,
          "claim_public_credit_refund_attempt",
          {
            p_token_hash: queued.tokenHash,
            p_product_id: queued.productId,
            p_order_id: queued.orderId,
          },
          fetcher,
        );
        if (claim?.claimed !== true) {
          counts.manualReview++;
          continue;
        }
        // This is the only outbound refund attempt for this token. A timeout or
        // lost response is left for provider readback and manual disposition.
        if (
          await requestGoogleFullCreditRefund(
            input.packageName,
            queued.orderId,
            input.accessToken,
            fetcher,
          )
        ) counts.requested++;
        else counts.manualReview++;
      } else {
        counts.manualReview++;
      }
    } catch {
      // A failed provider or database read must not hide later queued orders.
      // If the one-time claim already committed, operator readback is required.
      counts.retryLater++;
    }
  }
  return counts;
}
