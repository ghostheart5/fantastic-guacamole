# LIFE-ROOT-05C — Profile / Settings changed-file isolation

## Profile

| Item | Evidence |
| --- | --- |
| Root-05 API | `Future<void> ProfileController.cancelAndDrainWrites()` |
| Lifecycle caller | `_cancelAndDrainIdentityOwnedWork` |
| HEAD blob | `010bb5743865c4d57e13248cfa3332f86b9eb416` |
| Current SHA-256 | `017FA008655B58A1578656CC51CC0243911524F51EDBDD0AE5D6C23C336E1132` |
| Snapshot | unavailable in this sandbox (recovery path permission denied) |
| HEAD→current groups | 43 |
| HLM-06 staged blob | `481f1a937b4206403627c4557961f4c6cf4017d1` |

`cancelAndDrainWrites` advances the lifecycle generation and waits for the
write and side-effect tails while absorbing their prior failures. It is a
ROOT05-DRAIN / ROOT05-USER-SCOPE member: stale callbacks fail the generation
or scope check and cannot persist into the next account.

**Selected:** `PROFILE-ROOT05-H01` — the queue/generation fields and
`cancelAndDrainWrites` member required for that API. **Excluded:** 42 groups:
HLM-05 progression; Root-03 migration/key work; staged HLM-06 sound facade;
sync helpers; auth/session, notification, and SI changes. Post-snapshot
selected: 0. The future candidate is `CURRENT HEAD + H01` only. It is
independent of HLM-06 only with deterministic blob reconstruction afterward.

## Settings

| Item | Evidence |
| --- | --- |
| Path | `lib/data/repositories/settings_repository.dart` |
| Root-05 API | `Future<void> SettingsRepository.cancelAndDrain()` |
| Lifecycle caller | `_cancelAndDrainIdentityOwnedWork` |
| HEAD blob | `3815dffe11e384302dd1e25ba58bf1c607143298` |
| Current SHA-256 | `B8520F5F4BA71F6CC5B2C773BF134AE1A7B4D95DB0082712B312D9D87071DE4A` |
| Snapshot | unavailable in this sandbox (recovery path permission denied) |
| HLM-06 staged blob | `9ce97a019926bc7f33daa887416242ca5699b46b` |

**Selected:** `SETTINGS-ROOT05-H01` — `_cancelled`, `_writeQueue`,
`cancelAndDrain`, `dispose`, and serialized write admission check. This is a
single queue/gate drain contract: it rejects new queued writes after transition
and waits for accepted writes. It neither invalidates providers nor deletes
settings. **Excluded:** the remaining two current diff groups, including all
HLM-06 preference/sound/theme semantics. Post-snapshot selected: 0.

## Cross-phase decision

Total selected groups: 2; unknown selected: 0. Both files can be committed
independently of HLM-06 only through HEAD-derived candidate blobs, followed by
deterministic restoration of the recorded HLM-06 blobs. Required isolation
tests: Profile progression, Root-03 migration/key, sync-key, HLM-06 blob
reconstruction, and API resolution; Settings API resolution, HLM-06 blob
reconstruction, scope preservation, and exclusion of preference migration (10
tests total).

**Readiness: READY-FOR-REMAINING-ROOT05-HUNK-SELECTION.** This subphase does
not select any of the other eleven dirty owners and does not implement Root-05.
