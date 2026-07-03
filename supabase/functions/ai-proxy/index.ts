import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Set ANTHROPIC_API_KEY as a Supabase secret:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const ANTHROPIC_API = "https://api.anthropic.com/v1/messages";
const DEFAULT_MODEL = "claude-sonnet-4-6";
const MAX_TOKENS = 1024;

interface ProxyRequest {
  prompt: string;
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
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  try {
    const body: ProxyRequest = await req.json();
    const { prompt, system, model = DEFAULT_MODEL, maxTokens = MAX_TOKENS } = body;

    if (!prompt?.trim()) {
      return new Response(
        JSON.stringify({ error: "prompt is required" } satisfies Partial<ProxyResponse>),
        { status: 400, headers: { ...CORS, "Content-Type": "application/json" } },
      );
    }

    if (!ANTHROPIC_API_KEY) {
      return new Response(
        JSON.stringify({ error: "AI proxy not configured" } satisfies Partial<ProxyResponse>),
        { status: 500, headers: { ...CORS, "Content-Type": "application/json" } },
      );
    }

    const anthropicBody: Record<string, unknown> = {
      model,
      max_tokens: maxTokens,
      messages: [{ role: "user", content: prompt }],
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
      const err = await res.text();
      console.error("Anthropic API error:", err);
      return new Response(
        JSON.stringify({ error: "Upstream AI error" } satisfies Partial<ProxyResponse>),
        { status: 502, headers: { ...CORS, "Content-Type": "application/json" } },
      );
    }

    const data = await res.json();
    const message = data.content?.[0]?.text ?? "";
    const usage = data.usage ?? {};

    return new Response(
      JSON.stringify({
        message,
        model: data.model ?? model,
        inputTokens: usage.input_tokens ?? 0,
        outputTokens: usage.output_tokens ?? 0,
      } satisfies ProxyResponse),
      { headers: { ...CORS, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error(err);
    return new Response(
      JSON.stringify({ error: String(err) } satisfies Partial<ProxyResponse>),
      { status: 500, headers: { ...CORS, "Content-Type": "application/json" } },
    );
  }
});
