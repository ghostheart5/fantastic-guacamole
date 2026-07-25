# Subscription + Paywall Audit

Date: 2026-07-24
Owner:
Release Target:
Build/Commit:

ChronoSpark should monetize cleanly without ads. The trust goal: users understand what is free, what is premium, and what happens to their data if they downgrade.

## Checklist
- [ ] Base, Premium, Ultimate features are explicitly mapped.
- [ ] Trial quotas are exact and tested.
- [ ] Paywall only appears at meaningful feature boundary.
- [ ] No intrusive popups.
- [ ] Free users still receive strong core value.
- [ ] Upgrade/downgrade preserves user data.
- [ ] Billing provider selected and production-ready before launch.
- [ ] MockBillingService removed or clearly disabled for production.
- [ ] Refund/support language prepared.
- [ ] Subscription state handles offline gracefully.
- [ ] Expired/canceled subscription behavior tested.
- [ ] Store subscription products match app UI copy.

## Premium ideas that fit ChronoSpark
- [ ] Unlimited Temporal Ops and SI Console usage.
- [ ] Deeper SI recommendations and weekly planning intelligence.
- [ ] Advanced Reflect analytics: patterns, heatmaps, consistency tracker.
- [ ] Custom PrismCore themes and focus modes.
- [ ] Longer history, export, and backup tools.
- [ ] Future calendar sync, voice command, and multiverse account features.

## Current implementation signals to verify
- Free tier is represented by EntitlementTier.free in the app entitlement model.
- Premium tier is represented by EntitlementTier.premium.
- Ultimate tier is represented by EntitlementTier.ultimate and can be reserved for future high-tier plans.
- Google Play billing is the production billing path.
- Paywall testing mode must not ship enabled in production builds.
- Support language must be visible in-app and in store listing/help pages.

## Automated audit coverage
Executable script:
- test/audit/run_subscription_paywall_audit.ps1

Automated checks include:
- Explicit feature/tier mapping signals in entitlement, access, and paywall code.
- Google Play product ID and UI copy consistency.
- Trial quota presence and availability mapping.
- Production billing provider and paywall testing-mode gating.
- Absence of MockBillingService in production code.
- Refund/support language presence.
- Offline/cancel/restore handling signals.
- Downgrade data-retention signals in local cleanup logic.

## Manual evidence required
- [ ] Screenshot/video of paywall at meaningful boundary only.
- [ ] Screenshot/video of free user core value path.
- [ ] Proof that downgrade/cancel retains user data.
- [ ] Store listing copy matches actual product names and subscription behavior.
- [ ] Release-mode confirmation of billing provider configuration.

## Findings log
- Date/Time:
- Finding:
- Severity:
- Evidence:
- Owner:
- Fix PR/Commit:
- Retest result:
