# Ready Backend Check Results

## Run

- Target staging URL: `https://pxtjkwfedrtnxuihtdox.supabase.co`
- Command run: `./tool/staging_validation/run_ready_backend_checks.ps1 -ConfirmStaging`
- Passed checks: `22`
- Failures: `0`
- Skips: `4`
- Result: `PASSED_WITH_EXPECTED_SKIPS`

## Passed Checks

- Credit debit rejects zero amount.
- Credit debit rejects negative amount.
- Credit debit rejects anonymous caller.
- User A cannot ensure User B wallet.
- User B cannot ensure User A wallet.
- User A cannot reset User B allowance.
- User B cannot reset User A allowance.
- Anonymous caller cannot ensure wallet.
- Anonymous caller cannot reset allowance.
- Profile repair succeeds for User A.
- Profile repair returns User A profile.
- Profile repair is idempotent for User A.
- User A profile repair preserves ownership.
- Profile repair succeeds for User B.
- User B cannot affect User A profile.
- Profile repair rejects anonymous caller.
- Global metrics rejects anonymous caller.
- Global metrics rejects normal authenticated User A.
- Global metrics rejects normal authenticated User B.
- AI rate-limit RPC rejects anonymous caller.
- AI rate-limit requests 1 through 20 succeed.
- AI rate-limit request 21 fails across User A sessions.

## Expected Skips

- Credit debit succeeds and decrements exactly once: `NEEDS_SEED_OR_ADMIN_SETUP`.
- Credit debit insufficient balance preserves wallet: `NEEDS_SEED_OR_ADMIN_SETUP`.
- `grant_monetization_credits` denial: staging-effective service/admin-only authorization needs final exact coverage.
- `apply_verified_purchase` denial: receipt application belongs to the blocked receipt-validation category.

## Security Risks Closed By This Run

- Invalid and anonymous credit-consumption calls are denied.
- Normal users cannot invoke wallet or allowance helpers for another user.
- Profile repair is caller-bound, ownership-preserving, idempotent, and anonymous callers are denied.
- Global metrics are denied to anonymous and normal authenticated callers.
- The database-backed AI limit is anonymous-safe and shared across User A sessions.

## Risks Not Closed By This Run

- Core-sync table RLS and spoofed-upsert isolation.
- Monetization table read isolation.
- Valid debit and insufficient-balance wallet behavior.
- Exact authorization denial for `grant_monetization_credits`.
- Receipt mismatch and `apply_verified_purchase` behavior.
- Storage bucket/path/policy isolation.

## Production Release Status

**NO**
