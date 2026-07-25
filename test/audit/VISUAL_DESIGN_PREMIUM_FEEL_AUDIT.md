# Visual Design + Premium Feel Audit

Date: 2026-07-24
Owner:
Release Target:
Build/Commit:

ChronoSpark should feel like a futuristic command center, but the user should never fight the visuals. The best productivity app is clear first, badass second.

## Visual identity checklist
- [ ] Dark clean default theme with strong contrast.
- [ ] Prism/blue/purple accents used sparingly for priority, focus, progress, and SI moments.
- [ ] No screen shows more than 4-5 primary visible items on mobile.
- [ ] Cards have one purpose each.
- [ ] Typography limited to Title, Section, Body, Label.
- [ ] Buttons have clear hierarchy: primary action, secondary action, quiet action.
- [ ] Use whitespace/spacing instead of colored blocks to organize content.
- [ ] Animations are short, meaningful, and never slow down task completion.
- [ ] Every screen has empty, loading, error, and success states.
- [ ] Critical actions have confirmation only when needed; do not over-confirm normal actions.
- [ ] Paywall is premium, calm, and clear, with no spammy popups.

## Screen-by-screen polish goals

| Screen | Polish target |
|---|---|
| Nexus / Now | One clear recommendation, quick actions, calm command-center feel. |
| Add | Fastest path to create value; no oversized forms at first touch. |
| Plan | Readable timeline and time blocks; no cluttered calendar squeeze. |
| Smart Coach | Helpful, emotionally grounded, readable answer cards. |
| SI Console | Command-line feel with understandable prompts/examples. |
| Reflect / Logs | Insights first, raw logs secondary. |
| Settings | Trust center: privacy, subscriptions, reminders, support, tutorial replay. |

## Automated test coverage mapping
This audit has an executable counterpart script:
- test/audit/run_visual_design_premium_audit.ps1

Automated checks include:
- Theme darkness and contrast signals in theme definitions.
- Typography token presence (title/body/label hierarchy).
- Button hierarchy signals (elevated/text/icon usage).
- Animation duration guardrails (flag long durations).
- State handling signals (loading/empty/error/success keywords in core screens).
- Paywall calm-language heuristic.
- Smart Coach and Settings screen existence and quick static checks.

## Manual evidence still required
- [ ] Mobile screenshot proof: no more than 4-5 primary visible items above fold.
- [ ] Interaction recording: fast add flow and no clutter friction.
- [ ] UX review note: card purpose clarity per screen.
- [ ] UX review note: confirmation prompts used only for high-risk actions.

## Findings log
- Date/Time:
- Finding:
- Severity:
- Evidence:
- Owner:
- Fix PR/Commit:
- Retest result:
