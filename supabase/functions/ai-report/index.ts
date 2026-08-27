import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ALLOWED_ORIGINS = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ??
    "https://chronospark.app,https://www.chronospark.app")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
);
const requestWindows = new Map<string, number[]>();

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

async function authenticatedUserId(req: Request): Promise<string | null> {
  const authorization = req.headers.get("authorization") ?? "";
  if (
    !authorization.startsWith("Bearer ") ||
    !SUPABASE_URL ||
    !SUPABASE_ANON_KEY
  ) return null;
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: authorization, apikey: SUPABASE_ANON_KEY },
  });
  if (!response.ok) return null;
  const user = await response.json();
  return typeof user?.id === "string" ? user.id : null;
}

function withinRateLimit(userId: string): boolean {
  const now = Date.now();
  const recent = (requestWindows.get(userId) ?? []).filter((time) =>
    now - time < 60 * 60 * 1000
  );
  if (recent.length >= 10) return false;
  recent.push(now);
  requestWindows.set(userId, recent);
  return true;
}

const allowedReasons = new Set([
  "unsafe_or_harmful",
  "misleading_or_inaccurate",
  "privacy_concern",
  "other",
]);

serve(async (req) => {
  const headers = cors(req);
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers });
  }
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers });
  }

  try {
    const contentLength = Number(req.headers.get("content-length") ?? "0");
    if (contentLength > 16000) {
      return new Response(JSON.stringify({ error: "request too large" }), {
        status: 413,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }
    const userId = await authenticatedUserId(req);
    if (!userId) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }
    if (!withinRateLimit(userId)) {
      return new Response(JSON.stringify({ error: "rate limit exceeded" }), {
        status: 429,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(JSON.stringify({ error: "service not configured" }), {
        status: 500,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const reason = typeof body?.reason === "string" ? body.reason : "";
    const content = typeof body?.content === "string" ? body.content.trim() : "";
    if (!allowedReasons.has(reason) || content.length < 1 || content.length > 4000) {
      return new Response(JSON.stringify({ error: "invalid report" }), {
        status: 400,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }

    const insert = await fetch(`${SUPABASE_URL}/rest/v1/ai_content_reports`, {
      method: "POST",
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({
        user_id: userId,
        reason,
        content,
        source: "si_console",
      }),
    });
    if (!insert.ok) {
      await insert.body?.cancel();
      return new Response(JSON.stringify({ error: "report could not be saved" }), {
        status: 502,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ accepted: true }), {
      status: 202,
      headers: { ...headers, "Content-Type": "application/json" },
    });
  } catch {
    return new Response(JSON.stringify({ error: "request failed" }), {
      status: 500,
      headers: { ...headers, "Content-Type": "application/json" },
    });
  }
});
