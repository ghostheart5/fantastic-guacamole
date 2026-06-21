import '../../entities/si_insight.dart';

class GenerateSIInsightsUseCase {
  List<SIInsight> call({
    required int memoryCount,
    required int commandCount,
    required double emotionLevel,
  }) {
    final SIInsight load = memoryCount > 12
        ? const SIInsight(
            message: 'Cognitive load above safe threshold.',
            severity: InsightSeverity.critical,
          )
        : const SIInsight(
            message: 'Cognitive load stable.',
            severity: InsightSeverity.info,
          );

    final SIInsight command = commandCount > 6
        ? const SIInsight(
            message: 'Command-heavy pattern detected.',
            severity: InsightSeverity.warning,
          )
        : const SIInsight(
            message: 'Balanced command/reflection pattern.',
            severity: InsightSeverity.info,
          );

    final SIInsight affect = emotionLevel > 0.8
        ? const SIInsight(
            message: 'Emotional channel overclocked.',
            severity: InsightSeverity.critical,
          )
        : emotionLevel < 0.3
        ? const SIInsight(
            message: 'Emotional channel suppressed.',
            severity: InsightSeverity.warning,
          )
        : const SIInsight(
            message: 'Emotion channel nominal.',
            severity: InsightSeverity.info,
          );

    return <SIInsight>[load, command, affect];
  }
}
