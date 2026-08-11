# HR-CORE-001: canonical core journey

Version: `1.0.0`
Initial result: `NOT RUN`
Required independent verification: yes

Run this black-box journey against a fresh install of the exact binary identified
in the candidate passport, using the New user persona and a run-scoped D-NEW
dataset. Do not substitute seeded UI state for onboarding or authentication.

1. Confirm the passport's commit SHA, binary SHA-256, flavor, backend,
   schema version, device row and network mode; start the recording and
   capture the clean-install evidence.
2. Fresh-install the candidate, launch it, and complete onboarding.
3. Authenticate only with the assigned isolated test account.
4. In **Creator**, create one task, one goal, one habit/routine, and one note.
   Record their displayed names/IDs and creation time in the evidence record.
5. Open **Timeline** and verify all four saved items are displayed with the
   correct identity, scheduling and relationship. Do not treat a loading
   placeholder as proof.
6. Exercise the canonical lifecycle controls: complete, return an item to
   not-complete where supported, skip, and reschedule. Record each immediate
   result and the resulting Timeline history/state.
7. Visit **Nexus**, **Trajectory**, and **Progression**. Verify only the
   changes supported by the performed lifecycle actions; check that repeating
   a completed tap/submission did not duplicate items, credits or progression.
   Trajectory must remain a scenario/projection, not a guaranteed forecast.
8. Restart the application process, launch it again, and recheck Creator and
   Timeline state.
9. Log out, log in to the same assigned account, and verify the saved state is
   still correct. If account switching is included, use the separate
   interruption case and ensure no first-account data appears for the second.
10. Capture terminal screenshots, recording, redacted device logs and result.
    A second person repeats/independently verifies the recorded assertions.

## Pass criteria

The candidate passes only when all actions complete through the current
canonical UI, data survives restart and same-account reauthentication, the
three downstream roots show only supported updates, and no duplicate,
cross-account, crash, inaccessible-control, or chat-isolation veto occurs.
Any missing evidence is `BLOCKED`, not a pass.
