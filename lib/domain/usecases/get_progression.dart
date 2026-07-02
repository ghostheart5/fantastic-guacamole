import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';

class GetProgression {
  GetProgression(this.repository);

  final IProgressionRepository repository;

  Future<ProgressionEntity?> call() {
    return repository.getProgression();
  }
}
