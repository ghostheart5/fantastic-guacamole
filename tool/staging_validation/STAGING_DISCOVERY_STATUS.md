# Staging Discovery Status

## Confirmed Target

- Confirmed staging project ref: `RETIRED_STAGING_PROJECT`
- Expected staging base URL: `https://retired-staging-project.invalid`
- Non-staging project for this validation: `qpwhuckyirnqtmvhpede`

## Local Configuration Status

- CLI linked project ref: `RETIRED_STAGING_PROJECT` from local link metadata.
- CLI correctly linked to staging: **YES**.
- Local `.env` staging URL: missing or blank at last local shape check.
- Local `.env` anon key: missing or blank at last local shape check; value was not printed.
- Local `.env` test emails/passwords: missing or blank at last local shape check; values were not printed.
- Local `.env` user A UUID: missing or does not match the confirmed UUID at last local shape check.
- Local `.env` user B UUID: missing or does not match the confirmed UUID at last local shape check.

Manually add these non-secret identifiers to the local `.env` without overwriting other values:

```dotenv
STAGING_USER_A_UUID=a6dc2118-2140-4416-8642-9c3eba691288
STAGING_USER_B_UUID=aa116396-4dc1-461e-8502-61b6896570b4
```

## Discovery Status

- Schema discovery: expected public tables were previously reported absent; current catalog output is still required to identify any non-public or manually created objects. [schema_discovery.sql](schema_discovery.sql) is read-only.
- Function discovery: all expected functions returned `NOT_FOUND`: `apply_verified_purchase`, `consume_ai_proxy_rate_limit`, `consume_monetization_credits`, `ensure_monetization_wallet`, `ensure_profile_for_current_user`, `get_global_metrics`, `grant_monetization_credits`, `handle_new_user`, and `reset_monetization_allowance`.
- Migration history: local migrations are present, but the Remote column is blank for all listed migrations.

## Reported Preflight Finding

The prior preflight reported `table_exists=false` for public `profiles`, `tasks`, `goals`, `habits`, `settings`, `purchase_bindings`, and `user_daily_metrics`. This report does not independently rerun that query. The new schema discovery output must establish whether these objects are missing entirely or live in a different non-system schema.

| Category | Status |
| --- | --- |
| Tables found | Unknown until schema discovery runs in confirmed staging |
| Tables missing | Reported missing from public: `profiles`, `tasks`, `goals`, `habits`, `settings`, `purchase_bindings`, `user_daily_metrics` |
| Tables in wrong schema | Unknown until schema discovery runs |
| Functions found | None of the expected functions |
| Functions missing | `apply_verified_purchase`, `consume_ai_proxy_rate_limit`, `consume_monetization_credits`, `ensure_monetization_wallet`, `ensure_profile_for_current_user`, `get_global_metrics`, `grant_monetization_credits`, `handle_new_user`, `reset_monetization_allowance` |
| Core-sync RLS tests allowed | **NO** - `TABLE_MISSING_OR_WRONG_SCHEMA` remains unresolved |
| RPC validation allowed | **NO** - expected functions are missing |
| Credit tests allowed | **NO** - wallet and credit RPCs are missing |
| Rate-limit tests allowed | **NO** - rate-limit RPC is missing |
| Profile repair tests allowed | **NO** - profile-repair RPC is missing |
| Global metrics tests allowed | **NO** - global-metrics RPC is missing |
| Receipt mismatch tests allowed | **NO** - purchase RPC, schema, and deployment are unconfirmed |
| Seed SQL allowed | **NO** |
| Production release allowed | **NO** |

## Safe Next Action

Review [schema_discovery.sql](schema_discovery.sql) output for conflicting non-system objects before any migration application is proposed. Do not run migrations or mutation tests.
