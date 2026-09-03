# Priority 6 human-robot proxy result

## Verdict

**INSUFFICIENT / BLOCKED** for the Priority 6 moderated-human exit gate.

This was a scripted emulator proxy, not a real participant session. One of five planned persona-style attempts was started and none completed the full first-value, comprehension, save or decline, rediscovery, correction/export, and deletion protocol. The required five representative moderated human sessions therefore remain open.

## Exact target

- Device: `emulator-5558`, Android 16 / API 36
- App: `com.ghostheart5.chronospark`
- Version: `4.1.0` (`2026083003`)
- Profile APK SHA-256: `9770E55645D698A0E09DF1A6E44FEF3C3824C0FFD2B2CCBC401CF666D43A09CC`
- Source baseline: `ae6823bd9f03640834cfc52442d70cbf5d8135b3` plus the existing uncommitted Priority 8 repairs represented by the installed APK
- Android font scale during the attempt: `1.0`

## Counts

| Check | Result |
|---|---:|
| Planned proxy personas | 5 |
| Personas attempted | 1/5 |
| Fully completed proxy personas | 0/5 |
| Reached Nexus from fresh local app state | 1/1 |
| Reached useful Smart Planner guidance before the context offer | 1/1 |
| Reached the optional context offer after guidance | 1/1 |
| Completed **Not now** verification | 0/1 |
| Completed consent/save/rediscovery/delete core path | 0/1 |
| Completed correction/export governance path | 0/1 |
| Completed 200% text-scale attempt | 0/1 |
| Real moderated participants represented | 0/5 |

## Persona 1 evidence

Persona: privacy-cautious first-time user.

The fresh-state flow completed onboarding/login, reached Nexus, opened Smart Planner, and verified that **Add optional context** was absent before first guidance. It then produced useful deterministic guidance and found the context offer afterward. The scripted task segment from first input focus to the guidance-ready assertion was approximately **11.93 seconds**; this is automation timing, not valid human task timing. Total runner wall time before the assertion failure was **126.598 seconds**, including app reset, onboarding, login, navigation, driver overhead, and the failed assertion wait.

The offer was visibly rendered and the captured accessibility hierarchy contained:

- use-only as the default;
- decision-support purpose;
- Smart Planner-only scope;
- 30-day expiry;
- close-ranking-tie effect;
- **Add optional context** and **Not now** actions.

The exact child-text selector then failed because Flutter exposed the offer copy as one coalesced accessibility node. A resume flow could not return to the offer because the stopped runner relaunched at the login screen and its selector could not find **Add optional context**. A corrected retry was interrupted at the repeated boundary to avoid additional retries. These are automation-state/selector limitations; **no app defect was proven**.

## Evidence files

- `persona-01-console.txt` — original flow transcript
- `persona-01-timing.txt` — original runner wall time
- `persona-01-maestro/2026-09-03_111911/` — command log, hierarchy, and failure screenshot
- `persona-01-resume-console.txt` — bounded resume attempt transcript
- `persona-01-resume-maestro/2026-09-03_112214/` — login-state hierarchy proving why resume could not continue
- `persona-01-rerun-console.txt` — interrupted corrected retry; not counted as a completed attempt
- `p6-current.xml` — post-resume Android hierarchy at login

## Remaining Priority 6 requirement

Run the binder protocol with **five representative human participants**, using fresh authenticated test accounts and recording anonymized comprehension, hesitation, elapsed core-path time, rescue count, and defects. At least four of five must correctly explain all required governance facts, no participant may believe context is required, and every participant must complete the timed first-value-to-delete path in under two minutes with zero facilitator rescues. Until that evidence exists, Priority 6 is not complete.
