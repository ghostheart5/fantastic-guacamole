# Staging Migration State Report

## Confirmed Target

- Confirmed staging project ref: `pxtjkwfedrtnxuihtdox`
- CLI link status: linked to staging.

## Migration List Finding

`npx supabase migration list` was run against confirmed staging. Local migrations are present, but the Remote column is blank for all listed migrations.

## Interpretation

Staging likely has no tracked migrations applied, or its migration history is not recorded. Function discovery also returned `NOT_FOUND` for every expected function: `apply_verified_purchase`, `consume_ai_proxy_rate_limit`, `consume_monetization_credits`, `ensure_monetization_wallet`, `ensure_profile_for_current_user`, `get_global_metrics`, `grant_monetization_credits`, `handle_new_user`, and `reset_monetization_allowance`.

## Safety Conclusion

RPC validation, credit tests, rate-limit tests, profile-repair tests, global-metrics tests, and receipt-mismatch tests are blocked. Do not run RLS tests, seed SQL, Storage tests, or any mutation tests yet. Read-only schema discovery output is required before migration application can be reviewed.

## Production Release Status

**NO**
