# LIFE-BOUNDARY-PRE-01 — Session Boundary API

PRE-02 was blocked because its scoped recovery provider must read the stable
session boundary, not raw auth state. This commit extracts the immutable
boundary read model, provider, and state notifier into
`auth_session_boundary_provider.dart`. It contains no drain, cleanup,
migration, bootstrap, resume, or lifecycle-coordinator code.

The deferred untracked coordinator retains its protected source unchanged; a
future reconciliation will replace its duplicate local declarations with an
import of this committed API. The boundary distinguishes a stable transition
generation/user scope from raw auth-stream updates, and reading it performs no
durable mutation.
