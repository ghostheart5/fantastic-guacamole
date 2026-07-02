# Safe Rebuild Checklist

This checklist protects legal/policy/badge files while rebuilding the app.

## Protected Files (Do Not Modify)

- CODE_OF_CONDUCT.md
- LICENSE
- SECURITY.md
- README.md
- web/privacy.html
- assets/legal/privacy_policy.html

## Integrity Guard

- Baseline hash file: .rebuild/protected-file-hashes.txt
- Verify command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify_protected_files.ps1
```

Run this before and after every rebuild phase.

## Rebuild Phase Order

1. Core app boot path (`main.dart`, app wiring, DI)
2. Auth flow (`lib/features/auth` + auth service contract)
3. System shell (`main_shell`, tabs, nav, background)
4. State and persistence (`app_state`, runtime persistence, storage)
5. SI engine + adaptive learning modules
6. Temporal Ops and SI Console
7. Settings and paywall modules
8. Test suite stabilization
9. Docs refresh (`CHRONOSPARK.md`)

## Per-Phase Gate

1. `flutter pub get`
2. `flutter analyze`
3. Run targeted tests for modified modules
4. Run protected-file integrity check

Proceed to next phase only if all checks pass.
