-- The general billing ledger is authoritative for credits and token counts,
-- not conversation storage. Remove historical ai-proxy reply bodies now that
-- the Edge Function settles new requests with metadata-only payloads.
update public.ai_usage_requests
set response_payload = '{}'::jsonb,
    response_expires_at = null
where request_key like 'ai-%'
  and response_payload <> '{}'::jsonb;
