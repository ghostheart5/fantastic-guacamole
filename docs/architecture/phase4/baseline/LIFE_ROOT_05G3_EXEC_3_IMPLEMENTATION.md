# LIFE-ROOT-05G3 — G0 EXEC-3 implementation

Starting HEAD: `cbf86cab5e3e0569a494831b9d3202b30ca2a805`.

| R05 IDs | Path | HEAD blob | candidate blob |
| --- | --- | --- | --- |
| R05-015 | `lib/state/services/extended_domain_service.dart` | `38b6e315fe96350b953a549ee36afaf1322b5f32` | `19a0d163be5507cc78f0657038a59402f6830e40` |
| R05-016, R05-017 | `lib/state/providers/domain_usecase_providers.dart` | `af4e8fb2e43848ef352e5cc7e4b0fe2e03ef0bbf` | `e11119e5e41c52e69ea27eb723d795662826ae97` |

R05-016 and R05-017 depend on R05-015 in this EXEC only. No external,
HLM-06, protected-untracked, or future-EXEC dependency is included.

The service candidate gates/disposes in-memory state, drains its accepted write
tail, and leaves durable preferences intact. The provider candidate owns a
typed service provider, a drain helper, and a separate invalidation helper;
invalidation never deletes durable state.

T15 is dynamically covered by
`test/state/services/root05_exec3_extended_domain_test.dart`. T16/T17 are
provider integration coverage: the helpers statically resolve their same-EXEC
service API and are checked in targeted analysis. The focused candidate run
also includes G2 T11–T14 regression; 5 tests passed, 0 failed, with zero
targeted analyzer diagnostics.

The lifecycle overlay can consume the drain helper after the service exists;
the protected lifecycle source was not edited, staged, or committed. G0
EXEC-4 has no dependency on this commit and remains ready after this commit.
