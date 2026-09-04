# Priority 7 Planned-Source Reachability

Point-in-time scope: the uncommitted Windows working tree based on
`bc414f2dd851bba18570ec12e27d830b62fd10fb`.

## Baseline-to-current accounting

The binder's 80 raw `PLANNED` occurrences consisted of 75 domain classification
banners and five explanatory/test occurrences. The audit did not treat a
provider declaration as shipped behavior.

- 33 stale banners were promoted to `SHIPPING` after source review.
- 18 sources remain syntactically unreachable from `lib/main.dart` and are
  explicitly quarantined.
- 24 use cases remain compiled through the provider registry but have no
  production consumer. This group includes the persisted-plan trio caught by
  skilled review plus unused calendar, signal, workspace, progression, and
  bulk-save provider registrations.
- The stale weighted-XP explanatory occurrence was removed. Classification
  infrastructure text remains intentionally searchable.

`tool/planned_source_manifest.json` is the decision ledger for all 42 retained
planned sources. Every entry has an owner and removal/promotion criteria. The
provider-only entries also name the provider symbol whose absence of a
consumer is checked.

`test/domain/domain_source_contract_test.dart` now enforces exactly one valid
classification banner per domain source, excludes non-shipping sources from the
shipping barrel, validates manifest completeness, follows the Dart import graph
from `lib/main.dart`, and distinguishes `source-unreachable` from
`compiled-provider-only`.

## Deletion and correction list

No source file was deleted. The seven zero-reference model/use-case files were
retained only as owned future architecture with explicit removal criteria; this
is quarantine, not a claim that they ship. Twenty-four provider-only use cases
were retained or restored as `PLANNED` after a broad import-reachability pass
had incorrectly treated compilation as shipping behavior. Stale comments for
work windows, Timeline task update and delete, weighted XP, and domain
planned-code retention were corrected.

The legacy reachability utility now resolves the real
`package:fantastic_guacamole/` package prefix. Its verification reported 718
Dart sources, 651 syntactically reachable from `lib/main.dart`, and 67
unreachable; the generated temporary report was removed after readback.
