import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/ports/i_adaptive_plan_generator.dart';
import 'package:fantastic_guacamole/domain/planning/adaptive_plan_policy.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Smart Planner
///
/// Domain entry point for the shipping Smart Planner. The generation rules
/// themselves stay behind [IAdaptivePlanGenerator], so callers depend on a
/// domain-owned capability instead of a concrete engine.
///
/// Before this existed, `generateAdaptivePlan` was invoked from a screen, two
/// controllers, and a provider, so the planner had no domain representation at
/// all. Deliberately does not duplicate the scoring or duration rules.
class GenerateAdaptivePlan {
  const GenerateAdaptivePlan(this._generator);

  final IAdaptivePlanGenerator _generator;

  /// Builds the in-memory adaptive day plan. [energy] is clamped by the engine.
  List<TimeBlock> call({
    required List<PlannerInput> inputs,
    required double energy,
    DateTime? startTime,
    AdaptivePlanPolicy policy = const AdaptivePlanPolicy(),
  }) {
    if (inputs.isEmpty) {
      return const <TimeBlock>[];
    }
    return _generator.generateAdaptivePlan(
      inputs: inputs,
      energy: energy,
      startTime: startTime,
      policy: policy,
    );
  }
}
