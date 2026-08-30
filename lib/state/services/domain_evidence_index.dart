import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/domain_evidence_entry.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';

/// Builds a read-only, rebuildable index from canonical repositories.
abstract final class DomainEvidenceIndex {
  static List<DomainEvidenceEntry> build({
    required List<TaskEntity> tasks,
    required List<GoalEntity> goals,
    required List<HabitEntity> habits,
    required List<NoteEntity> notes,
    required List<TaskOccurrence> taskOccurrences,
    required List<HabitOccurrenceEntity> habitOccurrences,
    required List<DecisionOutcomeEntity> outcomes,
  }) {
    final Map<String, String> subjectTitles = <String, String>{
      for (final TaskEntity task in tasks) task.id: task.title,
      for (final GoalEntity goal in goals) goal.id: goal.title,
      for (final HabitEntity habit in habits) habit.id: habit.title,
    };
    final List<DomainEvidenceEntry> entries = <DomainEvidenceEntry>[
      ...goals.map(
        (GoalEntity goal) => DomainEvidenceEntry(
          kind: DomainEvidenceKind.goal,
          id: goal.id,
          title: goal.title,
          detail: goal.description,
          recordedAt: goal.createdAt.toUtc(),
        ),
      ),
      ...tasks.map(
        (TaskEntity task) => DomainEvidenceEntry(
          kind: DomainEvidenceKind.task,
          id: task.id,
          title: task.title,
          detail: task.description,
          recordedAt: task.createdAt.toUtc(),
          relatedIds: <String>[
            if (task.goalId?.trim().isNotEmpty ?? false) task.goalId!,
          ],
        ),
      ),
      ...habits.map(
        (HabitEntity habit) => DomainEvidenceEntry(
          kind: DomainEvidenceKind.dailyRhythm,
          id: habit.id,
          title: habit.title,
          detail: habit.description,
          recordedAt: habit.createdAt.toUtc(),
          relatedIds: habit.stepTaskIds,
        ),
      ),
      ...notes.map(
        (NoteEntity note) => DomainEvidenceEntry(
          kind: note.kind == NoteKind.reflection
              ? DomainEvidenceKind.reflection
              : DomainEvidenceKind.note,
          id: note.id,
          title: note.title,
          detail: note.body,
          recordedAt: note.updatedAt.toUtc(),
          relatedIds: <String>[
            if (note.goalId?.trim().isNotEmpty ?? false) note.goalId!,
            if (note.taskId?.trim().isNotEmpty ?? false) note.taskId!,
            if (note.habitId?.trim().isNotEmpty ?? false) note.habitId!,
            if (note.occurrenceId?.trim().isNotEmpty ?? false)
              note.occurrenceId!,
            if (note.outcomeId?.trim().isNotEmpty ?? false) note.outcomeId!,
          ],
        ),
      ),
      ...taskOccurrences.map((TaskOccurrence occurrence) {
        final String title =
            subjectTitles[occurrence.taskId] ?? 'Task occurrence';
        return DomainEvidenceEntry(
          kind: DomainEvidenceKind.taskOccurrence,
          id: occurrence.id,
          title: title,
          detail: occurrence.terminalOutcome?.name ?? 'open',
          recordedAt:
              (occurrence.transitions.isEmpty
                  ? null
                  : occurrence.transitions.last.at.toUtc()) ??
              occurrence.initialScheduledFor?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          relatedIds: <String>[occurrence.taskId, occurrence.seriesId],
        );
      }),
      ...habitOccurrences.map(
        (HabitOccurrenceEntity occurrence) => DomainEvidenceEntry(
          kind: DomainEvidenceKind.dailyRhythmOccurrence,
          id: occurrence.id,
          title: subjectTitles[occurrence.habitId] ?? 'Daily Rhythm occurrence',
          detail: occurrence.outcome.name,
          recordedAt: occurrence.recordedAt.toUtc(),
          relatedIds: <String>[occurrence.habitId],
        ),
      ),
      ...outcomes.map(
        (DecisionOutcomeEntity outcome) => DomainEvidenceEntry(
          kind: DomainEvidenceKind.outcome,
          id: outcome.id,
          title: outcome.subjectId == null
              ? outcome.kind.name
              : subjectTitles[outcome.subjectId] ?? outcome.kind.name,
          detail: outcome.detail,
          recordedAt: outcome.recordedAt.toUtc(),
          relatedIds: <String>[
            outcome.decisionId,
            if (outcome.subjectId?.trim().isNotEmpty ?? false)
              outcome.subjectId!,
          ],
        ),
      ),
    ];
    entries.sort(
      (DomainEvidenceEntry left, DomainEvidenceEntry right) =>
          right.recordedAt.compareTo(left.recordedAt),
    );
    return List<DomainEvidenceEntry>.unmodifiable(entries);
  }

  static List<DomainEvidenceEntry> search(
    List<DomainEvidenceEntry> entries,
    String query, {
    int limit = 50,
  }) {
    final String normalized = query.trim().toLowerCase();
    if (limit <= 0) return const <DomainEvidenceEntry>[];
    return entries
        .where((DomainEvidenceEntry entry) => entry.matches(normalized))
        .take(limit)
        .toList(growable: false);
  }
}
