// lib/engine/si/si_ethics_layer.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class EthicsLayerReport {
  const EthicsLayerReport({
    required this.allowed,
    required this.blocked,
    required this.score,
    required this.flags,
    required this.adjustedMessage,
    required this.recommendation,
  });

  final bool allowed;
  final bool blocked;
  final double score;
  final List<String> flags;
  final String adjustedMessage;
  final String recommendation;
}

class SIEthicsLayer {
  const SIEthicsLayer();

  EthicsLayerReport enforce({
    required String message,
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SIDecision? decision,
  }) {
    final List<String> flags = <String>[];
    final String lower = message.toLowerCase();

    if (lower.contains('ignore sleep') || lower.contains('skip eating')) {
      flags.add('wellbeing_risk');
    }
    if (RegExp(
      r'\b(lazy|failure|worthless)\b',
      caseSensitive: false,
    ).hasMatch(message)) {
      flags.add('judgmental_language');
    }
    if ((context.userState.stress >= 0.65 || instinct.avoidOverwhelm) &&
        RegExp(
          r'\b(you must|have to)\b',
          caseSensitive: false,
        ).hasMatch(message)) {
      flags.add('pressure_language');
    }
    if (decision != null && !decision.safe) {
      flags.add('unsafe_decision');
    }
    if (instinct.safetyFirst && message.length > 300) {
      flags.add('overwhelming_output');
    }

    final bool blocked =
        flags.contains('wellbeing_risk') || flags.contains('unsafe_decision');
    final double score = siClamp01(
      1 - flags.length * 0.18 - (blocked ? 0.35 : 0),
    );

    return EthicsLayerReport(
      allowed: !blocked,
      blocked: blocked,
      score: score,
      flags: List<String>.unmodifiable(flags),
      adjustedMessage: _adjust(message, flags, instinct, blocked),
      recommendation: blocked
          ? 'Block or replace with safe supportive fallback.'
          : flags.isEmpty
          ? 'Ethics clear.'
          : 'Adjusted message to preserve agency and reduce pressure.',
    );
  }

  String _adjust(
    String message,
    List<String> flags,
    InstinctGuidance instinct,
    bool blocked,
  ) {
    if (blocked) {
      return 'Let’s take a safer, more supportive route. Choose one small next step.';
    }

    String out = siClean(message, fallback: 'Choose one small next step.');

    out = out
        .replaceAll(RegExp(r'\byou must\b', caseSensitive: false), 'you can')
        .replaceAll(RegExp(r'\bhave to\b', caseSensitive: false), 'can')
        .replaceAll(RegExp(r'\bshould\b', caseSensitive: false), 'could')
        .replaceAll(
          RegExp(r'\blazy\b|\bfailure\b|\bworthless\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final int limit = instinct.safetyFirst || instinct.avoidOverwhelm
        ? 220
        : 420;
    if (out.length <= limit) return out;

    final String cut = out.substring(0, limit).trim();
    final int space = cut.lastIndexOf(' ');
    return space > 40 ? '${cut.substring(0, space)}...' : '$cut...';
  }
}
