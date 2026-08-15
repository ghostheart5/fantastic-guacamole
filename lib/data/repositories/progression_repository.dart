import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';

class ProgressionRepository implements IProgressionRepository {
  ProgressionRepository({
    required this.readCurrent,
    required this.writeCurrent,
  });

  final Future<ProgressionEntity?> Function() readCurrent;
  final Future<void> Function(ProgressionEntity progression) writeCurrent;

  @override
  Future<ProgressionEntity?> getProgression() => readCurrent();

  @override
  Future<void> saveProgression(ProgressionEntity progression) =>
      writeCurrent(progression);
}
