class SettingsEntity {
  const SettingsEntity({
    this.soundEnabled = true,
    this.notificationsEnabled = true,
    this.themeMode = 'system',
    this.onboardingComplete = false,
  });

  final bool soundEnabled;
  final bool notificationsEnabled;
  final String themeMode;
  final bool onboardingComplete;

  SettingsEntity copyWith({
    bool? soundEnabled,
    bool? notificationsEnabled,
    String? themeMode,
    bool? onboardingComplete,
  }) {
    return SettingsEntity(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }
}
