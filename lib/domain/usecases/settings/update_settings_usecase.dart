import '../../entities/app_settings.dart';

class UpdateSettingsUseCase {
  AppSettings call({
    required AppSettings current,
    bool? neonRecall,
    bool? siEnabled,
    bool? notifications,
    bool? dataSync,
    bool? compactMode,
    double? textScale,
    double? siTuning,
  }) {
    return AppSettings(
      neonRecall: neonRecall ?? current.neonRecall,
      siEnabled: siEnabled ?? current.siEnabled,
      notifications: notifications ?? current.notifications,
      dataSync: dataSync ?? current.dataSync,
      compactMode: compactMode ?? current.compactMode,
      textScale: textScale ?? current.textScale,
      siTuning: siTuning ?? current.siTuning,
    );
  }
}
