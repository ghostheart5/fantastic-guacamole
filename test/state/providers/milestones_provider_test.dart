import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_milestone_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'milestone projections remain evidence-backed and consistently ordered',
    () async {
      final DateTime now = DateTime.now();
      final List<MilestoneEntity> milestones = <MilestoneEntity>[
        _milestone(
          id: 'completed',
          title: 'Completed foundation',
          description: 'Verified release foundation',
          status: MilestoneStatus.completed,
          category: MilestoneCategory.project,
          completionPercent: 100,
          createdAt: now.subtract(const Duration(days: 20)),
          targetDate: now.subtract(const Duration(days: 2)),
        ),
        _milestone(
          id: 'overdue',
          title: 'Repair coverage',
          note: 'Priority seven gate',
          goalId: 'release-goal',
          priority: MilestonePriority.critical,
          createdAt: now.subtract(const Duration(days: 20)),
          targetDate: now.subtract(const Duration(days: 3)),
          completionPercent: 30,
        ),
        _milestone(
          id: 'upcoming',
          title: 'Run target guard',
          reflection: 'Protect exact candidate evidence',
          category: MilestoneCategory.timeline,
          priority: MilestonePriority.high,
          createdAt: now.subtract(const Duration(days: 5)),
          targetDate: now.add(const Duration(days: 2)),
          completionPercent: 80,
        ),
        _milestone(
          id: 'unlinked',
          title: 'Prepare closed test',
          goalId: 'missing-goal',
          createdAt: now.subtract(const Duration(days: 2)),
          targetDate: now.add(const Duration(days: 10)),
        ),
        _milestone(
          id: 'behind',
          title: 'Finish state coverage',
          createdAt: now.subtract(const Duration(days: 10)),
          targetDate: now.add(const Duration(days: 10)),
          completionPercent: 10,
        ),
      ];
      final ProviderContainer container = ProviderContainer(
        overrides: [
          milestonesProvider.overrideWith(() => _StaticMilestones(milestones)),
          tasksProvider.overrideWith((Ref ref) async {
            return <Task>[
              Task(
                id: 'task-1',
                title: 'Coverage work',
                priority: 5,
                difficulty: 4,
                energyRequired: 4,
                goalId: 'release-goal',
              ),
            ];
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(milestonesProvider.future);
      await container.read(tasksProvider.future);

      expect(container.read(milestoneSearchProvider('  ')), milestones);
      expect(
        container.read(milestoneSearchProvider('verified')).single.id,
        'completed',
      );
      expect(
        container.read(milestoneSearchProvider('priority seven')).single.id,
        'overdue',
      );
      expect(
        container.read(milestoneSearchProvider('exact candidate')).single.id,
        'upcoming',
      );
      expect(container.read(milestoneSearchProvider('absent')), isEmpty);

      final grouped = container.read(milestonesByCategoryProvider);
      expect(grouped.keys, containsAll(MilestoneCategory.values));
      expect(grouped[MilestoneCategory.project]?.single.id, 'completed');
      expect(grouped[MilestoneCategory.timeline]?.single.id, 'upcoming');
      expect(container.read(milestoneCompletedProvider).single.id, 'completed');
      final List<MilestoneEntity> upcoming = container.read(
        milestoneUpcomingProvider,
      );
      expect(upcoming.first.id, 'upcoming');
      expect(
        upcoming.map((MilestoneEntity item) => item.id),
        containsAll(<String>['upcoming', 'unlinked', 'behind']),
      );
      expect(container.read(milestoneOverdueProvider).single.id, 'overdue');

      final List<MilestoneRisk> risks = container.read(milestoneRisksProvider);
      expect(risks.first.milestone.id, 'overdue');
      expect(risks.first.daysBehind, greaterThanOrEqualTo(2));
      expect(
        risks.map((MilestoneRisk risk) => risk.reason),
        containsAll(<String>[
          'Milestone overdue.',
          'Milestone has no linked active tasks.',
          'Milestone is behind expected pace.',
        ]),
      );
      expect(
        risks.map((MilestoneRisk risk) => risk.riskWeight).toList(),
        orderedEquals(
          risks.map((MilestoneRisk risk) => risk.riskWeight).toList()
            ..sort((int a, int b) => b.compareTo(a)),
        ),
      );

      final List<MilestoneForecast> forecasts = container.read(
        milestoneForecastsProvider,
      );
      expect(forecasts, hasLength(4));
      expect(
        forecasts.map((MilestoneForecast item) => item.milestone.id),
        isNot(contains('completed')),
      );
      for (final MilestoneForecast forecast in forecasts) {
        expect(forecast.delayDays, greaterThanOrEqualTo(0));
        expect(forecast.successRate, inInclusiveRange(0, 100));
        expect(forecast.confidence, inInclusiveRange(35, 95));
      }

      final MilestoneSummary summary = container.read(milestoneSummaryProvider);
      expect(summary.total, 5);
      expect(summary.completed, 1);
      expect(summary.active, 4);
      expect(summary.overdue, 1);
      expect(summary.upcoming, 3);
      expect(summary.nextMilestone?.id, 'upcoming');
      expect(summary.closestMilestone?.id, 'overdue');
      expect(summary.highestPriority?.id, 'overdue');
      expect(summary.healthScore, inInclusiveRange(0, 100));
      expect(summary.momentumScore, inInclusiveRange(0, 100));
      expect(summary.riskScore, 100 - summary.healthScore);
    },
  );

  test('empty and loading milestone projections fail closed', () async {
    final ProviderContainer empty = ProviderContainer(
      overrides: [
        milestonesProvider.overrideWith(
          () => _StaticMilestones(const <MilestoneEntity>[]),
        ),
        tasksProvider.overrideWith((Ref ref) async => const <Task>[]),
      ],
    );
    addTearDown(empty.dispose);
    await empty.read(milestonesProvider.future);
    final MilestoneSummary summary = empty.read(milestoneSummaryProvider);
    expect(summary.total, 0);
    expect(summary.completionRate, 0);
    expect(summary.nextMilestone, isNull);
    expect(summary.closestMilestone, isNull);
    expect(summary.highestPriority, isNull);
    expect(empty.read(milestoneRisksProvider), isEmpty);
    expect(empty.read(milestoneForecastsProvider), isEmpty);

    final ProviderContainer loading = ProviderContainer(
      overrides: [milestonesProvider.overrideWith(_LoadingMilestones.new)],
    );
    addTearDown(loading.dispose);
    expect(loading.read(milestoneSearchProvider('anything')), isEmpty);
    expect(loading.read(milestoneCompletedProvider), isEmpty);
    expect(loading.read(milestoneSummaryProvider).total, 0);
  });

  test(
    'milestone actions persist lifecycle changes and mirror evidence',
    () async {
      final DateTime now = DateTime.now();
      final _FakeMilestoneRepository milestones =
          _FakeMilestoneRepository(<MilestoneEntity>[
            _milestone(
              id: 'existing',
              title: 'Existing milestone',
              createdAt: now.subtract(const Duration(days: 1)),
              targetDate: now.add(const Duration(days: 4)),
            ),
          ]);
      final _FakeTimelineRepository timeline = _FakeTimelineRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          domainMilestoneRepositoryProvider.overrideWithValue(milestones),
          domainTimelineRepositoryProvider.overrideWithValue(timeline),
          domainTaskRepositoryProvider.overrideWithValue(
            _EmptyTaskRepository(),
          ),
          domainSiRepositoryProvider.overrideWithValue(_EmptySiRepository()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(milestonesProvider.future);

      final MilestoneActions actions = container.read(milestoneActionsProvider);
      await actions.createMilestone(
        title: '  Priority seven complete  ',
        description: '  Verified gate  ',
        category: MilestoneCategory.project,
        priority: MilestonePriority.critical,
        targetDate: now.add(const Duration(days: 2)),
        dependencies: const <String>['coverage', 'analysis'],
      );
      final MilestoneEntity created = container
          .read(milestonesProvider)
          .requireValue
          .first;
      expect(created.title, 'Priority seven complete');
      expect(created.description, 'Verified gate');
      expect(created.dependencies, const <String>['coverage', 'analysis']);
      expect(timeline.events.last.title, 'Milestone Created');

      await container.read(milestonesProvider.notifier).create(title: '   ');
      expect(container.read(milestonesProvider).requireValue, hasLength(2));

      await container
          .read(milestonesProvider.notifier)
          .updateMilestone(created.copyWith(note: 'Audited'));
      expect(
        container
            .read(milestonesProvider)
            .requireValue
            .singleWhere((MilestoneEntity item) => item.id == created.id)
            .note,
        'Audited',
      );
      await container
          .read(milestonesProvider.notifier)
          .updateMilestone(
            _milestone(
              id: 'missing',
              title: 'Missing',
              createdAt: now,
              targetDate: now.add(const Duration(days: 1)),
            ),
          );

      await actions.updateProgress(created.id, 55);
      expect(
        container
            .read(milestonesProvider)
            .requireValue
            .singleWhere((MilestoneEntity item) => item.id == created.id)
            .completionPercent,
        55,
      );
      await actions.updateProgress(created.id, 1000);
      expect(timeline.events.last.title, 'Milestone Achieved');
      await actions.updateProgress('missing', 50);

      await actions.complete('existing', reflection: '  Evidence accepted  ');
      final MilestoneEntity completed = container
          .read(milestonesProvider)
          .requireValue
          .singleWhere((MilestoneEntity item) => item.id == 'existing');
      expect(completed.isCompleted, isTrue);
      expect(completed.reflection, 'Evidence accepted');
      await actions.complete('missing');

      await actions.archive(created.id);
      expect(
        container
            .read(milestonesProvider)
            .requireValue
            .singleWhere((MilestoneEntity item) => item.id == created.id)
            .isArchived,
        isTrue,
      );
      await actions.archive('missing');

      await actions.remove(created.id);
      expect(
        container
            .read(milestonesProvider)
            .requireValue
            .map((MilestoneEntity item) => item.id),
        isNot(contains(created.id)),
      );
      await actions.remove('missing');
      expect(milestones.saveCalls, greaterThanOrEqualTo(6));
      expect(
        timeline.events.where(
          (TimelineEventEntity event) => event.relatedId == created.id,
        ),
        hasLength(2),
      );
    },
  );
}

MilestoneEntity _milestone({
  required String id,
  required String title,
  String? description,
  String? note,
  String? reflection,
  String? goalId,
  MilestoneStatus status = MilestoneStatus.inProgress,
  MilestoneCategory category = MilestoneCategory.goal,
  MilestonePriority priority = MilestonePriority.medium,
  double completionPercent = 0,
  required DateTime createdAt,
  required DateTime targetDate,
}) {
  return MilestoneEntity(
    id: id,
    title: title,
    description: description,
    note: note,
    reflection: reflection,
    goalId: goalId,
    status: status,
    category: category,
    priority: priority,
    completionPercent: completionPercent,
    createdAt: createdAt,
    updatedAt: createdAt,
    targetDate: targetDate,
  );
}

final class _StaticMilestones extends MilestonesNotifier {
  _StaticMilestones(this._milestones);

  final List<MilestoneEntity> _milestones;

  @override
  Future<List<MilestoneEntity>> build() async => _milestones;
}

final class _LoadingMilestones extends MilestonesNotifier {
  @override
  Future<List<MilestoneEntity>> build() =>
      Completer<List<MilestoneEntity>>().future;
}

final class _FakeMilestoneRepository implements IMilestoneRepository {
  _FakeMilestoneRepository(List<MilestoneEntity> milestones)
    : _milestones = List<MilestoneEntity>.from(milestones);

  List<MilestoneEntity> _milestones;
  int saveCalls = 0;

  @override
  Future<List<MilestoneEntity>> getMilestones() async =>
      List<MilestoneEntity>.unmodifiable(_milestones);

  @override
  Future<void> saveMilestones(List<MilestoneEntity> milestones) async {
    saveCalls += 1;
    _milestones = List<MilestoneEntity>.from(milestones);
  }
}

final class _FakeTimelineRepository implements ITimelineRepository {
  final List<TimelineEventEntity> events = <TimelineEventEntity>[];

  @override
  bool get lastReadCorrupted => false;

  @override
  Future<void> addEvent(TimelineEventEntity event) async => events.add(event);

  @override
  List<TimelineEventEntity> getEvents() =>
      List<TimelineEventEntity>.unmodifiable(events);

  @override
  Future<void> removeEvent(String id) async =>
      events.removeWhere((TimelineEventEntity event) => event.id == id);

  @override
  Future<void> saveEvents(List<TimelineEventEntity> events) async {
    this.events
      ..clear()
      ..addAll(events);
  }
}

final class _EmptyTaskRepository implements ITaskRepository {
  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async => const <TaskEntity>[];

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;

  @override
  Future<void> saveTask(TaskEntity task) async {}
}

final class _EmptySiRepository implements ISiRepository {
  @override
  Future<SiStateEntity?> getCurrentState() async => null;

  @override
  Future<void> saveState(SiStateEntity state) async {}
}
