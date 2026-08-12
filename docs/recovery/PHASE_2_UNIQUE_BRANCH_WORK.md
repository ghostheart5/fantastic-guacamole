# ChronoSpark Phase 2 Unique Branch Work

All branch tips and unique-commit counts were preserved in the protected branch inventory. The following lines have obvious non-redundant history and must be inspected without merging before any integration decision:

| Branch / ref | Unique commits vs `main` | Initial recommendation |
| --- | ---: | --- |
| `backup-before-review-20260808` | 108 | Preserve as authoritative candidate; requires clean integration planning |
| `backup-before-form-and-ux-phase` | 91 | Needs architecture review |
| `heads/backup-before-bak-cleanup-2026-08-01` | 83 | Preserve only pending provenance review |
| `backup-before-flow-cleanup` | 13 | Later manual extraction candidate |
| `backup-before-onboarding-redesign` | 10 | Needs product decision and UX review |
| `safe-backup-20260724` | 9 | Preserve only |
| `agents/voice-navigation-fix-plan` | 11 | Current active work; inspect in its linked worktree |
| `rescue/chronospark-stabilization` | 2 | Needs architecture review |
| `fix/guard-mojibake-microbatch` | 24 | Unknown; preserve pending proof |

The remote `copilot/*` set contains additional unique history and is retained under **unique history — review required** in the full inventory. Names alone are not sufficient to classify their value. No cherry-pick or manual extraction was performed.

For any valuable item discovered later, the allowed next-phase dispositions are: preserve only, later cherry-pick candidate, later manual extraction candidate, superseded after proof, needs product decision, needs architecture review, or discard candidate after proof.
