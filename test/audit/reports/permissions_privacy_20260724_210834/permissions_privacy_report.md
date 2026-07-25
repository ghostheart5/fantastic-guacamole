# Android Permissions + Privacy Automated Audit

- Timestamp: 2026-07-24 21:09:00
- Project root: C:\Users\keegan radetski\fantastic-guacamole
- Passed: 6
- Failed: 3

| Check | Status | Details | Evidence |
|---|---|---|---|
| Manifest exists | PASS | Manifest found. | android/app/src/main/AndroidManifest.xml |
| Required permission: android.permission.INTERNET | PASS | Declared. | android.permission.INTERNET |
| Required permission: com.android.vending.BILLING | PASS | Declared. | com.android.vending.BILLING |
| Forbidden V1 permissions absent | PASS | No forbidden V1 permissions found. |  |
| Notification permission has code usage | FAIL | Permission declared but no notification permission/request code signals found. |  |
| Audio permission has code usage | FAIL | RECORD_AUDIO declared but no clear runtime usage found. |  |
| Boot permission receiver wiring | PASS | Boot receiver present for notifications. |  |
| Privacy policy artifact exists | PASS | Found at least one privacy policy artifact. |  |
| No obvious committed secrets | FAIL | Potential secret patterns detected. | C:\Users\keegan radetski\fantastic-guacamole\.agents\skills\supabase\SKILL.md:42; C:\Users\keegan radetski\fantastic-guacamole\.agents\skills\supabase-postgres-best-practices\references\security-rls-performance.md:50; C:\Users\keegan radetski\fantastic-guacamole\.archive\old_audits_tests_20260723_183854\.audit\working_tree_unstaged_before_cleanup.diff:1431; C:\Users\keegan radetski\fantastic-guacamole\.archive\old_audits_tests_20260723_183854\.audit\working_tree_unstaged_before_cleanup.diff:1572; C:\Users\keegan radetski\fantastic-guacamole\.archive\old_audits_tests_20260723_183854\.audit\working_tree_unstaged_before_cleanup.diff:1576 |

Overall result: FAIL
