import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';

abstract class IPlanRepository {
  Future<PlanEntity?> getPlan(DateTime date);
  Future<void> savePlan(PlanEntity plan);
}
