import 'package:fantastic_guacamole/core/utils/time_utils.dart';
import 'package:fantastic_guacamole/core/utils/math_utils.dart';

/// ChronoSpark Planning Horizon
/// Defines how far ahead the SI Engine should think, plan, and allocate.
/// Horizons are dynamic and respond to:
/// - user workload
/// - energy levels
/// - deadlines
/// - task density
/// - schedule constraints
class PlanningHorizon {
  final Duration shortTerm; // Tactical: next few hours
  final Duration midTerm; // Operational: next few days
  final Duration longTerm; // Strategic: next few weeks
  final Duration maxLimit; // Hard cap

  const PlanningHorizon({
    required this.shortTerm,
    required this.midTerm,
    required this.longTerm,
    required this.maxLimit,
  });

  /// Default ChronoSpark horizons
  factory PlanningHorizon.defaultHorizon() {
    return const PlanningHorizon(
      shortTerm: Duration(hours: 6),
      midTerm: Duration(days: 3),
      longTerm: Duration(days: 21),
      maxLimit: Duration(days: 30),
    );
  }

  // ------------------------------------------------------------
  // HORIZON SCORING
  // ------------------------------------------------------------

  /// Computes how far ahead the SI Engine should plan based on:
  /// - task density
  /// - urgency
  /// - energy
  /// - upcoming deadlines
  ///
  /// Returns a Duration representing the recommended horizon.
  Duration computeAdaptiveHorizon({
    required double energyLevel, // 0.0 → 1.0
    required double urgencyLevel, // 0.0 → 1.0
    required int tasksToday,
    required int tasksThisWeek,
    required bool hasMajorDeadlineSoon,
  }) {
    double score = 0.0;

    // Energy: low energy → shorter horizon
    score += energyLevel * 0.25;

    // Urgency: high urgency → longer horizon
    score += urgencyLevel * 0.35;

    // Task density
    if (tasksToday > 6) score += 0.15;
    if (tasksThisWeek > 20) score += 0.15;

    // Major deadline
    if (hasMajorDeadlineSoon) score += 0.25;

    score = MathUtils.clamp(score, 0.0, 1.0).toDouble();

    // Map score → horizon
    if (score < 0.33) return shortTerm;
    if (score < 0.66) return midTerm;
    return longTerm;
  }

  // ------------------------------------------------------------
  // EXPANSION / CONTRACTION
  // ------------------------------------------------------------

  /// Expands the planning horizon by a percentage.
  PlanningHorizon expand(double percent) {
    final factor = 1 + percent;

    return PlanningHorizon(
      shortTerm: _expandDuration(shortTerm, factor),
      midTerm: _expandDuration(midTerm, factor),
      longTerm: _expandDuration(longTerm, factor),
      maxLimit: maxLimit,
    );
  }

  /// Contracts the planning horizon by a percentage.
  PlanningHorizon contract(double percent) {
    final factor = 1 - percent;

    return PlanningHorizon(
      shortTerm: _expandDuration(shortTerm, factor),
      midTerm: _expandDuration(midTerm, factor),
      longTerm: _expandDuration(longTerm, factor),
      maxLimit: maxLimit,
    );
  }

  Duration _expandDuration(Duration d, double factor) {
    final ms = (d.inMilliseconds * factor).round();
    return Duration(
      milliseconds: MathUtils.clamp(ms, 0, maxLimit.inMilliseconds).toInt(),
    );
  }

  // ------------------------------------------------------------
  // HORIZON CHECKS
  // ------------------------------------------------------------

  bool isWithinShort(DateTime target) {
    return TimeUtils.minutesBetween(DateTime.now(), target) <=
        shortTerm.inMinutes;
  }

  bool isWithinMid(DateTime target) {
    return TimeUtils.minutesBetween(DateTime.now(), target) <=
        midTerm.inMinutes;
  }

  bool isWithinLong(DateTime target) {
    return TimeUtils.minutesBetween(DateTime.now(), target) <=
        longTerm.inMinutes;
  }

  bool exceedsMax(DateTime target) {
    return TimeUtils.minutesBetween(DateTime.now(), target) >
        maxLimit.inMinutes;
  }

  // ------------------------------------------------------------
  // NEXT HORIZON WINDOW
  // ------------------------------------------------------------

  /// Returns the end timestamp of the current planning horizon.
  DateTime horizonEnd(Duration horizon) {
    return DateTime.now().add(horizon);
  }

  DateTime shortTermEnd() => horizonEnd(shortTerm);
  DateTime midTermEnd() => horizonEnd(midTerm);
  DateTime longTermEnd() => horizonEnd(longTerm);
}
