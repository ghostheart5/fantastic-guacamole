// lib/engine/si/si_user_narrative_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_continuity_engine.dart';

class UserNarrative {
  const UserNarrative({
    required this.arc,
    required this.theme,
    required this.archetype,
    required this.phase,
    required this.challenge,
    required this.progressBeat,
    required this.nextStoryPrompt,
    required this.trajectory,
    required this.confidence,
    required this.signals,
    required this.timestamp,
  });

  final String arc;
  final String theme;
  final String archetype;
  final String phase;
  final String challenge;
  final String progressBeat;
  final String nextStoryPrompt;
  final String trajectory;
  final double confidence;
  final List<String> signals;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'arc': arc,
    'theme': theme,
    'archetype': archetype,
    'phase': phase,
    'challenge': challenge,
    'progress_beat': progressBeat,
    'next_story_prompt': nextStoryPrompt,
    'trajectory': trajectory,
    'confidence': siClamp01(confidence),
    'signals': signals,
    'timestamp': timestamp.toIso8601String(),
  };

  factory UserNarrative.fromJson(Map<String, dynamic> json) {
    return UserNarrative(
      arc: siClean(json['arc']?.toString(), fallback: 'orientation_arc'),
      theme: siClean(json['theme']?.toString(), fallback: 'momentum'),
      archetype: siClean(json['archetype']?.toString(), fallback: 'guide'),
      phase: siClean(json['phase']?.toString(), fallback: 'early'),
      challenge: siClean(
        json['challenge']?.toString(),
        fallback: 'clarity_gap',
      ),
      progressBeat: siClean(
        json['progress_beat']?.toString(),
        fallback:
            'You are turning scattered signals into one usable next step.',
      ),
      nextStoryPrompt: siClean(
        json['next_story_prompt']?.toString(),
        fallback: 'What is the next small chapter you want to complete?',
      ),
      trajectory: siClean(json['trajectory']?.toString(), fallback: 'stable'),
      confidence: siClamp01(_num(json['confidence'])),
      signals: ((json['signals'] as List?) ?? const <dynamic>[])
          .map((dynamic value) => value.toString())
          .where((String value) => value.trim().isNotEmpty)
          .toList(growable: false),
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static num? _num(Object? value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }
}

class NarrativeTransition {
  const NarrativeTransition({
    required this.changed,
    required this.previousArc,
    required this.nextArc,
    required this.previousPhase,
    required this.nextPhase,
    required this.reason,
  });

  final bool changed;
  final String? previousArc;
  final String nextArc;
  final String? previousPhase;
  final String nextPhase;
  final String reason;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'changed': changed,
    'previous_arc': previousArc,
    'next_arc': nextArc,
    'previous_phase': previousPhase,
    'next_phase': nextPhase,
    'reason': reason,
  };
}

class NarrativePrediction {
  const NarrativePrediction({
    required this.nextArc,
    required this.nextPhase,
    required this.regressionRisk,
    required this.growthProbability,
    required this.reason,
  });

  final String nextArc;
  final String nextPhase;
  final double regressionRisk;
  final double growthProbability;
  final String reason;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'next_arc': nextArc,
    'next_phase': nextPhase,
    'regression_risk': siClamp01(regressionRisk),
    'growth_probability': siClamp01(growthProbability),
    'reason': reason,
  };
}

class UserNarrativeResult {
  const UserNarrativeResult({
    required this.narrative,
    required this.transition,
    required this.prediction,
    required this.memory,
    required this.frameHint,
  });

  final UserNarrative narrative;
  final NarrativeTransition transition;
  final NarrativePrediction prediction;
  final SIMemoryStore memory;
  final String frameHint;
}

class UserNarrativeEngine {
  const UserNarrativeEngine();

  UserNarrativeResult build({
    required SIContext context,
    required SIMemoryStore memory,
    SIIntent? intent,
    double? confidence,
    List<String> goals = const <String>[],
    MicroPatternReport? patterns,
    AdaptiveLearningWeights? learning,
    ContinuityProfile? continuity,
    UserNarrative? previous,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final UserNarrative? last = previous ?? _latestNarrativeFromMemory(memory);

    final double safeConfidence = siClamp01(
      confidence ?? intent?.confidence ?? 0.5,
    );

    final List<String> signals = _signals(
      context: context,
      intent: intent,
      goals: goals,
      patterns: patterns,
      learning: learning,
      continuity: continuity,
    );

    final String trajectory = _trajectory(
      context: context,
      memory: memory,
      learning: learning,
      continuity: continuity,
    );

    final String arc = _arc(
      context: context,
      goals: goals,
      patterns: patterns,
      learning: learning,
      continuity: continuity,
      confidence: safeConfidence,
      trajectory: trajectory,
    );

    final String theme = _theme(
      context: context,
      intent: intent,
      patterns: patterns,
      trajectory: trajectory,
    );

    final String archetype = _archetype(
      context: context,
      intent: intent,
      arc: arc,
      theme: theme,
      continuity: continuity,
    );

    final String phase = _phase(
      context: context,
      arc: arc,
      memory: memory,
      confidence: safeConfidence,
      trajectory: trajectory,
    );

    final String challenge = _challenge(
      context: context,
      confidence: safeConfidence,
      patterns: patterns,
      learning: learning,
      continuity: continuity,
    );

    final UserNarrative narrative = UserNarrative(
      arc: arc,
      theme: theme,
      archetype: archetype,
      phase: phase,
      challenge: challenge,
      progressBeat: _progressBeat(
        arc: arc,
        theme: theme,
        archetype: archetype,
        phase: phase,
        challenge: challenge,
        trajectory: trajectory,
      ),
      nextStoryPrompt: _nextPrompt(
        arc: arc,
        theme: theme,
        challenge: challenge,
        context: context,
      ),
      trajectory: trajectory,
      confidence: safeConfidence,
      signals: List<String>.unmodifiable(signals),
      timestamp: timestamp,
    );

    final NarrativeTransition transition = _transition(
      previous: last,
      current: narrative,
    );

    final NarrativePrediction prediction = _predictNext(
      narrative: narrative,
      context: context,
      learning: learning,
      continuity: continuity,
    );

    final SIMemoryStore nextMemory = _writeMemory(
      memory: memory,
      narrative: narrative,
      transition: transition,
      prediction: prediction,
      timestamp: timestamp,
    );

    return UserNarrativeResult(
      narrative: narrative,
      transition: transition,
      prediction: prediction,
      memory: nextMemory,
      frameHint: _frameHint(narrative),
    );
  }

  String influenceResponse({
    required String message,
    required UserNarrative narrative,
    InstinctGuidance? instinct,
    bool includePrompt = true,
  }) {
    final String clean = siClean(
      message,
      fallback: 'Choose one small next step.',
    );

    final bool constrained =
        instinct?.safetyFirst == true || instinct?.avoidOverwhelm == true;

    if (constrained) {
      return _truncate('$clean\n\n${narrative.nextStoryPrompt}', 240);
    }

    final String frame = _frameHint(narrative);
    final String prompt = includePrompt
        ? '\n\n${narrative.nextStoryPrompt}'
        : '';

    return _truncate('$clean\n\n$frame$prompt', 420);
  }

  List<String> _signals({
    required SIContext context,
    required SIIntent? intent,
    required List<String> goals,
    required MicroPatternReport? patterns,
    required AdaptiveLearningWeights? learning,
    required ContinuityProfile? continuity,
  }) {
    final List<String> output = <String>[
      'emotion:${context.userState.emotion}',
      'stability:${context.userState.stability}',
      if (intent != null) 'intent:${intent.primary.label}',
      if (goals.isNotEmpty) 'goals:${goals.length}',
      if (patterns?.patterns.isNotEmpty == true)
        'patterns:${patterns!.patterns.first.type.name}',
      if (learning != null)
        'learning:momentum=${learning.momentum.toStringAsFixed(2)}',
      if (continuity != null) 'continuity:${continuity.identityLabel}',
    ];

    return output.toSet().toList(growable: false);
  }

  String _arc({
    required SIContext context,
    required List<String> goals,
    required MicroPatternReport? patterns,
    required AdaptiveLearningWeights? learning,
    required ContinuityProfile? continuity,
    required double confidence,
    required String trajectory,
  }) {
    final SIUserState user = context.userState;

    if (user.fatigue >= 0.7 ||
        user.stress >= 0.72 ||
        user.cognitiveLoad >= 0.78) {
      return 'recovery_arc';
    }

    if (confidence < 0.5 || goals.isEmpty) {
      return 'orientation_arc';
    }

    if (trajectory == 'declining' ||
        (learning?.resistance ?? 0.5) >= 0.68 ||
        _hasPattern(patterns, MicroPatternType.skipResistance)) {
      return 'stabilization_arc';
    }

    if ((learning?.momentum ?? 0.5) >= 0.68 ||
        _hasPattern(patterns, MicroPatternType.completionMomentum) ||
        (continuity?.continuityScore ?? 0.0) >= 0.7) {
      return 'growth_arc';
    }

    if (context.input.history.length >= 3) {
      return 'continuity_arc';
    }

    return 'orientation_arc';
  }

  String _theme({
    required SIContext context,
    required SIIntent? intent,
    required MicroPatternReport? patterns,
    required String trajectory,
  }) {
    final String label = intent?.primary.label ?? 'general_query';

    if (label == 'reflect') return 'reflection';
    if (label == 'insight_request') return 'pattern_reading';
    if (context.userState.stress >= 0.68 ||
        context.userState.cognitiveLoad >= 0.72) {
      return 'stabilization';
    }
    if (trajectory == 'improving' ||
        _hasPattern(patterns, MicroPatternType.completionMomentum)) {
      return 'momentum';
    }
    if (_hasPattern(patterns, MicroPatternType.fatigueDrift)) {
      return 'recovery';
    }

    return 'execution';
  }

  String _archetype({
    required SIContext context,
    required SIIntent? intent,
    required String arc,
    required String theme,
    required ContinuityProfile? continuity,
  }) {
    final String label = intent?.primary.label ?? '';

    if (arc == 'recovery_arc' || theme == 'recovery') return 'restorer';
    if (theme == 'reflection' || label == 'reflect') return 'seeker';
    if (label == 'insight_request' || theme == 'pattern_reading') {
      return 'analyst';
    }
    if (label == 'get_task' ||
        label == 'start_focus' ||
        theme == 'momentum' ||
        theme == 'execution') {
      return 'builder';
    }
    if ((continuity?.driftRisk ?? 0.0) >= 0.65) return 'guide';

    return 'guide';
  }

  String _phase({
    required SIContext context,
    required String arc,
    required SIMemoryStore memory,
    required double confidence,
    required String trajectory,
  }) {
    if (arc == 'recovery_arc') return 'recovery';
    if (trajectory == 'declining') return 'recovery';
    if (memory.snapshots.length < 3 || confidence < 0.55) return 'early';
    if (memory.snapshots.length < 8) return 'mid';
    if (trajectory == 'improving' && confidence >= 0.7) {
      return 'consolidation';
    }
    return 'mid';
  }

  String _challenge({
    required SIContext context,
    required double confidence,
    required MicroPatternReport? patterns,
    required AdaptiveLearningWeights? learning,
    required ContinuityProfile? continuity,
  }) {
    final SIUserState user = context.userState;

    if (user.stress >= 0.7 ||
        user.cognitiveLoad >= 0.75 ||
        user.fatigue >= 0.72) {
      return 'overload';
    }

    if (confidence < 0.55) return 'clarity_gap';

    if (_hasPattern(patterns, MicroPatternType.skipResistance) ||
        (learning?.resistance ?? 0.5) >= 0.65) {
      return 'execution_friction';
    }

    if ((continuity?.driftRisk ?? 0.0) >= 0.65) {
      return 'inconsistency';
    }

    return 'execution_friction';
  }

  String _trajectory({
    required SIContext context,
    required SIMemoryStore memory,
    required AdaptiveLearningWeights? learning,
    required ContinuityProfile? continuity,
  }) {
    if ((continuity?.driftRisk ?? 0.0) >= 0.72) return 'declining';
    if ((continuity?.continuityScore ?? 0.0) >= 0.72) return 'improving';

    if (memory.snapshots.length >= 4) {
      final int midpoint = memory.snapshots.length ~/ 2;
      final List<SISnapshot> recent = memory.snapshots.take(midpoint).toList();
      final List<SISnapshot> older = memory.snapshots.skip(midpoint).toList();

      final double delta = _quality(recent) - _quality(older);
      if (delta >= 0.08) return 'improving';
      if (delta <= -0.08) return 'declining';
    }

    if ((learning?.momentum ?? 0.5) >= 0.68 &&
        context.userState.fatigue < 0.68) {
      return 'improving';
    }

    if ((learning?.resistance ?? 0.5) >= 0.72 ||
        context.userState.stress >= 0.72) {
      return 'declining';
    }

    return 'stable';
  }

  double _quality(List<SISnapshot> snapshots) {
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
      ((completed + 1) / (completed + skipped + 2)) * 0.6 +
          energy * 0.25 +
          (1 - fatigue) * 0.15,
    );
  }

  String _progressBeat({
    required String arc,
    required String theme,
    required String archetype,
    required String phase,
    required String challenge,
    required String trajectory,
  }) {
    if (arc == 'recovery_arc') {
      return 'You are protecting capacity so the next action can become manageable.';
    }

    if (challenge == 'clarity_gap') {
      return 'You are moving from uncertainty into structure.';
    }

    if (trajectory == 'improving') {
      return 'You are consolidating capability through consistent action.';
    }

    if (trajectory == 'declining') {
      return 'You are noticing friction early enough to reduce the load and recover direction.';
    }

    if (phase == 'consolidation') {
      return 'You are turning repeated effort into a steadier operating rhythm.';
    }

    if (archetype == 'builder') {
      return 'You are shaping scattered intention into one concrete next move.';
    }

    if (theme == 'reflection') {
      return 'You are converting recent experience into useful signal.';
    }

    return 'You are building a clearer path one decision at a time.';
  }

  String _nextPrompt({
    required String arc,
    required String theme,
    required String challenge,
    required SIContext context,
  }) {
    if (arc == 'recovery_arc' || challenge == 'overload') {
      return 'What is the smallest step that would lower pressure right now?';
    }

    if (challenge == 'clarity_gap') {
      return 'What is the one detail that would make the next step clear?';
    }

    if (theme == 'reflection') {
      return 'What did this moment teach you about your next move?';
    }

    if (context.userState.motivation >= 0.7) {
      return 'What chapter can you complete while momentum is available?';
    }

    return 'What chapter do you want to complete today?';
  }

  NarrativeTransition _transition({
    required UserNarrative? previous,
    required UserNarrative current,
  }) {
    if (previous == null) {
      return NarrativeTransition(
        changed: true,
        previousArc: null,
        nextArc: current.arc,
        previousPhase: null,
        nextPhase: current.phase,
        reason: 'Initial narrative established.',
      );
    }

    final bool changed =
        previous.arc != current.arc || previous.phase != current.phase;

    return NarrativeTransition(
      changed: changed,
      previousArc: previous.arc,
      nextArc: current.arc,
      previousPhase: previous.phase,
      nextPhase: current.phase,
      reason: changed
          ? 'Narrative shifted from ${previous.arc}/${previous.phase} to ${current.arc}/${current.phase}.'
          : 'Narrative remained stable.',
    );
  }

  NarrativePrediction _predictNext({
    required UserNarrative narrative,
    required SIContext context,
    required AdaptiveLearningWeights? learning,
    required ContinuityProfile? continuity,
  }) {
    final double regressionRisk = siClamp01(
      context.userState.stress * 0.25 +
          context.userState.cognitiveLoad * 0.25 +
          context.userState.fatigue * 0.2 +
          (learning?.resistance ?? 0.5) * 0.15 +
          (continuity?.driftRisk ?? 0.0) * 0.15,
    );

    final double growthProbability = siClamp01(
      context.userState.motivation * 0.25 +
          context.userState.engagement * 0.25 +
          (learning?.momentum ?? 0.5) * 0.25 +
          (continuity?.continuityScore ?? 0.5) * 0.25,
    );

    if (regressionRisk >= 0.68) {
      return NarrativePrediction(
        nextArc: 'recovery_arc',
        nextPhase: 'recovery',
        regressionRisk: regressionRisk,
        growthProbability: growthProbability,
        reason: 'Load and drift signals suggest recovery may be needed next.',
      );
    }

    if (growthProbability >= 0.68 && narrative.phase != 'consolidation') {
      return NarrativePrediction(
        nextArc: 'growth_arc',
        nextPhase: 'consolidation',
        regressionRisk: regressionRisk,
        growthProbability: growthProbability,
        reason:
            'Momentum and continuity suggest movement toward consolidation.',
      );
    }

    if (narrative.challenge == 'clarity_gap') {
      return NarrativePrediction(
        nextArc: 'orientation_arc',
        nextPhase: 'mid',
        regressionRisk: regressionRisk,
        growthProbability: growthProbability,
        reason: 'Clarity work is likely to remain the next narrative step.',
      );
    }

    return NarrativePrediction(
      nextArc: narrative.arc,
      nextPhase: narrative.phase,
      regressionRisk: regressionRisk,
      growthProbability: growthProbability,
      reason: 'Current arc is likely to continue unless state signals change.',
    );
  }

  SIMemoryStore _writeMemory({
    required SIMemoryStore memory,
    required UserNarrative narrative,
    required NarrativeTransition transition,
    required NarrativePrediction prediction,
    required DateTime timestamp,
  }) {
    SIMemoryStore next = memory.pushRecord(
      MemoryTier.midTerm,
      MemoryRecord(
        content:
            'user_narrative|arc=${narrative.arc}|theme=${narrative.theme}|archetype=${narrative.archetype}|phase=${narrative.phase}|challenge=${narrative.challenge}|trajectory=${narrative.trajectory}',
        timestamp: timestamp,
        relevance: narrative.confidence,
        confidence: narrative.confidence,
        emotionalWeight: narrative.arc == 'recovery_arc' ? 0.72 : 0.42,
        reinforcement: narrative.trajectory == 'improving' ? 2 : 1,
      ),
    );

    if (transition.changed) {
      next = next.pushRecord(
        MemoryTier.longTerm,
        MemoryRecord(
          content:
              'narrative_transition|from=${transition.previousArc ?? 'none'}:${transition.previousPhase ?? 'none'}|to=${transition.nextArc}:${transition.nextPhase}|reason=${transition.reason}',
          timestamp: timestamp,
          relevance: 0.78,
          confidence: 0.72,
          emotionalWeight: transition.nextArc == 'recovery_arc' ? 0.72 : 0.45,
          reinforcement: transition.nextArc == 'growth_arc' ? 2 : 1,
        ),
      );
    }

    if (prediction.regressionRisk >= 0.68) {
      next = next.pushRecord(
        MemoryTier.longTerm,
        MemoryRecord(
          content:
              'narrative_regression_risk|next=${prediction.nextArc}:${prediction.nextPhase}|risk=${prediction.regressionRisk.toStringAsFixed(2)}',
          timestamp: timestamp,
          relevance: prediction.regressionRisk,
          confidence: 0.7,
          emotionalWeight: prediction.regressionRisk,
          reinforcement: 0,
        ),
      );
    } else if (prediction.growthProbability >= 0.68) {
      next = next.pushRecord(
        MemoryTier.longTerm,
        MemoryRecord(
          content:
              'narrative_milestone|next=${prediction.nextArc}:${prediction.nextPhase}|growth=${prediction.growthProbability.toStringAsFixed(2)}',
          timestamp: timestamp,
          relevance: prediction.growthProbability,
          confidence: 0.72,
          emotionalWeight: 0.35,
          reinforcement: 2,
        ),
      );
    }

    return next.dedupe().decay(timestamp);
  }

  UserNarrative? _latestNarrativeFromMemory(SIMemoryStore memory) {
    for (final MemoryRecord record in <MemoryRecord>[
      ...memory.tiered.shortTerm,
      ...memory.tiered.midTerm,
      ...memory.tiered.longTerm,
    ]) {
      if (!record.content.startsWith('user_narrative|')) continue;

      final Map<String, String> parts = _parsePipeFields(record.content);

      return UserNarrative(
        arc: parts['arc'] ?? 'orientation_arc',
        theme: parts['theme'] ?? 'momentum',
        archetype: parts['archetype'] ?? 'guide',
        phase: parts['phase'] ?? 'early',
        challenge: parts['challenge'] ?? 'clarity_gap',
        progressBeat: 'You are continuing an existing narrative thread.',
        nextStoryPrompt: 'What is the next useful chapter?',
        trajectory: parts['trajectory'] ?? 'stable',
        confidence: record.confidence,
        signals: const <String>['memory:previous_narrative'],
        timestamp: record.timestamp,
      );
    }

    return null;
  }

  Map<String, String> _parsePipeFields(String content) {
    final Map<String, String> out = <String, String>{};
    for (final String part in content.split('|').skip(1)) {
      final int index = part.indexOf('=');
      if (index <= 0) continue;
      out[part.substring(0, index)] = part.substring(index + 1);
    }
    return out;
  }

  bool _hasPattern(MicroPatternReport? report, MicroPatternType type) {
    return report?.patterns.any((MicroPattern p) => p.type == type) ?? false;
  }

  String _frameHint(UserNarrative narrative) {
    if (narrative.arc == 'recovery_arc') {
      return 'Narrative frame: protect capacity, reduce pressure, and choose one safe next step.';
    }

    if (narrative.archetype == 'builder') {
      return 'Narrative frame: builder mode — turn intention into one concrete action.';
    }

    if (narrative.archetype == 'restorer') {
      return 'Narrative frame: restorer mode — lower the load and rebuild rhythm.';
    }

    if (narrative.archetype == 'seeker') {
      return 'Narrative frame: seeker mode — reflect without judgment and extract one lesson.';
    }

    if (narrative.archetype == 'analyst') {
      return 'Narrative frame: analyst mode — name one pattern and connect it to the next step.';
    }

    return 'Narrative frame: guide mode — make the next step clear and non-overwhelming.';
  }

  String _truncate(String text, int maxChars) {
    final String clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= maxChars) return clean;

    final String cut = clean.substring(0, maxChars).trim();
    final int punctuation = cut.lastIndexOf(RegExp(r'[.!?]'));

    if (punctuation > 80) return cut.substring(0, punctuation + 1);

    final int space = cut.lastIndexOf(' ');
    return space > 40 ? '${cut.substring(0, space)}...' : '$cut...';
  }
}
