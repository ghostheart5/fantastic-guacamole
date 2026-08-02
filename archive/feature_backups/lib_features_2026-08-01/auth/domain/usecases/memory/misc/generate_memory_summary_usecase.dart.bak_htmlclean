import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/memory/misc/view_memory_analytics_usecase.dart';

class MemorySummaryResult {
  const MemorySummaryResult({
    required this.headline,
    required this.detail,
    required this.healthScore,
  });

  final String headline;
  final String detail;
  final int healthScore;
}

class GenerateMemorySummaryUsecase {
  const GenerateMemorySummaryUsecase();

  MemorySummaryResult call(List<MemoryEntity> memories) {
    final MemoryAnalyticsResult analytics = const ViewMemoryAnalyticsUsecase()
        .call(memories);

    if (analytics.total == 0) {
      return const MemorySummaryResult(
        headline: 'No memories captured yet.',
        detail:
            'Capture preferences, lessons, goals, insights, and important context to strengthen the memory layer.',
        healthScore: 0,
      );
    }

    final String topTag = analytics.topTags.isEmpty
        ? 'no dominant tag yet'
        : analytics.topTags.first;
    final String headline =
        '${analytics.total} memories tracked, ${analytics.recent} recent.';
    final String detail =
        'Memory health ${analytics.healthScore}%. Top signal: $topTag. '
        '${analytics.starred} starred, ${analytics.highImportance} high-importance, '
        '${analytics.linked} linked, ${analytics.archived} archived.';

    return MemorySummaryResult(
      headline: headline,
      detail: detail,
      healthScore: analytics.healthScore,
    );
  }
}
