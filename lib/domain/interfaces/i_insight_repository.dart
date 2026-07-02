import 'package:fantastic_guacamole/domain/entities/insight_entity.dart';

abstract class IInsightRepository {
  Future<List<InsightEntity>> getInsights();
  Future<void> saveInsight(InsightEntity insight);
}
