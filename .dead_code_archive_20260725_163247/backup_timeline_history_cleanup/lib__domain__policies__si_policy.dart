import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';

class SiPolicy {
  static const Set<String> _unsafeClaims = <String>{
    'guarantee',
    'cure',
    'diagnose',
    'prescribe',
    'legal advice',
  };

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

  static bool isSupportedAndSafe(SiDecisionEntity decision) {
    final String text =
        '${decision.rationale} ${decision.action} ${decision.reasoningTrace}'
            .toLowerCase();
    return !_unsafeClaims.any(text.contains);
  }

  static bool hasRequiredContext({
    required bool hasCurrentContext,
    required bool hasSettings,
    required bool hasLogs,
    required bool withinSubscriptionLimits,
  }) {
    return hasCurrentContext &&
        hasSettings &&
        hasLogs &&
        withinSubscriptionLimits;
  }

  static SiDecisionEntity reduceSuggestionVolume(
    SiDecisionEntity decision, {
    required bool overloaded,
    int maxSuggestionsWhenOverloaded = 2,
  }) {
    if (!overloaded) return decision;
    return decision.copyWith(
      orderedTaskIds: decision.orderedTaskIds
          .take(maxSuggestionsWhenOverloaded)
          .toList(),
      recommendedFocusMinutes: decision.recommendedFocusMinutes > 10
          ? 10
          : decision.recommendedFocusMinutes,
      shouldSimplify: true,
      tone: 'calm',
    );
  }

  static String _simplify(String action) {
    if (action.isEmpty) return action;
    final List<String> sentences = action.split('. ');
    if (sentences.length <= 2) return action;
    return '${sentences.take(2).join('. ')}.';
  }
}
