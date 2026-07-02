import 'package:flutter/foundation.dart';

@immutable
class SettingsModel {
  const SettingsModel({
    this.soundEnabled = true,
    this.hapticEnabled = true,
    this.notificationsEnabled = true,
    this.darkMode = true,
    this.focusDurationMinutes = 25,
    this.breakDurationMinutes = 5,
    this.dailyGoalTasks = 5,
    this.language = 'en',
  });

  final bool soundEnabled;
  final bool hapticEnabled;
  final bool notificationsEnabled;
  final bool darkMode;
  final int focusDurationMinutes;
  final int breakDurationMinutes;
  final int dailyGoalTasks;
  final String language;

  SettingsModel copyWith({
    bool? soundEnabled,
    bool? hapticEnabled,
    bool? notificationsEnabled,
    bool? darkMode,
    int? focusDurationMinutes,
    int? breakDurationMinutes,
    int? dailyGoalTasks,
    String? language,
  }) {
    return SettingsModel(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkMode: darkMode ?? this.darkMode,
      focusDurationMinutes: focusDurationMinutes ?? this.focusDurationMinutes,
      breakDurationMinutes: breakDurationMinutes ?? this.breakDurationMinutes,
      dailyGoalTasks: dailyGoalTasks ?? this.dailyGoalTasks,
      language: language ?? this.language,
    );
  }

  Map<String, dynamic> toJson() => {
    'soundEnabled': soundEnabled,
    'hapticEnabled': hapticEnabled,
    'notificationsEnabled': notificationsEnabled,
    'darkMode': darkMode,
    'focusDurationMinutes': focusDurationMinutes,
    'breakDurationMinutes': breakDurationMinutes,
    'dailyGoalTasks': dailyGoalTasks,
    'language': language,
  };

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
    soundEnabled: json['soundEnabled'] as bool? ?? true,
    hapticEnabled: json['hapticEnabled'] as bool? ?? true,
    notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    darkMode: json['darkMode'] as bool? ?? true,
    focusDurationMinutes: (json['focusDurationMinutes'] as num?)?.toInt() ?? 25,
    breakDurationMinutes: (json['breakDurationMinutes'] as num?)?.toInt() ?? 5,
    dailyGoalTasks: (json['dailyGoalTasks'] as num?)?.toInt() ?? 5,
    language: json['language'] as String? ?? 'en',
  );
}
