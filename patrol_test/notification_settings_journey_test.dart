import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fantastic_guacamole/app/startup/app_bootstrap.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';

import 'current_navigation_support.dart';

// Real UI changes only. loadPrefs and pendingForAccount are read oracles.
// This lane observes registration/cancellation, never claims timed delivery.
void main() {
  patrolTest(
    'daily planning settings register cancel and restore actual QA reminders',
    ($) async {
      final package = await PackageInfo.fromPlatform();
      expect(package.packageName, 'com.ghostheart5.chronospark.qa');
      expect(package.version, '4.2.4-qa');
      expect(package.buildNumber, '2026101201');
      expect(Platform.isAndroid && kDebugMode && Env.isLocalMode, isTrue);
      expect(
        Env.cloudServicesEnabled ||
            Env.isMockMode ||
            Env.isMockLoginEnabled ||
            Env.isPaywallDisabled ||
            Env.hasTesterFullAccess,
        isFalse,
      );
      final captureKey = GlobalKey();
      await $.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: const ProviderScope(child: StartupBootstrapGate()),
        ),
      );
      await $.pump(const Duration(seconds: 1));
      await settleCurrentUserNavigation(
        $,
        destinationReady: () => find
            .byTooltip('Open navigation map')
            .hitTestable()
            .evaluate()
            .isNotEmpty,
      );
      final container = ProviderScope.containerOf(
        $.tester.element(find.byType(StartupBootstrapGate).first),
        listen: false,
      );
      final scope = container.read(accountStorageScopeProvider);
      expect(scope.isWritable && scope.rawUserId != null, isTrue);
      final digest = AccountDataRegistry.accountDigest(scope.rawUserId!);
      final scheduler = container.read(notificationSchedulerProvider);
      final reminder = container.read(reminderOrchestratorServiceProvider);
      final initial = reminder.loadPrefs();
      final folder = await getApplicationDocumentsDirectory();
      final run = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      final evidence = Directory('${folder.path}/notification-settings-$run');
      await evidence.create(recursive: true);
      final receipt = File('${evidence.path}/events.jsonl');
      void record(String id, String status, Map<String, Object?> fields) {
        final line = jsonEncode({
          'case': id,
          'status': status,
          'run': run,
          'operator': 'codex_ai',
          'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
          ...fields,
        });
        receipt.writeAsStringSync(
          '$line\n',
          mode: FileMode.append,
          flush: true,
        );
        debugPrint('AXIOMARA_NOTIFICATION_SETTINGS $line');
      }

      Future<String> capture(String id) async {
        await $.pump(const Duration(milliseconds: 100));
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final path = '${evidence.path}/$id.png';
          await File(
            path,
          ).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
          return path;
        } finally {
          image.dispose();
        }
      }

      Future<void> caseRun(
        String id,
        Future<Map<String, Object?>> Function() action,
      ) async {
        record(id, 'started', {});
        try {
          final fields = await action();
          expect($.tester.takeException(), isNull);
          record(id, 'passed', {...fields, 'screenshot': await capture(id)});
        } catch (error) {
          String? screenshot;
          try {
            screenshot = await capture('$id-failed');
          } catch (_) {}
          record(id, 'failed', {
            'error': error.toString(),
            'screenshot': screenshot,
          });
          rethrow;
        }
      }

      Future<void> waitRead(
        Future<bool> Function() ready,
        String reason,
      ) async {
        final deadline = DateTime.now().add(const Duration(seconds: 35));
        while (DateTime.now().isBefore(deadline)) {
          await $.pump(const Duration(milliseconds: 200));
          if (await ready()) return;
        }
        fail(reason);
      }

      Future<void> reveal(Finder target) async {
        // Settings categories grow when opened. Use actual bounds, since fixed
        // downward searches can pass a target after an expansion/layout change.
        var direction = AxisDirection.down;
        var missing = 0;
        for (var attempt = 0; attempt < 40; attempt++) {
          await $.pump(const Duration(milliseconds: 150));
          if (target.hitTestable().evaluate().isNotEmpty) return;
          final scroll = find.byType(Scrollable).hitTestable().first;
          expect(scroll, findsOneWidget);
          if (target.evaluate().isNotEmpty) {
            missing = 0;
            direction =
                $.tester.getRect(target).center.dy <
                    $.tester.getRect(scroll).center.dy
                ? AxisDirection.up
                : AxisDirection.down;
          } else if (++missing % 8 == 0) {
            direction = direction == AxisDirection.down
                ? AxisDirection.up
                : AxisDirection.down;
          }
          await $.tester.drag(
            scroll,
            Offset(0, direction == AxisDirection.up ? 240 : -240),
          );
        }
        fail(
          'Settings target $target remained unreachable after bounded ordinary scrolling.',
        );
      }

      Future<void> tap(Finder target) async {
        await reveal(target);
        await $(target.hitTestable()).tap();
        await $.pump(const Duration(milliseconds: 250));
      }

      Future<void> textTap(String label) => tap(find.text(label));
      Future<void> openSettings() async {
        await tap(find.byTooltip('Open navigation map'));
        await tap(find.widgetWithText(ListTile, 'Control Center'));
        await waitRead(
          () async => find.text('SETTINGS').evaluate().isNotEmpty,
          'Control Center must show Settings.',
        );
      }

      Future<void> openPlanning() async {
        if (find.text('Daily Planning Reminder').evaluate().isEmpty) {
          await textTap('Planning & guidance');
        }
        await waitRead(
          () async =>
              find.text('Daily Planning Reminder').evaluate().isNotEmpty,
          'Daily planning controls must load.',
        );
      }

      Future<void> toggleDaily(bool enabled) async {
        await reveal(find.text('Daily Planning Reminder'));
        final tile = find
            .ancestor(
              of: find.text('Daily Planning Reminder'),
              matching: find.byType(InkWell),
            )
            .first;
        final toggle = find.descendant(of: tile, matching: find.byType(Switch));
        expect(toggle, findsOneWidget);
        if ($.tester.widget<Switch>(toggle).value != enabled) await tap(toggle);
        await waitRead(
          () async =>
              reminder.loadPrefs().dailyPlanningEnabled == enabled &&
              $.tester.widget<Switch>(toggle).value == enabled,
          'Daily planning toggle must persist the requested effective preference.',
        );
        expect($.tester.widget<Switch>(toggle).value, enabled);
      }

      Future<void> pickTime(TimeOfDay time, {bool cancel = false}) async {
        await textTap('Daily Planning Time');
        await $(find.byType(TimePickerDialog)).waitUntilVisible();
        final switchInput = find.byTooltip('Switch to text input mode');
        if (switchInput.evaluate().isNotEmpty) await tap(switchInput);
        final dialog = find.byType(TimePickerDialog);
        final fields = find.descendant(
          of: dialog,
          matching: find.byType(TextField),
        );
        expect(fields, findsNWidgets(2));
        final twelveHour =
            find
                .descendant(of: dialog, matching: find.text('AM'))
                .evaluate()
                .isNotEmpty &&
            find
                .descendant(of: dialog, matching: find.text('PM'))
                .evaluate()
                .isNotEmpty;
        final hour = twelveHour
            ? (time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod)
            : time.hour;
        await $(fields.at(0)).enterText(hour.toString());
        await $(fields.at(1)).enterText(time.minute.toString().padLeft(2, '0'));
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        if (twelveHour) {
          await tap(
            find.descendant(
              of: dialog,
              matching: find.text(time.period == DayPeriod.am ? 'AM' : 'PM'),
            ),
          );
        }
        await tap(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(TextButton, cancel ? 'Cancel' : 'OK'),
          ),
        );
        if (!cancel) {
          await waitRead(
            () async =>
                reminder.loadPrefs().dailyPlanningHour == time.hour &&
                reminder.loadPrefs().dailyPlanningMinute == time.minute,
            'Selected time must persist exactly.',
          );
        }
      }

      Future<List<Map<String, Object?>>> pending() async => [
        for (final item in await scheduler.pendingForAccount(digest))
          {
            'id': item.id,
            'title': item.title,
            'body': item.body,
            'hour': item.hour,
            'minute': item.minute,
          },
      ];
      Future<List<Map<String, Object?>>> dailyPending() async =>
          (await pending())
              .where((item) => item['id'] == 'daily_planning_reminder')
              .toList();
      record('scope', 'bounded', {
        'package': package.packageName,
        'version': package.version,
        'build_number': package.buildNumber,
        'initial_daily_enabled': initial.dailyPlanningEnabled,
        'initial_hour': initial.dailyPlanningHour,
        'initial_minute': initial.dailyPlanningMinute,
        'limits': [
          'No master notification preference switch exists on this Settings surface',
          'OS registration/cancellation only; no timed delivery or background claim',
          'Initial effective daily settings restored; raw absent/default preference keys may become explicit',
          'An explicitly allowed QA notification permission stays granted',
        ],
      });
      await openSettings();
      await caseRun('notification-permission-info', () async {
        await textTap('Appearance & permissions');
        await reveal(find.text('Alert Permission'));
        expect(
          find.textContaining('reminder text may appear in device previews'),
          findsOneWidget,
        );
        final initialPermission = container
            .read(notificationPermissionListenableProvider)
            .value;
        if (initialPermission != true) {
          if (find.text('Enable Notifications').evaluate().isNotEmpty) {
            await textTap('Enable Notifications');
            expect(find.text('WHEN IT IS USED'), findsOneWidget);
            await textTap('Allow Notifications');
            final shown = await $.platform.mobile.isPermissionDialogVisible(
              timeout: const Duration(seconds: 5),
            );
            if (shown) {
              // Only the preceding QA notifications action may initiate this prompt.
              await $.platform.mobile.grantPermissionWhenInUse();
              record(
                'qa-native-notification-prompt',
                'approved-through-os-ui',
                {'package': package.packageName},
              );
            }
            await waitRead(
              () async =>
                  container
                      .read(notificationPermissionListenableProvider)
                      .value ==
                  true,
              'Visible QA notification permission request must read back Granted.',
            );
          } else {
            record('notification-permission-recovery', 'blocked', {
              'permission': initialPermission,
              'visible_denied_recovery': find
                  .text('Permission Denied')
                  .evaluate()
                  .isNotEmpty,
              'reason':
                  'Current production UI exposes system-settings recovery, not a re-request action. Ordinary QA system settings recovery is required before schedule acceptance.',
              'screenshot': await capture('permission-recovery-blocked'),
            });
            fail(
              'QA notifications are denied; no visible in-app re-request control is available. No permission bypass was used.',
            );
          }
        }
        expect(
          container.read(notificationPermissionListenableProvider).value,
          isTrue,
        );
        expect(find.textContaining('Granted'), findsWidgets);
        return {
          'initial_permission': initialPermission,
          'final_permission': true,
          'device_preview_disclosure_present': true,
        };
      });
      await openPlanning();
      var restoreNeeded = false;
      try {
        restoreNeeded = true;
        await caseRun('daily-planning-disable-cancellation', () async {
          await toggleDaily(false);
          await waitRead(
            () async => (await dailyPending()).isEmpty,
            'Disabling must cancel the actual account-scoped daily planning registration.',
          );
          return {
            'effective_enabled': false,
            'actual_os_daily_requests': await dailyPending(),
          };
        });
        await caseRun('daily-planning-time-schedule-and-cancel-edit', () async {
          await toggleDaily(true);
          final target = DateTime.now().add(const Duration(minutes: 3));
          final time = TimeOfDay.fromDateTime(target);
          await pickTime(time);
          await waitRead(
            () async {
              final requests = await dailyPending();
              return requests.length == 1 &&
                  requests.single['hour'] == time.hour &&
                  requests.single['minute'] == time.minute;
            },
            'Exactly one real OS daily request must carry the selected hour/minute.',
          );
          final registered = await dailyPending();
          final cancelTime = TimeOfDay(
            hour: (time.hour + 1) % 24,
            minute: time.minute,
          );
          await pickTime(cancelTime, cancel: true);
          final prefs = reminder.loadPrefs();
          expect(prefs.dailyPlanningHour, time.hour);
          expect(prefs.dailyPlanningMinute, time.minute);
          expect(await dailyPending(), equals(registered));
          record('temporary-schedule', 'registered-not-delivery-tested', {
            'target_local': target.toIso8601String(),
            'actual_os_requests': registered,
            'restore_required': true,
          });
          return {
            'selected_hour': time.hour,
            'selected_minute': time.minute,
            'actual_os_requests': registered,
            'cancel_edit_preserved_time_and_request': true,
            'delivery_verified': false,
          };
        });
        await caseRun('daily-planning-cancel-temporary-registration', () async {
          await toggleDaily(false);
          await waitRead(
            () async => (await dailyPending()).isEmpty,
            'Temporary QA registration must be canceled.',
          );
          return {
            'temporary_registration_canceled': true,
            'actual_os_daily_requests': await dailyPending(),
          };
        });
      } finally {
        if (restoreNeeded) {
          record('restore-initial-daily-settings', 'started', {});
          try {
            if (find.byType(TimePickerDialog).evaluate().isNotEmpty) {
              await tap(find.widgetWithText(TextButton, 'Cancel'));
            }
            await toggleDaily(true);
            await pickTime(
              TimeOfDay(
                hour: initial.dailyPlanningHour,
                minute: initial.dailyPlanningMinute,
              ),
            );
            await toggleDaily(initial.dailyPlanningEnabled);
            final restored = reminder.loadPrefs();
            expect(restored.dailyPlanningEnabled, initial.dailyPlanningEnabled);
            expect(restored.dailyPlanningHour, initial.dailyPlanningHour);
            expect(restored.dailyPlanningMinute, initial.dailyPlanningMinute);
            expect(restored.goalRemindersEnabled, initial.goalRemindersEnabled);
            expect(
              restored.habitRemindersEnabled,
              initial.habitRemindersEnabled,
            );
            await waitRead(
              () async {
                final requests = await dailyPending();
                return initial.dailyPlanningEnabled
                    ? requests.length == 1 &&
                          requests.single['hour'] ==
                              initial.dailyPlanningHour &&
                          requests.single['minute'] ==
                              initial.dailyPlanningMinute
                    : requests.isEmpty;
              },
              'OS registration must match restored initial effective daily settings.',
            );
            record('restore-initial-daily-settings', 'passed', {
              'enabled': restored.dailyPlanningEnabled,
              'hour': restored.dailyPlanningHour,
              'minute': restored.dailyPlanningMinute,
              'actual_os_daily_requests': await dailyPending(),
              'temporary_schedule_left_active': false,
              'screenshot': await capture('restored-settings'),
            });
          } catch (error) {
            record('restore-initial-daily-settings', 'failed', {
              'error': error.toString(),
              'manual_restore_required': true,
              'initial_enabled': initial.dailyPlanningEnabled,
              'initial_hour': initial.dailyPlanningHour,
              'initial_minute': initial.dailyPlanningMinute,
            });
            rethrow;
          }
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
    config: const PatrolTesterConfig(
      settlePolicy: SettlePolicy.noSettle,
      printLogs: true,
    ),
  );
}
