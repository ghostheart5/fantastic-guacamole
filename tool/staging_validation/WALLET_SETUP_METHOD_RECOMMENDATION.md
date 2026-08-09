# Wallet Setup Method Recommendation

**Review only. No method is approved for execution.**

## 1. `grant_monetization_credits` as an Admin Operation

| Factor | Assessment |
| --- | --- |
| Safety | Requires a privileged database capability and must stay outside client scripts. |
| Repeatability | Good for a known credit amount. |
| Cleanup complexity | High: it increments wallet lifetime values and creates an immutable-style transaction record that must be reconciled. |
| Creates transaction records | Yes. |
| Production-like behavior | Yes for credit grants. |
| Recommendation | Not recommended for debit fixture setup because cleanup is more complex than the debit assertion. |

## 2. Direct Table Fixture Insert as an Admin Operation

| Factor | Assessment |
| --- | --- |
| Safety | Acceptable only for confirmed disposable staging users under this contract. |
| Repeatability | High: all wallet fields and the exact transaction baseline are explicit. |
| Cleanup complexity | Moderate and deterministic when the user has no pre-existing wallet/transactions. |
| Creates transaction records | Only when a separately documented fixture transaction is inserted. |
| Production-like behavior | No for setup; the debit under test still uses the production consume RPC. |
| Recommendation | **Recommended** for deterministic staging debit setup and cleanup. |

## 3. Existing Edge Function or Test Helper

| Factor | Assessment |
| --- | --- |
| Safety | Unknown until a deployed route, authorization model, and cleanup behavior are reviewed. |
| Repeatability | Unknown. |
| Cleanup complexity | Unknown. |
| Creates transaction records | Unknown. |
| Production-like behavior | Potentially, but unverified. |
| Recommendation | Not recommended until separately discovered and approved. |

## 4. Manual Dashboard Setup

| Factor | Assessment |
| --- | --- |
| Safety | Operator-dependent; risk of undocumented values. |
| Repeatability | Low. |
| Cleanup complexity | High without a written baseline. |
| Creates transaction records | Depends on the dashboard action. |
| Production-like behavior | Depends on the dashboard action. |
| Recommendation | Not recommended except as a documented admin procedure matching the direct-fixture contract. |

## Decision

Use a direct table fixture only through an explicitly approved external admin process for disposable staging users. The disabled template in [admin_only_wallet_setup_TEMPLATE.sql](admin_only_wallet_setup_TEMPLATE.sql) is not client code and must not be executed automatically.