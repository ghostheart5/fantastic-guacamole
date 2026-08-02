class SIResponseFrame {
  const SIResponseFrame._();

  static String build({
    required String signal,
    required String whyItMatters,
    required List<String> evidence,
    required String tradeoff,
    required String recommendedMove,
    String? confidenceSignal,
  }) {
    final String evidenceBlock = evidence.isEmpty
        ? '- Evidence is limited from current live signals.'
        : evidence.map((line) => '- $line').join('\n');

    final StringBuffer output = StringBuffer()
      ..writeln('SIGNAL')
      ..writeln(signal)
      ..writeln()
      ..writeln('WHY IT MATTERS')
      ..writeln(whyItMatters)
      ..writeln()
      ..writeln('EVIDENCE')
      ..writeln(evidenceBlock)
      ..writeln()
      ..writeln('TRADEOFF')
      ..writeln(tradeoff)
      ..writeln()
      ..writeln('RECOMMENDED MOVE')
      ..write(recommendedMove);

    final String confidence = confidenceSignal?.trim() ?? '';
    if (confidence.isNotEmpty) {
      output
        ..writeln()
        ..writeln()
        ..writeln('CONFIDENCE SIGNAL')
        ..write(confidence);
    }

    return output.toString().trim();
  }

  static String signalBandFromPercent(int value) {
    if (value >= 80) return 'signal is strong';
    if (value >= 60) return 'signal is moderate to strong';
    if (value >= 40) return 'signal is emerging';
    return 'evidence is limited and unstable';
  }
}
