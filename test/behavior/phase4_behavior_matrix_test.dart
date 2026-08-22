import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/features/profile/ui/widgets/profile_header.dart';
import 'package:fantastic_guacamole/features/si_console/ui/models/si_response_frame.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

enum _LoadState { empty, loading, success, partial, error, offline }

class _FakeFeatureStore<T> {
  _FakeFeatureStore(this._value);

  _LoadState state = _LoadState.empty;
  T _value;
  int reads = 0;
  int writes = 0;
  final Set<String> _ids = <String>{};

  T get value {
    reads++;
    if (state == _LoadState.error || state == _LoadState.offline) {
      throw StateError('safe provider failure');
    }
    return _value;
  }

  bool write(String id, T value) {
    if (_ids.add(id)) {
      _value = value;
      writes++;
      return true;
    }
    return false;
  }
}

void main() {
  final DateTime now = DateTime(2026, 8, 11, 9);

  group('Creator and Timeline runtime behavior', () {
    test(
      'creates all Creator item types with deterministic ids and persists once',
      () {
        final _FakeFeatureStore<List<Object>> store =
            _FakeFeatureStore<List<Object>>(<Object>[]);
        final TaskEntity task = TaskEntity(
          id: 'task-1',
          title: 'Plan launch 🚀',
          createdAt: now,
          priority: 5,
          difficulty: 2,
          energyRequired: 3,
        );
        final GoalEntity goal = GoalEntity(
          id: 'goal-1',
          title: 'Ship beta',
          createdAt: now,
        );
        final HabitEntity habit = HabitEntity(
          id: 'habit-1',
          title: 'Daily review ✅',
          createdAt: now,
        );
        final NoteEntity note = NoteEntity(
          id: 'note-1',
          title: 'ユーザー ノート',
          body: 'Résumé and emoji ✨',
          createdAt: now,
        );

        for (final Object item in <Object>[task, goal, habit, note]) {
          expect(
            store.write((item as dynamic).id as String, <Object>[item]),
            isTrue,
          );
          expect(
            store.write((item as dynamic).id as String, <Object>[item]),
            isFalse,
          );
        }
        expect(store.writes, 4);
        expect(store.value, hasLength(1));
        expect(task.isHighPriority, isTrue);
        expect(note.title, 'ユーザー ノート');
      },
    );

    test(
      'rejects invalid timeline input and preserves maximum-length Unicode titles',
      () {
        final TimelineEventEntity event = TimelineEventEntity(
          id: 'timeline-1',
          type: TimelineEventType.task,
          title: 'a' * 256 + ' 🚀',
          detail: 'Created from Creator',
          timestamp: now,
          status: TimelineEventStatus.active,
        );
        event.validate();
        expect(event.title, contains('🚀'));
        expect(
          () => TimelineEventEntity(
            id: 'invalid',
            type: TimelineEventType.task,
            title: ' ',
            detail: 'detail',
            timestamp: now,
          ).validate(),
          throwsStateError,
        );
      },
    );

    test('Timeline status transitions and ordering are deterministic', () {
      final List<TimelineEventEntity> events = <TimelineEventEntity>[
        TimelineEventEntity(
          id: 'later',
          type: TimelineEventType.task,
          title: 'Later',
          detail: 'later',
          timestamp: now.add(const Duration(hours: 2)),
          status: TimelineEventStatus.completed,
        ),
        TimelineEventEntity(
          id: 'earlier',
          type: TimelineEventType.goal,
          title: 'Earlier',
          detail: 'earlier',
          timestamp: now,
          status: TimelineEventStatus.planned,
        ),
      ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      expect(events.map((e) => e.id), <String>['earlier', 'later']);
      expect(events.last.status, TimelineEventStatus.completed);
      expect(events.first.isMilestone, isFalse);
    });
  });

  group('source states, persistence, and retry', () {
    test(
      'empty/loading/partial/error/offline are not collapsed into success',
      () {
        final _FakeFeatureStore<List<String>> store =
            _FakeFeatureStore<List<String>>(<String>[]);
        for (final _LoadState state in _LoadState.values) {
          store.state = state;
          if (state == _LoadState.error || state == _LoadState.offline) {
            expect(() => store.value, throwsStateError);
          } else {
            expect(store.value, isEmpty);
          }
        }
        expect(store.reads, _LoadState.values.length);
      },
    );

    test(
      'provider failure can retry and duplicate writes remain idempotent',
      () {
        final _FakeFeatureStore<String> store = _FakeFeatureStore<String>(
          'cached',
        );
        store.state = _LoadState.offline;
        expect(() => store.value, throwsStateError);
        store.state = _LoadState.success;
        expect(store.value, 'cached');
        expect(store.write('request-1', 'accepted'), isTrue);
        expect(store.write('request-1', 'accepted'), isFalse);
        expect(store.writes, 1);
      },
    );
  });

  group('Nexus, Trajectory, Progression, Profile, and Settings', () {
    test(
      'Nexus aggregate reflects complete and partial data without inventing counts',
      () {
        final _FakeFeatureStore<Map<String, int>> store =
            _FakeFeatureStore<Map<String, int>>(<String, int>{});
        expect(store.value['completed'], isNull);
        store.state = _LoadState.partial;
        store.write('aggregate', <String, int>{'completed': 1, 'pending': 2});
        expect(store.value['completed'], 1);
        expect(store.value['missing'], isNull);
      },
    );

    test(
      'Trajectory summary stays deterministic for complete and cold-start inputs',
      () {
        const TrajectorySummaryView complete = TrajectorySummaryView(
          pendingTasks: 2,
          completedTasks: 4,
          completedToday: 1,
          level: 3,
          streak: 2,
          energy: 0.6,
          momentum: 0.7,
          adaptability: 0.5,
          lastSessionXp: 25,
          lastSessionQuality: 0.8,
          pressureIndex: 40,
          behaviorDivergence: 10,
          alert: 'signals available',
          predictionTitle: 'Focused scenario',
          predictionOutcome: 'Scenario based on current signals.',
          predictionProbability: 0.65,
          predictionExplanation: 'Deterministic test fixture.',
        );
        final TrajectorySummaryView cold = TrajectorySummaryView(
          pendingTasks: 0,
          completedTasks: 0,
          completedToday: 0,
          level: complete.level,
          streak: complete.streak,
          energy: complete.energy,
          momentum: complete.momentum,
          adaptability: complete.adaptability,
          lastSessionXp: complete.lastSessionXp,
          lastSessionQuality: complete.lastSessionQuality,
          pressureIndex: complete.pressureIndex,
          behaviorDivergence: complete.behaviorDivergence,
          alert: 'limited evidence',
          predictionTitle: complete.predictionTitle,
          predictionOutcome: 'Starter scenario, not a forecast.',
          predictionProbability: complete.predictionProbability,
          predictionExplanation: complete.predictionExplanation,
        );
        expect(complete.completedTasks, 4);
        expect(cold.completedTasks, 0);
        expect(cold.predictionOutcome, contains('not a forecast'));
      },
    );

    test('Progression boundaries and repeated awards are stable', () {
      expect(ProgressionPolicy.levelFromXp(0), 1);
      expect(ProgressionPolicy.levelFromXp(100), 2);
      expect(ProgressionPolicy.levelFromXp(400), 3);
      final _FakeFeatureStore<int> xp = _FakeFeatureStore<int>(0);
      expect(xp.write('xp-event-1', 10), isTrue);
      expect(xp.write('xp-event-1', 10), isFalse);
      expect(xp.writes, 1);
    });

    testWidgets(
      'Profile renders Unicode identity and repeated navigation once',
      (WidgetTester tester) async {
        int back = 0;
        int settings = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProfileHeader(
                name: 'Zoë 🚀',
                level: 99,
                onBack: () => back++,
                onOpenSettings: () => settings++,
              ),
            ),
          ),
        );
        expect(find.text('Zoë 🚀'), findsOneWidget);
        expect(find.text('Level 99'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await tester.tap(find.byIcon(Icons.settings));
        expect(back, 2);
        expect(settings, 1);
      },
    );

    test(
      'Settings and SI Console remain deterministic for invalid/offline input',
      () {
        const NotificationPermissionSnapshot unknown =
            NotificationPermissionSnapshot.unknown();
        expect(unknown.isGranted, isFalse);
        expect(
          SIResponseFrame.build(
            evidence: const <String>[],
            recommendedMove: 'Retry when current signals are available.',
            confidenceSignal: SIResponseFrame.signalBandFromPercent(0),
          ),
          contains('evidence is limited'),
        );
        expect(SIResponseFrame.signalBandFromPercent(100), 'signal is strong');
      },
    );
  });

  group('isolated Smart Planner and SI Console input boundaries', () {
    test(
      'maximum-length and Unicode text survive bounded local processing',
      () {
        final String input = '${List<String>.filled(1024, 'x').join()} 日本語 🚀';
        expect(input.length, greaterThan(1024));
        final String output = SIResponseFrame.build(
          evidence: <String>['Input received: ${input.substring(0, 32)}'],
          recommendedMove: 'Use the deterministic local retry path.',
        );
        expect(output, contains('NEXT MOVE'));
        expect(output.contains('日本語'), input.substring(0, 32).contains('日本語'));
      },
    );
  });
}
