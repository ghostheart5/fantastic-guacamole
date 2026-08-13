# BASE-01 bridge session-write repair

This change reconstructs the Phase 2 bridge session-write subsystem on top of
the BASE-00A public `store` constructor contract. It adds one serialized
mutation tail, the suspend/resume gate, draining, cache and sync write guards,
and identity checks before queued metadata mutation or disassociation.

The candidate was compared with the protected snapshot after normalizing only
the already committed constructor contract. Queue failures remain observable to
their original caller while the tail recovers for later work. No queued replay
or second store is introduced. The protected working bridge file is not staged.

Auth callers remain unchanged. BASE-02 remains outside this repair.
