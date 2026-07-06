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

  // Domain behavior
  SettingsEntity toggleSound() => copyWith(soundEnabled: !soundEnabled);

  SettingsEntity toggleNotifications() =>
      copyWith(notificationsEnabled: !notificationsEnabled);

  SettingsEntity setTheme(String mode) => copyWith(themeMode: mode);

  SettingsEntity completeOnboarding() => copyWith(onboardingComplete: true);

  bool get isDarkMode => themeMode == 'dark';
  bool get isLightMode => themeMode == 'light';
  bool get isSystemMode => themeMode == 'system';

  void validate() {
    const allowed = ['light', 'dark', 'system'];
    if (!allowed.contains(themeMode)) {
      throw StateError('Invalid theme mode: $themeMode');
    }
  }
}
