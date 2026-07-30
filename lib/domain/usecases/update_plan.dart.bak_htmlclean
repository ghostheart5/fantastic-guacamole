import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';

class UpdatePlan {
  UpdatePlan(this.repository);

  final IPlanRepository repository;

  Future<PlanEntity> call(PlanEntity plan) async {
    await repository.savePlan(plan.copyWith(updatedAt: DateTime.now()));
    return plan;
  }
}
