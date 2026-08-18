import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/policies/si_policy.dart';
import 'package:fantastic_guacamole/engine/si/api.dart';

/// CHRONOSPARK-CLASS: EXPERIMENTAL | Feature: SI Console
///
/// Exploratory natural-language entry point onto the SI engine. No provider;
/// depends on the engine layer directly.
/// Architecture note: this use case depends on the engine layer directly
/// (`SIEngineService` is a concrete type, not a domain interface), which
/// inverts the dependency rule. Introduce a domain-owned SI engine port and
/// have the engine implement it. Tracked separately — not changed here to keep
/// this pass reviewable.
class GetNextAction {
  GetNextAction(this._siEngine);

  final SIEngineService _siEngine;

  Future<SiDecisionEntity> call() async {
    final output = await _siEngine.handleText('what should the user do next?');
    // Raw engine output must pass the same terminal safety gate as any other
    // decision before it leaves the domain.
    return SiPolicy.sanitize(
      SiDecisionEntity(
        selectedTaskId: output.decision.task?.id,
        rationale: output.decision.reasoning,
        action: output.decision.action,
        shouldTakeBreak: false,
        reasoningTrace: output.core.cognition.summary,
      ),
    );
  }
}
