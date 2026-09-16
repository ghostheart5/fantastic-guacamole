# ChronoSpark approved internal credit policy

September 8, 2026. The user approved this policy for setup in the existing internal-testing release. This replaces the earlier $4.99/$39.99 proposal. Production availability remains contained.

| Product | USD catalog price | Included allowance |
|---|---:|---|
| Free | $0 | 20 credits per monthly allowance window |
| Premium monthly | $7.99/month | 300 credits per month |
| Premium annual | $69.99/year | 300 credits per month, with yearly billing |
| 100-credit pack | $2.99 once | 100 purchased credits, no expiry |
| 300-credit pack | $7.99 once | 300 purchased credits, no expiry |

Monthly included allowance does not roll over. Spend included allowance before purchased credits. Purchased credits survive subscription expiry. No automatic top-ups, overage purchases or monetary charges. A refunded pack reverses remaining purchased credits; already-spent refunded credits are offset against future packs. In-flight AI failures reverse matching refund debt before restoring spendable credits.

Tasks, goals, notes, local planning, history and XP remain available at zero AI credits. A subscription does not grant internal advisor-account authorization. The fictional credit-test panel is the internal validation surface; it is not a finished public AI product.

## Server and app behavior

Migration `20260908205414_monthly_allowances_and_credit_topups.sql` separates paid subscription coverage from monthly allowance windows, preserves existing balances at transition, and anchors calendar months without end-of-month drift. Missed windows do not accumulate. Active/canceled paid coverage can fund the next window; grace, hold and pause do not add unfunded allowances. Verified initial/renewal/recovery causes retain the existing durable-principal grant ledger and idempotency guards.

Google verifies completed, account-bound one-time purchases before server grant and consumption. Duplicate receipts cannot mint credits. Pending/canceled purchases do not grant. Void/refund notifications create tombstones even before the first client verification. Only license-test credit purchases are accepted in this internal rollout. One-time RTDN delivery must be enabled before activation.

The AI proxy returns a five-minute signed quote bound to account, request ID, complete request digest, model/output cap and policy version. Quoting does not call the generation provider or debit credits. Explicit confirmation reserves the quoted credits before provider traffic. The quote budgets $0.003 per credit using the serialized UTF-8 request size plus a conservative framing allowance and full output cap. Provider usage is validated and actual cost recorded; missing usage, failures and timeouts retain conservative cost accounting even when credits are refunded. Cost ceilings and daily limits bound repeated refunded attempts. Pricing assumptions must be reviewed when the model/provider price changes.

## Unit economics assumptions

At the $0.003 provider budget, 300 included credits budget $0.90/month and $10.80/year. Assuming the 15% Google Play auto-renewing subscription fee, contribution before other expenses is $7.99 x 0.85 - $0.90 = $5.8915/month, or $69.99 x 0.85 - $10.80 = $48.6915/year. These are estimates, not profit or a provider invoice. Hosting, support, free-user allowances, taxes, refunds and acquisition remain additional costs. One-time product fees depend on the applicable program and are not assumed equal to subscription fees.

Sources: [Google Play service fees](https://support.google.com/googleplay/android-developer/answer/112622?hl=en), [Google one-time purchase lifecycle](https://developer.android.com/google/play/billing/lifecycle/one-time), [Anthropic Sonnet 4.6 pricing](https://platform.claude.com/docs/en/models/sonnet-4-6/overview).

## Validation and release status

Local focused Flutter billing suite: 109 passing cases, with additional credit-pack/no-premium and wallet serialization checks passing. Edge Function gate: 130 passing cases, zero failures/errors/skips. Isolated PostgreSQL 16 billing-schema fixture passes monthly allowance, annual coverage, account isolation, duplicate grants, bucket ordering, refund races, month rollover and privilege assertions. The full Supabase Database Gate passed on source 2e472658 (run 34277098915): clean migration replay, schema lint, 342 database contracts and 130 Edge Function tests. Full Flutter/static/Windows/Linux CI passed on the same source (run 34277099116).

Live migration 20260908205414 is applied. Both existing wallets retained consistent balances. Deployed verify-receipt v21, google-play-rtdn v19 and ai-proxy v15 are active and their retrieved source files match the tested bundles exactly. JWT settings remain true/false/true respectively, preserving the RTDN handler's Google OIDC authentication.

Play Console readback: active monthly and prepaid-test base plans are $7.99; annual is $69.99. Active, backwards-compatible one-time products chronospark_credits_100 ($2.99) and chronospark_credits_300 ($7.99) use a single buy option, single quantity, US-only availability and no future-country expansion. Prices apply to new purchases; no existing subscriber price cohort was migrated. One-time purchase notifications were enabled on the existing Pub/Sub topic.

Candidate version 4.1.0+2026083020 contains the new policy. Final-source CI, authoritative catalog preflight, signed build and exact-device license-test verification are separate release gates still to be recorded. Build 3019 is the earlier repaired installation and cannot prove this new policy.
