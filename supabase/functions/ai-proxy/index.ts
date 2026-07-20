import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_PUBLISHABLE_KEY = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const ALLOWED_ORIGINS = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ?? "https://chronospark.app,https://www.chronospark.app")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
);
const requestWindows = new Map<string, number[]>();

function cors(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  return {
    ...(ALLOWED_ORIGINS.has(origin) ? { "Access-Control-Allow-Origin": origin } : {}),
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
  };
}

async function authenticatedUserId(req: Request): Promise<string | null> {
  const authorization = req.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ") || !SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY) return null;
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: authorization, apikey: SUPABASE_PUBLISHABLE_KEY },
  });
  if (!response.ok) return null;
  const user = await response.json();
  return typeof user?.id === "string" ? user.id : null;
}

function withinRateLimit(userId: string): boolean {
  const now = Date.now();
  const recent = (requestWindows.get(userId) ?? []).filter((time) => now - time < 60_000);
  if (recent.length >= 20) return false;
  recent.push(now);
  requestWindows.set(userId, recent);
  return true;
}

// Set ANTHROPIC_API_KEY as a Supabase secret:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const ANTHROPIC_API = "https://api.anthropic.com/v1/messages";
const DEFAULT_MODEL = "claude-sonnet-4-6";
const MAX_TOKENS = 1024;

interface ProxyRequest {
  prompt?: string;
  message?: string;
  history?: Array<{ role: "user" | "assistant"; content: string }>;
  system?: string;
  model?: string;
  maxTokens?: number;
  context?: Record<string, unknown>;  // arbitrary agent context
}

interface ProxyResponse {
  message: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  error?: string;
}

serve(async (req) => {
  const headers = cors(req);
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers });
  }

  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405, headers });
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
    const body: ProxyRequest = await req.json();
    const {
      prompt: explicitPrompt,
      message,
      history = [],
      system,
      maxTokens = MAX_TOKENS,
    } = body;
    const prompt = explicitPrompt ?? message ?? "";

    if (!prompt?.trim()) {
      return new Response(
        JSON.stringify({ error: "prompt is required" } satisfies Partial<ProxyResponse>),
        { status: 400, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }
    if (prompt.length > 8_000 || history.length > 8) {
      return new Response(JSON.stringify({ error: "request too large" }), {
        status: 413,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }

    if (!ANTHROPIC_API_KEY) {
      return new Response(
        JSON.stringify({ error: "AI proxy not configured" } satisfies Partial<ProxyResponse>),
        { status: 500, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    const recentHistory = history.slice(-6);
    const messages =
      recentHistory.at(-1)?.role === "user" &&
        recentHistory.at(-1)?.content === prompt
        ? recentHistory
        : [...recentHistory, { role: "user" as const, content: prompt }];

    const anthropicBody: Record<string, unknown> = {
      model: DEFAULT_MODEL,
      max_tokens: Math.max(128, Math.min(MAX_TOKENS, Number(maxTokens) || MAX_TOKENS)),
      messages,
    };
    if (system) anthropicBody.system = system;

    const res = await fetch(ANTHROPIC_API, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(anthropicBody),
    });

    if (!res.ok) {
      await res.body?.cancel();
      console.error("Anthropic API request failed");
      return new Response(
        JSON.stringify({ error: "Upstream AI error" } satisfies Partial<ProxyResponse>),
        { status: 502, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    const data = await res.json();
    const message = data.content?.[0]?.text ?? "";
    const usage = data.usage ?? {};

    return new Response(
      JSON.stringify({
        message,
        model: data.model ?? DEFAULT_MODEL,
        inputTokens: usage.input_tokens ?? 0,
        outputTokens: usage.output_tokens ?? 0,
      } satisfies ProxyResponse),
      { headers: { ...headers, "Content-Type": "application/json" } },
    );
  } catch {
    console.error("AI proxy request failed");
    return new Response(
      JSON.stringify({ error: "request failed" } satisfies Partial<ProxyResponse>),
      { status: 500, headers: { ...headers, "Content-Type": "application/json" } },
    );
  }
});
