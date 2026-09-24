import {
  creditTopupRequiresLicenseTest,
  parsePublicCreditTopupPolicy,
} from "./public_credit_topup_policy.ts";

const required = [
  "CHRONOSPARK_PUBLIC_CREDIT_TOPUPS_ENABLED",
  "CHRONOSPARK_PUBLIC_BILLING_REVIEW_APPROVED",
  "CHRONOSPARK_PUBLIC_AI_ENABLED",
  "CHRONOSPARK_PUBLIC_AI_PROVIDER_RETENTION_VERIFIED",
  "CHRONOSPARK_PUBLIC_AI_SAFETY_REVIEW_APPROVED",
] as const;

Deno.test("credit top-ups remain license-test-only by default", () => {
  const policy = parsePublicCreditTopupPolicy(() => undefined);
  if (!creditTopupRequiresLicenseTest(policy, undefined)) {
    throw new Error("real credit sale opened by default");
  }
  if (!creditTopupRequiresLicenseTest(policy, false)) {
    throw new Error("client flag unlocked real credit sale");
  }
});

Deno.test("every public sale approval must be an exact server affirmative", () => {
  for (const absent of required) {
    const policy = parsePublicCreditTopupPolicy((name) =>
      name === absent ? undefined : "true"
    );
    if (!creditTopupRequiresLicenseTest(policy, false)) {
      throw new Error(`opened without ${absent}`);
    }
  }
  const malformed = parsePublicCreditTopupPolicy((name) =>
    name === "CHRONOSPARK_PUBLIC_BILLING_REVIEW_APPROVED" ? "TRUE" : "true"
  );
  if (!creditTopupRequiresLicenseTest(malformed, false)) {
    throw new Error("malformed approval unlocked public sales");
  }
});

Deno.test("reviewed public rollout still honors client demand for license test", () => {
  const policy = parsePublicCreditTopupPolicy(() => "true");
  if (creditTopupRequiresLicenseTest(policy, undefined)) {
    throw new Error("server notification recovery rejected a public purchase");
  }
  if (creditTopupRequiresLicenseTest(policy, false)) {
    throw new Error("reviewed public receipt wrongly forced to test");
  }
  if (!creditTopupRequiresLicenseTest(policy, true)) {
    throw new Error("client test demand was ignored");
  }
});
