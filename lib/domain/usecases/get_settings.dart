import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_settings_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Workspace
///
/// Registered as getSettingsUseCaseProvider; settings UI currently uses its own
/// state.
class GetSettings {
  GetSettings(this.repository);

  final ISettingsRepository repository;

  Future<SettingsEntity?> call() {
    return repository.getSettings();
  }
}
