# ChronoSpark Release UAT Matrix

These scenarios are prepared for later physical-device and release-candidate
execution. They are not part of the non-build reliability gate. For every run,
record app version/build, device/OS, account, network state, timestamps,
screenshots or video, and sanitized logs.

## UAT-001 — First launch and guided setup

- Objective: prove a new user reaches Nexus with current canon and retained setup progress.
- Prerequisites: fresh install, new test account, network available.
- Test data: a Unicode display name and one planning priority.
- Action: interrupt setup halfway, kill/reopen, resume, complete, and reopen again.
- Expected: the correct step resumes; Nexus is home; no Session or standalone Insight surface appears.
- Failure indicators: reset progress, blank route, duplicate setup step, retired terminology, or lost personalization.
- Severity: P0.
- Evidence: full recording plus final Nexus and persisted-profile screenshots.
- Cleanup/recovery: delete the disposable account through the in-app flow.

## UAT-002 — Authentication expiry and recovery

- Objective: verify an expired or revoked token cannot expose authenticated data.
- Prerequisites: authenticated account with one task and one goal.
- Test data: revoke the session from the backend while the app is backgrounded.
- Action: resume, open protected deep links, then sign in again.
- Expected: protected surfaces close without flashing private data; state restores after reauthentication.
- Failure indicators: stale data exposure, redirect loop, crash, or lost local work.
- Severity: P0.
- Evidence: recording and sanitized auth/route logs.
- Cleanup/recovery: restore a valid account session.

## UAT-003 — Creator double-submit and interruption

- Objective: prove Creator produces one useful connected artifact under hostile timing.
- Prerequisites: authenticated account at Nexus.
- Test data: long Unicode title, multiline description, maximum priority.
- Action: rapidly tap submit, background during save, resume, and reopen the result.
- Expected: one persisted artifact with visible Smart Planner and Timeline connections.
- Failure indicators: duplicates, spinner deadlock, lost fields, placeholder output, or disconnected result.
- Severity: P0.
- Evidence: recording plus Creator, Planner, and Timeline screenshots.
- Cleanup/recovery: remove only the generated artifact.

## UAT-004 — Smart Planner offline retry

- Objective: validate useful failure handling without false AI claims or duplicate responses.
- Prerequisites: account with tasks and goals.
- Test data: a concrete planning question referencing those items.
- Action: disconnect before submit, retry twice, reconnect, and retry once.
- Expected: bounded offline/error state, no duplicate response or credit loss, and contextual output after reconnection.
- Failure indicators: raw exception, endless spinner, duplicated result, misleading success, or generic unrelated advice.
- Severity: P0.
- Evidence: recording, network transition timestamps, and sanitized request IDs.
- Cleanup/recovery: restore network and clear only the test conversation if supported.

## UAT-005 — Task completion idempotency and crash recovery

- Objective: protect Progression, Timeline, and task state from duplicate completion.
- Prerequisites: one incomplete high-priority task.
- Test data: fixed task title recorded in the run sheet.
- Action: tap complete rapidly, kill during feedback, reopen, and inspect every connected surface.
- Expected: one completion, one XP award, one Timeline event, and consistent Nexus synthesis.
- Failure indicators: doubled XP/events, reopened task, impossible state, or stale Nexus summary.
- Severity: P0.
- Evidence: before/after screenshots and sanitized persistence logs.
- Cleanup/recovery: reopen only through supported UI and document the resulting state.

## UAT-006 — Multi-device conflict

- Objective: verify simultaneous edits do not silently erase newer work.
- Prerequisites: the same test account on two physical devices.
- Test data: one shared task and one shared goal.
- Action: take both offline, edit differently, reconnect in opposite orders, and force sync.
- Expected: deterministic conflict behavior and converged state without silent disappearance.
- Failure indicators: data loss, infinite retry, duplicate records, or permanent divergence.
- Severity: P0.
- Evidence: synchronized recordings and backend row/object timestamps.
- Cleanup/recovery: retain evidence, then reconcile using normal UI actions.

## UAT-007 — Corrupted or legacy local state

- Objective: validate upgrade and recovery without destroying recoverable data.
- Prerequisites: controlled legacy fixture installed by the release engineer.
- Test data: legacy tutorial keys, `activeMissionId`, malformed optional cache, and valid tasks/goals.
- Action: upgrade in place, launch, visit canon surfaces, change one profile field, and restart.
- Expected: compatible setup state, retained valid data, safe malformed-data handling, and no retired UI.
- Failure indicators: reset account, overwritten valid data, crash loop, or exposed retired surface.
- Severity: P0.
- Evidence: fixture hash, upgrade video, post-upgrade export, and sanitized logs.
- Cleanup/recovery: uninstall only after exporting evidence.

## UAT-008 — Account deletion with nested cloud backups

- Objective: prove deletion removes identity, database rows, and every nested Storage object.
- Prerequisites: disposable account with both cloud backup objects.
- Test data: objects below `<uid>/backup/` plus profile and metrics rows.
- Action: cancel deletion once, retry with the correct credential, then attempt sign-in again.
- Expected: cancel is non-destructive; success removes nested objects and auth/data rows; retry is idempotent.
- Failure indicators: success while objects remain, retained auth user, partial deletion without error, or cross-user impact.
- Severity: P0.
- Evidence: before/after backend listings and queries, response status, and redacted recording.
- Cleanup/recovery: none; use only a disposable account.

## UAT-009 — Purchase restore and entitlement failure

- Objective: verify premium access reflects authoritative billing state.
- Prerequisites: Play license-test account and configured test products.
- Test data: active, canceled, and expired states plus a verifier outage.
- Action: purchase, restart, restore, interrupt verification, recover service, and restore again.
- Expected: no pre-verification unlock, correct restoration, safe retry, and no duplicate charge.
- Failure indicators: client-only unlock, permanent lockout, deceptive success, or duplicate purchase.
- Severity: P0.
- Evidence: Play test order, entitlement timestamps, recording, and sanitized verifier logs.
- Cleanup/recovery: cancel the test subscription and verify later expiry.

## UAT-010 — Notification and deep-link safety

- Objective: verify notification actions route safely across auth and lifecycle states.
- Prerequisites: scheduled task and streak reminders.
- Test data: valid target, deleted target, and malformed deep link.
- Action: tap each while foregrounded, backgrounded, killed, signed out, and token-expired.
- Expected: valid target opens once; invalid targets fall back to Nexus; protected data never flashes.
- Failure indicators: crash, redirect loop, duplicate navigation, or unauthorized exposure.
- Severity: P1.
- Evidence: recordings for each lifecycle state and notification payload IDs.
- Cleanup/recovery: cancel remaining test notifications.

## UAT-011 — Voice permission and audio interruption

- Objective: verify optional voice/audio features degrade cleanly.
- Prerequisites: microphone-capable device and media interruption source.
- Test data: denied and granted microphone states.
- Action: deny, retry, grant in settings, dictate, interrupt with media/call, resume, and disable sound.
- Expected: no pre-consent recording, clear fallback, clean recovery, and honored sound preference.
- Failure indicators: permission loop, background recording, transcript leak, overlapping audio, or crash.
- Severity: P1.
- Evidence: recording, permission screenshots, and audio-focus logs.
- Cleanup/recovery: revoke microphone permission and stop playback.

## UAT-012 — Accessibility and alternate input

- Objective: keep core flows operable without precise touch or default text size.
- Prerequisites: TalkBack, 200% text scale, high contrast, and keyboard/switch access.
- Test data: task, goal, Planner query, and Creator form.
- Action: complete core flows using accessibility focus/keyboard; rotate during forms and errors.
- Expected: logical focus, announced labels/state, visible focus, no clipped critical control, and preserved input.
- Failure indicators: unlabeled control, focus trap, hidden CTA, clipped error, or lost data.
- Severity: P1.
- Evidence: screen-reader recording, scaled screenshots, and scanner report.
- Cleanup/recovery: restore accessibility settings.

## UAT-013 — Tablet, foldable, and orientation transitions

- Objective: verify premium layout behavior across large and changing viewports.
- Prerequisites: physical tablet/foldable or approved device lab.
- Test data: populated Nexus, long Timeline, Creator form, and SI conversation.
- Action: fold, unfold, and rotate during scrolling, editing, loading, and error states.
- Expected: no overflow, lost selection, duplicated request, inaccessible panel, or reset navigation.
- Failure indicators: layout exception, blank pane, lost draft, or inconsistent back behavior.
- Severity: P1.
- Evidence: videos and screenshots at each posture/orientation.
- Cleanup/recovery: return to portrait and confirm state consistency.

## UAT-014 — Error privacy and screenshot review

- Objective: prove failures and logs never expose credentials or personal data.
- Prerequisites: controlled failing endpoints and test account.
- Test data: synthetic email, bearer token, password, API-key-shaped value, and personal task text.
- Action: trigger auth, sync, AI, billing, and storage failures; collect every surface and log bundle.
- Expected: actionable generic UI and redacted sensitive patterns with safe correlation data.
- Failure indicators: raw stack, email/token/password/key, backend internals, or full personal payload.
- Severity: P0.
- Evidence: screenshot set and reviewed sanitized log archive.
- Cleanup/recovery: delete evidence after the approved security-retention period.

## UAT-015 — Resource pressure and lifecycle abuse

- Objective: expose race, leak, and resume failures on representative hardware.
- Prerequisites: low/mid Android device and large test dataset.
- Test data: long task/Timeline lists and SI conversation.
- Action: rapidly switch tabs, background/resume 30 times, rotate, submit while returning, and reopen after OS kill.
- Expected: bounded memory, no duplicate writes, responsive navigation, restored draft/state, and no crash loop.
- Failure indicators: sustained memory rise, ANR, lost state, duplicates, or stuck loading.
- Severity: P1.
- Evidence: profiler screenshots, recording, and sanitized crash/ANR logs.
- Cleanup/recovery: stop profiling and remove only the generated dataset.
