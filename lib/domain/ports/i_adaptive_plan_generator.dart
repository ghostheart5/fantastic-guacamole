import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/planning/adaptive_plan_policy.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Smart Planner
abstract interface class IAdaptivePlanGenerator {
  List<TimeBlock> generateAdaptivePlan({
    required List<PlannerInput> inputs,
    required double energy,
    DateTime? startTime,
    AdaptivePlanPolicy policy = const AdaptivePlanPolicy(),
  });
}
