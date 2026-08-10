import 'dart:convert';

import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/filter_goals_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/core/sort_goals_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/portability/export_goals_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/misc/export_timeline_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reporting Builder', () {
    test('report generation returns serialized goal and timeline output', () {
      final _FakeGoalRepository goalRepo = _FakeGoalRepository(<GoalEntity>[
        GoalEntity(
          id: 'g-1',
          title: 'Launch',
          createdAt: DateTime(2026, 1, 2),
          targetDate: DateTime(2026, 1, 20),
        ),
      ]);
      final _FakeTimelineRepository timelineRepo =
          _FakeTimelineRepository(<TimelineEventEntity>[
            TimelineEventEntity(
              id: 'e-1',
              type: TimelineEventType.recommendation,
              title: 'Focus Window',
              detail: 'Ship one high-impact task',
              timestamp: DateTime(2026, 1, 2, 12),
            ),
          ]);

      final String goalsReport = ExportGoalsUsecase(goalRepo).call();
      final String timelineReport = ExportTimelineUsecase(timelineRepo).call();

      final List<dynamic> goalsDecoded =
          jsonDecode(goalsReport) as List<dynamic>;
      final List<dynamic> timelineDecoded =
          jsonDecode(timelineReport) as List<dynamic>;

      expect(goalsDecoded, hasLength(1));
      expect((goalsDecoded.first as Map<String, dynamic>)['id'], 'g-1');
      expect(timelineDecoded, hasLength(1));
      expect((timelineDecoded.first as Map<String, dynamic>)['id'], 'e-1');
    });

    test('filtering supports target-date and overdue views', () {
      final DateTime now = DateTime.now();
      final _FakeGoalRepository repo = _FakeGoalRepository(<GoalEntity>[
        GoalEntity(
          id: 'g-overdue',
          title: 'Overdue Goal',
          createdAt: now.subtract(const Duration(days: 2)),
          targetDate: now.subtract(const Duration(days: 1)),
        ),
        GoalEntity(
          id: 'g-upcoming',
          title: 'Upcoming Goal',
          createdAt: now.subtract(const Duration(days: 2)),
          targetDate: now.add(const Duration(days: 2)),
        ),
        GoalEntity(
          id: 'g-no-date',
          title: 'No Date Goal',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ]);

      final FilterGoalsUsecase usecase = FilterGoalsUsecase(repo);

      final List<GoalEntity> overdue = usecase.call(overdueOnly: true);
      final List<GoalEntity> withTargetDate = usecase.call(
        withTargetDateOnly: true,
      );

      expect(overdue.map((g) => g.id).toList(), <String>['g-overdue']);
      expect(withTargetDate.map((g) => g.id).toSet(), <String>{
        'g-overdue',
        'g-upcoming',
      });
    });

    test('sorting returns expected title and target-date order', () {
      final DateTime now = DateTime.now();
      final _FakeGoalRepository repo = _FakeGoalRepository(<GoalEntity>[
        GoalEntity(
          id: 'g-b',
          title: 'Beta',
          createdAt: now.subtract(const Duration(days: 3)),
          targetDate: now.add(const Duration(days: 4)),
        ),
        GoalEntity(
          id: 'g-a',
          title: 'Alpha',
          createdAt: now.subtract(const Duration(days: 2)),
          targetDate: now.add(const Duration(days: 1)),
        ),
        GoalEntity(
          id: 'g-z',
          title: 'Zulu',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ]);

      final SortGoalsUsecase usecase = SortGoalsUsecase(repo);

      final List<GoalEntity> titleAsc = usecase.call(
        mode: GoalSortMode.titleAsc,
      );
      final List<GoalEntity> bySoonest = usecase.call(
        mode: GoalSortMode.targetDateSoonest,
      );

      expect(titleAsc.map((g) => g.id).toList(), <String>['g-a', 'g-b', 'g-z']);
      expect(bySoonest.map((g) => g.id).toList(), <String>[
        'g-a',
        'g-b',
        'g-z',
      ]);
    });

    test(
      'export formats differ for pretty goals JSON vs compact timeline JSON',
      () {
        final _FakeGoalRepository goalRepo = _FakeGoalRepository(<GoalEntity>[
          GoalEntity(
            id: 'g-1',
            title: 'Readable Export',
            createdAt: DateTime(2026, 1, 1),
          ),
        ]);
        final _FakeTimelineRepository timelineRepo =
            _FakeTimelineRepository(<TimelineEventEntity>[
              TimelineEventEntity(
                id: 't-1',
                type: TimelineEventType.task,
                title: 'Compact Export',
                detail: 'single line json',
                timestamp: DateTime(2026, 1, 1),
              ),
            ]);

        final String goalsReport = ExportGoalsUsecase(goalRepo).call();
        final String timelineReport = ExportTimelineUsecase(
          timelineRepo,
        ).call();

        expect(goalsReport.contains('\n  {'), isTrue);
        expect(timelineReport.contains('\n'), isFalse);
        expect(() => jsonDecode(goalsReport), returnsNormally);
        expect(() => jsonDecode(timelineReport), returnsNormally);
      },
    );
  });
}

class _FakeGoalRepository implements IGoalRepository {
  _FakeGoalRepository(this._goals);

  final List<GoalEntity> _goals;

  @override
  List<GoalEntity> getGoals() => _goals;

  @override
  Future<void> deleteGoal(String id) async {}

  @override
  Future<void> saveGoal(GoalEntity goal) async {}

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {}
}

class _FakeTimelineRepository implements ITimelineRepository {
  _FakeTimelineRepository(this._events);

  final List<TimelineEventEntity> _events;

  @override
  Future<void> addEvent(TimelineEventEntity event) async {}

  @override
  List<TimelineEventEntity> getEvents() => _events;

  @override
  Future<void> removeEvent(String id) async {}

  @override
  Future<void> saveEvents(List<TimelineEventEntity> events) async {}
}
