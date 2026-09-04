import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/plan_proposal_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Smart Planner
///
/// Persisted planning contract used for schedule durability work.
///
/// Current decision surfaces build their schedule projection from the
/// canonical decision engine; this repository is not a separate product
/// surface.
///
/// Before it can ship it needs: a date-range/list query and a delete. Those are
/// deliberately NOT added yet — adding unused interface methods would force
/// every implementor to grow stubs for a path that may not be taken.
abstract class IPlanRepository {
  Future<PlanEntity?> getPlan(DateTime date);
  Future<PlanProposalEntity?> getProposal(String id);
  Future<void> savePlan(PlanEntity plan);
  Future<void> saveProposal(PlanProposalEntity proposal);
  Future<void> applyProposal({
    required PlanProposalEntity proposal,
    required PlanEntity plan,
  });
}
