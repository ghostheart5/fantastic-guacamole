/// <reference lib="deno.ns" />

import {
  authenticatedUserId,
  type BillingBackendConfig,
  consumeDurableRateLimits,
} from "../_shared/billing_backend.ts";

const config: BillingBackendConfig = {
  supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
  publishableKey: Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
  secretKey: Deno.env.get("SUPABASE_SECRET_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
};
const ALLOWED_ORIGINS = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
);

const allowedReasons = new Set([
  "unsafe_or_harmful",
  "misleading_or_inaccurate",
  "privacy_concern",
  "other",
]);

// Recorded in ai_content_reports.source. Only these surfaces are stored; a
// missing value (the released app sends none) or any other text is recorded
// as unspecified so client free text never reaches the table.
const KNOWN_SURFACES = new Set(["chat", "si_console", "planner"]);
const UNSPECIFIED_SURFACE = "unspecified";

function reportSurface(value: unknown): string {
  return typeof value === "string" && KNOWN_SURFACES.has(value)
    ? value
    : UNSPECIFIED_SURFACE;
}

function cors(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  return {
    ...(ALLOWED_ORIGINS.has(origin)
      ? { "Access-Control-Allow-Origin": origin }
      : {}),
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Cache-Control": "no-store",
    "Vary": "Origin",
  };
}

function json(
  req: Request,
  body: Record<string, unknown>,
  status: number,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors(req), "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors(req) });
  }
  if (req.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405,
      headers: cors(req),
    });
  }

  try {
    const contentLength = Number(req.headers.get("content-length") ?? "0");
    if (contentLength > 16000) {
      return json(req, { error: "request too large" }, 413);
    }
    // Real accounts only: a missing, invalid or anonymous session is refused.
    const userId = await authenticatedUserId(req, config);
    if (!userId) return json(req, { error: "unauthorized" }, 401);
    if (!config.supabaseUrl || !config.secretKey) {
      return json(req, { error: "service not configured" }, 500);
    }
    // Durable (database-backed) limit shared by every isolate: ten reports an
    // hour per account and thirty per address.
    if (
      !await consumeDurableRateLimits(req, config, userId, {
        bucket: "ai_report",
        userLimit: 10,
        ipLimit: 30,
        windowSeconds: 60 * 60,
      })
    ) return json(req, { error: "rate limit exceeded" }, 429);

    const body = await req.json();
    const reason = typeof body?.reason === "string" ? body.reason : "";
    const content = typeof body?.content === "string"
      ? body.content.trim()
      : "";
    if (
      !allowedReasons.has(reason) || content.length < 1 || content.length > 4000
    ) {
      return json(req, { error: "invalid report" }, 400);
    }

    const insert = await fetch(
      `${config.supabaseUrl}/rest/v1/ai_content_reports`,
      {
        method: "POST",
        headers: {
          apikey: config.secretKey,
          Authorization: `Bearer ${config.secretKey}`,
          "Content-Type": "application/json",
          Prefer: "return=minimal",
        },
        body: JSON.stringify({
          user_id: userId,
          reason,
          content,
          source: reportSurface(body?.surface),
        }),
      },
    );
    if (!insert.ok) {
      await insert.body?.cancel();
      return json(req, { error: "report could not be saved" }, 502);
    }
    return json(req, { accepted: true }, 202);
  } catch {
    return json(req, { error: "request failed" }, 500);
  }
});
