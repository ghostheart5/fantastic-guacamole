import 'package:fantastic_guacamole/domain/entities/emotional_state.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The single boundary for human-state and governed-memory context.
///
/// Numeric fallbacks remain available to deterministic engines, but their
/// evidence origin is unavailable and they cannot be presented as a report
/// from the person.
class ConsentedHumanContext {
  const ConsentedHumanContext({
    required this.emotionAllowed,
    required this.memoryAllowed,
    required this.emotion,
    required this.siState,
  });

  final bool emotionAllowed;
  final bool memoryAllowed;
  final EmotionalState? emotion;
  final SIState siState;

  EmotionalState? authorizeReportedEmotion(EmotionalState? reported) {
    return emotionAllowed ? reported : null;
  }

  double? authorizeReportedEnergy(double? reported) {
    if (reported == null || !reported.isFinite) return null;
    return reported.clamp(0.0, 1.0).toDouble();
  }
}

final consentedHumanContextProvider = Provider<ConsentedHumanContext>((
  Ref ref,
) {
  final PersonalizationProfile profile = ref.watch(
    personalizationProfileProvider,
  );
  final SIState rawState = ref.watch(siStateProvider);
  final EmotionalState? reportedEmotion = ref.watch(observedEmotionProvider);
  final bool emotionAllowed = profile.allowsEmotionSignals;

  return ConsentedHumanContext(
    emotionAllowed: emotionAllowed,
    memoryAllowed: profile.allowsMemoryContext,
    emotion: emotionAllowed ? reportedEmotion : null,
    siState: SIState(
      energy: rawState.hasObservedEnergy ? rawState.energy : 0.5,
      fatigue: rawState.hasObservedFatigue ? rawState.fatigue : 0.5,
      completedToday: rawState.completedToday,
      energyOrigin: rawState.hasObservedEnergy
          ? PredictiveEvidenceOrigin.observed
          : PredictiveEvidenceOrigin.unavailable,
      fatigueOrigin: rawState.hasObservedFatigue
          ? PredictiveEvidenceOrigin.observed
          : PredictiveEvidenceOrigin.unavailable,
    ),
  );
});
