// Temporary owner-approved Phase 2 credential check. Remove after verification.
const EXPIRES_AT = Date.parse("2026-09-05T15:20:00Z");
const headers = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "https://supabase.com",
  "Access-Control-Allow-Headers": "apikey, authorization, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function reply(status: number, value: Record<string, unknown>) {
  return new Response(JSON.stringify(value), { status, headers });
}
async function sameSecret(a: string, b: string): Promise<boolean> {
  const encode = new TextEncoder();
  const [ah, bh] = await Promise.all([a, b].map(
    async (v) => new Uint8Array(await crypto.subtle.digest("SHA-256", encode.encode(v))),
  ));
  let difference = 0;
  for (let i = 0; i < ah.length; i++) difference |= ah[i] ^ bh[i];
  return difference === 0;
}
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const presented = req.headers.get("apikey") ?? "";
  let authorized = false;
  try {
    const configured: unknown = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    if (configured && typeof configured === "object" && !Array.isArray(configured) &&
        presented.startsWith("sb_secret_") && presented.length <= 512) {
      for (const key of Object.values(configured)) {
        if (typeof key === "string" && key.startsWith("sb_secret_") &&
            await sameSecret(presented, key)) authorized = true;
      }
    }
  } catch { /* Fail closed without logging configuration. */ }
  if (!authorized) return reply(403, { error: "forbidden" });
  if (Date.now() >= EXPIRES_AT) return reply(410, { error: "expired" });
  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key || !key.startsWith("sk-ant-")) return reply(503, { error: "credential_missing_or_malformed" });
  try {
    const upstream = await fetch("https://api.anthropic.com/v1/messages/count_tokens", {
      method: "POST",
      redirect: "error",
      signal: AbortSignal.timeout(15000),
      headers: { "x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({
        model: "claude-sonnet-4-6",
        messages: [{ role: "user", content: "Credential validation." }],
      }),
    });
    const data: unknown = await upstream.json();
    const count = data && typeof data === "object" && "input_tokens" in data ? data.input_tokens : null;
    const pass = upstream.status === 200 && typeof count === "number" &&
      Number.isSafeInteger(count) && count >= 0;
    let rejection = pass ? null : "unclassified_provider_rejection";
    if (!pass && data && typeof data === "object" && "error" in data) {
      const error = data.error;
      if (error && typeof error === "object" && "message" in error &&
          typeof error.message === "string") {
        const message = error.message.toLowerCase();
        if (message.includes("credit balance") || message.includes("insufficient credit")) {
          rejection = "insufficient_provider_credits";
        } else if (message.includes("model")) {
          rejection = "model_request_rejected";
        } else if (message.includes("api key") || message.includes("authentication")) {
          rejection = "credential_rejected";
        } else if (message.includes("permission")) {
          rejection = "permission_denied";
        }
      }
    }
    const safeId = (name: string) => {
      const value = upstream.headers.get(name);
      return value && /^[A-Za-z0-9_-]{1,120}$/.test(value) ? value : null;
    };
    return reply(pass ? 200 : 502, {
      check: "server-held-anthropic-token-count",
      pass,
      checked_at: new Date().toISOString(),
      upstream_status: upstream.status,
      rejection,
      input_tokens: pass ? count : null,
      request_id: safeId("request-id"),
      organization_id: safeId("anthropic-organization-id"),
      workspace_id: safeId("anthropic-workspace-id"),
    });
  } catch {
    return reply(502, { error: "upstream_check_failed", checked_at: new Date().toISOString() });
  }
});
