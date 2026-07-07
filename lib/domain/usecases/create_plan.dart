import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';

class CreatePlan {
  CreatePlan(this.repository);

  final IPlanRepository repository;

  Future<PlanEntity> call(PlanEntity plan) async {
    await repository.savePlan(plan);
    return plan;
  }
}
