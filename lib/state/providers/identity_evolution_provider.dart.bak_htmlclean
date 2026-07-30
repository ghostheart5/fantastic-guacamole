import 'package:fantastic_guacamole/state/providers/identity_drift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IdentityEvolutionState {
  const IdentityEvolutionState({
    required this.stage,
    required this.trait,
    required this.summary,
    required this.nextEvolution,
  });

  final String stage;
  final String trait;
  final String summary;
  final String nextEvolution;
}

final identityEvolutionProvider = Provider<IdentityEvolutionState>((ref) {
  final drift = ref.watch(identityDriftProvider);

  if (drift.score >= 80) {
    return const IdentityEvolutionState(
      stage: 'Advanced Alignment',
      trait: 'Strategic Executor',
      summary: 'Behavior consistently reflects the desired future identity.',
      nextEvolution: 'Expand influence while maintaining consistency.',
    );
  }

  if (drift.score >= 60) {
    return const IdentityEvolutionState(
      stage: 'Developing Alignment',
      trait: 'Intentional Builder',
      summary: 'Execution is strengthening but still requires reinforcement.',
      nextEvolution: 'Increase consistency of daily execution.',
    );
  }

  return const IdentityEvolutionState(
    stage: 'Foundation Stage',
    trait: 'Emerging Operator',
    summary: 'Identity is forming but habits are not yet fully aligned.',
    nextEvolution: 'Focus on small repeated wins before expansion.',
  );
});
