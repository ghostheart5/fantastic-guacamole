import {
  creditTopupRequiresLicenseTest,
  parsePublicCreditTopupPolicy,
  publicCreditSaleEnabled,
} from "./public_credit_topup_policy.ts";

const required = [
  "CHRONOSPARK_PUBLIC_CREDIT_TOPUPS_ENABLED",
  "CHRONOSPARK_PUBLIC_BILLING_REVIEW_APPROVED",
  "CHRONOSPARK_PUBLIC_AI_ENABLED",
  "CHRONOSPARK_PUBLIC_AI_PROVIDER_RETENTION_VERIFIED",
  "CHRONOSPARK_PUBLIC_AI_SAFETY_REVIEW_APPROVED",
] as const;

Deno.test("new public credit checkouts remain closed by default", () => {
  const policy = parsePublicCreditTopupPolicy(() => undefined);
  if (publicCreditSaleEnabled(policy)) {
    throw new Error("public credit checkout opened by default");
  }
});

Deno.test("every public sale approval must be an exact server affirmative", () => {
  for (const absent of required) {
    const policy = parsePublicCreditTopupPolicy((name) =>
      name === absent ? undefined : "true"
    );
    if (publicCreditSaleEnabled(policy)) {
      throw new Error(`opened without ${absent}`);
    }
  }
  const malformed = parsePublicCreditTopupPolicy((name) =>
    name === "CHRONOSPARK_PUBLIC_BILLING_REVIEW_APPROVED" ? "TRUE" : "true"
  );
  if (publicCreditSaleEnabled(malformed)) {
    throw new Error("malformed approval unlocked public sales");
  }
});

Deno.test("closing new sales cannot invalidate an already-paid receipt", () => {
  const active = parsePublicCreditTopupPolicy(() => "true");
  const closed = parsePublicCreditTopupPolicy(() => undefined);
  if (!publicCreditSaleEnabled(active) || publicCreditSaleEnabled(closed)) {
    throw new Error("rollout transition did not close new checkouts");
  }
  if (
    creditTopupRequiresLicenseTest(undefined) ||
    creditTopupRequiresLicenseTest(false)
  ) {
    throw new Error("rollout closure stranded an existing standard purchase");
  }
});

Deno.test("reviewed public rollout still honors an internal client's test demand", () => {
  const policy = parsePublicCreditTopupPolicy(() => "true");
  if (!publicCreditSaleEnabled(policy)) {
    throw new Error("approved public checkout remained closed");
  }
  if (!creditTopupRequiresLicenseTest(true)) {
    throw new Error("client test demand was ignored");
  }
});
