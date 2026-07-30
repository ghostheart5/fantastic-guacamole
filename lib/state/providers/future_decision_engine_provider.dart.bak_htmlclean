import 'package:fantastic_guacamole/state/providers/cognitive_twin_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_drift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FutureDecision {
  const FutureDecision({
    required this.recommendedChoice,
    required this.reason,
    required this.alignmentScore,
  });

  final String recommendedChoice;
  final String reason;
  final int alignmentScore;
}

final futureDecisionEngineProvider = Provider<FutureDecision>((ref) {
  final twin = ref.watch(cognitiveTwinProvider);
  final drift = ref.watch(identityDriftProvider);

  final int alignmentScore = drift.score.clamp(0, 100);

  final String recommendation = twin.bestAction;

  final String reason =
      'This action best aligns with the future identity, current operator state, and intelligence fusion recommendations.';

  return FutureDecision(
    recommendedChoice: recommendation,
    reason: reason,
    alignmentScore: alignmentScore,
  );
});
