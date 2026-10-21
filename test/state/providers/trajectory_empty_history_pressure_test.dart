import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/prediction.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/prediction_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/state/logs_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'two pending tasks without history have load 32, not invented deferral pressure',
    () async {
      final container = ProviderContainer(
        overrides: [
          tasksProvider.overrideWith(
            (ref) async => [
              for (final id in ['one', 'two'])
                Task(
                  id: id,
                  title: 'QA $id',
                  priority: 1,
                  difficulty: 1,
                  energyRequired: 1,
                ),
            ],
          ),
          profileProvider.overrideWith(_Profile.new),
          learningProvider.overrideWith(_Learning.new),
          personalizationProfileProvider.overrideWith(_Preferences.new),
          logsProvider.overrideWith(_EmptyLogs.new),
          consentedHumanContextProvider.overrideWithValue(
            const ConsentedHumanContext(
              emotionAllowed: false,
              memoryAllowed: false,
              emotion: null,
              siState: SIState(),
            ),
          ),
          predictionProvider.overrideWith(
            (ref, title) async => const Prediction(
              outcome: 'Unknown',
              probability: .5,
              explanation: 'No observations',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(tasksProvider.future);
      final summary = container.read(trajectorySummaryProvider);
      expect(summary.pendingTasks, 2);
      expect(summary.pressureIndex, 32);
      expect(summary.momentum, 0);
    },
  );
}

class _Profile extends ProfileController {
  @override
  ProfileState build() => ProfileState();
}

class _Learning extends LearningController {
  @override
  LearningState build() => const LearningState();
}

class _Preferences extends PersonalizationProfileController {
  @override
  PersonalizationProfile build() => const PersonalizationProfile();
}

class _EmptyLogs extends LogsController {
  @override
  LogsState build() => LogsState.initial();
}
