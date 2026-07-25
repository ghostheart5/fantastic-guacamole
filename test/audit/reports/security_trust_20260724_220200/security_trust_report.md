# Security + Trust Automated Audit

- Timestamp: 2026-07-24 22:02:25
- Project root: C:\Users\keegan radetski\fantastic-guacamole
- Passed: 10
- Failed: 2

| Check | Status | Details | Evidence |
|---|---|---|---|
| Environment/config files documented | PASS | Example env and release config files exist. | .env.example, supabase/functions/.env.example, android/key.properties.example, android/release.properties.example, scripts/chronospark_env.example.ps1 |
| Environment ignore and docs align | PASS | Ignore rules and local-config documentation are present. | Hits: 5 |
| No obvious secrets in source or history | FAIL | Potential secret patterns detected. | C:\Users\keegan radetski\fantastic-guacamole\supabase\functions\.env.example:11; C:\Users\keegan radetski\fantastic-guacamole\supabase\functions\monetization-verify\index.ts:231 |
| Supabase rules reviewed | PASS | RLS and storage policy evidence found in migrations. | Files: 7; Hits: 71 |
| Firebase rules reviewed | FAIL | Firebase database/storage usage found without rules files. | Usage hits: 11 |
| Account deletion path exists | PASS | Delete-account routing, support fallback, and auth service support are present. | Hits: 19 |
| Sensitive logs are scrubbed or disabled in release | PASS | Release logging is gated and sensitive content is redacted. | Hits: 36 |
| Crash reports avoid private task content | PASS | Crash reporting routes through redaction and guarded collection. | Hits: 21 |
| Local storage privacy risk reviewed | PASS | Backup, secure storage, and cleanup signals reduce privacy risk. | Hits: 55 |
| Exported backups warn about sensitive contents | PASS | Settings copy warns users before sharing sensitive data. | Hits: 7 |
| Authentication edge cases tested | PASS | Sign out, token refresh/expiry, and network failure handling are covered in code paths. | Hits: 34 |
| Privacy policy, terms, support, and data safety align | PASS | Release-facing legal/support URLs line up with the documented privacy audit. | Hits: 23 |

Overall result: FAIL
