# Accessibility + Real-User Usability Audit

Date: 2026-07-24
Owner:
Release Target:
Build/Commit:

## Checklist
- [ ] Text is readable at large font sizes.
- [ ] Tap targets are large enough for thumbs.
- [ ] Color is not the only way to communicate priority/warning.
- [ ] Contrast passes for body text and secondary text.
- [ ] Screen reader labels exist for buttons/icons.
- [ ] Forms have clear labels and validation messages.
- [ ] Error messages say what happened and what to do next.
- [ ] Reduced motion setting is respected or planned.
- [ ] Offline/error states are understandable.
- [ ] First-time user can complete first task without developer help.
- [ ] No feature depends on users understanding internal module names.

## Automated audit coverage
Executable script:
- test/audit/run_accessibility_real_user_audit.ps1

Automated checks include:
- Semantics/tooltip coverage signals for buttons and icons.
- Form labels and validation messaging signals.
- Tap-target sizing heuristics in shared button widgets.
- Reduced-motion/lifecycle animation guardrails.
- Offline/error-state copy signals.
- First-time journey/tutorial copy signals.
- User-facing copy heuristics that avoid internal module names.
- Contrast/token presence in theme and reusable UI widgets.

## Manual evidence still required
- [ ] Large-font screenshot review on a small Android device.
- [ ] TalkBack/VoiceOver pass over the first task flow.
- [ ] Thumb reach check for primary actions.
- [ ] Error-state and offline-state screenshot proof.
- [ ] First-run walkthrough proof without developer help.

## Findings log
- Date/Time:
- Finding:
- Severity:
- Evidence:
- Owner:
- Fix PR/Commit:
- Retest result:
