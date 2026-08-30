import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/domain_evidence_entry.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/state/services/domain_evidence_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('indexes every canonical Phase 4 domain without type collapse', () {
    final DateTime now = DateTime.utc(2026, 8, 30, 12);
    final List<DomainEvidenceEntry> entries = DomainEvidenceIndex.build(
      tasks: <TaskEntity>[
        TaskEntity(id: 'task-1', title: 'Ship brief', createdAt: now),
      ],
      goals: <GoalEntity>[
        GoalEntity(id: 'goal-1', title: 'Launch', createdAt: now),
      ],
      habits: <HabitEntity>[
        HabitEntity(id: 'habit-1', title: 'Reset', createdAt: now),
      ],
      notes: <NoteEntity>[
        NoteEntity(
          id: 'note-1',
          title: 'What helped',
          createdAt: now,
          kind: NoteKind.reflection,
          habitId: 'habit-1',
          occurrenceId: 'habit-1::2026-08-30',
          outcomeId: 'decision-1::completed::nexus',
        ),
      ],
      taskOccurrences: <TaskOccurrence>[
        TaskOccurrence(
          taskId: 'task-1',
          seriesId: 'task-1',
          occurrenceKey: '2026-08-30',
          initialScheduledFor: now,
        ),
      ],
      habitOccurrences: <HabitOccurrenceEntity>[
        HabitOccurrenceEntity(
          habitId: 'habit-1',
          occurrenceKey: '2026-08-30',
          operationId: 'op-1',
          outcome: HabitOccurrenceOutcome.completed,
          recordedAt: now,
        ),
      ],
      outcomes: <DecisionOutcomeEntity>[
        DecisionOutcomeEntity(
          decisionId: 'decision-1',
          kind: DecisionOutcomeKind.completed,
          surface: 'nexus',
          recordedAt: now,
          modelVersion: 'v1',
          recommendationConfidence: 0.8,
          subjectId: 'task-1',
        ),
      ],
    );

    expect(
      entries.map((DomainEvidenceEntry value) => value.kind).toSet(),
      containsAll(<DomainEvidenceKind>{
        DomainEvidenceKind.goal,
        DomainEvidenceKind.task,
        DomainEvidenceKind.dailyRhythm,
        DomainEvidenceKind.reflection,
        DomainEvidenceKind.taskOccurrence,
        DomainEvidenceKind.dailyRhythmOccurrence,
        DomainEvidenceKind.outcome,
      }),
    );
    expect(
      DomainEvidenceIndex.search(entries, 'what helped').single.kind,
      DomainEvidenceKind.reflection,
    );
    final DomainEvidenceEntry reflection = entries.singleWhere(
      (DomainEvidenceEntry value) =>
          value.kind == DomainEvidenceKind.reflection,
    );
    expect(reflection.relatedIds, contains('habit-1::2026-08-30'));
    expect(reflection.relatedIds, contains('decision-1::completed::nexus'));
    expect(DomainEvidenceIndex.search(entries, '', limit: 2), hasLength(2));
  });
}
