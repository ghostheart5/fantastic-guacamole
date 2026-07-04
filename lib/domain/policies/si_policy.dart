import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';

class SiPolicy {
  static bool shouldSuggestBreak(SiStateEntity state) {
    return state.fatigue > 0.7 || state.energy < 0.3;
  }

  static bool shouldPushFocus(SiStateEntity state) {
    return state.energy > 0.6 && state.focus > 0.5 && state.fatigue < 0.5;
  }

  static SiDecisionEntity enforce(SiDecisionEntity decision) {
    if (decision.shouldSimplify) {
      final String simplified = _simplify(decision.action);
      return decision.copyWith(
        action: simplified,
        tone: 'calm',
        recommendedFocusMinutes: decision.recommendedFocusMinutes > 15
            ? 15
            : decision.recommendedFocusMinutes,
      );
    }
    return decision;
  }

  static String _simplify(String action) {
    if (action.isEmpty) return action;
    final List<String> sentences = action.split('. ');
    if (sentences.length <= 2) return action;
    return '${sentences.take(2).join('. ')}.';
  }
}
