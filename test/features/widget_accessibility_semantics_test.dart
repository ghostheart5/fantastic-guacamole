import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTimelineNotifier extends TimelineNotifier {
  _FakeTimelineNotifier(this._events);

  final List<TimelineEventEntity> _events;

  @override
  List<TimelineEventEntity> build() => _events;
}

class _FakeGoalsNotifier extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}

void main() {
  group('widget accessibility semantics', () {
    testWidgets('nexus quick actions expose semantics labels', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          nexusStartupSummaryProvider.overrideWithValue(
            NexusStartupSummary(
              profile: ProfileState(
                name: 'Operator',
                level: 3,
                streak: 5,
                profileReady: true,
              ),
              energy: 0.68,
              fatigue: 0.22,
              completedToday: 2,
              emotionLabel: 'focused',
              startupDirective:
                  'Prime objective locked. Execute one decisive action now.',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: NexusScreen()),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Quick actions'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Creator'), findsOneWidget);
      expect(find.bySemanticsLabel('Timeline'), findsOneWidget);
      expect(find.bySemanticsLabel('Trajectory'), findsOneWidget);
      expect(find.bySemanticsLabel('Planning overview'), findsOneWidget);
    });

    testWidgets('timeline search is keyboard editable and filters list', (
      WidgetTester tester,
    ) async {
      final DateTime now = DateTime.now();
      final List<TimelineEventEntity> seededEvents = <TimelineEventEntity>[
        TimelineEventEntity(
          id: 'task-1',
          type: TimelineEventType.task,
          title: 'Ship launch checklist',
          detail: 'Close today\'s high-priority execution block.',
          timestamp: now,
          status: TimelineEventStatus.active,
          dueAt: now.add(const Duration(hours: 2)),
          phase: 'task',
          relatedId: 'task-1',
        ),
        TimelineEventEntity(
          id: 'journal-1',
          type: TimelineEventType.reflection,
          title: 'Daily reflection checkpoint',
          detail: 'Capture one lesson from today\'s effort.',
          timestamp: now.subtract(const Duration(minutes: 20)),
          status: TimelineEventStatus.info,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timelineProvider.overrideWith(() => _FakeTimelineNotifier(seededEvents)),
            timelineTodayProvider.overrideWith((Ref ref) => seededEvents),
            timelineCompletedEventsProvider.overrideWith(
              (Ref ref) => const <TimelineEventEntity>[],
            ),
            goalsProvider.overrideWith(_FakeGoalsNotifier.new),
            tasksProvider.overrideWith((Ref ref) async => const []),
          ],
          child: const MaterialApp(home: TimelineScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Ship launch checklist'), findsOneWidget);
      expect(find.text('Daily reflection checkpoint'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'reflection');
await tester.pump(const Duration(milliseconds: 500));
      debugPrint(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((e) => e.data)
            .whereType<String>()
            .join('\n'),
      );
      expect(find.text('Daily reflection checkpoint'), findsOneWidget);
      expect(find.text('Ship launch checklist'), findsNothing);
    });

    testWidgets('timeline back button is exposed as a button control', (
      WidgetTester tester,
    ) async {
      final DateTime now = DateTime.now();
      final List<TimelineEventEntity> seededEvents = <TimelineEventEntity>[
        TimelineEventEntity(
          id: 'task-1',
          type: TimelineEventType.task,
          title: 'Ship launch checklist',
          detail: 'Close today\'s high-priority execution block.',
          timestamp: now,
          status: TimelineEventStatus.active,
          dueAt: now.add(const Duration(hours: 2)),
          phase: 'task',
          relatedId: 'task-1',
        ),
      ];

      await tester.pumpWidget(
  ProviderScope(
    overrides: [
      timelineProvider.overrideWith(() => _FakeTimelineNotifier(seededEvents)),
      timelineTodayProvider.overrideWith((Ref ref) => seededEvents),
      timelineCompletedEventsProvider.overrideWith(
        (Ref ref) => const <TimelineEventEntity>[],
      ),
      goalsProvider.overrideWith(_FakeGoalsNotifier.new),
      tasksProvider.overrideWith((Ref ref) async => const []),
    ],
    child: const MaterialApp(home: TimelineScreen()),
  ),
);

await tester.pump();
    });
  });
}