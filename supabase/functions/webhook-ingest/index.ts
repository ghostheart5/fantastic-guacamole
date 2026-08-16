// Supabase Edge Function: webhook-ingest
// Purpose: simple test ingestion endpoint (no DB writes)

interface IngestBody {
  eventType?: string;
  userId?: string;
  payload?: unknown;
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let body: IngestBody;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const eventType = typeof body.eventType === 'string' ? body.eventType : null;
  const userId = typeof body.userId === 'string' ? body.userId : null;
  const payload = body.payload ?? null;

  // Note: verify_jwt=true is recommended/configured for this function.
  // This handler is intentionally DB-free so it can be used as a smoke test.

  const res = {
    ok: true,
    receivedAt: new Date().toISOString(),
    eventType,
    userId,
    payload,
  };

  return new Response(JSON.stringify(res), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Connection': 'keep-alive',
    },
  });
});

