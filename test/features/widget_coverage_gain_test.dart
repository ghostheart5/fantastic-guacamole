import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
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
  group('widget coverage gain surfaces', () {
    testWidgets('dashboard renders mission surfaces and quick actions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
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
          child: const MaterialApp(home: NexusScreen()),
        ),
      );

      expect(find.text('NEXUS'), findsOneWidget);
      expect(find.text('Today\'s overview'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Quick actions'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('Quick actions'), findsOneWidget);
      expect(find.text('CREATOR'), findsOneWidget);
      expect(find.text('TIMELINE'), findsOneWidget);
    });

    testWidgets('timeline surfaces task and reflection cards', (
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
  id: 'reflection-1',
  type: TimelineEventType.reflection,
  title: 'Daily reflection checkpoint',
  detail: 'Capture one lesson from today\'s effort.',
  timestamp: now.subtract(const Duration(minutes: 15)),
  status: TimelineEventStatus.info,
),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timelineProvider.overrideWith(
              () => _FakeTimelineNotifier(seededEvents),
            ),
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

      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Task'), findsWidgets);
      
      expect(find.text('Reflection'), findsWidgets);
      expect(find.text('Ship launch checklist'), findsOneWidget);
      expect(find.text('Daily reflection checkpoint'), findsOneWidget);
    });

    testWidgets('si console surfaces mission control opportunity card', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SIConsoleScreen())),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('MISSION CONTROL'), findsOneWidget);
      expect(find.text('Goals, habits, tasks, and momentum'), findsOneWidget);
      expect(find.text('/daily'), findsOneWidget);
      expect(find.text('/focus'), findsOneWidget);
    });

    testWidgets('settings screen shows primary control sections', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsScreen())),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Workspace status'), findsOneWidget);
      expect(find.text('Reminder Automation'), findsOneWidget);
      expect(find.text('Voice Access'), findsOneWidget);
    });
  });
}
