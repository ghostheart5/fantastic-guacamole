# Internal build 3011 validation repairs

Moto testing of Play-delivered build 3010 reproduced a duration mismatch:
"Help me organize my desk in 10 minutes" recommended 20 minutes. Planner now
recognizes explicit numeric work windows in the current request and caps every
option at that limit or the stricter consented capacity limit. The adaptation
receipt explains the applied limit and leaves it unsaved. Concrete new requests
start a new budget; referential follow-ups retain the subject and most recent
explicit budget within the bounded conversation history.

Validation reproduced the failure before repair (5/20/40-minute options for a
10-minute request). After repair, 68 related controller, screen, input-lifecycle,
and Planner learning/persistence tests passed. Exact-commit CI, signed artifact,
Play delivery, and device retest remain separate evidence gates.

Publishing the Terms from main also triggered the Supabase GitHub integration
to redeploy older billing code at 18:43 UTC. The next free monthly test purchase
was approved by Play but its notification failed with `google_oauth_failed`.
The previously tested runtime files were restored, read back byte-for-byte,
and the purchase restored to active; notification retry and renewal succeeded.
PR 101 carries those existing backend repairs onto main so future deployments
retain the valid OAuth grant and terminal-notification handling.

Hosted Maestro evidence exposed two navigation assumptions: the updated action
panel is above chat history, and the keyboard can partially clip the multiline
input despite complete text entry. The harness returns to the action panel and
scrolls the complete typed field into view without sending Android Back, which
was observed to pop the Planner route during keyboard dismissal. Failures remain recorded and the
full suite must rerun. No monkey testing or direct XP writes are authorized for
this validation phase. Level-20 endurance stays gated on material test results.

Build 3011 was signed from `957ea1344c54c31f68f53805bb09f723ab85dfc9`
after CI run 34155916844 passed (2,523 Flutter tests, no failures or skips).
Build run 34156883203 produced the verified AAB with SHA-256
`b80a21b3eee579efe62aea717d885b7af244021499e8185f9f443eb24f8d4249`.
It was published as internal-track release 15 on September 7 at 20:00 UTC.
Moto update and final release-device checks remain pending at this checkpoint.

Backend PR 101 merged as `5c9be7d788d7514ee8f0c8eba7d41172060fdd46`.
Its additional refund regression keeps an unbound voided-purchase notification
retryable until ownership reconciliation; all 96 Edge Function tests passed.
Post-merge source readback matched verify-receipt version 19 and
google-play-rtdn version 14. Those deployed functions successfully activated a
new annual license-test purchase automatically and reconciled its renewal.
The same backend-only correction is retained on this branch after the frozen
AAB source; it does not change the compiled Flutter application.

Build 3010's continuous-foreground monthly expiry was observed at 19:51 UTC
and correlated with expired backend authority. Earlier brief inactive samples
during renewal recovered automatically and were not counted as expiry.
Annual cancellation, decline, retry, activation, and accelerated renewal were
also observed. Billing Lab offered only Renew despite the configured 14-day
grace period and 46-day account hold, so recovery scenarios still need live
evidence. These device observations do not establish a completed full suite.
