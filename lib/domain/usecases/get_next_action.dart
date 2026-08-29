import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/policies/si_policy.dart';

typedef NextActionResolver = Future<SiDecisionEntity> Function();

/// CHRONOSPARK-CLASS: EXPERIMENTAL | Feature: SI Console
///
/// Exploratory entry point for a domain-safe next-action resolver. Mapping raw
/// engine output into [SiDecisionEntity] belongs in the composition layer.
class GetNextAction {
  GetNextAction(this._resolve);

  final NextActionResolver _resolve;

  Future<SiDecisionEntity> call() async {
    return SiPolicy.sanitize(await _resolve());
  }
}
