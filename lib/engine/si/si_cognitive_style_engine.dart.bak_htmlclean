// lib/engine/si/si_cognitive_style_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class CognitiveStylePlan {
  const CognitiveStylePlan({
    required this.tone,
    required this.format,
    required this.maxChars,
    required this.prefix,
    required this.suffix,
    required this.useBullets,
  });

  final String tone;
  final String format;
  final int maxChars;
  final String prefix;
  final String suffix;
  final bool useBullets;
}

class StyledCognitiveOutput {
  const StyledCognitiveOutput({required this.text, required this.plan});

  final String text;
  final CognitiveStylePlan plan;
}

class SICognitiveStyleEngine {
  const SICognitiveStyleEngine();

  CognitiveStylePlan plan({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    SIDecision? decision,
  }) {
    final bool safety =
        instinct.safetyFirst || (decision != null && !decision.safe);
    final bool confused = context.userState.emotion == 'confused';
    final bool stressed = context.userState.emotion == 'stressed';

    if (safety || stressed) {
      return const CognitiveStylePlan(
        tone: 'calm_supportive',
        format: 'single_step',
        maxChars: 220,
        prefix: '',
        suffix: 'One step only.',
        useBullets: false,
      );
    }

    if (confused || instinct.reduceConfusion) {
      return const CognitiveStylePlan(
        tone: 'clear_direct',
        format: 'stepwise',
        maxChars: 280,
        prefix: '',
        suffix: 'I’ll keep it step-by-step.',
        useBullets: true,
      );
    }

    if (intent.primary.label == 'insight_request') {
      return const CognitiveStylePlan(
        tone: 'precise_practical',
        format: 'short_explanation',
        maxChars: 420,
        prefix: '',
        suffix: '',
        useBullets: false,
      );
    }

    return const CognitiveStylePlan(
      tone: 'focused_supportive',
      format: 'action_first',
      maxChars: 340,
      prefix: '',
      suffix: '',
      useBullets: false,
    );
  }

  StyledCognitiveOutput apply({
    required String message,
    required CognitiveStylePlan plan,
  }) {
    String text = siClean(
      message,
      fallback: 'Tell me what you want to work on.',
    );

    text = _softenPressure(text);

    if (plan.useBullets) {
      text = _toBullets(text);
    }

    if (plan.prefix.isNotEmpty && !text.startsWith(plan.prefix)) {
      text = '${plan.prefix} $text';
    }

    if (plan.suffix.isNotEmpty && !text.contains(plan.suffix)) {
      text = '$text\n\n${plan.suffix}';
    }

    text = _truncate(text, plan.maxChars);

    return StyledCognitiveOutput(text: text, plan: plan);
  }

  String _softenPressure(String text) {
    return text
        .replaceAll(RegExp(r'\byou must\b', caseSensitive: false), 'you can')
        .replaceAll(RegExp(r'\bhave to\b', caseSensitive: false), 'can')
        .replaceAll(RegExp(r'\bshould\b', caseSensitive: false), 'could');
  }

  String _toBullets(String text) {
    final List<String> parts = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map(siClean)
        .where((String p) => p.isNotEmpty)
        .take(3)
        .toList();

    if (parts.length <= 1) return text;
    return parts.map((String p) => '• $p').join('\n');
  }

  String _truncate(String text, int maxChars) {
    final int limit = maxChars < 80 ? 80 : maxChars;
    final String clean = text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();

    if (clean.length <= limit) return clean;

    final String cut = clean.substring(0, limit).trim();
    final int period = cut.lastIndexOf(RegExp(r'[.!?]'));
    if (period > 80) return cut.substring(0, period + 1);

    final int space = cut.lastIndexOf(' ');
    return space > 40 ? '${cut.substring(0, space)}...' : '$cut...';
  }
}
