# Internal 3022 device findings — repair record

The three findings from the Moto acceptance session are repaired in the local
source. The installed Play version remains 4.1.0+2026083022; these changes have
not been built, uploaded, or installed. Physical-device acceptance remains
pending on a higher-version release.

## Changes

1. **DEVICE3022-01 — readable Creator goal review.** Creator resolves the linked
   goal's title from the active goal list, preserves the actual ID in the saved
   task, and uses `Linked goal unavailable` when it cannot resolve that title.
   The existing confirmation/revision checks remain in place.
2. **DEVICE3022-02 — Creator note history.** Confirmed note creation now records
   its Timeline creation event, and undo records deletion history. Both use the
   existing idempotent adapter, with the projection captured before the storage
   await and an account-generation check before projection. Timeline is refreshed
   after Creator note mutations and normal note create/edit/archive projection.
   A history-storage failure does not roll back the canonical note save or undo.
   This fixes new operations; it does not fabricate or backfill old history.
3. **DEVICE3022-03 — visible Planner destination.** After explicit note consent,
   the app removes the exact imperative note-detail route before changing the
   shell destination. It does not rely on popping the top route while the
   consent dialog may still be closing. Cancel and account-ownership checks are
   preserved.

## Regression evidence

Evidence directory: `test-results/device-3022-repairs-20260910/`.

- `route-verified-tests-manifest.json`: **18 passed**, zero failed/error/skipped.
  New journeys confirm through the Creator UI, inspect the real Timeline screen,
  reload its provider from storage, repeat confirmation/undo without duplicates,
  and open Notes through Nexus into the visible Planner with both shared and
  distinct shell page identities. Cancel leaves the note and selection unchanged.
- `regressions-manifest.json`: **86 passed**, zero failed/error/skipped. Covers
  Creator review/save/undo, note links and consent, English/Spanish controls,
  Timeline rendering/projections/storage, Creator profile recovery, account
  changes during a suspended note save, and history-storage failure.
- `analyze-final.txt`: focused static analysis of all changed Dart source/test
  files (the initial analyzer report is retained in `analyze.txt`).
- Final formatting, patch whitespace and protected-file checks are recorded in
  `FINAL_SUMMARY.json`.

The new widget mutation journeys retain real screens, routing, domain operations
and repositories, with memory-backed storage boundaries. They are host evidence,
not Android Keystore, native disk or Play-installation evidence. Early harness
attempts stalled on native storage inside the fake async clock or failed route
transition/disposal assertions; those reports are retained. The accepted runs
above are complete runs with no skipped tests or weakened route/data assertions.

## Release boundary

No commit, push, signed rebuild, Play upload, subscription transaction, monkey
test or new level-20 endurance run was performed for these repairs. The earlier
device report remains the historical result for installed 3022. After rebuilding,
repeat its three failure reproductions through a Play-preserving Moto update.
