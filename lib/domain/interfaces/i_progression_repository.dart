import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';

abstract class IProgressionRepository {
  Future<ProgressionEntity?> getProgression();
  Future<void> saveProgression(ProgressionEntity progression);
}
