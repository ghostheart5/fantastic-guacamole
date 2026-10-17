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

// Select ONE named case per instrumentation process. Preparation intentionally
// leaves a temporary daily request for a separate normal-main/background OS
// observation. Cleanup is a later process. Neither case claims delivery.
// App mutations originate exclusively in visible Settings controls. JSON writes
// below are owned QA evidence/lifecycle artifacts, not application state.
void main() {
  for (final prepare in [true, false]) {
    patrolTest(
      prepare
          ? 'prepare temporary daily reminder for normal app delivery'
          : 'restore temporary daily reminder after normal app delivery',
      ($) => _journey($, prepare: prepare),
      timeout: const Timeout(Duration(minutes: 10)),
      config: const PatrolTesterConfig(
        settlePolicy: SettlePolicy.noSettle,
        printLogs: true,
      ),
    );
  }
}

Future<void> _journey(
  PatrolIntegrationTester $, {
  required bool prepare,
}) async {
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
  final accountDigest = AccountDataRegistry.accountDigest(scope.rawUserId!);
  final scheduler = container.read(notificationSchedulerProvider);
  final reminder = container.read(reminderOrchestratorServiceProvider);
  final docs = await getApplicationDocumentsDirectory();
  final androidUser = RegExp(
    r'^/data/user/(\d+)/',
  ).firstMatch(docs.path)?.group(1);
  expect(
    androidUser,
    '10',
    reason: 'Delivery evidence must bind to the isolated QA Android user 10.',
  );
  final root = Directory('${docs.path}/notification-delivery-evidence');
  await root.create(recursive: true);
  final pointer = File('${root.path}/baseline-pointer.json');
  final attempt = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
  final evidence = Directory('${root.path}/attempt-$attempt');
  await evidence.create(recursive: true);
  final events = File('${evidence.path}/events.jsonl');
  final binding = <String, Object?>{
    'package': package.packageName,
    'version': package.version,
    'build_number': package.buildNumber,
    'android_user': androidUser,
    'account_digest': accountDigest,
    'account_namespace': scope.v2Namespace,
  };
  void record(String action, String status, Map<String, Object?> fields) {
    final line = jsonEncode({
      'action': action,
      'status': status,
      'attempt': attempt,
      'operator': 'codex_ai',
      'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
      ...binding,
      ...fields,
    });
    events.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    debugPrint('AXIOMARA_NOTIFICATION_DELIVERY $line');
  }

  Future<String> capture(String name) async {
    await $.pump(const Duration(milliseconds: 100));
    final boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final path = '${evidence.path}/$name.png';
      await File(path).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      return path;
    } finally {
      image.dispose();
    }
  }

  Future<void> waitRead(Future<bool> Function() ready, String reason) async {
    final deadline = DateTime.now().add(const Duration(seconds: 35));
    while (DateTime.now().isBefore(deadline)) {
      await $.pump(const Duration(milliseconds: 200));
      if (await ready()) return;
    }
    fail(reason);
  }

  Future<void> reveal(Finder target) async {
    var direction = AxisDirection.down;
    var missing = 0;
    for (var count = 0; count < 40; count++) {
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

  Future<void> openSettings() async {
    await tap(find.byTooltip('Open navigation map'));
    await tap(find.widgetWithText(ListTile, 'Control Center'));
    await waitRead(
      () async => find.text('SETTINGS').evaluate().isNotEmpty,
      'Control Center must show Settings.',
    );
    if (find.text('Daily Planning Reminder').evaluate().isEmpty) {
      await tap(find.text('Planning & guidance'));
    }
    await waitRead(
      () async => find.text('Daily Planning Reminder').evaluate().isNotEmpty,
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
      'Daily toggle must persist and visibly match.',
    );
  }

  Future<void> pickTime(TimeOfDay time) async {
    await tap(find.text('Daily Planning Time'));
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
        matching: find.widgetWithText(TextButton, 'OK'),
      ),
    );
    await waitRead(
      () async =>
          reminder.loadPrefs().dailyPlanningHour == time.hour &&
          reminder.loadPrefs().dailyPlanningMinute == time.minute,
      'Selected time must persist exactly.',
    );
  }

  Future<List<Map<String, Object?>>> pending() async => [
    for (final item in await scheduler.pendingForAccount(accountDigest))
      {
        'id': item.id,
        'title': item.title,
        'body': item.body,
        'hour': item.hour,
        'minute': item.minute,
      },
  ];
  Future<List<Map<String, Object?>>> dailyPending() async => (await pending())
      .where((item) => item['id'] == 'daily_planning_reminder')
      .toList();
  Future<void> writePointer(Map<String, dynamic> value) =>
      pointer.writeAsString(jsonEncode(value), flush: true);
  void verifyBinding(Map<String, dynamic> baseline) {
    expect(baseline['schema'], 1);
    for (final field in binding.keys) {
      expect(
        baseline[field],
        binding[field],
        reason:
            'Stored baseline must match current QA package/user/account: $field.',
      );
    }
    expect(baseline['run'], isA<String>());
    expect(baseline['daily_enabled'], isA<bool>());
    expect(baseline['daily_hour'], inInclusiveRange(0, 23));
    expect(baseline['daily_minute'], inInclusiveRange(0, 59));
  }

  Future<void> restore(
    Map<String, dynamic> baseline,
    Map<String, dynamic> lifecycle,
  ) async {
    record('restore-baseline', 'started', {'baseline_run': baseline['run']});
    try {
      if (find.byType(TimePickerDialog).evaluate().isNotEmpty) {
        await tap(find.widgetWithText(TextButton, 'Cancel'));
      }
      await toggleDaily(true);
      await pickTime(
        TimeOfDay(
          hour: baseline['daily_hour'] as int,
          minute: baseline['daily_minute'] as int,
        ),
      );
      await toggleDaily(baseline['daily_enabled'] as bool);
      final restored = reminder.loadPrefs();
      expect(restored.dailyPlanningEnabled, baseline['daily_enabled']);
      expect(restored.dailyPlanningHour, baseline['daily_hour']);
      expect(restored.dailyPlanningMinute, baseline['daily_minute']);
      expect(restored.goalRemindersEnabled, baseline['goal_enabled']);
      expect(restored.habitRemindersEnabled, baseline['habit_enabled']);
      await waitRead(() async {
        final registrations = await dailyPending();
        return baseline['daily_enabled'] == true
            ? registrations.length == 1 &&
                  registrations.single['hour'] == baseline['daily_hour'] &&
                  registrations.single['minute'] == baseline['daily_minute']
            : registrations.isEmpty;
      }, 'Actual OS registration must match the restored effective baseline.');
      await writePointer({
        ...lifecycle,
        'status': 'complete',
        'completed_at_utc': DateTime.now().toUtc().toIso8601String(),
        'temporary_settings_left_active': false,
      });
      record('restore-baseline', 'passed', {
        'baseline_run': baseline['run'],
        'daily_enabled': restored.dailyPlanningEnabled,
        'daily_hour': restored.dailyPlanningHour,
        'daily_minute': restored.dailyPlanningMinute,
        'actual_os_daily_requests': await dailyPending(),
        'temporary_settings_left_active': false,
        'screenshot': await capture('baseline-restored'),
      });
    } catch (error) {
      record('restore-baseline', 'failed', {
        'baseline_run': baseline['run'],
        'error': error.toString(),
        'manual_restore_required': true,
        'daily_enabled': baseline['daily_enabled'],
        'daily_hour': baseline['daily_hour'],
        'daily_minute': baseline['daily_minute'],
      });
      rethrow;
    }
  }

  record('scope', 'bounded', {
    'case': prepare ? 'prepare' : 'restore',
    'pointer_path': pointer.path,
    'delivery_verified': false,
    'limits': [
      'Run one selected case per process',
      'No simulated-time or timed-delivery acceptance',
      'Preparation success intentionally leaves a temporary request for root normal-main OS observation',
      'Reminder preferences restore through UI; evidence files are retained',
    ],
  });
  try {
    final existing = pointer.existsSync()
        ? jsonDecode(await pointer.readAsString()) as Map<String, dynamic>
        : null;
    Map<String, dynamic> baseline;
    Map<String, dynamic> lifecycle;
    if (prepare) {
      expect(
        existing == null || existing['status'] == 'complete',
        isTrue,
        reason:
            'An unrestored owned baseline exists. Run the restore case before preparing again; do not overwrite it.',
      );
      final before = reminder.loadPrefs();
      final initialPending = await pending();
      expect(
        container.read(notificationPermissionListenableProvider).value,
        isTrue,
        reason:
            'QA notification permission must already be granted through its ordinary permission UI.',
      );
      baseline = {
        'schema': 1,
        'run': attempt,
        ...binding,
        'daily_enabled': before.dailyPlanningEnabled,
        'daily_hour': before.dailyPlanningHour,
        'daily_minute': before.dailyPlanningMinute,
        'goal_enabled': before.goalRemindersEnabled,
        'habit_enabled': before.habitRemindersEnabled,
        'initial_os_requests': initialPending,
        'created_at_utc': DateTime.now().toUtc().toIso8601String(),
      };
      final baselineFile = File('${evidence.path}/baseline.json');
      await baselineFile.writeAsString(jsonEncode(baseline), flush: true);
      lifecycle = {
        'schema': 1,
        'status': 'pending',
        'run': attempt,
        'baseline_path': baselineFile.path,
        ...binding,
        'prepared': false,
      };
      await writePointer(lifecycle);
      var prepared = false;
      try {
        await openSettings();
        await toggleDaily(true);
        final future = DateTime.now().add(const Duration(minutes: 5));
        final target = DateTime(
          future.year,
          future.month,
          future.day,
          future.hour,
          future.minute,
        );
        await pickTime(TimeOfDay.fromDateTime(target));
        await waitRead(
          () async {
            final registrations = await dailyPending();
            return registrations.length == 1 &&
                registrations.single['hour'] == target.hour &&
                registrations.single['minute'] == target.minute;
          },
          'Preparation must read back exactly one actual daily OS request with target metadata.',
        );
        expect(
          target.isAfter(DateTime.now()),
          isTrue,
          reason:
              'The delivery target must still be in the future at preparation handoff.',
        );
        final registrations = await dailyPending();
        final preparation = {
          'run': attempt,
          ...binding,
          'target_local': target.toIso8601String(),
          'target_utc': target.toUtc().toIso8601String(),
          'actual_os_daily_requests': registrations,
          'restore_required': true,
          'delivery_verified': false,
        };
        await File(
          '${evidence.path}/preparation.json',
        ).writeAsString(jsonEncode(preparation), flush: true);
        lifecycle = {
          ...lifecycle,
          'prepared': true,
          'preparation_path': '${evidence.path}/preparation.json',
          'target_local': target.toIso8601String(),
          'target_utc': target.toUtc().toIso8601String(),
        };
        await writePointer(lifecycle);
        expect($.tester.takeException(), isNull);
        record('prepare-temporary-daily-reminder', 'passed', {
          ...preparation,
          'temporary_registration_left_active': true,
          'screenshot': await capture('temporary-reminder-prepared'),
        });
        prepared = true;
      } finally {
        // Only successful preparation may leave the temporary schedule active.
        if (!prepared) {
          record('prepare-failure-restoration', 'required', {
            'baseline_run': baseline['run'],
          });
          if (find.text('Daily Planning Reminder').evaluate().isEmpty &&
              find
                  .byTooltip('Open navigation map')
                  .hitTestable()
                  .evaluate()
                  .isNotEmpty) {
            await openSettings();
          }
          await restore(baseline, lifecycle);
        }
      }
    } else {
      expect(
        existing,
        isNotNull,
        reason: 'No owned preparation baseline exists to restore.',
      );
      lifecycle = existing!;
      expect(
        lifecycle['status'],
        'pending',
        reason: 'Only an unrestored owned lifecycle may be cleaned up.',
      );
      final baselinePath = lifecycle['baseline_path'] as String;
      expect(
        File(baselinePath).absolute.path.startsWith(
          '${root.absolute.path}${Platform.pathSeparator}',
        ),
        isTrue,
        reason:
            'Restore may read only the owned evidence baseline under this app directory.',
      );
      baseline =
          jsonDecode(await File(baselinePath).readAsString())
              as Map<String, dynamic>;
      verifyBinding(baseline);
      expect(lifecycle['run'], baseline['run']);
      for (final field in binding.keys) {
        expect(lifecycle[field], binding[field]);
      }
      await pending();
      expect(
        container.read(notificationPermissionListenableProvider).value,
        isTrue,
      );
      await openSettings();
      await restore(baseline, lifecycle);
      expect($.tester.takeException(), isNull);
      record('cleanup-complete', 'passed', {
        'baseline_run': baseline['run'],
        'temporary_settings_left_active': false,
        'delivery_verified': false,
        'pointer_path': pointer.path,
        'screenshot': await capture('cleanup-complete'),
      });
    }
  } catch (error) {
    String? screenshot;
    try {
      screenshot = await capture('journey-failed');
    } catch (_) {}
    record(prepare ? 'prepare-journey' : 'restore-journey', 'failed', {
      'error': error.toString(),
      'screenshot': screenshot,
      'evidence_preserved': true,
    });
    rethrow;
  }
}
