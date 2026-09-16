import {
  internalAiAccountAllowed,
  internalAiPreflightResponse,
  parseInternalAiCohort,
} from "./internal_ai_cohort.ts";

const user = "11111111-1111-4111-8111-111111111111";
// Independently derived using the Flutter namespace specification.
const digest =
  "6c360d206728b8cc03034e9f3e803a817fcba5fcfa20c218c7a94744d1a76313";

Deno.test("internal AI cohort matches canonical client v2 account namespace", async () => {
  const cohort = parseInternalAiCohort(digest);
  if (!await internalAiAccountAllowed(user, cohort)) {
    throw new Error("canonical digest rejected");
  }
  for (
    const value of [
      "",
      "v2.signed_out",
      "v2.unsafe",
      "test@example.invalid",
      "22222222-2222-4222-8222-222222222222",
      ` ${user}`,
    ]
  ) {
    if (await internalAiAccountAllowed(value, cohort)) {
      throw new Error("unrelated or unsafe identity allowed");
    }
  }
});

Deno.test("AI readiness GET reveals only aggregate cohort fingerprint and fails closed on missing setup", async () => {
  const req = new Request("https://local.example/ai-proxy");
  const response = await internalAiPreflightResponse(
    req,
    parseInternalAiCohort(digest),
    "ai-proxy-v2",
    true,
  );
  if (
    response?.status !== 405 ||
    response.headers.get("x-chronospark-internal-ai-guard") !== "v1"
  ) throw new Error("missing deployed guard marker");
  const hash = response.headers.get("x-chronospark-internal-ai-cohort-sha256");
  if (
    hash !== "b5fff3221a3f3de54ba2bade8e353f9c72a1943e37e93d4e9da9c12121dd7167"
  ) {
    throw new Error(
      "runtime cohort fingerprint disagrees with release preflight",
    );
  }
  const text = await response.text();
  if (text.includes(user) || text.includes(digest)) {
    throw new Error("readiness response exposed account identity");
  }
  for (
    const [cohort, configured] of [[new Set<string>(), true], [
      parseInternalAiCohort(digest),
      false,
    ]] as const
  ) {
    const denied = await internalAiPreflightResponse(
      req,
      cohort,
      "ai-proxy-v2",
      configured,
    );
    if (
      denied?.status !== 503 ||
      denied.headers.has("x-chronospark-internal-ai-cohort-sha256")
    ) throw new Error("missing config claimed ready");
    await denied.body?.cancel();
  }
  if (
    await internalAiPreflightResponse(
      new Request(req.url, { method: "POST" }),
      parseInternalAiCohort(digest),
      "ai-proxy-v2",
      true,
    ) !== null
  ) throw new Error("preflight intercepted application request");
});

Deno.test("empty, missing, duplicate, broad or malformed cohort configuration denies all", async () => {
  for (
    const value of [
      undefined,
      "",
      "*",
      digest.toUpperCase(),
      ` ${digest}`,
      `${digest},`,
      `${digest},${digest}`,
      Array.from({ length: 101 }, (_, i) => i.toString(16).padStart(64, "0"))
        .join(","),
    ]
  ) {
    const cohort = parseInternalAiCohort(value);
    if (cohort.size || await internalAiAccountAllowed(user, cohort)) {
      throw new Error("bad server configuration did not fail closed");
    }
  }
});
