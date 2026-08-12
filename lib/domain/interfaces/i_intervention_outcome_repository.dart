import 'package:fantastic_guacamole/domain/interventions/intervention_outcome.dart';

abstract class IInterventionOutcomeRepository {
  List<InterventionOutcome> getOutcomes();
  Future<void> addOutcome(InterventionOutcome outcome);
  Future<void> saveOutcomes(List<InterventionOutcome> outcomes);
  Future<void> removeOutcome(String id);
}
