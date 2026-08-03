import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart'
  as extended_domain;
import 'package:fantastic_guacamole/state/providers/future_decision_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/future_timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_drift_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/theme_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_simulation_provider.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
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

class _FakeThemeController extends CurrentThemeController {
  @override
  Future<AppThemeEntity> build() async => AppThemeEntity.dark();
}

class _StaticNotificationPermissionNotifier
    extends NotificationPermissionNotifier {
  @override
  NotificationPermissionSnapshot build() {
    return const NotificationPermissionSnapshot(
      granted: false,
      permissionState: NotificationPermissionState.denied,
    );
  }

  @override
  Future<NotificationPermissionSnapshot> refresh() async {
    return state;
  }

  @override
  Future<NotificationPermissionSnapshot> requestPermission() async {
    return state;
  }
}

void main() {
  group('widget coverage interactions', () {
    testWidgets('nexus quick actions update app flow', (WidgetTester tester) async {
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

      final Map<String, AppView> expectations = <String, AppView>{
        'CREATOR': AppView.creator,
        'TIMELINE': AppView.timeline,
        'TRAJECTORY': AppView.trajectoryEngine,
        'PLANNING OVERVIEW': AppView.console,
      };

      for (final MapEntry<String, AppView> entry in expectations.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pump();
        expect(container.read(appFlowProvider), entry.value);
      }
    });

    testWidgets('timeline back action returns to nexus', (WidgetTester tester) async {
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

      final ProviderContainer container = ProviderContainer(
        overrides: [
          timelineProvider.overrideWith(() => _FakeTimelineNotifier(seededEvents)),
          timelineTodayProvider.overrideWith((Ref ref) => seededEvents),
          timelineCompletedEventsProvider.overrideWith(
            (Ref ref) => const <TimelineEventEntity>[],
          ),
          goalsProvider.overrideWith(_FakeGoalsNotifier.new),
          tasksProvider.overrideWith((Ref ref) async => const []),
        ],
      );
      addTearDown(container.dispose);
      container.read(appFlowProvider.notifier).toTimeline();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TimelineScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pump();

      expect(container.read(appFlowProvider), AppView.nexus);
    });

    testWidgets('trajectory back action returns to nexus', (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          trajectorySummaryProvider.overrideWithValue(
            const TrajectorySummaryView(
              pendingTasks: 4,
              completedTasks: 3,
              completedToday: 1,
              level: 2,
              streak: 6,
              energy: 0.64,
              momentum: 0.61,
              adaptability: 0.58,
              lastSessionXp: 32,
              lastSessionQuality: 0.72,
              pressureIndex: 43,
              behaviorDivergence: 21,
              alert: 'trajectory stable',
              predictionTitle: 'focus block',
              predictionOutcome: 'Trajectory strengthens with focused execution.',
              predictionProbability: 0.74,
              predictionExplanation:
                  'Execution consistency remains the leading factor.',
            ),
          ),
          momentumEngineProvider.overrideWithValue(
            const MomentumEngineState(
              score: 71,
              trend: 'Rising',
              recovery: 'Recovered',
              forecast: 'Execution quality determines near-term momentum slope.',
              energyPercent: 66,
              pressurePercent: 38,
              streak: 5,
              completedToday: 2,
            ),
          ),
          trajectorySimulationProvider.overrideWithValue(
            const <TrajectorySimulationResult>[
              TrajectorySimulationResult(
                type: TrajectorySimulationType.momentumBoost,
                title: 'Deep Focus Plan',
                summary: 'Protect one uninterrupted focus block.',
                projectedMomentum: 84,
                projectedPressure: 41,
                projectedRecovery: 'Recovered',
                projectedOutcome: 'Momentum compounds when scope stays narrow.',
              ),
            ],
          ),
          futureTimelineProvider.overrideWithValue(
            const FutureTimelineState(
              checkpoints: <FutureTimelineCheckpoint>[
                FutureTimelineCheckpoint(
                  label: '7 DAYS',
                  days: 7,
                  prediction: 'Execution stabilizes if deferrals remain low.',
                ),
              ],
            ),
          ),
          identityDriftProvider.overrideWithValue(
            const IdentityDriftState(
              alignment: IdentityAlignment.aligned,
              score: 84,
              summary: 'Behavior and direction are aligned.',
              correction: 'Maintain current cadence.',
            ),
          ),
          futureDecisionEngineProvider.overrideWithValue(
            const FutureDecision(
              recommendedChoice: 'Ship the focused milestone block',
              reason: 'Highest alignment path',
              alignmentScore: 84,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(appFlowProvider.notifier).toTrajectoryEngine();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TrajectoryEngineScreen()),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      expect(container.read(appFlowProvider), AppView.nexus);
    });

    testWidgets('settings back action returns to nexus', (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          extended_domain.extendedDomainBootstrapProvider.overrideWith(
            (Ref ref) async {},
          ),
          extended_domain.privacyPoliciesProvider.overrideWith(
            (Ref ref) => const [],
          ),
          appAccessProvider.overrideWith(
            (Ref ref) => const AppAccessState(
              hasPremiumAccess: false,
              hasTesterFullAccess: false,
              paywallDisabled: false,
            ),
          ),
          currentThemeProvider.overrideWith(_FakeThemeController.new),
          notificationPermissionProvider.overrideWith(
            _StaticNotificationPermissionNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(appFlowProvider.notifier).toSettings();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pump();

      expect(container.read(appFlowProvider), AppView.nexus);
    });
  });
}