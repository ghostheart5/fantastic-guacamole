import 'package:fantastic_guacamole/domain/entities/insight_entity.dart';

abstract class IInsightRepository {
  Future<List<InsightEntity>> getInsights();
  Future<void> saveInsight(InsightEntity insight);

  // Optional helpers
  Future<bool> exists(String id);
  Future<void> removeInsight(String id);
  Future<List<InsightEntity>> searchInsights(String query);
}
