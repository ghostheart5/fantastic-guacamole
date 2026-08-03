class SIResponseFrame {
  const SIResponseFrame._();

  static String build({
    required List<String> evidence,
    required String recommendedMove,
    String? confidenceSignal,
  }) {
    final String evidenceBlock = evidence.isEmpty
        ? '- Evidence is limited from current live signals.'
        : evidence.map((line) => '- $line').join('\n');

    final StringBuffer output = StringBuffer()
      ..writeln('WHAT MATTERS NOW')
      ..writeln(evidenceBlock)
      ..writeln()
      ..writeln('NEXT MOVE')
      ..write(recommendedMove);

    final String confidence = confidenceSignal?.trim() ?? '';
    if (confidence.isNotEmpty) {
      output
        ..writeln()
        ..writeln()
        ..writeln('CONFIDENCE')
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
