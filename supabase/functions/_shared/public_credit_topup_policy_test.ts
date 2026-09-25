import {
  creditAdmissionAllowed,
  creditTopupRequiresLicenseTest,
  internalCreditRtdnTestAllowed,
  internalCreditTestRequestAllowed,
  parsePublicCreditTopupPolicy,
  publicCreditSaleEnabled,
} from "./public_credit_topup_policy.ts";
import { parseInternalAiCohort } from "./internal_ai_cohort.ts";

const required = [
  "CHRONOSPARK_PUBLIC_CREDIT_TOPUPS_ENABLED",
  "CHRONOSPARK_PUBLIC_BILLING_REVIEW_APPROVED",
  "CHRONOSPARK_PUBLIC_AI_ENABLED",
  "CHRONOSPARK_PUBLIC_AI_PROVIDER_RETENTION_VERIFIED",
  "CHRONOSPARK_PUBLIC_AI_SAFETY_REVIEW_APPROVED",
  "PUBLIC_CREDIT_AUTO_REFUND_ENABLED",
  "CHRONOSPARK_PUBLIC_CREDIT_REFUND_READINESS_VERIFIED",
] as const;

Deno.test("new public credit checkouts remain closed by default", () => {
  const policy = parsePublicCreditTopupPolicy(() => undefined);
  if (publicCreditSaleEnabled(policy)) {
    throw new Error("public credit checkout opened by default");
  }
});

Deno.test("public checkout stays closed without refund enablement and readiness", () => {
  for (
    const gate of [
      "PUBLIC_CREDIT_AUTO_REFUND_ENABLED",
      "CHRONOSPARK_PUBLIC_CREDIT_REFUND_READINESS_VERIFIED",
    ]
  ) {
    for (const value of [undefined, "", "false", "TRUE", " true "]) {
      const policy = parsePublicCreditTopupPolicy((name) =>
        name === gate ? value : "true"
      );
      if (publicCreditSaleEnabled(policy)) {
        throw new Error("new paid checkout opened without its refund remedy");
      }
    }
  }
});

Deno.test("license QA admission is private and cannot open public sales", async () => {
  const closed = parsePublicCreditTopupPolicy(() => undefined);
  const user = "11111111-1111-4111-8111-111111111111";
  const other = "22222222-2222-4222-8222-222222222222";
  const cohort = parseInternalAiCohort(
    "6c360d206728b8cc03034e9f3e803a817fcba5fcfa20c218c7a94744d1a76313",
  );
  if (
    await creditAdmissionAllowed(closed, false, user, cohort) ||
    await creditAdmissionAllowed(closed, true, other, cohort) ||
    await creditAdmissionAllowed(closed, true, user, new Set()) ||
    publicCreditSaleEnabled(closed)
  ) throw new Error("license QA opened public or unauthorized checkout");
  if (!await creditAdmissionAllowed(closed, true, user, cohort)) {
    throw new Error("private license QA admission was denied");
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

Deno.test("a forged private test flag cannot bypass the server billing cohort", async () => {
  const user = "11111111-1111-4111-8111-111111111111";
  const other = "22222222-2222-4222-8222-222222222222";
  const cohort = parseInternalAiCohort(
    "6c360d206728b8cc03034e9f3e803a817fcba5fcfa20c218c7a94744d1a76313",
  );
  if (!await internalCreditTestRequestAllowed(true, user, cohort)) {
    throw new Error("private billing tester was denied");
  }
  if (
    await internalCreditTestRequestAllowed(true, other, cohort) ||
    await internalCreditTestRequestAllowed(true, user, new Set())
  ) {
    throw new Error(
      "unconfigured or unrelated account gained private test mode",
    );
  }
  if (!await internalCreditTestRequestAllowed(false, other, cohort)) {
    throw new Error("public receipt verification was blocked");
  }
});

Deno.test("RTDN exempts only profile-free private license tests", async () => {
  const user = "11111111-1111-4111-8111-111111111111";
  const other = "22222222-2222-4222-8222-222222222222";
  const cohort = parseInternalAiCohort(
    "6c360d206728b8cc03034e9f3e803a817fcba5fcfa20c218c7a94744d1a76313",
  );
  if (!await internalCreditRtdnTestAllowed(0, undefined, user, cohort)) {
    throw new Error("private profile-free license test was denied");
  }
  for (
    const [type, profile, owner] of [
      [0, undefined, other],
      [undefined, undefined, user],
      [0, "", user],
      [0, "123e4567-e89b-12d3-a456-426614174000", user],
    ] as const
  ) {
    if (await internalCreditRtdnTestAllowed(type, profile, owner, cohort)) {
      throw new Error("public or malformed receipt gained private exemption");
    }
  }
});
