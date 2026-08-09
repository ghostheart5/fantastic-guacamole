# Functions Needed For Next Pass

Source: tracked migrations only. Entries describe the final local definition implied by migration order, not the effective staging database. `READY` means a test shape can be drafted locally; it does not authorize execution before staging confirmation.

| Function | Exact signature / security / path | Grants and caller checks | Validation / meaning | Test status |
| --- | --- | --- | --- | --- |
| `apply_verified_purchase` | `public.apply_verified_purchase(uuid, text, text, text, text, timestamptz, timestamptz, jsonb)`; INVOKER; `public` | service role only; accepts `target_user_id`, no uid equality check | Applies verified Google product entitlement/purchase; target, product, type, token hash, order, verification/expiry times, payload are clear from parameters | Blocked: server-only and receipt path/cleanup not confirmed |
| `consume_monetization_credits` | `public.consume_monetization_credits(integer, text, jsonb)`; DEFINER; `public, pg_temp` | authenticated; PUBLIC/anon revoked; `auth.uid()` required; no target parameter | `credit_amount`, `reason`, `metadata`; amount must be `1..1000`, reason nonblank max 160, metadata object max 8192 bytes; debit caller wallet | READY for denial tests; valid/insufficient debit needs approved wallet state |
| `ensure_monetization_wallet` | `public.ensure_monetization_wallet(target_user_id uuid default null)`; INVOKER; `public` | service role only in final hardening; body accepts arbitrary target | Ensures/returns wallet; target defaults to current uid but does not require equality | READY for denial tests |
| `reset_monetization_allowance` | `public.reset_monetization_allowance(target_user_id uuid default null)`; INVOKER; `public` | service role only in final hardening; body accepts arbitrary target | Resets allowance based on subscription status; target defaults to current uid but does not require equality | READY for denial tests |
| `grant_monetization_credits` | `public.grant_monetization_credits(target_user_id uuid, credit_amount integer, transaction_type text, transaction_source text, transaction_description text, metadata jsonb default '{}'::jsonb)`; INVOKER; `public, pg_temp` | service role only; no uid target equality check | Amount must be `1..5000`; nonblank transaction fields; object metadata max 8192 bytes; grants credits to target | Blocked pending staging-effective grant/owner confirmation |
| `consume_ai_proxy_rate_limit` | `public.consume_ai_proxy_rate_limit()`; DEFINER; `public, pg_temp` | authenticated; PUBLIC/anon revoked; `auth.uid()` required | Per-user DB window; first 20 requests in one minute succeed, request count above 20 raises `rate limit exceeded` | READY |
| `get_global_metrics` | `public.get_global_metrics()`; DEFINER; `public, pg_temp` | PUBLIC/anon/authenticated revoked; no uid check | Returns aggregate task-completion and momentum values from daily metrics | READY for denial tests; normal-user success is a release-risk finding |
| `ensure_profile_for_current_user` | `public.ensure_profile_for_current_user()`; DEFINER; `public, pg_temp` | authenticated; PUBLIC/anon revoked; `auth.uid()` required | Looks up caller in `auth.users`, inserts/returns only caller profile; no target parameter | READY |

## Definition Summaries

### `apply_verified_purchase`

Rejects null target, ensures the target wallet, suppresses duplicate `(user_id, purchase_token_hash)` application, maps known products to subscription/lifetime/credit behavior, persists purchase and entitlement rows, and returns application details. It is expected to be reached only from server-side receipt verification.

### `consume_monetization_credits`

Creates a default caller wallet if absent, locks the caller row, refreshes an expired allowance from active status, rejects insufficient balance, debits only the caller, records a negative spend transaction, and returns the updated balances.

### `ensure_monetization_wallet` / `reset_monetization_allowance`

Both use `coalesce(target_user_id, auth.uid())`; neither body itself requires `target_user_id = auth.uid()`. Their security boundary is the final service-role-only execute grant and must be confirmed on staging.

### `grant_monetization_credits`

The hardened final body validates positive bounded amounts and transaction metadata before mutating the target wallet and adding a transaction. It remains intentionally server-only by grant.

### `consume_ai_proxy_rate_limit`

Uses an insert-or-update on the current user's rate-limit row, resets after one minute, and rejects counts above 20.

### `get_global_metrics` / `ensure_profile_for_current_user`

Global metrics aggregates all daily metrics but is revoked from normal roles. Profile repair requires an authenticated caller and inserts only the caller's profile.

Parameter meaning is `UNKNOWN — needs source call-site or migration comment confirmation` only where not stated above. No parameter meaning is inferred beyond the function body and tracked migration names.