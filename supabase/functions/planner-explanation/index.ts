/// <reference lib="deno.ns" />

import {
  authenticatedUserId,
  type BillingBackendConfig,
  consumeDurableRateLimits,
  serviceRpc,
} from "../_shared/billing_backend.ts";
import { AnthropicPlannerProvider } from "./anthropic.ts";
import {
  isExplicitlyEnabled,
  type ModelPolicy,
  PLANNER_EXPLANATION_PROMPT_VERSION,
} from "./contract.ts";
import {
  createPlannerExplanationHandler,
  type PlannerExplanationStore,
} from "./handler.ts";

const config: BillingBackendConfig = {
  supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
  publishableKey: Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
  secretKey: Deno.env.get("SUPABASE_SECRET_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
};
const anthropicApiKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const configuredModelId = Deno.env.get("PLANNER_EXPLANATION_MODEL") ??
  "claude-sonnet-4-6";
const MODEL_ALLOWLIST = new Map<string, string>([
  ["claude-sonnet-4-6", "Claude Sonnet 4.6"],
]);
const modelLabel = MODEL_ALLOWLIST.get(configuredModelId) ?? "";
const requiredEvaluationApproval =
  `${configuredModelId}:${PLANNER_EXPLANATION_PROMPT_VERSION}:response-schema-v1`;
const modelPolicy: ModelPolicy = {
  id: configuredModelId,
  label: modelLabel,
  allowlisted: modelLabel.length > 0,
  evaluationApproved:
    Deno.env.get("PLANNER_EXPLANATION_MODEL_EVAL_APPROVAL") ===
      requiredEvaluationApproval,
};
const allowedOrigins = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ??
    "https://chronospark.app,https://www.chronospark.app")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
);

const store: PlannerExplanationStore = {
  issueQuote: async (input) =>
    await serviceRpc(config, "issue_planner_explanation_quote", {
      p_user_id: input.userId,
      p_request_key: input.requestId,
      p_quote_fingerprint: input.quoteFingerprint,
      p_input_fingerprint: input.inputFingerprint,
      p_expected_credits: input.expectedCredits,
      p_model_id: input.modelId,
      p_model_label: input.modelLabel,
      p_prompt_version: input.promptVersion,
      p_response_schema_version: 1,
      p_disclosure_version: 1,
    }),
  verifyQuote: async (input) =>
    await serviceRpc(config, "verify_planner_explanation_quote", {
      p_user_id: input.userId,
      p_request_key: input.requestId,
      p_quote_id: input.quoteId,
      p_input_fingerprint: input.inputFingerprint,
      p_expected_credits: input.expectedCredits,
      p_disclosure_version: input.disclosureVersion,
      p_model_id: input.modelId,
      p_model_label: input.modelLabel,
      p_prompt_version: input.promptVersion,
      p_response_schema_version: 1,
    }),
  reserveUsage: async (input) =>
    await serviceRpc(config, "reserve_ai_usage", {
      p_user_id: input.userId,
      p_request_key: input.requestId,
      p_credit_amount: input.expectedCredits,
      p_prompt_hash: input.envelopeFingerprint,
    }),
  settleUsage: async (input) =>
    await serviceRpc(config, "settle_planner_explanation_usage", {
      p_user_id: input.userId,
      p_request_key: input.requestId,
      p_succeeded: input.succeeded,
      p_input_tokens: input.inputTokens ?? null,
      p_output_tokens: input.outputTokens ?? null,
      p_provider_request_id: input.providerRequestId ?? null,
      p_failure_code: input.failureCode ?? null,
      p_response_payload: input.responsePayload ?? {},
      p_content_expires_at: input.contentExpiresAt ?? null,
    }),
  loadReplay: async (userId, requestId) =>
    await serviceRpc(config, "load_planner_explanation_replay", {
      p_user_id: userId,
      p_request_key: requestId,
    }),
  scrubReplay: async (userId, requestId) =>
    await serviceRpc(config, "scrub_planner_explanation_replay", {
      p_user_id: userId,
      p_request_key: requestId,
    }),
};

const handler = createPlannerExplanationHandler({
  authenticate: async (req) => await authenticatedUserId(req, config),
  consumeRateLimit: async (req, userId) =>
    await consumeDurableRateLimits(req, config, userId, {
      bucket: "planner_explanation",
      userLimit: 12,
      ipLimit: 36,
      windowSeconds: 60,
    }),
  store,
  provider: new AnthropicPlannerProvider(
    anthropicApiKey,
    configuredModelId,
  ),
  externalAiEnabled: isExplicitlyEnabled(
    Deno.env.get("PLANNER_EXPLANATION_EXTERNAL_AI_ENABLED"),
  ),
  providerRetentionVerified: isExplicitlyEnabled(
    Deno.env.get("PLANNER_EXPLANATION_PROVIDER_RETENTION_VERIFIED"),
  ),
  safetyReviewApproved: isExplicitlyEnabled(
    Deno.env.get("PLANNER_EXPLANATION_SAFETY_REVIEW_APPROVED"),
  ),
  serviceConfigured: Boolean(
    config.supabaseUrl && config.publishableKey && config.secretKey &&
      anthropicApiKey,
  ),
  modelPolicy,
  now: () => new Date(),
  providerTimeoutMs: 12_000,
  allowedOrigins,
});

Deno.serve(handler);
