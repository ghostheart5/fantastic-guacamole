# ChronoSpark Google Play package

This directory stages launch-facing Google Play copy and graphics without changing the app, release candidate, or Play Console.

## Exact source boundary

- Package: `com.ghostheart5.chronospark`
- Version in the audited source: `4.1.0` (`2026083003`)
- Source base: `888c4a8a5452e38ddfbf6720f63dbc4609f9ae9b`
- Staging branch: `codex/public-surface-2040-20260831`
- This package is not a release artifact and does not authorize an upload or production submission.

## Prepared files

- `store-listing-en-US.md`: truthful English title and descriptions
- `release-notes-en-US.txt`: bounded release-note draft
- `console-readback-2026-08-31.md`: live Play Console inventory and blockers
- `data-safety-review.md`: exact declarations that require correction or verification
- `production-access-draft.md`: production-access evidence and owner-input fields
- `assets/app-icon-512.png`: 512 x 512 icon candidate
- `assets/feature-graphic-1024x500.png`: 1024 x 500 feature graphic candidate
- `assets/feature-graphic-background-v1.png`: generated source background
- `assets/feature-graphic-prompt.txt`: generation prompt and composition notes
- `assets/manifest.json`: dimensions, byte sizes, and SHA-256 hashes
- `screenshots/README.md`: exact-build screenshot acceptance criteria

## Do not upload yet

The Play listing cannot be submitted truthfully until:

1. the public legal-site update is merged and the canonical URLs return `200`;
2. Data safety is reconciled against the exact release artifact and its SDKs;
3. fresh phone screenshots are captured from that exact artifact;
4. the signed release candidate is uploaded and verified separately;
5. the production-access answers are completed by the account owner from actual tester recruitment and feedback evidence.
