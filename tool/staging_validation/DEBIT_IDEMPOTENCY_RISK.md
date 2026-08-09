# Debit Idempotency Risk

## Current RPC Signature

```text
consume_monetization_credits(credit_amount integer, reason text, metadata jsonb)
```

## Risk

The function has no idempotency key, request ID, or uniqueness-enforced debit identifier. Repeating a successful call can therefore create another spend transaction and decrement the wallet again, subject only to remaining balance.

## Where Duplicate Prevention Could Live

| Layer | Role |
| --- | --- |
| Client | Generate and retry a stable request ID, but do not trust client-only state as the authorization boundary. |
| Edge Function | Authenticate caller, enforce a server-side request ledger, and make retries return the prior result. |
| RPC | Accept an idempotency key and perform the debit plus ledger insert atomically. |
| Transaction metadata uniqueness constraint | Store a canonical request identifier in a dedicated indexed column or enforce a safe uniqueness expression; JSON metadata alone has no current uniqueness constraint. |

## Production Recommendation

Add an atomic server-side or RPC-level idempotency contract before treating repeated debit delivery as safe. Do not rely on UI disabling or retry timing alone.

## Effect on Staging Testing

This does not block valid single-debit, insufficient-balance, anonymous-denial, or RLS visibility testing once setup is approved. It blocks a claim that duplicate debit protection has been validated, because no such contract currently exists.

## Production Release Status

**NO**