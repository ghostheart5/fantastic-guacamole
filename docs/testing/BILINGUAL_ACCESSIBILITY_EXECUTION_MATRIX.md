# Bilingual accessibility execution matrix

This matrix is an execution record, not a blanket accessibility claim. Every
row must be tied to one Git commit, build artifact hash, device/browser, locale,
and evidence path. `PASS` is allowed only when the named check actually ran;
otherwise record `FAIL`, `BLOCKED`, or `NOT RUN`.

Destructive account deletion is excluded from this matrix and from ordinary
automated runs.

## Required environments

| ID | Locale | Text scale | Input | Assistive technology | Target |
| --- | --- | --- | --- | --- | --- |
| EN-STD | English | 100% | Touch | None | Pixel 8 API 35 |
| ES-STD | Spanish | 100% | Touch | None | Pixel 8 API 35 |
| EN-LARGE | English | 200% | Touch | None | Pixel 8 API 35 |
| ES-LARGE | Spanish | 200% | Touch | None | Pixel 8 API 35 |
| EN-TB | English | 100% and 200% | Accessibility focus | TalkBack | Pixel 8 API 35 |
| ES-TB | Spanish | 100% and 200% | Accessibility focus | TalkBack | Pixel 8 API 35 |
| EN-KB | English | 100% and 200% | Hardware keyboard | TalkBack off/on | Pixel 8 API 35 |
| ES-KB | Spanish | 100% and 200% | Hardware keyboard | TalkBack off/on | Pixel 8 API 35 |
| EN-WEB | English | 100%, 200%, 400% zoom | Keyboard | Browser screen reader | Chrome |
| ES-WEB | Spanish | 100%, 200%, 400% zoom | Keyboard | Browser screen reader | Chrome |

## Surface matrix

Execute every applicable environment above for each row. Core actions must
remain possible without precise touch, color-only meaning, or memorized layout.

| Surface | Language/readability | Large text/reflow | Semantics/state | Focus order | Keyboard | Screen reader announcement |
| --- | --- | --- | --- | --- | --- | --- |
| Login and recovery | All labels, errors, and recovery actions localized | No clipped fields or hidden submit/recovery action | Fields expose label, required/error state, and secure-entry role | Heading, email, password, recovery, submit | Tab/Shift+Tab/Enter; focus returns to first invalid field | Error announced once without raw exception text |
| Two-step onboarding | Plain English/Spanish; no internal or military language | Content scrolls; primary action remains reachable | Current step, progress, fields, and actions named | Reading order follows visual order | Complete both steps without touch | Step change and validation announced |
| Nexus | Concrete signals and next action; no bare “Insight” destination | Rings, Timeline content, and actions do not overlap | Ring values include labels/units; cards expose state | Heading, status, primary action, navigation | Navigation and primary actions operable | Dynamic state changes announced without repeated noise |
| Creator | Field purpose and resulting artifact are clear | Long labels/help/errors wrap | Required fields, validation, busy/success state exposed | Heading, fields, help, submit | Full create flow and error correction | Submission progress and result announced |
| Smart Planner | Recommendation includes reason/evidence/freshness | Query and answer remain readable at 200% | Input, send, busy, evidence, confidence named | Transcript before composer; latest result reachable | Submit/retry/cancel without touch | Loading, failure, and response announced once |
| Timeline | Event type, time, and consequence localized | Long event text reflows without horizontal scroll | List position, event title/time/status exposed | Chronological order is deterministic | Open/filter/return without touch | Event grouping and empty state announced |
| Trajectory Engine | Forecast language distinguishes estimate from fact | Scenario controls and ranges reflow | Assumptions, range, confidence, freshness exposed | Baseline before controls before outcomes | Change scenario and return with keyboard | Updated projection announced with context |
| Progression | XP/activity separated from observed capability change | Charts have text alternatives at 200% | Values, trend direction, and units exposed | Summary before detail | Reach all detail and help actions | Trend is not communicated by color alone |
| SI Console | Processing mode and source limitations localized | Transcript/composer remain usable | Message author/status, composer, send, stop named | Chronological transcript then composer | Compose, send, stop, retry | New reply and failure announced once |
| Profile and Settings | Every setting and consequence localized | Switch labels/descriptions wrap | Switch checked state and destructive boundaries exposed | Logical section order | Change/revert setting without touch | Saved/failed state announced |
| Offline and sync recovery | No false success; conflict wording explains choices | Recovery controls remain visible | Offline, queued, conflict, retry states exposed | Problem before choices | Retry/recover/keep choice operable | Connectivity and result announced |

## Robot evidence

The non-device gate must retain results for:

- localization completeness for every declared English and Spanish string;
- English/Spanish legal and router-error rendering;
- semantic labels and minimum touch targets for shared controls;
- onboarding and SI composer behavior with a software keyboard;
- widget tests at large text scale where the screen has deterministic fakes;
- no raw exception text in user-facing routing errors.

Robot checks cannot prove TalkBack reading order, spoken clarity, switch access,
or browser screen-reader behavior. Those rows remain `NOT RUN` until the human
UAT phase records device evidence.

## Run record

| Commit | Artifact SHA-256 | Environment ID | Surface | Result | Evidence | Issue ID |
| --- | --- | --- | --- | --- | --- | --- |
| _record at execution_ | _record at execution_ | _record_ | _record_ | NOT RUN | _path_ | _if any_ |
