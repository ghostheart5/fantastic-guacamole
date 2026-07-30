import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_settings_repository.dart';

class GetSettings {
  GetSettings(this.repository);

  final ISettingsRepository repository;

  Future<SettingsEntity?> call() {
    return repository.getSettings();
  }
}
