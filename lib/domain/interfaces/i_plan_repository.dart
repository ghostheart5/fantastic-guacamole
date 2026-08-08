import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Smart Planner
///
/// Planned/alternate planner path. Not currently used by production UI.
///
/// The shipping Smart Planner builds its day view in-memory from tasks via
/// `lib/engine/planning/calendar_service.dart` (see `PlanScreen`). This
/// persisted plan path is complete and DI-wired but has no consumer yet.
///
/// Before it can ship it needs: a date-range/list query and a delete. Those are
/// deliberately NOT added yet — adding unused interface methods would force
/// every implementor to grow stubs for a path that may not be taken.
abstract class IPlanRepository {
  Future<PlanEntity?> getPlan(DateTime date);
  Future<void> savePlan(PlanEntity plan);
}
