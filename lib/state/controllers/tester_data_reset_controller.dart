import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/momentum_controller.dart';
import 'package:fantastic_guacamole/state/controllers/prediction_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/behavior_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/services/tester_data_reset_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TesterDataResetController {
  const TesterDataResetController(this._ref, this._service);

  final Ref _ref;
  final TesterDataResetService _service;

  Future<void> reset() async {
    await _ref.read(siEngineServiceProvider).clearAllMemory();
    await _service.reset();

    _ref.read(mockSignInProvider.notifier).set(false);
    _ref.read(onboardingCompleteProvider.notifier).set(false);
    _ref.read(onboardingWelcomeCompleteProvider.notifier).set(false);
    _ref.invalidate(accountOnboardingCompleteProvider);
    _ref.read(aiInputProvider.notifier).set(null);
    _ref.read(smartPlannerAiInputProvider.notifier).set(null);
    _ref.read(notificationProvider.notifier).clear();

    _ref.invalidate(tasksProvider);
    _ref.invalidate(profileProvider);
    _ref.invalidate(goalsProvider);
    _ref.invalidate(goalProgressProvider);
    _ref.invalidate(timelineProvider);
    _ref.invalidate(memoriesProvider);
    _ref.invalidate(behaviorStateProvider);
    _ref.invalidate(identityStateProvider);
    _ref.invalidate(learningProvider);
    _ref.invalidate(learningHistoryProvider);
    _ref.invalidate(siStateProvider);
    _ref.invalidate(siMemoryProvider);
    _ref.invalidate(smartPlannerMemoryProvider);
    _ref.invalidate(logsProvider);
    _ref.invalidate(completionScoreProvider);
    _ref.invalidate(momentumProvider);
    _ref.invalidate(emotionProvider);
    _ref.invalidate(aiDecisionProvider);
    _ref.invalidate(aiResponseProvider);
    _ref.invalidate(smartPlannerAiResponseProvider);
    _ref.invalidate(aiAgentTraceProvider);
    _ref.invalidate(smartPlannerAiAgentTraceProvider);
    _ref.invalidate(aiExecutionStatusProvider);
    _ref.invalidate(smartPlannerAiExecutionStatusProvider);
    _ref.invalidate(aiCreditWalletProvider);
    _ref.invalidate(optimizationConfigProvider);
    _ref.invalidate(progressionProvider);
    _ref.invalidate(trajectorySummaryProvider);
    _ref.invalidate(predictionProvider);
  }
}
