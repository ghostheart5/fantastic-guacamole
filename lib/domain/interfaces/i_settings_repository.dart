import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Workspace
///
/// Bound to SettingsRepository; settings UI uses its own state today.
abstract class ISettingsRepository {
  Future<SettingsEntity?> getSettings();
  Future<void> saveSettings(SettingsEntity settings);
}
