import { sha256Hex } from "./billing_backend.ts";
import {
  aiAudienceAllowed,
  parsePublicAiAudiencePolicy,
  publicAiAudienceEnabled,
} from "./ai_audience_policy.ts";

const internalUser = "b1f377ed-4075-45c8-9681-1e8eaec3571c";
const publicUser = "c651629f-9ca9-46f2-aa55-a383ff15cdf9";
const disabled = parsePublicAiAudiencePolicy(() => undefined);

Deno.test("public AI audience defaults closed without deployment values", async () => {
  if (publicAiAudienceEnabled(disabled)) throw new Error("opened by default");
  if (await aiAudienceAllowed(publicUser, new Set(), disabled)) {
    throw new Error("public user admitted without review");
  }
});

Deno.test("each independent public AI gate must be exactly affirmative", () => {
  for (
    const missing of [
      "CHRONOSPARK_PUBLIC_AI_ENABLED",
      "CHRONOSPARK_PUBLIC_AI_PROVIDER_RETENTION_VERIFIED",
      "CHRONOSPARK_PUBLIC_AI_SAFETY_REVIEW_APPROVED",
    ]
  ) {
    const policy = parsePublicAiAudiencePolicy((name) =>
      name === missing ? undefined : "true"
    );
    if (publicAiAudienceEnabled(policy)) {
      throw new Error(`opened without ${missing}`);
    }
  }
  for (const malformed of ["TRUE", "1", " true", "true ", "approved"]) {
    const policy = parsePublicAiAudiencePolicy((name) =>
      name === "CHRONOSPARK_PUBLIC_AI_SAFETY_REVIEW_APPROVED"
        ? malformed
        : "true"
    );
    if (publicAiAudienceEnabled(policy)) {
      throw new Error(`opened for malformed approval ${malformed}`);
    }
  }
});

Deno.test("private cohort remains available while public rollout is closed", async () => {
  const namespace = `v2.${
    btoa(internalUser).replace(/\+/g, "-").replace(/\//g, "_")
  }`;
  const cohort = new Set([await sha256Hex(namespace)]);
  if (!await aiAudienceAllowed(internalUser, cohort, disabled)) {
    throw new Error("existing private cohort was denied");
  }
  if (await aiAudienceAllowed(publicUser, cohort, disabled)) {
    throw new Error("non-cohort user was admitted");
  }
});

Deno.test("all public gates admit only canonical authenticated identifiers", async () => {
  const enabled = parsePublicAiAudiencePolicy(() => "true");
  if (!await aiAudienceAllowed(publicUser, new Set(), enabled)) {
    throw new Error("approved public user was denied");
  }
  for (
    const invalid of [
      "",
      "anonymous",
      "v2.test",
      publicUser.toUpperCase(),
      "00000000-0000-0000-0000-000000000000",
    ]
  ) {
    if (await aiAudienceAllowed(invalid, new Set(), enabled)) {
      throw new Error(`invalid principal admitted: ${invalid}`);
    }
  }
});
