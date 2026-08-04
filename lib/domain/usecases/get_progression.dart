import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Progression
///
/// Registered as getProgressionUseCaseProvider; awaiting a domain-backed
/// progression screen.
class GetProgression {
  GetProgression(this.repository);

  final IProgressionRepository repository;

  Future<ProgressionEntity?> call() {
    return repository.getProgression();
  }
}
