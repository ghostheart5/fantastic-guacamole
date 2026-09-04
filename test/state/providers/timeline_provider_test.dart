import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'timeline projections derive risk and health from recorded evidence',
    () {
      final DateTime now = DateTime.now();
      final List<TimelineEventEntity> events = <TimelineEventEntity>[
        _event(
          id: 'overdue',
          type: TimelineEventType.deadline,
          status: TimelineEventStatus.overdue,
          timestamp: now.subtract(const Duration(days: 2)),
        ),
        _event(
          id: 'risk',
          type: TimelineEventType.risk,
          status: TimelineEventStatus.atRisk,
          timestamp: now,
        ),
        _event(
          id: 'recommendation',
          type: TimelineEventType.recommendation,
          timestamp: now,
        ),
        _event(
          id: 'upcoming',
          type: TimelineEventType.deadline,
          status: TimelineEventStatus.active,
          timestamp: now,
          dueAt: now.add(const Duration(days: 2)),
        ),
        _event(
          id: 'milestone',
          type: TimelineEventType.goalComplete,
          status: TimelineEventStatus.completed,
          timestamp: now,
        ),
      ];
      final ProviderContainer container = ProviderContainer(
        overrides: [
          timelineProvider.overrideWith(() => _StaticTimeline(events)),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(timelineActionsProvider), isA<TimelineActions>());
      expect(container.read(timelineOverdueProvider).single.id, 'overdue');
      expect(container.read(timelineUpcomingProvider).single.id, 'upcoming');
      expect(container.read(timelineRiskEventsProvider).single.id, 'risk');
      expect(
        container.read(timelineRecommendationsProvider).single.id,
        'recommendation',
      );
      expect(container.read(timelineHealthScoreProvider), 81);
      expect(container.read(timelineRiskScoreProvider), 19);
    },
  );

  test('timeline health clamps at both safety bounds', () {
    final DateTime now = DateTime.now();
    final ProviderContainer empty = ProviderContainer(
      overrides: [
        timelineProvider.overrideWith(
          () => _StaticTimeline(const <TimelineEventEntity>[]),
        ),
      ],
    );
    addTearDown(empty.dispose);
    expect(empty.read(timelineHealthScoreProvider), 100);
    expect(empty.read(timelineRiskScoreProvider), 0);

    final ProviderContainer overloaded = ProviderContainer(
      overrides: [
        timelineProvider.overrideWith(
          () => _StaticTimeline(<TimelineEventEntity>[
            for (int index = 0; index < 10; index += 1)
              _event(
                id: 'overdue-$index',
                type: TimelineEventType.risk,
                status: TimelineEventStatus.overdue,
                timestamp: now,
              ),
          ]),
        ),
      ],
    );
    addTearDown(overloaded.dispose);
    expect(overloaded.read(timelineHealthScoreProvider), 0);
    expect(overloaded.read(timelineRiskScoreProvider), 100);
  });

  test(
    'timeline actions persist every lifecycle mutation and refresh state',
    () async {
      final DateTime now = DateTime.utc(2026, 9, 3, 12);
      final _FakeTimelineRepository repository =
          _FakeTimelineRepository(<TimelineEventEntity>[
            _event(
              id: 'existing',
              type: TimelineEventType.task,
              status: TimelineEventStatus.active,
              timestamp: now,
              dueAt: now.add(const Duration(days: 1)),
            ),
          ]);
      final ProviderContainer container = ProviderContainer(
        overrides: [
          domainTimelineRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final TimelineActions actions = container.read(timelineActionsProvider);
      expect(container.read(timelineProvider), hasLength(1));
      expect(container.read(timelinePersistenceCorruptedProvider), isFalse);
      expect(
        actions
            .eventsInRange(
              start: now.subtract(const Duration(hours: 1)),
              end: now.add(const Duration(days: 2)),
            )
            .single
            .id,
        'existing',
      );

      final TimelineEventEntity mirrored = _event(
        id: 'mirrored',
        type: TimelineEventType.recommendation,
        timestamp: now.add(const Duration(minutes: 1)),
      );
      await actions.addMirroredEvent(mirrored);
      expect(container.read(timelineProvider).first.id, 'mirrored');

      final TimelineEventEntity scheduled = _event(
        id: 'scheduled',
        type: TimelineEventType.deadline,
        timestamp: now.add(const Duration(minutes: 2)),
        dueAt: now.add(const Duration(days: 3)),
      );
      await actions.schedule(scheduled);
      expect(
        container.read(timelineProvider).first.status,
        TimelineEventStatus.planned,
      );

      final DateTime postponed = now.add(const Duration(days: 5));
      await actions.reschedule('scheduled', postponed);
      TimelineEventEntity current = container
          .read(timelineProvider)
          .singleWhere((TimelineEventEntity item) => item.id == 'scheduled');
      expect(current.dueAt, postponed);
      expect(current.phase, 'rescheduled');
      expect(current.userOverride, isTrue);

      await actions.complete('existing');
      current = container
          .read(timelineProvider)
          .singleWhere((TimelineEventEntity item) => item.id == 'existing');
      expect(current.status, TimelineEventStatus.completed);

      await actions.skip('mirrored');
      current = container
          .read(timelineProvider)
          .singleWhere((TimelineEventEntity item) => item.id == 'mirrored');
      expect(current.status, TimelineEventStatus.skipped);

      final DateTime recoveredDueAt = now.add(const Duration(days: 2));
      await actions.recover('mirrored', recoveredDueAt);
      current = container
          .read(timelineProvider)
          .singleWhere((TimelineEventEntity item) => item.id == 'mirrored');
      expect(current.status, TimelineEventStatus.planned);
      expect(current.phase, 'recovered');
      expect(current.dueAt, recoveredDueAt);

      await container.read(timelineProvider.notifier).remove('existing');
      expect(
        container
            .read(timelineProvider)
            .map((TimelineEventEntity item) => item.id),
        isNot(contains('existing')),
      );

      repository.lastReadCorrupted = true;
      container.invalidate(timelinePersistenceCorruptedProvider);
      expect(container.read(timelinePersistenceCorruptedProvider), isTrue);
      await container
          .read(timelineProvider.notifier)
          .preserveAndRepairCorruptedStorage();
      expect(repository.saveCalls, 5);

      final List<TimelineEventEntity> beforeMissing = container.read(
        timelineProvider,
      );
      await actions.reschedule('missing', postponed);
      await actions.complete('missing');
      await actions.skip('missing');
      await actions.recover('missing', recoveredDueAt);
      expect(container.read(timelineProvider), beforeMissing);
    },
  );

  test('timeline retains only the newest five hundred events', () async {
    final DateTime now = DateTime.utc(2026, 9, 3, 12);
    final _FakeTimelineRepository repository =
        _FakeTimelineRepository(<TimelineEventEntity>[
          for (int index = 0; index < 500; index += 1)
            _event(
              id: 'seed-$index',
              type: TimelineEventType.task,
              timestamp: now.subtract(Duration(minutes: index)),
            ),
        ]);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        domainTimelineRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(timelineActionsProvider)
        .addMirroredEvent(
          _event(id: 'newest', type: TimelineEventType.task, timestamp: now),
        );

    final List<TimelineEventEntity> state = container.read(timelineProvider);
    expect(state, hasLength(500));
    expect(state.first.id, 'newest');
    expect(
      state.map((TimelineEventEntity item) => item.id),
      isNot(contains('seed-499')),
    );
  });
}

TimelineEventEntity _event({
  required String id,
  required TimelineEventType type,
  TimelineEventStatus status = TimelineEventStatus.info,
  required DateTime timestamp,
  DateTime? dueAt,
}) {
  return TimelineEventEntity(
    id: id,
    type: type,
    title: id,
    detail: 'Evidence for $id',
    timestamp: timestamp,
    status: status,
    dueAt: dueAt,
  );
}

final class _StaticTimeline extends TimelineNotifier {
  _StaticTimeline(this._value);

  final List<TimelineEventEntity> _value;

  @override
  List<TimelineEventEntity> build() => _value;
}

final class _FakeTimelineRepository implements ITimelineRepository {
  _FakeTimelineRepository(List<TimelineEventEntity> events)
    : _events = List<TimelineEventEntity>.from(events);

  List<TimelineEventEntity> _events;
  int saveCalls = 0;

  @override
  bool lastReadCorrupted = false;

  @override
  Future<void> addEvent(TimelineEventEntity event) async {
    _events = <TimelineEventEntity>[event, ..._events];
  }

  @override
  List<TimelineEventEntity> getEvents() =>
      List<TimelineEventEntity>.unmodifiable(_events);

  @override
  Future<void> removeEvent(String id) async {
    _events = _events
        .where((TimelineEventEntity event) => event.id != id)
        .toList(growable: false);
  }

  @override
  Future<void> saveEvents(List<TimelineEventEntity> events) async {
    saveCalls += 1;
    _events = List<TimelineEventEntity>.from(events);
  }
}
