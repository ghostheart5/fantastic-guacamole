-- apply_verified_purchase is a server-only receipt application RPC.
-- It must be invoked only after trusted receipt validation, never directly by clients.

revoke execute on function public.apply_verified_purchase(
  uuid, text, text, text, text, timestamptz, timestamptz, jsonb
) from public;

revoke execute on function public.apply_verified_purchase(
  uuid, text, text, text, text, timestamptz, timestamptz, jsonb
) from anon;

revoke execute on function public.apply_verified_purchase(
  uuid, text, text, text, text, timestamptz, timestamptz, jsonb
) from authenticated;

grant execute on function public.apply_verified_purchase(
  uuid, text, text, text, text, timestamptz, timestamptz, jsonb
) to service_role;
