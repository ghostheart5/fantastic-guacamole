import '../../domain/entities/app_settings.dart';
import '../services/settings_service.dart';
import 'settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({SettingsService? service})
    : _service = service ?? SettingsService();

  final SettingsService _service;

  @override
  AppSettings load() {
    return AppSettings(
      neonRecall: _service.neonRecall,
      siEnabled: _service.siModule,
      notifications: _service.notifications,
      dataSync: _service.dataSync,
      compactMode: _service.compactMode,
      textScale: _service.textScale,
      siTuning: _service.siTuning,
    );
  }

  @override
  void resetDefaults() {
    _service.resetAll();
  }

  @override
  void save(AppSettings settings) {
    _service.setNeonRecall(settings.neonRecall);
    _service.setSiModule(settings.siEnabled);
    _service.setNotifications(settings.notifications);
    _service.setDataSync(settings.dataSync);
    _service.setCompactMode(settings.compactMode);
    _service.setTextScale(settings.textScale);
    _service.setSiTuning(settings.siTuning);
  }
}
