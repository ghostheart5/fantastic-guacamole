import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Smart Planner
///
/// Persisted-plan path. Registered as updatePlanUseCaseProvider; no production
/// consumer yet.
/// See [IPlanRepository] for the shipping-vs-planned split.
class UpdatePlan {
  UpdatePlan(this.repository);

  final IPlanRepository repository;

  /// Saves [plan] with a refreshed `updatedAt` and returns the object that was
  /// actually persisted. It previously returned the caller's stale input, so
  /// the caller's copy silently diverged from storage.
  Future<PlanEntity> call(PlanEntity plan, {DateTime? updatedAt}) async {
    final PlanEntity persisted = plan.copyWith(
      updatedAt: updatedAt ?? DateTime.now(),
    );
    await repository.savePlan(persisted);
    return persisted;
  }
}
