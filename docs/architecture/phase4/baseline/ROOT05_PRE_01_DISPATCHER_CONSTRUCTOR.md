# ROOT05-PRE-01 — Scoped mutation dispatcher construction

The dispatcher now receives a captured nullable `userId` at construction.
The DI provider obtains it from the existing Supabase client wiring; no new
scope authority or resolver is introduced. Enqueue operations use that fixed
scope, so accepted work cannot silently change from account A to B when auth
state later changes. This phase intentionally excludes cancellation, operation
tails, and all `DISPATCH-H01…H03` drain semantics.

Focused tests cover null scope rejection, de-duplication, and captured-scope
retention. The exact-index candidate contains only the dispatcher, its DI
caller, these tests, and this record.
