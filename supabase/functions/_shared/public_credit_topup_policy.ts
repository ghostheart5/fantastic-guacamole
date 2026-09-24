import {
  parsePublicAiAudiencePolicy,
  publicAiAudienceEnabled,
} from "./ai_audience_policy.ts";
import { internalAiAccountAllowed } from "./internal_ai_cohort.ts";

export interface PublicCreditTopupPolicy {
  readonly enabled: boolean;
  readonly billingReviewApproved: boolean;
  readonly publicAiEnabled: boolean;
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
  };
}

export function publicCreditSaleEnabled(
  policy: PublicCreditTopupPolicy,
): boolean {
  return policy.enabled && policy.billingReviewApproved &&
    policy.publicAiEnabled;
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
