// ignore_for_file: prefer_const_constructors

import 'dart:ui';

import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart'
    as extended_domain;
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
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
  group('Secondary UI frame budget performance', () {
    testWidgets('settings screen pumps within frame budget envelope', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final Stopwatch stopwatch = Stopwatch()..start();
      final List<FrameTiming> timings = <FrameTiming>[];
      void onTimings(List<FrameTiming> value) => timings.addAll(value);
      WidgetsBinding.instance.addTimingsCallback(onTimings);
      addTearDown(
        () => WidgetsBinding.instance.removeTimingsCallback(onTimings),
      );

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

      for (int i = 0; i < 18; i += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(2800));
      _assertFrameTimingsWithinBudget(
        timings: timings,
        maxBuildMs: 24,
        maxRasterMs: 24,
      );
    });

    testWidgets('nexus screen first paint stays within budget envelope', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final Stopwatch stopwatch = Stopwatch()..start();
      final List<FrameTiming> timings = <FrameTiming>[];
      void onTimings(List<FrameTiming> value) => timings.addAll(value);
      WidgetsBinding.instance.addTimingsCallback(onTimings);
      addTearDown(
        () => WidgetsBinding.instance.removeTimingsCallback(onTimings),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationsProvider.overrideWith((Ref ref) => 0),
            nexusStartupSummaryProvider.overrideWith(
              (Ref ref) => NexusStartupSummary(
                profile: ProfileState(
                  xp: 420,
                  level: 3,
                  streak: 6,
                  longestStreak: 10,
                  name: 'Operative',
                  profileReady: true,
                ),
                energy: 0.72,
                fatigue: 0.24,
                completedToday: 3,
                emotionLabel: 'focused',
                startupDirective:
                    'Prime objective locked. Execute one decisive action now.',
              ),
            ),
          ],
          child: const MaterialApp(home: NexusScreen()),
        ),
      );

      // Do not advance extra frames to avoid deferred heavy section noise.
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(2100));
      _assertFrameTimingsWithinBudget(
        timings: timings,
        maxBuildMs: 22,
        maxRasterMs: 22,
      );
    });
  });
}

void _assertFrameTimingsWithinBudget({
  required List<FrameTiming> timings,
  required int maxBuildMs,
  required int maxRasterMs,
}) {
  if (timings.isEmpty) {
    return;
  }

  int worstBuildMs = 0;
  int worstRasterMs = 0;
  for (final FrameTiming timing in timings) {
    final int buildMs = timing.buildDuration.inMilliseconds;
    final int rasterMs = timing.rasterDuration.inMilliseconds;
    if (buildMs > worstBuildMs) {
      worstBuildMs = buildMs;
    }
    if (rasterMs > worstRasterMs) {
      worstRasterMs = rasterMs;
    }
  }

  expect(
    worstBuildMs,
    lessThanOrEqualTo(maxBuildMs),
    reason: 'Worst build time exceeded budget. ms=$worstBuildMs',
  );
  expect(
    worstRasterMs,
    lessThanOrEqualTo(maxRasterMs),
    reason: 'Worst raster time exceeded budget. ms=$worstRasterMs',
  );
}
