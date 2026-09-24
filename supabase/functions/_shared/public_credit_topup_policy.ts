import {
  parsePublicAiAudiencePolicy,
  publicAiAudienceEnabled,
} from "./ai_audience_policy.ts";

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

export function creditTopupRequiresLicenseTest(
  policy: PublicCreditTopupPolicy,
  clientRequiresTest: boolean | undefined,
): boolean {
  return clientRequiresTest === true ||
    !(policy.enabled && policy.billingReviewApproved && policy.publicAiEnabled);
}
