# Wallet Setup Options

**Planning only. No setup is approved or performed by these documents.**

## 1. Naturally Provisioned Wallet

`consume_monetization_credits` creates a caller-owned free wallet on first invocation with balance and allowance values of `20`.

| Factor | Assessment |
| --- | --- |
| Safety | Good for a disposable staging user; the function creates only the caller’s row. |
| Repeatability | Limited: each successful debit permanently changes wallet and transaction state. |
| Cleanup complexity | High without an approved account-removal or privileged cleanup process. |
| Recommendation | Not recommended as the sole valid-debit setup method. Suitable only as part of an approved disposable-user lifecycle. |

## 2. Admin-Only Wallet Setup

An approved operator prepares an isolated wallet baseline and cleanup procedure outside client scripts. Client-side tests still use only normal authenticated sessions.

| Factor | Assessment |
| --- | --- |
| Safety | Good when limited to confirmed staging disposable users and reviewed by a human. |
| Repeatability | High: known balance, transaction baseline, and expected post-test state. |
| Cleanup complexity | Defined before execution; must remove or reset all resulting wallet and transaction state. |
| Recommendation | **Recommended.** |

## 3. Test-Only Wallet Seeding

Direct insertion or mutation of wallet and transaction tables for test setup.

| Factor | Assessment |
| --- | --- |
| Safety | Poor unless separately authorized and isolated; it bypasses the normal client contract. |
| Repeatability | High technically, but risks masking production-path behavior. |
| Cleanup complexity | High because seeded wallets and dependent transactions must be removed exactly. |
| Recommendation | Not recommended. Do not generate a client-side seeding script. |

## 4. Existing Wallet Discovery

Use a naturally existing User A/User B wallet as the baseline.

| Factor | Assessment |
| --- | --- |
| Safety | Poor for shared staging users; existing balances may support real staging workflows. |
| Repeatability | Low because external activity can change state. |
| Cleanup complexity | High because restoring a pre-existing state is ambiguous. |
| Recommendation | Not recommended for debit mutation testing. It is suitable only for read-only discovery. |

## Decision

Use an approved external administrative setup and cleanup contract for disposable staging users. Do not put privileged credentials or setup actions in client scripts.