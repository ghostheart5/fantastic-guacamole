// lib/engine/si/si_user_growth_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_continuity_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_temporal_awareness_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_user_narrative_engine.dart';

enum UserGrowthStage {
  orientation,
  stabilizing,
  building,
  consolidating,
  recovering,
}

enum UserGrowthTrajectory { improving, stable, declining, insufficientData }

class UserGrowthMetric {
  const UserGrowthMetric({
    required this.name,
    required this.value,
    required this.reason,
  });

  final String name;
  final double value;
  final String reason;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'value': siClamp01(value),
    'reason': reason,
  };
}

class UserGrowthProfile {
  const UserGrowthProfile({
    required this.stage,
    required this.trajectory,
    required this.growthScore,
    required this.consistencyScore,
    required this.recoveryNeed,
    required this.metrics,
    required this.recommendation,
    required this.memory,
  });

  final UserGrowthStage stage;
  final UserGrowthTrajectory trajectory;
  final double growthScore;
  final double consistencyScore;
  final double recoveryNeed;
  final List<UserGrowthMetric> metrics;
  final String recommendation;
  final SIMemoryStore memory;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'stage': stage.name,
    'trajectory': trajectory.name,
    'growth_score': siClamp01(growthScore),
    'consistency_score': siClamp01(consistencyScore),
    'recovery_need': siClamp01(recoveryNeed),
    'metrics': metrics
        .map((UserGrowthMetric metric) => metric.toJson())
        .toList(),
    'recommendation': recommendation,
  };
}

class SIUserGrowthEngine {
  const SIUserGrowthEngine();

  UserGrowthProfile track({
    required SIContext context,
    required SIMemoryStore memory,
    MicroPatternReport? patterns,
    AdaptiveLearningWeights? learning,
    ContinuityProfile? continuity,
    TemporalAwarenessReport? temporal,
    UserNarrative? narrative,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();

    final double performance = _performance(memory);
    final double consistency = _consistency(memory, temporal);
    final double readiness = _readiness(context, learning);
    final double recoveryNeed = _recoveryNeed(context, patterns, learning);
    final double continuityScore = siClamp01(
      continuity?.continuityScore ?? 0.5,
    );
    final double narrativeBoost = _narrativeBoost(narrative);

    final double growthScore = siClamp01(
      performance * 0.24 +
          consistency * 0.22 +
          readiness * 0.22 +
          continuityScore * 0.18 +
          narrativeBoost * 0.14,
    );

    final UserGrowthTrajectory trajectory = _trajectory(
      memory: memory,
      temporal: temporal,
      growthScore: growthScore,
      recoveryNeed: recoveryNeed,
    );

    final UserGrowthStage stage = _stage(
      growthScore: growthScore,
      recoveryNeed: recoveryNeed,
      trajectory: trajectory,
      context: context,
    );

    final List<UserGrowthMetric> metrics = <UserGrowthMetric>[
      UserGrowthMetric(
        name: 'performance',
        value: performance,
        reason: 'Completion and skip behavior from recent snapshots.',
      ),
      UserGrowthMetric(
        name: 'consistency',
        value: consistency,
        reason: 'Temporal momentum and repeated stable activity.',
      ),
      UserGrowthMetric(
        name: 'readiness',
        value: readiness,
        reason:
            'Motivation, engagement, fatigue, stress, and learning weights.',
      ),
      UserGrowthMetric(
        name: 'continuity',
        value: continuityScore,
        reason: 'Goal, identity, and behavior continuity signals.',
      ),
      UserGrowthMetric(
        name: 'recovery_need',
        value: recoveryNeed,
        reason: 'Stress, fatigue, overload, and resistance signals.',
      ),
    ];

    final String recommendation = _recommendation(
      stage: stage,
      trajectory: trajectory,
      recoveryNeed: recoveryNeed,
    );

    final SIMemoryStore nextMemory = _writeMemory(
      memory: memory,
      timestamp: timestamp,
      stage: stage,
      trajectory: trajectory,
      growthScore: growthScore,
      consistency: consistency,
      recoveryNeed: recoveryNeed,
      recommendation: recommendation,
    );

    return UserGrowthProfile(
      stage: stage,
      trajectory: trajectory,
      growthScore: growthScore,
      consistencyScore: consistency,
      recoveryNeed: recoveryNeed,
      metrics: List<UserGrowthMetric>.unmodifiable(metrics),
      recommendation: recommendation,
      memory: nextMemory,
    );
  }

  String influenceResponse({
    required String message,
    required UserGrowthProfile growth,
    InstinctGuidance? instinct,
  }) {
    final String clean = siClean(
      message,
      fallback: 'Choose one small next step.',
    );
    final bool constrained =
        instinct?.safetyFirst == true || instinct?.avoidOverwhelm == true;

    if (constrained || growth.recoveryNeed >= 0.68) {
      return _truncate(
        '$clean\n\nGrowth note: protect capacity and take one small step.',
        260,
      );
    }

    if (growth.trajectory == UserGrowthTrajectory.improving &&
        growth.growthScore >= 0.68) {
      return _truncate(
        '$clean\n\nGrowth note: momentum is building — keep the scope clear.',
        420,
      );
    }

    if (growth.trajectory == UserGrowthTrajectory.declining) {
      return _truncate(
        '$clean\n\nGrowth note: reduce friction before pushing harder.',
        360,
      );
    }

    return clean;
  }

  double _performance(SIMemoryStore memory) {
    final List<SISnapshot> snapshots = memory.snapshots.take(12).toList();
    if (snapshots.isEmpty) return 0.5;

    final int completed = snapshots.fold<int>(
      0,
      (int sum, SISnapshot s) => sum + s.completed,
    );
    final int skipped = snapshots.fold<int>(
      0,
      (int sum, SISnapshot s) => sum + s.skipped,
    );

    final double energy =
        snapshots.fold<double>(
          0,
          (double sum, SISnapshot s) => sum + siClamp01(s.energy),
        ) /
        snapshots.length;

    final double fatigue =
        snapshots.fold<double>(
          0,
          (double sum, SISnapshot s) => sum + siClamp01(s.fatigue),
        ) /
        snapshots.length;

    return siClamp01(
      ((completed + 1) / (completed + skipped + 2)) * 0.58 +
          energy * 0.24 +
          (1 - fatigue) * 0.18,
    );
  }

  double _consistency(SIMemoryStore memory, TemporalAwarenessReport? temporal) {
    if (temporal != null) {
      return siClamp01((temporal.momentum + temporal.recencyBias) / 2);
    }

    final List<SISnapshot> snapshots = memory.snapshots.take(12).toList();
    if (snapshots.length < 3) return 0.45;

    final int active = snapshots
        .where(
          (SISnapshot snapshot) =>
              snapshot.completed > 0 || snapshot.skipped > 0,
        )
        .length;

    return siClamp01(active / snapshots.length);
  }

  double _readiness(SIContext context, AdaptiveLearningWeights? learning) {
    final SIUserState user = context.userState;

    final double base = siClamp01(
      user.motivation * 0.28 +
          user.engagement * 0.28 +
          (1 - user.fatigue) * 0.22 +
          (1 - user.stress) * 0.22,
    );

    if (learning == null) return base;

    return siClamp01(
      base * 0.65 + learning.focusReadiness * 0.18 + learning.momentum * 0.17,
    );
  }

  double _recoveryNeed(
    SIContext context,
    MicroPatternReport? patterns,
    AdaptiveLearningWeights? learning,
  ) {
    final SIUserState user = context.userState;

    double need = siClamp01(
      user.stress * 0.3 +
          user.cognitiveLoad * 0.28 +
          user.fatigue * 0.28 +
          user.frustration * 0.14,
    );

    if (_hasPattern(patterns, MicroPatternType.fatigueDrift)) {
      need = siClamp01(need + 0.12);
    }

    if (_hasPattern(patterns, MicroPatternType.highLoadLoop)) {
      need = siClamp01(need + 0.12);
    }

    if ((learning?.resistance ?? 0) >= 0.65) {
      need = siClamp01(need + 0.08);
    }

    return need;
  }

  double _narrativeBoost(UserNarrative? narrative) {
    if (narrative == null) return 0.5;

    if (narrative.trajectory == 'improving') return 0.75;
    if (narrative.trajectory == 'declining') return 0.32;
    if (narrative.phase == 'consolidation') return 0.72;
    if (narrative.arc == 'recovery_arc') return 0.42;

    return 0.55;
  }

  UserGrowthTrajectory _trajectory({
    required SIMemoryStore memory,
    required TemporalAwarenessReport? temporal,
    required double growthScore,
    required double recoveryNeed,
  }) {
    if (temporal != null) {
      switch (temporal.trend) {
        case TemporalTrend.improving:
          return UserGrowthTrajectory.improving;
        case TemporalTrend.declining:
          return UserGrowthTrajectory.declining;
        case TemporalTrend.stable:
          return UserGrowthTrajectory.stable;
        case TemporalTrend.insufficientData:
          break;
      }
    }

    if (memory.snapshots.length < 4) {
      return UserGrowthTrajectory.insufficientData;
    }

    if (recoveryNeed >= 0.72) return UserGrowthTrajectory.declining;
    if (growthScore >= 0.68) return UserGrowthTrajectory.improving;
    if (growthScore <= 0.38) return UserGrowthTrajectory.declining;
    return UserGrowthTrajectory.stable;
  }

  UserGrowthStage _stage({
    required double growthScore,
    required double recoveryNeed,
    required UserGrowthTrajectory trajectory,
    required SIContext context,
  }) {
    if (recoveryNeed >= 0.68 ||
        context.userState.fatigue >= 0.72 ||
        context.userState.stress >= 0.72) {
      return UserGrowthStage.recovering;
    }

    if (trajectory == UserGrowthTrajectory.insufficientData ||
        growthScore < 0.45) {
      return UserGrowthStage.orientation;
    }

    if (growthScore >= 0.76 && trajectory == UserGrowthTrajectory.improving) {
      return UserGrowthStage.consolidating;
    }

    if (growthScore >= 0.6) return UserGrowthStage.building;

    return UserGrowthStage.stabilizing;
  }

  String _recommendation({
    required UserGrowthStage stage,
    required UserGrowthTrajectory trajectory,
    required double recoveryNeed,
  }) {
    if (stage == UserGrowthStage.recovering || recoveryNeed >= 0.68) {
      return 'Reduce scope and protect recovery before increasing output.';
    }

    if (stage == UserGrowthStage.consolidating) {
      return 'Protect the rhythm that is already working.';
    }

    if (trajectory == UserGrowthTrajectory.improving) {
      return 'Use momentum for one focused action.';
    }

    if (trajectory == UserGrowthTrajectory.declining) {
      return 'Shrink the task and rebuild consistency.';
    }

    if (stage == UserGrowthStage.orientation) {
      return 'Clarify the next useful step and collect more behavior data.';
    }

    return 'Keep the next action small, repeatable, and clear.';
  }

  SIMemoryStore _writeMemory({
    required SIMemoryStore memory,
    required DateTime timestamp,
    required UserGrowthStage stage,
    required UserGrowthTrajectory trajectory,
    required double growthScore,
    required double consistency,
    required double recoveryNeed,
    required String recommendation,
  }) {
    SIMemoryStore next = memory.pushRecord(
      MemoryTier.midTerm,
      MemoryRecord(
        content:
            'user_growth|stage=${stage.name}|trajectory=${trajectory.name}|growth=${growthScore.toStringAsFixed(2)}|consistency=${consistency.toStringAsFixed(2)}|recovery=${recoveryNeed.toStringAsFixed(2)}',
        timestamp: timestamp,
        relevance: growthScore,
        confidence: 0.72,
        emotionalWeight: recoveryNeed,
        reinforcement: trajectory == UserGrowthTrajectory.improving ? 2 : 1,
      ),
    );

    if (stage == UserGrowthStage.consolidating ||
        trajectory == UserGrowthTrajectory.improving && growthScore >= 0.72) {
      next = next.pushRecord(
        MemoryTier.longTerm,
        MemoryRecord(
          content:
              'growth_milestone|stage=${stage.name}|growth=${growthScore.toStringAsFixed(2)}|$recommendation',
          timestamp: timestamp,
          relevance: growthScore,
          confidence: 0.74,
          emotionalWeight: 0.32,
          reinforcement: 2,
        ),
      );
    }

    if (stage == UserGrowthStage.recovering ||
        trajectory == UserGrowthTrajectory.declining) {
      next = next.pushRecord(
        MemoryTier.longTerm,
        MemoryRecord(
          content:
              'growth_recovery_signal|recovery=${recoveryNeed.toStringAsFixed(2)}|$recommendation',
          timestamp: timestamp,
          relevance: recoveryNeed,
          confidence: 0.7,
          emotionalWeight: recoveryNeed,
          reinforcement: 0,
        ),
      );
    }

    return next.dedupe().decay(timestamp);
  }

  bool _hasPattern(MicroPatternReport? report, MicroPatternType type) {
    return report?.patterns.any(
          (MicroPattern pattern) => pattern.type == type,
        ) ??
        false;
  }

  String _truncate(String text, int maxChars) {
    final String clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= maxChars) return clean;

    final String cut = clean.substring(0, maxChars).trim();
    final int punctuation = cut.lastIndexOf(RegExp(r'[.!?]'));

    if (punctuation > 80) {
      return cut.substring(0, punctuation + 1);
    }

    final int space = cut.lastIndexOf(' ');
    return space > 40 ? '${cut.substring(0, space)}...' : '$cut...';
  }
}
