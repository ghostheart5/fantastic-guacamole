import '../../domain/entities/app_settings.dart';

abstract class SettingsRepository {
  AppSettings load();
  void save(AppSettings settings);
  void resetDefaults();
}
