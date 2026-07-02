import 'package:fantastic_guacamole/features/si_engine/repositories/si_engine_repository.dart';

class SiEngineService {
  SiEngineService(this._repository);

  final SiEngineRepository _repository;

  Future<Map<String, dynamic>?> loadState() => _repository.loadState();

  Future<void> saveState(Map<String, dynamic> state) =>
      _repository.saveState(state);
}
