# FIX-006 Habit Domain Authority

Habit definitions are owned by `HabitRepository` in scoped Habit V2 storage.
Habit occurrences are owned by `HabitOccurrenceRepository` in scoped V2 storage.
Daily, weekly, and monthly occurrence period keys preserve target-count,
completion, skip, missed-inference, and streak semantics. Timeline is a
projection; Sync replicates occurrence mutations; reminders schedule Habit
definitions only.

Routine is a compatibility concept. Its reads project canonical Habits.
Create and update delegate only when `stepTaskIds` is empty; delete and bulk
save fail closed. `routines_v1` is physically preserved, inactive, unclaimed,
has no fallback or automatic migration, and is excluded from current-account
lifecycle cleanup. Creator and voice retain their separate deferred semantics.

Certification evidence: B-3 occurrence/provider/queue regressions, B-4A
Habit-backed reads, B-4B conditional writes, and B-4C lifecycle deactivation.
The known Timeline durable retry limitation remains unchanged.
