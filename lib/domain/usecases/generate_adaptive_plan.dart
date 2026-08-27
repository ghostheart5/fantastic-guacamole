import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/engine/planning/calendar_service.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Smart Planner
///
/// Domain entry point for the shipping Smart Planner. The generation rules
/// themselves stay in [CalendarService] — this wraps them so callers depend on
/// a use case instead of reaching into the engine directly.
///
/// Before this existed, `generateAdaptivePlan` was invoked from a screen, two
/// controllers, and a provider, so the planner had no domain representation at
/// all. Deliberately does not duplicate the scoring or duration rules.
class GenerateAdaptivePlan {
  const GenerateAdaptivePlan(this._calendarService);

  final CalendarService _calendarService;

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
    return _calendarService.generateAdaptivePlan(
      inputs: inputs,
      energy: energy,
      startTime: startTime,
      policy: policy,
    );
  }
}
