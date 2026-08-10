import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/project_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/work_window_entity.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('model and entity roundtrip', () {
    test('Task toJson and fromJson keep key fields and nullable values', () {
      final Task original = Task(
        id: 'task-1',
        title: 'Focus block',
        description: null,
        kind: 'deep-work',
        priority: 5,
        difficulty: 4,
        energyRequired: 3,
        scheduledFor: DateTime.utc(2026, 7, 28, 14, 30),
        goalId: null,
        subtasks: const <String>['sub-1', 'sub-2'],
        recurrenceRule: RecurrenceRule.weekly,
      );

      final Map<String, dynamic> json = original.toJson();
      final Task restored = Task.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.description, isNull);
      expect(restored.kind, original.kind);
      expect(restored.priority, original.priority);
      expect(restored.recurrenceRule, RecurrenceRule.weekly);
      expect(restored.scheduledFor, DateTime.utc(2026, 7, 28, 14, 30));
      expect(
        restored.subtasks,
        orderedEquals(const <String>['sub-1', 'sub-2']),
      );
    });

    test('Task.fromJson handles missing values with fallbacks', () {
      final Task restored = Task.fromJson(<String, dynamic>{
        'id': 'task-2',
        'title': 'Fallback task',
        'scheduledFor': 'not-a-date',
        'recurrenceRule': 'unexpected',
      });

      expect(restored.priority, 3);
      expect(restored.difficulty, 3);
      expect(restored.energyRequired, 3);
      expect(restored.scheduledFor, isNull);
      expect(restored.recurrenceRule, RecurrenceRule.none);
      expect(restored.subtasks, isEmpty);
    });

    test('Task.fromJson throws on malformed numeric/list payloads', () {
      expect(
        () => Task.fromJson(<String, dynamic>{
          'id': 'task-3',
          'title': 'Malformed task',
          'priority': 'bad-number',
          'subtasks': <dynamic>['ok', 9],
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test('GoalEntity roundtrip keeps DateTime and nullable fields', () {
      final GoalEntity original = GoalEntity(
        id: 'goal-1',
        title: 'Ship V1',
        createdAt: DateTime.utc(2026, 7, 1),
        description: 'Launch planning',
        targetDate: DateTime.utc(2026, 8, 1),
        colorHex: 0xFF123456,
      );

      final GoalEntity restored = GoalEntity.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.createdAt, original.createdAt);
      expect(restored.description, original.description);
      expect(restored.targetDate, original.targetDate);
      expect(restored.colorHex, original.colorHex);

      final GoalEntity copied = original.copyWith(title: 'Ship V2');
      expect(copied.title, 'Ship V2');
      expect(copied.description, original.description);
      expect(copied.targetDate, original.targetDate);
    });

    test(
      'ProjectEntity fromJson falls back for malformed status and dates',
      () {
        final ProjectEntity restored = ProjectEntity.fromJson(<String, dynamic>{
          'id': 'p-1',
          'name': 'Momentum',
          'createdAt': 'bad-date',
          'updatedAt': 'also-bad',
          'status': 'not-a-status',
          'archived': true,
        });

        expect(restored.name, 'Momentum');
        expect(restored.status, ProjectStatus.archived);
        expect(restored.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));

        final ProjectEntity copied = restored.copyWith(description: 'desc');
        expect(copied.description, 'desc');
        expect(copied.name, restored.name);
        expect(copied.id, restored.id);
      },
    );

    test('WorkWindowEntity roundtrip and range behavior stay stable', () {
      final WorkWindowEntity original = WorkWindowEntity(
        id: 'window-1',
        start: DateTime.utc(2026, 7, 28, 9),
        end: DateTime.utc(2026, 7, 28, 10, 30),
        label: 'Morning focus',
        preferredTaskIds: const <String>['a', 'b'],
        status: WorkWindowStatus.active,
      );

      final WorkWindowEntity restored = WorkWindowEntity.fromJson(
        original.toJson(),
      );
      expect(restored.id, original.id);
      expect(restored.duration, const Duration(minutes: 90));
      expect(restored.isValidRange, isTrue);
      expect(restored.status, WorkWindowStatus.active);
      expect(
        restored.preferredTaskIds,
        orderedEquals(const <String>['a', 'b']),
      );

      final WorkWindowEntity invalid = WorkWindowEntity.fromJson(
        <String, dynamic>{
          'id': 'window-2',
          'start': 'nope',
          'end': 'still-nope',
          'status': 'bad',
        },
      );
      expect(invalid.status, WorkWindowStatus.planned);
    });

    test(
      'TutorialProgress copyWith and equality/hashCode remain consistent',
      () {
        const TutorialProgress baseline = TutorialProgress(
          completedStepIds: <String>{'a'},
          dismissedStepIds: <String>{'b'},
          skippedForeverStepIds: <String>{'c'},
          started: true,
          hasSeenIntro: true,
          contentVersion: 6,
        );

        final TutorialProgress copy = baseline.copyWith();
        expect(copy, baseline);
        expect(copy.hashCode, baseline.hashCode);

        final TutorialProgress changed = baseline.copyWith(contentVersion: 7);
        expect(changed, isNot(baseline));
        expect(changed.contentVersion, 7);
        expect(changed.completedStepIds, baseline.completedStepIds);
      },
    );
  });
}
