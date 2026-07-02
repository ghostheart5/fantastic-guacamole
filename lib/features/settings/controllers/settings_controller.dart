import 'package:fantastic_guacamole/features/settings/models/settings_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsController extends Notifier<SettingsModel> {
  @override
  SettingsModel build() => const SettingsModel();

  void toggleSound() {
    state = state.copyWith(soundEnabled: !state.soundEnabled);
  }

  void toggleHaptic() {
    state = state.copyWith(hapticEnabled: !state.hapticEnabled);
  }

  void toggleNotifications() {
    state = state.copyWith(notificationsEnabled: !state.notificationsEnabled);
  }

  void setFocusDuration(int minutes) {
    state = state.copyWith(focusDurationMinutes: minutes);
  }

  void setBreakDuration(int minutes) {
    state = state.copyWith(breakDurationMinutes: minutes);
  }

  void setDailyGoal(int tasks) {
    state = state.copyWith(dailyGoalTasks: tasks);
  }

  void update(SettingsModel newSettings) {
    state = newSettings;
  }
}
