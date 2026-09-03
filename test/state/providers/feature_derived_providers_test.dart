import 'package:fantastic_guacamole/domain/entities/emotional_state.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/signal_model.dart';
import 'package:fantastic_guacamole/state/models/signals_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/state/logs_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final ({double momentum, int completed, String expectedTrajectory})
      fixture
      in <({double momentum, int completed, String expectedTrajectory})>[
        (momentum: .8, completed: 24, expectedTrajectory: 'On track'),
        (
          momentum: .5,
          completed: 8,
          expectedTrajectory: 'Slightly inconsistent',
        ),
        (momentum: .2, completed: 1, expectedTrajectory: 'Rebuilding'),
      ]) {
    test('growth and narrative derive from momentum ${fixture.momentum}', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          profileProvider.overrideWith(
            () => _StaticProfile(
              ProfileState(streak: fixture.completed >= 20 ? 8 : 2),
            ),
          ),
          trajectorySummaryProvider.overrideWithValue(
            _trajectory(
              momentum: fixture.momentum,
              completed: fixture.completed,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final growth = container.read(userGrowthProvider);
      expect(growth.skillProgress, greaterThanOrEqualTo(0));
      expect(growth.adaptationRate, greaterThan(0));
      expect(container.read(userGrowthTitleProvider), 'Beginner');
      expect(container.read(progressSignalsProvider).momentum, isNotEmpty);
      expect(
        container.read(narrativeProvider).trajectory,
        contains(fixture.expectedTrajectory),
      );
    });
  }

  test('soul state uses consented observations and recent evidence', () {
    final DateTime now = DateTime.now();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(
          () => _StaticProfile(ProfileState(streak: 5)),
        ),
        trajectorySummaryProvider.overrideWithValue(
          _trajectory(momentum: .7, completed: 6),
        ),
        consentedHumanContextProvider.overrideWithValue(
          const ConsentedHumanContext(
            emotionAllowed: true,
            memoryAllowed: false,
            emotion: EmotionalState.anxious,
            siState: SIState(energy: .65, fatigue: .4, completedToday: 2),
          ),
        ),
        signalsBundleProvider.overrideWithValue(
          const SignalsBundle(
            items: <Signal>[
              Signal(title: 'Momentum', description: 'Improving'),
              Signal(title: 'Pressure', description: 'Stable'),
            ],
            summary: 'Two current signals',
            healthScore: .8,
          ),
        ),
        logsProvider.overrideWith(
          () => _StaticLogs(
            LogsState(
              entries: <LogEntryEntity>[
                LogEntryEntity(
                  id: 'log-1',
                  message: 'Completed task',
                  source: 'task',
                  timestamp: now.subtract(const Duration(minutes: 1)),
                ),
                LogEntryEntity(
                  id: 'log-2',
                  message: 'Recorded state',
                  source: 'system',
                  timestamp: now.subtract(const Duration(minutes: 2)),
                ),
              ],
              isLoading: false,
            ),
          ),
        ),
        timelineProvider.overrideWith(
          () => _StaticTimeline(<TimelineEventEntity>[
            TimelineEventEntity(
              id: 'event-1',
              type: TimelineEventType.goalComplete,
              title: 'Goal completed',
              detail: 'Evidence',
              timestamp: now.subtract(const Duration(minutes: 1)),
            ),
            TimelineEventEntity(
              id: 'event-2',
              type: TimelineEventType.levelUp,
              title: 'Level increased',
              detail: 'Evidence',
              timestamp: now.subtract(const Duration(minutes: 2)),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final soul = container.read(soulStateProvider);
    expect(soul.continuity, inInclusiveRange(0, 1));
    expect(soul.identityStrength, inInclusiveRange(0, 1));
    expect(soul.narrativePresence, greaterThan(.35));
    expect(soul.userConnection, inInclusiveRange(0, 1));
  });
}

TrajectorySummaryView _trajectory({
  required double momentum,
  required int completed,
}) {
  return TrajectorySummaryView(
    pendingTasks: 3,
    completedTasks: completed,
    completedToday: 2,
    level: 2,
    streak: 4,
    energy: .65,
    momentum: momentum,
    adaptability: .7,
    lastCompletionXp: 20,
    lastCompletionQuality: .8,
    pressureIndex: 45,
    behaviorDivergence: 10,
    alert: 'Evidence stable',
    predictionTitle: null,
    predictionOutcome: null,
    predictionProbability: null,
    predictionExplanation: null,
  );
}

final class _StaticProfile extends ProfileController {
  _StaticProfile(this._value);

  final ProfileState _value;

  @override
  ProfileState build() => _value;
}

final class _StaticLogs extends LogsController {
  _StaticLogs(this._value);

  final LogsState _value;

  @override
  LogsState build() => _value;
}

final class _StaticTimeline extends TimelineNotifier {
  _StaticTimeline(this._value);

  final List<TimelineEventEntity> _value;

  @override
  List<TimelineEventEntity> build() => _value;
}
