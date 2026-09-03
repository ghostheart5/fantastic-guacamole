# Priority 6 First-Use Context Usability

## Evidence boundary

This is the moderated test script and consent-copy review for the app-only
Priority 6 gate. Automated host checks may verify reachability, semantics, and
layout. They do not substitute for a moderated participant session, physical
device evidence, translation review, or human comprehension.

## Moderator setup

- Use a fresh authenticated test account with no prior context-offer marker.
- Keep the existing two-page onboarding unchanged.
- Start on Nexus and do not explain Person Context before the participant sees
  the product copy.
- Ask the participant to think aloud. Do not define product terms unless the
  script explicitly asks for their interpretation.
- Record task outcome, quoted comprehension, hesitation, elapsed time, whether
  the facilitator rescued the participant, and defects. Do not record private
  goal or context text.

## Moderated scenario

1. Ask: "Use ChronoSpark to get one useful next step for something you want to
   do today."
2. Observe whether the participant reaches Smart Planner and receives guidance
   without being forced through a context intake.
3. When the optional context offer appears, ask: "What would happen if you do
   nothing here?"
4. Ask: "If you save something, where may ChronoSpark use it, why, for how long,
   and what could it change?"
5. Ask the participant to choose **Not now**. Confirm the plan remains usable
   and no durable context is created.
6. Repeat with another fresh test account. Start the timer before asking the
   participant to seek first value. The timed core path begins here; give no
   coaching or rescue.
7. After the participant gets first guidance, ask the comprehension questions
   from steps 3 and 4, then ask them to open **Add optional context**, enter a
   harmless exact current priority, inspect the disabled save control, grant
   consent, and save. Confirm saving requires both exact text and consent.
8. Ask the participant to use the **Context** entry from Nexus, find the saved
   item again, and delete it. Stop the timer only when deletion is confirmed.
   The complete first-value, comprehension, save, discovery, and deletion path
   must finish in under two minutes without facilitator coaching or rescue.
9. As separate, untimed governance checks, repeat with a fresh account and ask
   the participant to identify exact text, purpose, Smart Planner-only scope,
   expiry, correction, and export. Correct and export the item, then delete it;
   confirm later guidance does not present the deleted context as active.
10. Ask: "Did ChronoSpark ask for a personality type, life history, or emotional
    label?" The expected answer is no.

## Acceptance criteria

- First useful guidance is available before any durable-context prompt.
- The offer appears once per account after useful guidance, not during the
  short onboarding.
- At least 4 of 5 representative participants correctly explain use-only as the
  default, Smart Planner-only scope, decision-support purpose, 30-day expiry, and the
  possible effect before saving.
- No participant believes the prompt is required to continue.
- No participant is asked for personality, life history, or a synthetic
  emotional label.
- All participants can find Context from Nexus and Settings and can locate
  review, correction, expiry, export, and delete controls.
- Every participant completes the timed first-value-to-delete core path in
  under two minutes with zero facilitator rescues. Record duration and rescue
  count for each run; any rescue or time at or above two minutes is a failure.
- Any material misunderstanding is a failure requiring copy or interaction
  repair and another moderated run.

## Consent-copy review

- **Optionality:** "Use only this time remains the default" appears before the
  add action and again in the consent dialog.
- **Data minimization:** the prompt asks for one exact current priority in
  the participant's own words; the field is blank and capped at 280 characters.
- **Purpose:** decision support is stated before saving and matches the central
  policy for a current-priority signal.
- **Surface scope:** Smart Planner only is fixed and stated before saving.
- **Expiry:** automatic deletion after 30 days is stated before saving.
- **Effect:** copy says the priority may break a close ranking tie while active
  and does not become an identity fact.
- **Consent:** saving is disabled until exact text and an explicit checkbox are
  both present.
- **Governance:** Nexus and Settings expose Context; Settings retains review,
  correction, expiry, export, withdrawal, and deletion controls.
- **Prohibited intake:** no personality quiz, life-history intake, or inferred
  emotional label is requested.

## Evidence log

- Automated widget, provider-restart, semantics, and 200% visual checks: record
  the exact command and result in `APP_ONLY_READINESS_MATRIX.md`.
- Moderated sessions: not complete until participant count, device/build SHA,
  anonymized outcomes, and defects are attached here or in a linked artifact.

## Human-robot proxy evidence — 2026-09-03

A bounded human-robot proxy was run on `emulator-5558` against profile APK
version `4.1.0` (`2026083003`), SHA-256
`9770E55645D698A0E09DF1A6E44FEF3C3824C0FFD2B2CCBC401CF666D43A09CC`.
It reached fresh-state Nexus, useful Smart Planner guidance before the optional
context offer, and the visible offer containing all five governance facts.

The exact child-text selector then failed against Flutter's coalesced semantics
node, and the bounded resume attempt returned to login instead of the offer.
Testing stopped after that repeated automation boundary. Result: **1/5 proxy
personas attempted, 0/5 fully completed; INSUFFICIENT / BLOCKED**. No app defect
was proven. This scripted proxy is not a human participant and does not close
the five-participant moderated exit gate.

Evidence: `../../artifacts/priority6/human-robot-proxy/20260903-111837-ae6823bd-dirty/results.md`.
