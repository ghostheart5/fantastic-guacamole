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
checks typed text after keyboard dismissal. Failures remain recorded and the
full suite must rerun. No monkey testing or direct XP writes are authorized for
this validation phase. Level-20 endurance stays gated on material test results.
