import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';

class GetPlan {
  GetPlan(this.repository);

  final IPlanRepository repository;

  Future<PlanEntity?> call(DateTime date) {
    return repository.getPlan(date);
  }
}
