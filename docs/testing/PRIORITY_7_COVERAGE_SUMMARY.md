# Priority 7 Coverage Summary

Status: **PASS — target-mode thresholds met by final full-suite evidence.**

Point-in-time scope: final Windows candidate tree based on
`bc414f2dd851bba18570ec12e27d830b62fd10fb`, 2026-09-03. This is local host
evidence; exact-commit CI, device/runtime, deployed-service, and human evidence
remain separate gates.

Command:

```powershell
flutter test test --no-pub --coverage --concurrency=1
```

Result: **2,099 tests passed, one intentional test skipped, zero failures.**
The final run includes the repaired source-contract readers, AI/SI and
intelligence behavior coverage, account-transition regressions, release-critical
paywall/backup/sync coverage, and the final storage-boundary tests.

The full-suite LCOV artifact and target-mode guard reported:

| Binder layer | Measured | Target | Result |
| --- | ---: | ---: | --- |
| Domain/use-cases | 85.7% (735/858) | >=85% | PASS |
| Data/storage | 82.7% (311/376) | >=80% | PASS |
| State/controllers/providers | 70.5% (6,091/8,634) | >=70% | PASS |
| Domain/policies | 97.8% (827/846) | >=90% | PASS |
| Domain/value objects | 100% (49/49) | >=90% | PASS |
| Data/repositories | 76.9% (2,053/2,668) | >=75% | PASS |
| Engine/SI | 76.6% (1,858/2,426) | >=70% | PASS |
| Features/UI | 72.8% (6,530/8,966) | >=50% | PASS |

Overall coverage is **73.4%**. Critical-only coverage is **92.4%**. Every
release-critical target passes: auth 92.0%, backup 95.1%, paywall 88.2%, sync
95.4%, and runtime diagnostics 98.3%.

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/coverage_guard.ps1 -CoverageFile coverage/priority7-authoritative.info -Mode target
```

Result: **PASS**. The guard also reports 11 integration-flow files against its
5-8 guidance range. That is a non-blocking maintainability warning, not a
coverage failure; the added percentage came from focused unit/provider/storage
behavior rather than recreated integration tests. No coverage target, shipping
source, or production behavior was excluded to improve the result.
