import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: SI Console
///
/// sanitize() is the terminal gate every SiDecisionEntity must pass.
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
    return !containsUnsupportedClaim(
      '${decision.rationale} ${decision.action} ${decision.reasoningTrace}',
    );
  }

  /// Whether [text] contains a claim ChronoSpark is not permitted to make.
  ///
  /// Exposed so free-form assistant text can be held to the same standard as a
  /// [SiDecisionEntity]. Model output previously bypassed this list entirely —
  /// `sanitize` only ever saw decisions, never generated prose.
  static bool containsUnsupportedClaim(String text) {
    final String lowered = text.toLowerCase();
    return _unsafeClaims.any(lowered.contains);
  }

  /// Rationale used when a decision is withheld for containing an unsupported
  /// claim. Deliberately free of every term in [_unsafeClaims] so the fallback
  /// can never itself fail the safety check.
  static const String withheldRationale =
      'Suggestion withheld: it contained an unsupported claim.';

  /// Rationale used when required context is missing.
  static const String missingContextRationale =
      'Not enough context to make a recommendation yet.';

  /// Terminal gate that every [SiDecisionEntity] must pass before it leaves the
  /// domain. Applies [enforce], then blocks the decision entirely if it fails
  /// [isSupportedAndSafe].
  ///
  /// Call this from every code path that returns a decision — currently
  /// `GenerateSiDecision` and `GetNextAction`.
  static SiDecisionEntity sanitize(SiDecisionEntity decision) {
    final SiDecisionEntity enforced = enforce(decision);
    if (isSupportedAndSafe(enforced)) {
      return enforced;
    }
    return SiDecisionEntity(
      rationale: withheldRationale,
      tone: 'calm',
      recommendedFocusMinutes: enforced.recommendedFocusMinutes,
    );
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
