# Expected RLS Results

**Execution approval status: `NOT APPROVED`.**

A protected outcome is a test **PASS**. A successful cross-user read or mutation, an uncleaned test row, or any target other than confirmed staging is a test **FAIL**.

## Core-Sync Tables

The following expected outcomes apply independently to `tasks`, `goals`, `habits`, `settings`, `purchase_bindings`, and `user_daily_metrics`.

| Generated test | Expected result |
| --- | --- |
| User A inserts own row | `PASS`: authenticated User A creates a row whose `user_id` is User A. |
| User A reads own row | `PASS`: User A receives the row created for User A. |
| User B cannot read User A row | `PASS`: denial or zero visible rows. |
| User B cannot update User A row | `PASS`: denial or zero affected rows. |
| User B cannot delete User A row | `PASS`: denial or zero affected rows. |
| User A cannot spoof `user_id = User B UUID` | `PASS`: insert is denied or returns no created row. |
| User B cannot spoof `user_id = User A UUID` | `PASS`: insert is denied or returns no created row. |
| Owner cleanup after each Core-Sync case | `PASS`: cleanup response is successful; an unexpected spoof row is removed by its actual owner. |

`settings` has one additional safe precondition: if either user already has `id = 'default'`, the suite records `SKIP` rather than overwrite or delete a pre-existing settings row.

## Profiles

`profiles` ownership is `id = auth.uid()`; no test uses or assumes `user_id`.

| Generated test | Expected result |
| --- | --- |
| User A reads own profile | `PASS`: User A receives exactly its own profile. |
| User B cannot read User A profile | `PASS`: denial or zero visible rows. |
| User B cannot update User A profile | `PASS`: denial or zero affected rows. |
| User A cannot write User B profile | `PASS`: denial or zero affected rows. |
| User B cannot write User A profile | `PASS`: denial or zero affected rows. |
| Owner restoration after each profile probe | `PASS`: the owner can restore the original `full_name`; restoration failure is a test failure. |

## Monetization Read Isolation

The following expected outcomes apply independently to `monetization_subscription_statuses`, `monetization_wallets`, `monetization_credit_transactions`, `monetization_purchases`, and `monetization_entitlement_events`.

| Generated test | Expected result |
| --- | --- |
| User A queries own records | `PASS`: request succeeds and every returned row has User A's `user_id`. `SKIP: NO_OWN_ROW_AVAILABLE` is inconclusive, not a failure. |
| User B cannot read User A records | `PASS`: denial or zero visible rows. |
| User A cannot read User B records | `PASS`: denial or zero visible rows. |

No monetization direct-write test is generated because the reviewed client policy contract is read isolation only.

## Explicit Exclusions

- `ai_proxy_rate_limits`: no direct-table test; validate only through `consume_ai_proxy_rate_limit()`.
- Valid debit, insufficient balance, grant authorization, receipt mismatch, `apply_verified_purchase`, and Storage remain blocked pending their documented prerequisites.
- Production release status: **NO**.