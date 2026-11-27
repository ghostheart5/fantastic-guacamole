// The Patterns result types for screens, which may not import lib/engine
// directly (check_architecture.ps1, rule 11). Types only: the engine's
// computation is reached through patternsProvider.
export 'package:fantastic_guacamole/engine/patterns/activity_record.dart'
    show ActivityRecord;
export 'package:fantastic_guacamole/engine/patterns/habit_consistency.dart'
    show HabitConsistency, HabitPeriodState;
export 'package:fantastic_guacamole/engine/patterns/patterns_engine.dart'
    show
        CompletionTrend,
        HabitPattern,
        HabitPeriodMiss,
        MissedItems,
        PartOfDay,
        PatternEvidence,
        PatternEvidenceReason,
        PatternMetric,
        PatternsResult,
        TrendBucket,
        UnplacedWork,
        WhenThingsGetDone,
        WorkloadDay;
