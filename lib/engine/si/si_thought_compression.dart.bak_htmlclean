// lib/engine/si/si_thought_compression.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum ThoughtCompressionMode { cognition, output, memory, safety }

class ThoughtCompressionConfig {
  const ThoughtCompressionConfig({
    this.defaultMaxChars = 280,
    this.minChars = 80,
    this.outputMaxChars = 420,
    this.safetyMaxChars = 220,
    this.memoryMaxChars = 360,
    this.preserveSentences = true,
  });

  final int defaultMaxChars;
  final int minChars;
  final int outputMaxChars;
  final int safetyMaxChars;
  final int memoryMaxChars;
  final bool preserveSentences;
}

class ThoughtCompressionResult {
  const ThoughtCompressionResult({
    required this.text,
    required this.mode,
    required this.wasCompressed,
    required this.originalLength,
    required this.finalLength,
    required this.compressionRatio,
    required this.memory,
  });

  final String text;
  final ThoughtCompressionMode mode;
  final bool wasCompressed;
  final int originalLength;
  final int finalLength;
  final double compressionRatio;
  final SIMemoryStore memory;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'text': text,
    'mode': mode.name,
    'was_compressed': wasCompressed,
    'original_length': originalLength,
    'final_length': finalLength,
    'compression_ratio': siClamp01(compressionRatio),
  };
}

class SIThoughtCompression {
  const SIThoughtCompression({this.config = const ThoughtCompressionConfig()});

  final ThoughtCompressionConfig config;

  ThoughtCompressionResult compress({
    required String input,
    required SIMemoryStore memory,
    ThoughtCompressionMode mode = ThoughtCompressionMode.output,
    SIContext? context,
    InstinctGuidance? instinct,
    int? maxChars,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();
    final String clean = _clean(input);
    final int limit = _limit(
      mode: mode,
      maxChars: maxChars,
      context: context,
      instinct: instinct,
    );

    final String output = clean.length <= limit
        ? clean
        : config.preserveSentences
        ? _sentenceSafe(clean, limit)
        : _wordSafe(clean, limit);

    final bool compressed = output.length < clean.length;
    final double ratio = clean.isEmpty ? 1.0 : output.length / clean.length;

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'thought_compression|mode=${mode.name}|compressed=$compressed|original=${clean.length}|final=${output.length}',
            timestamp: timestamp,
            relevance: compressed ? 0.68 : 0.42,
            confidence: 0.72,
            emotionalWeight: instinct?.safetyFirst == true ? 0.62 : 0.32,
            reinforcement: compressed ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(timestamp);

    return ThoughtCompressionResult(
      text: output,
      mode: mode,
      wasCompressed: compressed,
      originalLength: clean.length,
      finalLength: output.length,
      compressionRatio: siClamp01(ratio),
      memory: nextMemory,
    );
  }

  ThoughtCompressionResult compressCognition({
    required SICognitionState cognition,
    required SIMemoryStore memory,
    SIContext? context,
    InstinctGuidance? instinct,
    int? maxChars,
    DateTime? now,
  }) {
    final String text =
        '${cognition.trace.plan}. ${cognition.trace.evaluate}. ${cognition.trace.refine}. '
        'Prediction: ${cognition.prediction.outcome}. '
        'Meta: ${cognition.meta.rationale}.';

    return compress(
      input: text,
      memory: memory,
      mode: ThoughtCompressionMode.cognition,
      context: context,
      instinct: instinct,
      maxChars: maxChars,
      now: now,
    );
  }

  ThoughtCompressionResult compressResponse({
    required SIResponse response,
    required SIMemoryStore memory,
    SIContext? context,
    InstinctGuidance? instinct,
    int? maxChars,
    DateTime? now,
  }) {
    return compress(
      input: response.message,
      memory: memory,
      mode: instinct?.safetyFirst == true
          ? ThoughtCompressionMode.safety
          : ThoughtCompressionMode.output,
      context: context,
      instinct: instinct,
      maxChars: maxChars,
      now: now,
    );
  }

  ThoughtCompressionResult compressForMemory({
    required String content,
    required SIMemoryStore memory,
    SIContext? context,
    DateTime? now,
  }) {
    return compress(
      input: content,
      memory: memory,
      mode: ThoughtCompressionMode.memory,
      context: context,
      maxChars: config.memoryMaxChars,
      now: now,
    );
  }

  String _clean(String input) {
    final String value = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.isEmpty ? 'No thought content available.' : value;
  }

  int _limit({
    required ThoughtCompressionMode mode,
    required int? maxChars,
    required SIContext? context,
    required InstinctGuidance? instinct,
  }) {
    int limit =
        maxChars ??
        switch (mode) {
          ThoughtCompressionMode.cognition => config.defaultMaxChars,
          ThoughtCompressionMode.output => config.outputMaxChars,
          ThoughtCompressionMode.memory => config.memoryMaxChars,
          ThoughtCompressionMode.safety => config.safetyMaxChars,
        };

    if (instinct?.safetyFirst == true && limit > config.safetyMaxChars) {
      limit = config.safetyMaxChars;
    }

    if (instinct?.avoidOverwhelm == true && limit > 220) {
      limit = 220;
    }

    if ((context?.userState.cognitiveLoad ?? 0) >= 0.75 && limit > 220) {
      limit = 220;
    }

    return limit < config.minChars ? config.minChars : limit;
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
    final int lastSpace = cut.lastIndexOf(' ');

    if (lastSpace > 40) {
      return '${cut.substring(0, lastSpace).trim()}...';
    }

    return '$cut...';
  }
}
