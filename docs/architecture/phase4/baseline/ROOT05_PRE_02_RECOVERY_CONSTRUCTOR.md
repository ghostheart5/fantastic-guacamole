# ROOT05-PRE-02 — Scoped recovery constructor

Session recovery now captures its required storage scope at construction and
uses `<recovery-key>.<scope>` for all reads and writes. Its provider reads the
committed session boundary and uses `boundary.userId ?? 'signed_out'`. This
contains no drain, cleanup, migration, or lifecycle coordinator behavior.
