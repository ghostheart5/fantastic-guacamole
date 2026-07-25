# Security + Trust Audit

Date: 2026-07-24
Owner:
Release Target:
Build/Commit:

Principle: trust is a release feature. If the app stores, exports, logs, or syncs user data, the release must prove that the sensitive path is bounded, documented, and recoverable.

## Scope

- No secrets in git history or source files.
- Environment/config files are documented and ignored where needed.
- Supabase/Firebase rules reviewed if used.
- Account deletion path exists if an account system exists.
- Sensitive logs are disabled or scrubbed in release.
- Crash reports do not include private task content unnecessarily.
- Local storage is reviewed for privacy risk.
- Exported backups clearly warn users about sensitive contents.
- Authentication edge cases are tested: sign out, token expired, network fail.
- Privacy policy, terms/support contact, and data safety answers align.

## Commands

Run from project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test\audit\run_security_trust_audit.ps1
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test\audit\run_audit.ps1 -NoWindowsBuild -NoAndroidReleaseBuild -NoPermissionsPrivacyAudit -NoVisualDesignAudit -NoPerformanceStabilityAudit -NoSubscriptionPaywallAudit -NoAccessibilityAudit
```

## Evidence checklist

- [ ] Secret scan output attached.
- [ ] Environment file documentation reviewed.
- [ ] Supabase migration or policy evidence attached.
- [ ] Account deletion path evidence attached.
- [ ] Log redaction and crash reporting evidence attached.
- [ ] Local storage and backup/export evidence attached.
- [ ] Auth edge-case evidence attached.
- [ ] Privacy policy and support alignment evidence attached.

## Findings log

- Date/Time:
- Finding:
- Severity:
- Evidence:
- Owner:
- Fix PR/Commit:
- Retest result:
