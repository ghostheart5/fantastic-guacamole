# Apply Verified Purchase Grant Status

## Local Migration Review

- Migration found: `supabase/migrations/20260804160000_harden_apply_verified_purchase_rpc_grants.sql`.
- Local ordering: it is the newest local migration after `20260804150000_harden_ai_proxy_rate_limit.sql`.
- Target signature: `public.apply_verified_purchase(uuid, text, text, text, text, timestamptz, timestamptz, jsonb)`.
- Grant changes: revoke EXECUTE from `PUBLIC`, `anon`, and `authenticated`; grant EXECUTE to `service_role`.
- Non-grant changes: none found. The migration does not define or replace a function, modify product tiers or wallet logic, alter tables, mutate data, deploy Edge Functions, or contain secrets.

## Local Safety Conclusion

The migration appears safe for approved staging application because it is grant-only and explicitly documents the RPC as server-only after trusted receipt validation.

## Deployment Evidence Limitation

Local migration history proves only that the migration file exists and is ordered last locally. It does not prove the effective grants on staging. Capture the read-only grant verification result before treating hardening as effective.

Production release remains **NO**.