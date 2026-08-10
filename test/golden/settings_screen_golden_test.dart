// ignore_for_file: prefer_const_constructors

import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart'
    as extended_domain;
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/theme_provider.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeThemeController extends CurrentThemeController {
  @override
  Future<AppThemeEntity> build() async => AppThemeEntity.dark();
}

class _StaticNotificationPermissionNotifier
    extends NotificationPermissionNotifier {
  @override
  NotificationPermissionSnapshot build() {
    return NotificationPermissionSnapshot(
      granted: false,
      permissionState: NotificationPermissionState.denied,
    );
  }

  @override
  Future<NotificationPermissionSnapshot> refresh() async {
    return state;
  }

  @override
  Future<NotificationPermissionSnapshot> requestPermission() async {
    return state;
  }
}

void main() {
  group('settings screen golden', () {
    testWidgets('settings screen matches baseline', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            extended_domain.extendedDomainBootstrapProvider.overrideWith(
              (Ref ref) async {},
            ),
            extended_domain.privacyPoliciesProvider.overrideWith(
              (Ref ref) => const [],
            ),
            appAccessProvider.overrideWith(
              (Ref ref) => const AppAccessState(
                hasPremiumAccess: false,
                hasTesterFullAccess: false,
                paywallDisabled: false,
              ),
            ),
            currentThemeProvider.overrideWith(_FakeThemeController.new),
            notificationPermissionProvider.overrideWith(
              _StaticNotificationPermissionNotifier.new,
            ),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/settings/settings_screen_default.png'),
      );
    });
  });
}
