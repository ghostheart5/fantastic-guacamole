import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('settings permission state models', () {
    test('unknown snapshot defaults to unknown state and not granted', () {
      const NotificationPermissionSnapshot snapshot =
          NotificationPermissionSnapshot.unknown();

      expect(snapshot.granted, isNull);
      expect(snapshot.permissionState, NotificationPermissionState.unknown);
      expect(snapshot.isGranted, isFalse);
    });

    test('isGranted reflects granted value only when true', () {
      const NotificationPermissionSnapshot granted =
          NotificationPermissionSnapshot(
            granted: true,
            permissionState: NotificationPermissionState.granted,
          );
      const NotificationPermissionSnapshot denied =
          NotificationPermissionSnapshot(
            granted: false,
            permissionState: NotificationPermissionState.denied,
          );

      expect(granted.isGranted, isTrue);
      expect(denied.isGranted, isFalse);
    });
  });

  group('voicePermissionStatusProvider', () {
    test('initial state is null and set updates state', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(voicePermissionStatusProvider), isNull);

      container.read(voicePermissionStatusProvider.notifier).set(true);
      expect(container.read(voicePermissionStatusProvider), isTrue);

      container.read(voicePermissionStatusProvider.notifier).set(false);
      expect(container.read(voicePermissionStatusProvider), isFalse);
    });
  });
}
