import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_settings_repository.dart';

class UpdateSettings {
  UpdateSettings(this.repository);

  final ISettingsRepository repository;

  Future<void> call(SettingsEntity settings) {
    return repository.saveSettings(settings);
  }
}
