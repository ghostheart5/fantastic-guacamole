import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Smart Planner
///
/// Persisted-plan path. Registered as getPlanUseCaseProvider; the shipping
/// planner is engine/planning/calendar_service.dart.
/// See [IPlanRepository] for the shipping-vs-planned split.
class GetPlan {
  GetPlan(this.repository);

  final IPlanRepository repository;

  Future<PlanEntity?> call(DateTime date) {
    return repository.getPlan(date);
  }
}
