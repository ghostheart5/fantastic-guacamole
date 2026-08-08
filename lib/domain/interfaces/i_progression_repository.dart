import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Progression
///
/// Bound to ProgressionRepository.
abstract class IProgressionRepository {
  Future<ProgressionEntity?> getProgression();
  Future<void> saveProgression(ProgressionEntity progression);
}
