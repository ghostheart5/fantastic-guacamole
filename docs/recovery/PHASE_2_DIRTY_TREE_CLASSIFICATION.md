# ChronoSpark Phase 2 Dirty-Tree Classification

Captured before creating Phase 2 documentation: 2026-08-12. The complete, reconstructable manifest is stored only in the protected local recovery snapshot identified in `PHASE_2_RECOVERY_REPORT.md`; it includes every changed, untracked, sensitive ignored, and deleted tracked path.

| Classification | Paths | Basis and handling |
| --- | ---: | --- |
| A. Current user work | 0 proven | No dirty path could safely be attributed as clearly intentional current user work from pathname alone. |
| B. Phase / audit artifact | 70 | Existing `docs/`, `must do/`, and `todo/` audit/planning artifacts. Preserve; do not conflate with application source. |
| C. Generated / build output | 11 | Present test-result and device-artifact outputs. Preserve in snapshot; do not treat as source truth. |
| D. Unknown | 202 | Present modifications/untracked source, test, configuration, and mixed artifacts without sufficient provenance. Preserve unchanged. |
| E. Possible legacy | 2,453 | All currently deleted tracked paths, especially `archive/` (1,589), `lib/` (676), and dead-code archives. Deletion intent is unproven. Preserve deletion state in manifest; do not remove or restore. |
| F. Sensitive | 3 | `.env`, `.supabase.local.env`, and `tool/staging_validation/.env`; copied only to the protected local snapshot, never to Git. |

The before-state had zero staged paths, 2,650 unstaged paths, 2,453 tracked deletions, and 86 untracked paths. Classification is intentionally conservative: unknown and possible-legacy entries require later proof before cleanup.
