import {
  parsePublicAiAudiencePolicy,
  publicAiAudienceEnabled,
} from "./ai_audience_policy.ts";
import { internalAiAccountAllowed } from "./internal_ai_cohort.ts";

export interface PublicCreditTopupPolicy {
  readonly enabled: boolean;
  readonly billingReviewApproved: boolean;
  readonly publicAiEnabled: boolean;
  readonly refundsEnabled: boolean;
  readonly refundReadinessVerified: boolean;
}

// Purchase verification must never take public-sale authority from the app's
// request body. A production credit sale is possible only after the reviewed
// public AI service and billing lifecycle have both been enabled on the server.
export function parsePublicCreditTopupPolicy(
  read: (name: string) => string | undefined,
): PublicCreditTopupPolicy {
  return {
    enabled: read("CHRONOSPARK_PUBLIC_CREDIT_TOPUPS_ENABLED") === "true",
    billingReviewApproved:
      read("CHRONOSPARK_PUBLIC_BILLING_REVIEW_APPROVED") === "true",
    publicAiEnabled: publicAiAudienceEnabled(
      parsePublicAiAudiencePolicy(read),
    ),
    refundsEnabled: read("PUBLIC_CREDIT_AUTO_REFUND_ENABLED") === "true",
    // Release attestation for source-matched worker, schedule, alerts and
    // license-test readback; this flag is not a live worker-health probe.
    refundReadinessVerified:
      read("CHRONOSPARK_PUBLIC_CREDIT_REFUND_READINESS_VERIFIED") === "true",
  };
}

export function publicCreditSaleEnabled(
  policy: PublicCreditTopupPolicy,
): boolean {
  return policy.enabled && policy.billingReviewApproved &&
    policy.publicAiEnabled && policy.refundsEnabled &&
    policy.refundReadinessVerified;
}

// A separately configured private cohort can exercise the one-use public
// admission in Play license QA while the global public-sale gate remains off.
// A request-body flag is never authority for this exception.
export async function creditAdmissionAllowed(
  policy: PublicCreditTopupPolicy,
  licenseQaEnabled: boolean,
  userId: string,
  billingCohort: ReadonlySet<string>,
): Promise<boolean> {
  return publicCreditSaleEnabled(policy) ||
    (licenseQaEnabled &&
      await internalAiAccountAllowed(userId, billingCohort));
}

// Rollout closure stops new admissions. An already admitted purchase remains
// redeemable through its Play-echoed admission and one-use database grant.
// License-test clients continue to demand Google's test purchase marker.
export function creditTopupRequiresLicenseTest(
  clientRequiresTest: boolean | undefined,
): boolean {
  return clientRequiresTest === true;
}

// The request body can demand test proof, but it cannot grant the private
// admission exemption. That requires a server-owned billing cohort match.
export async function internalCreditTestRequestAllowed(
  clientRequiresTest: boolean | undefined,
  authenticatedUserId: string,
  internalBillingCohort: ReadonlySet<string>,
): Promise<boolean> {
  return clientRequiresTest !== true ||
    await internalAiAccountAllowed(authenticatedUserId, internalBillingCohort);
}

export async function internalCreditRtdnTestAllowed(
  purchaseType: unknown,
  admissionProfileId: unknown,
  authenticatedUserId: string,
  internalBillingCohort: ReadonlySet<string>,
): Promise<boolean> {
  return purchaseType === 0 && admissionProfileId === undefined &&
    await internalAiAccountAllowed(authenticatedUserId, internalBillingCohort);
}
