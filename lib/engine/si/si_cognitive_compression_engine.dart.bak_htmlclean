// lib/engine/si/si_cognitive_compression_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class CompressionConfig {
  const CompressionConfig({
    this.defaultMaxChars = 280,
    this.minimumLimit = 80,
    this.preserveSentences = true,
    this.removeRedundantWhitespace = true,
  });

  final int defaultMaxChars;
  final int minimumLimit;
  final bool preserveSentences;
  final bool removeRedundantWhitespace;
}

class CompressionResult {
  const CompressionResult({
    required this.text,
    required this.wasCompressed,
    required this.originalLength,
    required this.finalLength,
  });

  final String text;
  final bool wasCompressed;
  final int originalLength;
  final int finalLength;
}

class SICognitiveCompressionEngine {
  const SICognitiveCompressionEngine({this.config = const CompressionConfig()});

  final CompressionConfig config;

  CompressionResult compress(
    String input, {
    int? maxChars,
    InstinctGuidance? instinct,
    SIContext? context,
  }) {
    final String cleaned = _clean(input);
    final int originalLength = cleaned.length;

    final int limit = _limit(
      maxChars: maxChars,
      instinct: instinct,
      context: context,
    );

    if (cleaned.length <= limit) {
      return CompressionResult(
        text: cleaned,
        wasCompressed: false,
        originalLength: originalLength,
        finalLength: cleaned.length,
      );
    }

    final String compressed = config.preserveSentences
        ? _sentenceSafe(cleaned, limit)
        : _wordSafe(cleaned, limit);

    return CompressionResult(
      text: compressed,
      wasCompressed: true,
      originalLength: originalLength,
      finalLength: compressed.length,
    );
  }

  String summarizeTrace(SICognitionState cognition, {int maxChars = 240}) {
    return compress(
      '${cognition.trace.plan}. ${cognition.trace.evaluate}. ${cognition.trace.refine}. ${cognition.prediction.outcome}.',
      maxChars: maxChars,
    ).text;
  }

  String _clean(String input) {
    final String value = config.removeRedundantWhitespace
        ? input.replaceAll(RegExp(r'\s+'), ' ').trim()
        : input.trim();

    return value.isEmpty ? 'No summary available.' : value;
  }

  int _limit({int? maxChars, InstinctGuidance? instinct, SIContext? context}) {
    int limit = maxChars ?? config.defaultMaxChars;

    if (instinct?.safetyFirst ?? false) limit = limit > 220 ? 220 : limit;
    if (instinct?.avoidOverwhelm ?? false) limit = limit > 180 ? 180 : limit;
    if ((context?.userState.cognitiveLoad ?? 0) >= 0.75) {
      limit = limit > 180 ? 180 : limit;
    }

    return limit < config.minimumLimit ? config.minimumLimit : limit;
  }

  String _sentenceSafe(String text, int limit) {
    final StringBuffer buffer = StringBuffer();

    for (final RegExpMatch match in RegExp(r'[^.!?]+[.!?]?').allMatches(text)) {
      final String sentence = match.group(0)?.trim() ?? '';
      if (sentence.isEmpty) continue;

      final String candidate = buffer.isEmpty
          ? sentence
          : '${buffer.toString()} $sentence';

      if (candidate.length > limit) break;

      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(sentence);
    }

    final String result = buffer.toString().trim();
    if (result.length >= 40) return result;

    return _wordSafe(text, limit);
  }

  String _wordSafe(String text, int limit) {
    if (text.length <= limit) return text;

    final String cut = text.substring(0, limit).trim();
    final int space = cut.lastIndexOf(' ');

    if (space > 40) return '${cut.substring(0, space).trim()}...';
    return '$cut...';
  }
}
