import 'package:fantastic_guacamole/domain/entities/insight_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_insight_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Insights
///
/// Registered as getInsightsUseCaseProvider; insights UI reads
/// insightsBundleProvider.
class GetInsights {
  GetInsights(this.repository);

  final IInsightRepository repository;

  Future<List<InsightEntity>> call() {
    return repository.getInsights();
  }
}
