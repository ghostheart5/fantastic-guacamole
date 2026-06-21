import '../../entities/app_settings.dart';

class ResetSettingsUseCase {
  AppSettings call() {
    return const AppSettings(
      neonRecall: false,
      siEnabled: true,
      notifications: true,
      dataSync: true,
      compactMode: false,
      textScale: 1,
      siTuning: 0.55,
    );
  }
}
