# Internal candidate 3026 reviewer access

The designated existing Play reviewer account now receives a separate, server-authorized complimentary entitlement. It is not a Google purchase, mock receipt, administrator grant or local paywall bypass. Customer purchase bindings and purchased credit balances cannot be replaced by this operation.

The initial review window ends October 11, 2026 at 12:39:48 UTC. Its total allowance is 300 credits, including the account's initial 20 credits. It never automatically refills. Spending uses normal quote/reserve/settle authority; exhaustion blocks another reservation. Expiry and revocation remove unused review allowance, including protection against a later in-flight failure restoring revoked credits. A repeated grant key does not refill or extend access and cannot be moved to another account.

The grant function remains SECURITY INVOKER and service-role-only. A separate service-only SECURITY DEFINER helper with an empty search path returns only confirmed-account eligibility; it does not expose authentication records or expand auth-table grants. Anonymous and signed-in clients cannot call either helper or grant function. The append-only entitlement event log retains its existing privileges.

The migration was replayed with all database contracts, schema lint and Edge checks in disposable hosted run `34599578664` before production application. Its production migration version is `20260911123820`; the local filename matches that independently read-back record. The live entitlement and wallet were read back with 300 credits, no recurring allowance, no order and no purchase token. The post-migration security advisor inventory introduced no additional findings.

Client validation: 119 focused paywall, repository and entitlement tests passed, including owner mismatch, malformed review authority, expiry and explicit English/Spanish complimentary-access messages. The previous Home-vitals gate passed 227 focused checks. Final exact-source CI, the signed AAB, installation, and reviewer device journey remain separate evidence and are not implied by these local passes.

The private candidate/backend cohort must include the verified reviewer while preserving existing tester entries. Credentials are not included in this document. Before any future submission, verify that the review window and remaining allowance cover review, and explicitly renew the designated grant if necessary. Reusable sign-in credentials alone do not prove access to paid features. Do not claim the Play full-access declaration has been validated until the installed reviewer journey passes.

Public paid activation still requires the project's completed, signed and dated qualified privacy/AI-safety review, aligned client/backend eligibility and public-feature validation. This internal configuration is not production approval. No production release is authorized.
