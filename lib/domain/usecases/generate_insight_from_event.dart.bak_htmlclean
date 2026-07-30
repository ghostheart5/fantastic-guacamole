import 'package:fantastic_guacamole/domain/entities/insight_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_insight_repository.dart';

class GenerateInsightFromEvent {
  GenerateInsightFromEvent(this.repository);

  final IInsightRepository repository;

  Future<InsightEntity> call({
    required String eventType,
    required String summary,
    List<String> tags = const <String>[],
    String? action,
  }) async {
    final DateTime now = DateTime.now();
    final InsightEntity insight = InsightEntity(
      id: 'insight-${now.microsecondsSinceEpoch}',
      title: eventType,
      summary: summary,
      createdAt: now,
      tags: tags,
      action: action,
    );
    await repository.saveInsight(insight);
    return insight;
  }
}
