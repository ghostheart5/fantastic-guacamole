import 'package:fantastic_guacamole/domain/entities/insight_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_insight_repository.dart';

class GenerateInsight {
  GenerateInsight(this.repository);

  final IInsightRepository repository;

  Future<InsightEntity> call(InsightEntity insight) async {
    await repository.saveInsight(insight);
    return insight;
  }
}
