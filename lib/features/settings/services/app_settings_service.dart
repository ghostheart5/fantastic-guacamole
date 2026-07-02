import 'package:fantastic_guacamole/features/settings/repositories/app_settings_repository.dart';

class AppSettingsService {
  AppSettingsService(this._repository);

  final AppSettingsRepository _repository;

  Future<Map<String, dynamic>> loadSettings() => _repository.loadSettings();

  Future<void> saveSettings(Map<String, dynamic> settings) =>
      _repository.saveSettings(settings);
}
