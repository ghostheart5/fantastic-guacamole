// CHRONOSPARK-CLASS: SHIPPING | Feature: Milestones
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';

abstract class IMilestoneRepository {
  Future<List<MilestoneEntity>> getMilestones();
  Future<void> saveMilestones(List<MilestoneEntity> milestones);
}
