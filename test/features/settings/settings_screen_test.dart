import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens without provider crash', (WidgetTester tester) async {
    final ValueNotifier<bool?> permissionListenable = ValueNotifier<bool?>(
      true,
    );
    addTearDown(permissionListenable.dispose);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        settingsUiActionsProvider.overrideWith(
          (Ref ref) => _FakeSettingsUiActions(ref),
        ),
        notificationPermissionListenableProvider.overrideWithValue(
          permissionListenable,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('COMMAND MATRIX'), findsOneWidget);
    expect(find.text('SYSTEM TUNING'), findsOneWidget);
  });
}

class _FakeSettingsUiActions extends SettingsUiActions {
  _FakeSettingsUiActions(super.ref);

  @override
  ReflectionReminderPrefs loadReflectionReminderPrefs() {
    return const ReflectionReminderPrefs(
      enabled: false,
      time: TimeOfDay(hour: 20, minute: 0),
    );
  }

  @override
  Future<bool> setReflectionReminderEnabled({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    return enabled;
  }

  @override
  Future<void> setReflectionReminderTime({required TimeOfDay time}) async {}

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> requestVoicePermission() async => true;

  @override
  Future<bool> openSystemAppSettings() async => true;
}
