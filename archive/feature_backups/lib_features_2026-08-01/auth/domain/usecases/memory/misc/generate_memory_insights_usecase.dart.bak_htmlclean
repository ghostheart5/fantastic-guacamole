import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/memory/misc/view_memory_analytics_usecase.dart';

class GenerateMemoryInsightsUsecase {
  const GenerateMemoryInsightsUsecase();

  List<String> call(List<MemoryEntity> memories) {
    final MemoryAnalyticsResult analytics = const ViewMemoryAnalyticsUsecase()
        .call(memories);
    final List<String> insights = <String>[];

    if (analytics.total == 0) {
      return const <String>[
        'No memories are captured yet.',
        'Start by saving one preference, lesson, goal context, or personal insight.',
      ];
    }

    if (analytics.recent == 0) {
      insights.add('No recent memories were captured in the last 3 days.');
    }

    if (analytics.unlinkedImportant > 0) {
      insights.add(
        '${analytics.unlinkedImportant} high-importance memory item(s) are not linked to related context.',
      );
    }

    if (analytics.topTags.isNotEmpty) {
      insights.add('Top memory signal: ${analytics.topTags.first}.');
    }

    final int uncategorized =
        analytics.categoryCounts[MemoryCategory.other] ?? 0;
    if (uncategorized > 0) {
      insights.add(
        '$uncategorized memory item(s) are still categorized as other.',
      );
    }

    if (analytics.starred == 0) {
      insights.add(
        'No memories are starred yet. Star key identity, preference, or lesson memories for faster recall.',
      );
    }

    if (analytics.healthScore >= 80) {
      insights.add(
        'Memory layer health is strong at ${analytics.healthScore}%.',
      );
    } else if (analytics.healthScore < 45) {
      insights.add(
        'Memory layer health is low at ${analytics.healthScore}%. Add tags, links, and recent captures.',
      );
    }

    if (insights.isEmpty) {
      insights.add(
        'Memory layer is stable. Keep capturing and linking useful context.',
      );
    }

    return insights;
  }
}
