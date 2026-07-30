// lib/engine/si/si_policy_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIPolicyReport {
  const SIPolicyReport({
    required this.allowed,
    required this.flags,
    required this.adjustedText,
    required this.maxOutputChars,
  });

  final bool allowed;
  final List<String> flags;
  final String adjustedText;
  final int maxOutputChars;
}

class SIPolicyEngine {
  const SIPolicyEngine();

  SIPolicyReport apply({
    required String text,
    required SIContext context,
    required InstinctGuidance instinct,
    SIDecision? decision,
  }) {
    final List<String> flags = <String>[];
    final String lower = text.toLowerCase();

    if (lower.contains('ignore sleep') || lower.contains('skip eating')) {
      flags.add('wellbeing_risk');
    }
    if (RegExp(
      r'\b(lazy|failure|worthless)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      flags.add('judgmental_language');
    }
    if ((context.userState.stress >= .65 || instinct.avoidOverwhelm) &&
        RegExp(
          r'\b(you must|have to)\b',
          caseSensitive: false,
        ).hasMatch(text)) {
      flags.add('pressure_language');
    }
    if (decision != null && !decision.safe) flags.add('unsafe_decision');

    final bool blocked =
        flags.contains('wellbeing_risk') || flags.contains('unsafe_decision');
    final int max = instinct.safetyFirst || instinct.avoidOverwhelm ? 220 : 420;

    return SIPolicyReport(
      allowed: !blocked,
      flags: List<String>.unmodifiable(flags),
      adjustedText: blocked
          ? 'Let’s take a safer route. Choose one small next step.'
          : _soften(text, max),
      maxOutputChars: max,
    );
  }

  String _soften(String text, int max) {
    String out = siClean(text, fallback: 'Choose one small next step.')
        .replaceAll(RegExp(r'\byou must\b', caseSensitive: false), 'you can')
        .replaceAll(RegExp(r'\bhave to\b', caseSensitive: false), 'can')
        .replaceAll(RegExp(r'\bshould\b', caseSensitive: false), 'could')
        .replaceAll(
          RegExp(r'\blazy\b|\bfailure\b|\bworthless\b', caseSensitive: false),
          '',
        )
        .trim();

    if (out.length <= max) return out;
    final String cut = out.substring(0, max).trim();
    final int space = cut.lastIndexOf(' ');
    return space > 40 ? '${cut.substring(0, space)}...' : '$cut...';
  }
}
