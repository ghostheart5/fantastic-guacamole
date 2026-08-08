import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Smart Planner
///
/// Persisted-plan path. Registered as createPlanUseCaseProvider; no production
/// consumer yet.
/// See [IPlanRepository] for the shipping-vs-planned split.
class CreatePlan {
  CreatePlan(this.repository);

  final IPlanRepository repository;

  Future<PlanEntity> call(PlanEntity plan) async {
    await repository.savePlan(plan);
    return plan;
  }
}
