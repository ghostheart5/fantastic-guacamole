import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemoryIntelligenceState {
  const MemoryIntelligenceState({
    required this.recurringWin,
    required this.recurringFriction,
    required this.lesson,
    required this.executionSuggestion,
  });

  final String recurringWin;
  final String recurringFriction;
  final String lesson;
  final String executionSuggestion;
}

final memoryIntelligenceProvider = Provider<MemoryIntelligenceState>((ref) {
  final momentum = ref.watch(momentumEngineProvider);

  final String recurringWin = momentum.score >= 70
      ? 'Momentum rises when execution stays deliberate.'
      : 'Small completed actions reliably improve momentum.';

  final String recurringFriction = momentum.pressurePercent >= 70
      ? 'High pressure repeatedly disrupts execution.'
      : 'Context switching reduces forward progress.';

  final String lesson = momentum.score >= 70
      ? 'Protect attention before adding new commitments.'
      : 'Restore rhythm through completion before expansion.';

  final String executionSuggestion = momentum.pressurePercent >= 70
      ? 'Reduce active commitments today.'
      : 'Finish one meaningful action before starting another.';

  return MemoryIntelligenceState(
    recurringWin: recurringWin,
    recurringFriction: recurringFriction,
    lesson: lesson,
    executionSuggestion: executionSuggestion,
  );
});
