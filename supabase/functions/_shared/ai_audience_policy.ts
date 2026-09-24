import { internalAiAccountAllowed } from "./internal_ai_cohort.ts";

export interface PublicAiAudiencePolicy {
  readonly enabled: boolean;
  readonly providerRetentionVerified: boolean;
  readonly safetyReviewApproved: boolean;
}

const canonicalUserId =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

// Each deployment value must be the exact affirmative token. Missing, malformed
// or merely present environment variables cannot broaden the audience.
export function parsePublicAiAudiencePolicy(
  read: (name: string) => string | undefined,
): PublicAiAudiencePolicy {
  return {
    enabled: read("CHRONOSPARK_PUBLIC_AI_ENABLED") === "true",
    providerRetentionVerified:
      read("CHRONOSPARK_PUBLIC_AI_PROVIDER_RETENTION_VERIFIED") === "true",
    safetyReviewApproved:
      read("CHRONOSPARK_PUBLIC_AI_SAFETY_REVIEW_APPROVED") === "true",
  };
}

export function publicAiAudienceEnabled(
  policy: PublicAiAudiencePolicy,
): boolean {
  return policy.enabled && policy.providerRetentionVerified &&
    policy.safetyReviewApproved;
}

// An authenticated canonical user may enter through the existing private
// cohort or a separately reviewed public rollout. This only decides audience;
// it does not replace consent, durable limits, quote, balance or settlement.
export async function aiAudienceAllowed(
  userId: string,
  internalCohort: ReadonlySet<string>,
  publicPolicy: PublicAiAudiencePolicy,
): Promise<boolean> {
  if (!canonicalUserId.test(userId)) return false;
  if (await internalAiAccountAllowed(userId, internalCohort)) return true;
  return publicAiAudienceEnabled(publicPolicy);
}
