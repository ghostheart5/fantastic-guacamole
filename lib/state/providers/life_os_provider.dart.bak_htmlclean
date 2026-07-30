import 'package:fantastic_guacamole/state/providers/cognitive_twin_provider.dart';
import 'package:fantastic_guacamole/state/providers/future_decision_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/future_timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_evolution_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LifeOSState {
  const LifeOSState({
    required this.mission,
    required this.currentMode,
    required this.primaryAction,
    required this.nextMilestone,
    required this.identityStage,
  });

  final String mission;
  final String currentMode;
  final String primaryAction;
  final String nextMilestone;
  final String identityStage;
}

final lifeOSProvider = Provider<LifeOSState>((ref) {
  final twin = ref.watch(cognitiveTwinProvider);
  final decision = ref.watch(futureDecisionEngineProvider);
  final timeline = ref.watch(futureTimelineProvider);
  final evolution = ref.watch(identityEvolutionProvider);

  return LifeOSState(
    mission:
        'Become the future version of yourself through consistent execution.',
    currentMode: twin.mode.name,
    primaryAction: decision.recommendedChoice,
    nextMilestone: timeline.checkpoints.first.label,
    identityStage: evolution.stage,
  );
});
