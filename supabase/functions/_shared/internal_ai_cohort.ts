import { sha256Hex } from "./billing_backend.ts";

// Server-owned deployment input, never request JSON, JWT user_metadata or an
// email address. Keep this identical to the private candidate build's cohort.
export function parseInternalAiCohort(
  value: string | undefined,
): ReadonlySet<string> {
  const digests = (value ?? "").split(",");
  if (
    digests.length > 100 || new Set(digests).size !== digests.length ||
    digests.some((digest) => !/^[a-f0-9]{64}$/.test(digest))
  ) return new Set();
  return new Set(digests);
}

export async function internalAiAccountAllowed(
  authenticatedUserId: string,
  cohort: ReadonlySet<string>,
): Promise<boolean> {
  // Supabase Auth supplies UUIDs. Reject anonymous/signed-out/test namespaces.
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
      .test(authenticatedUserId)
  ) {
    return false;
  }
  // AccountStorageNamespace.v2Scope uses padded base64UrlEncode(UTF-8(id));
  // InternalBillingTestConfig hashes that entire namespace, not the email/id.
  const namespace = `v2.${
    btoa(authenticatedUserId).replace(/\+/g, "-").replace(/\//g, "_")
  }`;
  return cohort.has(await sha256Hex(namespace));
}

// A read-only deployment probe. It exposes only an aggregate fingerprint of
// the already hashed cohort, never the allowlist, user identities or secrets.
// It does not authenticate a user, create a quote, reserve or call a provider.
export async function internalAiPreflightResponse(
  req: Request,
  cohort: ReadonlySet<string>,
  contract: string,
  serviceConfigured: boolean,
): Promise<Response | null> {
  if (req.method !== "GET") return null;
  const configured = serviceConfigured && cohort.size > 0;
  return Response.json(
    { error: configured ? "method_not_allowed" : "internal_ai_not_configured" },
    {
      status: configured ? 405 : 503,
      headers: {
        "Cache-Control": "no-store",
        "X-Content-Type-Options": "nosniff",
        "X-ChronoSpark-Contract": contract,
        "X-ChronoSpark-Internal-Ai-Guard": "v1",
        ...(configured
          ? {
            "X-ChronoSpark-Internal-Ai-Cohort-SHA256": await sha256Hex(
              [...cohort].sort().join(","),
            ),
          }
          : {}),
      },
    },
  );
}
