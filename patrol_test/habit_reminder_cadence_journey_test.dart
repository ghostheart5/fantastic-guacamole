import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/app/startup/app_bootstrap.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_handshake_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
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

// Run only in a disposable Android QA profile bound by the native runner.
// All creation/outcome/toggle mutations use ordinary visible controls. Native
// registration metadata is read via the real plugin, not a mocked scheduler.
void main() {
  patrolTest('habit reminder cadence skips completed periods through real UI', (
    $,
  ) async {
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
    final taskRepo = container.read(domainTaskRepositoryProvider);
    final habitRepo = container.read(domainHabitRepositoryProvider);
    final scheduler = container.read(notificationSchedulerProvider);
    final reminder = container.read(reminderOrchestratorServiceProvider);
    final initialPrefs = reminder.loadPrefs();
    final scope = container.read(accountStorageScopeProvider);
    expect(scope.isWritable && scope.rawUserId != null, isTrue);
    final account = AccountDataRegistry.accountDigest(scope.rawUserId!);
    final baselineTasks = {
      for (final task in await taskRepo.getAllTasks()) task.id: task.toJson(),
    };
    final initialHabits = await habitRepo.getHabits();
    expect(
      initialHabits.any((habit) => habit.active),
      isFalse,
      reason:
          'Only empty or entirely paused baseline rhythms are allowed; never pause preexisting records.',
    );
    final baselineHabits = {
      for (final habit in initialHabits) habit.id: habit.toJson(),
    };
    final baselineOutcomes = {
      for (final item
          in await container.read(habitOccurrenceRepositoryProvider)!.load())
        item.id: item.toJson(),
    };
    final initialXp = container.read(profileProvider).xp;
    final owned = <String, String>{};
    final terminalRecords = <String, Map<String, dynamic>>{};
    final run = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    final documents = await getApplicationDocumentsDirectory();
    final evidence = Directory('${documents.path}/habit-reminder-cadence-$run');
    await evidence.create(recursive: true);
    final events = File('${evidence.path}/events.jsonl');
    void record(String id, String status, Map<String, Object?> data) {
      final line = jsonEncode({
        'case': id,
        'status': status,
        'run': run,
        'operator': 'codex_ai',
        'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
        ...data,
      });
      events.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
      debugPrint('AXIOMARA_HABIT_REMINDER_CADENCE $line');
    }

    Future<String> capture(String name) async {
      await $.pump(const Duration(milliseconds: 100));
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
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

    Future<void> caseRun(
      String id,
      Future<Map<String, Object?>> Function() action,
    ) async {
      record(id, 'started', {});
      try {
        final data = await action();
        expect($.tester.takeException(), isNull);
        record(id, 'passed', {...data, 'screenshot': await capture(id)});
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

    Future<void> waitRead(Future<bool> Function() ready, String reason) async {
      final deadline = DateTime.now().add(const Duration(seconds: 40));
      while (DateTime.now().isBefore(deadline)) {
        await $.pump(const Duration(milliseconds: 200));
        if (await ready()) return;
      }
      fail(reason);
    }

    Future<void> reveal(
      Finder target, {
      AxisDirection initialDirection = AxisDirection.down,
      bool reverseWhenMissing = true,
    }) async {
      var direction = initialDirection;
      var missing = 0;
      var guides = 0;
      for (var attempt = 0; attempt < 45; attempt++) {
        await $.pump(const Duration(milliseconds: 150));
        final pause = find.text('Pause guide').hitTestable();
        final notNow = find.text('Not now').hitTestable();
        if (pause.evaluate().isNotEmpty ||
            (find
                    .text('CONTEXTUAL GUIDANCE')
                    .hitTestable()
                    .evaluate()
                    .isNotEmpty &&
                notNow.evaluate().isNotEmpty)) {
          expect(guides++, lessThan(8));
          await $(pause.evaluate().isNotEmpty ? pause : notNow).tap();
          continue;
        }
        if (target.hitTestable().evaluate().isNotEmpty) return;
        final scrollables = find.byType(Scrollable).hitTestable();
        // A route transition may briefly expose no list. Never evaluate .first
        // on an empty finder, or turn a missing lazy header into a StateError.
        if (scrollables.evaluate().isEmpty) continue;
        final scroll = scrollables.first;
        if (target.evaluate().isNotEmpty) {
          missing = 0;
          direction =
              $.tester.getRect(target).center.dy <
                  $.tester.getRect(scroll).center.dy
              ? AxisDirection.up
              : AxisDirection.down;
        } else if (++missing % 8 == 0 && reverseWhenMissing) {
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
        'Real UI target remained unreachable after bounded ordinary scrolling: $target',
      );
    }

    Future<void> tap(
      Finder target, {
      AxisDirection initialDirection = AxisDirection.down,
    }) async {
      await reveal(target, initialDirection: initialDirection);
      await $(target.hitTestable()).tap();
      await $.pump(const Duration(milliseconds: 250));
    }

    Future<void> dismissKeyboard() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await $.pump(const Duration(milliseconds: 200));
    }

    Future<void> navigate(String label) async {
      for (var hop = 0; hop < 7; hop++) {
        if (find
            .byTooltip('Open navigation map')
            .hitTestable()
            .evaluate()
            .isNotEmpty) {
          break;
        }
        // First reveal whichever normal navigation controls this route
        // actually exposes. A lazy/offscreen map is preferred to Back; an
        // unmounted Settings header is found by bounded upward scrolling.
        final navigationControls = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              (widget.tooltip == 'Open navigation map' ||
                  widget.tooltip == 'Back' ||
                  widget.tooltip == 'Back to Nexus'),
        );
        await reveal(
          navigationControls,
          initialDirection: AxisDirection.up,
          reverseWhenMissing: false,
        );
        if (find
            .byTooltip('Open navigation map')
            .hitTestable()
            .evaluate()
            .isNotEmpty) {
          break;
        }
        final header = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              (widget.tooltip == 'Back' || widget.tooltip == 'Back to Nexus'),
        );
        expect(header.hitTestable(), findsOneWidget);
        await tap(header.hitTestable(), initialDirection: AxisDirection.up);
        record('navigation-back-$label-$hop', 'visible-ui-action', {
          'action': 'Back from actual visible app header',
          'scope':
              'Bounded route pop; an intermediate Creator route need not expose Nexus map',
        });
        await $.pump(const Duration(milliseconds: 350));
        await waitRead(
          () async =>
              find
                  .byTooltip('Open navigation map')
                  .hitTestable()
                  .evaluate()
                  .isNotEmpty ||
              header.hitTestable().evaluate().isNotEmpty,
          'The ordinary Back action must expose actual navigation controls on the next app route.',
        );
      }
      expect(
        find.byTooltip('Open navigation map').hitTestable(),
        findsOneWidget,
        reason:
            'Seven ordinary visible Back actions must reach Nexus before using its map.',
      );
      await tap(find.byTooltip('Open navigation map'));
      await tap(find.widgetWithText(ListTile, label));
    }

    Future<void> settingsPlanning() async {
      await navigate('Control Center');
      if (find.text('Habit Reminders').evaluate().isEmpty) {
        await tap(find.text('Planning & guidance'));
      }
    }

    Future<void> toggleHabitReminder(bool enabled) async {
      await reveal(find.text('Habit Reminders'));
      final tile = find
          .ancestor(
            of: find.text('Habit Reminders'),
            matching: find.byType(InkWell),
          )
          .first;
      final toggle = find.descendant(of: tile, matching: find.byType(Switch));
      expect(toggle, findsOneWidget);
      if ($.tester.widget<Switch>(toggle).value != enabled) await tap(toggle);
      await waitRead(
        () async =>
            reminder.loadPrefs().habitRemindersEnabled == enabled &&
            $.tester.widget<Switch>(toggle).value == enabled,
        'Habit reminder preference must persist.',
      );
    }

    Future<void> manageRhythms() async {
      await navigate('Reality Builder');
      if (find.text('New item').evaluate().isNotEmpty) {
        await tap(find.text('New item'));
      }
      await tap(find.text('Manage Daily Rhythms'));
    }

    Finder cardFor(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byType(TemporalGlassSurface),
    );
    Future<void> pauseOwned(String id, String title) async {
      final habit = (await habitRepo.getHabits()).singleWhere(
        (habit) => habit.id == id,
      );
      if (!habit.active) return;
      await tap(
        find.descendant(
          of: cardFor(title),
          matching: find.widgetWithText(TextButton, 'Pause'),
        ),
      );
      await waitRead(
        () async => !(await habitRepo.getHabits())
            .singleWhere((habit) => habit.id == id)
            .active,
        'Only the owned synthetic rhythm may be paused.',
      );
    }

    DateTime expectedFirst(HabitCadence cadence, DateTime now, bool terminal) {
      final initial = switch (cadence) {
        HabitCadence.daily => DateTime(now.year, now.month, now.day, 20),
        HabitCadence.weekly => DateTime(
          now.year,
          now.month,
          now.day - now.weekday + DateTime.monday,
          20,
        ),
        HabitCadence.monthly => DateTime(now.year, now.month, 1, 20),
      };
      if (!terminal && initial.isAfter(now)) return initial;
      return switch (cadence) {
        HabitCadence.daily => DateTime(
          initial.year,
          initial.month,
          initial.day + 1,
          20,
        ),
        HabitCadence.weekly => DateTime(
          initial.year,
          initial.month,
          initial.day + 7,
          20,
        ),
        HabitCadence.monthly => DateTime(
          initial.year,
          initial.month + 1,
          1,
          20,
        ),
      };
    }

    Future<Map<String, Object?>> nativeSnapshot(
      String name, {
      HabitCadence? cadence,
      DateTime? first,
      String? title,
    }) async {
      // Only this QA application's sandboxed alarm cache, never auth storage.
      final cache = File(
        '${documents.parent.path}/shared_prefs/scheduled_notifications.xml',
      );
      String? matchedXml;
      Map<String, Object?>? matchedNative;
      await waitRead(
        () async {
          if (!await cache.exists()) return false;
          expect(await cache.length(), lessThan(1024 * 1024));
          final raw = await cache.readAsString();
          final text = RegExp(
            r'<string name="scheduled_notifications">([\s\S]*?)</string>',
          ).firstMatch(raw)?.group(1);
          if (text == null) return false;
          final decoded = text
              .replaceAll('&quot;', '"')
              .replaceAll('&apos;', "'")
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&amp;', '&');
          final items = (jsonDecode(decoded) as List<Object?>)
              .cast<Map<String, Object?>>();
          final own = items.where((item) {
            final payload = item['payload'];
            final scoped = payload is String
                ? NotificationScheduler.parseAccountPayload(payload)
                : null;
            return scoped?.accountScope == account &&
                scoped?.notificationId == 'habit_reminder_daily';
          }).toList();
          if (cadence == null) {
            if (own.isNotEmpty) return false;
          } else {
            if (own.length != 1) return false;
            final item = own.single;
            final component = switch (cadence) {
              HabitCadence.daily => 'Time',
              HabitCadence.weekly => 'DayOfWeekAndTime',
              HabitCadence.monthly => 'DayOfMonthAndTime',
            };
            final actual = DateTime.tryParse(
              item['scheduledDateTime']?.toString() ?? '',
            );
            if (actual != first ||
                item['matchDateTimeComponents'] != component ||
                item['body'] != 'Stay consistent: $title') {
              return false;
            }
            matchedNative = item;
          }
          matchedXml = raw;
          return true;
        },
        'Actual native alarm persistence must match the first date/components or cancellation.',
      );
      final path = '${evidence.path}/$name-native-cache.xml';
      final bytes = utf8.encode(matchedXml!);
      await File(path).writeAsBytes(bytes, flush: true);
      return {
        'native_snapshot': path,
        'native_snapshot_sha256': sha256.convert(bytes).toString(),
        'native_scheduled_local': matchedNative?['scheduledDateTime'],
        'native_match_components': matchedNative?['matchDateTimeComponents'],
        'native_time_zone': matchedNative?['timeZoneName'],
        'native_habit_registration_count': cadence == null ? 0 : 1,
      };
    }

    Future<Map<String, Object?>> registration(
      HabitCadence cadence,
      String title,
      bool terminal,
    ) async {
      final expected = expectedFirst(cadence, DateTime.now(), terminal);
      await waitRead(
        () async {
          final all = await scheduler.pendingForAccount(account);
          final selected = all
              .where((item) => item.id == 'habit_reminder_daily')
              .toList();
          return selected.length == 1 &&
              selected.single.cadence == cadence &&
              selected.single.firstScheduledLocal == expected &&
              selected.single.body.contains(title);
        },
        'Native registration must match the selected cadence and first eligible period.',
      );
      final selected = (await scheduler.pendingForAccount(
        account,
      )).where((item) => item.id == 'habit_reminder_daily').single;
      expect(selected.hour, 20);
      expect(selected.minute, 0);
      expect(selected.firstScheduledLocal, expected);
      return {
        'id': selected.id,
        'cadence': selected.cadence?.name,
        'first_scheduled_local': selected.firstScheduledLocal
            ?.toIso8601String(),
        'body': selected.body,
        'expected_first_local': expected.toIso8601String(),
        'terminal_current_period': terminal,
        'one_account_habit_registration': true,
        'limits': 'Registration only; no future timed-delivery claim',
        ...await nativeSnapshot(
          '${cadence.name}-${terminal ? 'terminal' : 'initial'}',
          cadence: cadence,
          first: expected,
          title: title,
        ),
      };
    }

    record('baseline', 'observed', {
      'initial_habit_reminders_enabled': initialPrefs.habitRemindersEnabled,
      'preexisting_habits_all_paused': true,
      'baseline_paused_habits': baselineHabits.length,
      'baseline_period_outcomes': baselineOutcomes.length,
      'initial_tasks': baselineTasks.length,
      'limits': [
        'No existing Level20 profile changes',
        'No clock changes or future delivery claim',
        'Owned synthetic rhythms will be paused after testing; initial effective reminder preferences restored',
        'Explicit QA notification permission remains allowed',
      ],
    });
    try {
      await caseRun('fresh-qa-notification-consent-and-habit-toggle', () async {
        await navigate('Control Center');
        await tap(find.text('Appearance & permissions'));
        await reveal(find.text('Alert Permission'));
        if (container.read(notificationPermissionListenableProvider).value !=
            true) {
          await tap(find.text('Enable Notifications'));
          expect(find.text('WHEN IT IS USED'), findsOneWidget);
          await tap(find.text('Allow Notifications'));
          if (await $.platform.mobile.isPermissionDialogVisible(
            timeout: const Duration(seconds: 5),
          )) {
            await $.platform.mobile.grantPermissionWhenInUse();
          }
          await waitRead(
            () async =>
                container
                    .read(notificationPermissionListenableProvider)
                    .value ==
                true,
            'Real notification consent must read back Granted; no adb permission grant.',
          );
        }
        if (find.text('Habit Reminders').evaluate().isEmpty) {
          await tap(find.text('Planning & guidance'));
        }
        await toggleHabitReminder(false);
        expect(
          (await scheduler.pendingForAccount(
            account,
          )).where((item) => item.id == 'habit_reminder_daily'),
          isEmpty,
        );
        await toggleHabitReminder(true);
        return {
          'notification_permission_granted': true,
          'off_cancelled_habit_alarm': true,
        };
      });
      for (final cadence in HabitCadence.values) {
        final label =
            '${cadence.name[0].toUpperCase()}${cadence.name.substring(1)}';
        final title = 'QA-REMINDER-${cadence.name.toUpperCase()}-$run';
        late String id;
        await caseRun('${cadence.name}-create-and-register', () async {
          await navigate('Reality Builder');
          if (find.text('New item').evaluate().isNotEmpty) {
            await tap(find.text('New item'));
          }
          await tap(find.byKey(const Key('creator-type-selector')));
          await tap(find.text('Daily Rhythm').hitTestable().last);
          final titleField = find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.hintText == 'Title *',
          );
          await reveal(titleField);
          await $(titleField).enterText(title);
          await dismissKeyboard();
          await tap(
            find.descendant(
              of: find.byKey(const Key('creator-rhythm-cadence')),
              matching: find.text(label),
            ),
          );
          await tap(find.text('REVIEW CHANGES'));
          expect(
            (await habitRepo.getHabits()).any((habit) => habit.title == title),
            isFalse,
          );
          expect(
            container
                .read(creatorHandshakeProvider)
                .preview!
                .selectedOperations,
            hasLength(1),
          );
          await tap(find.byKey(const Key('creator-confirm-selected')));
          await waitRead(
            () async =>
                (await habitRepo.getHabits())
                    .where((habit) => habit.title == title)
                    .length ==
                1,
            'One reviewed rhythm must be durably created.',
          );
          final habit = (await habitRepo.getHabits()).singleWhere(
            (habit) => habit.title == title,
          );
          id = habit.id;
          owned[id] = title;
          expect(habit.cadence, cadence);
          expect(habit.targetCount, 1);
          expect(
            (await habitRepo.getHabits())
                .where((habit) => habit.active)
                .map((habit) => habit.id),
            [id],
          );
          return {'habit_id': id, ...await registration(cadence, title, false)};
        });
        await caseRun('${cadence.name}-terminal-period-defers-reminder', () async {
          await manageRhythms();
          final card = cardFor(title);
          final completed = cadence != HabitCadence.weekly;
          final period = switch (cadence) {
            HabitCadence.daily => 'day',
            HabitCadence.weekly => 'week',
            HabitCadence.monthly => 'month',
          };
          final button = find.descendant(
            of: card,
            matching: completed
                ? find.widgetWithText(FilledButton, 'Mark target completed')
                : find.widgetWithText(OutlinedButton, 'Skip this $period'),
          );
          await waitRead(
            () async =>
                button.hitTestable().evaluate().isNotEmpty &&
                $.tester.widget<ButtonStyleButton>(button).onPressed != null,
            'The selected real rhythm outcome control must finish loading and become enabled.',
          );
          await tap(button);
          final occurrenceRepo = container.read(
            habitOccurrenceRepositoryProvider,
          )!;
          await waitRead(
            () async =>
                (await occurrenceRepo.load())
                    .where((item) => item.habitId == id)
                    .length ==
                1,
            'One terminal rhythm occurrence must persist.',
          );
          final result = (await occurrenceRepo.load()).singleWhere(
            (item) => item.habitId == id,
          );
          terminalRecords[id] = result.toJson();
          expect(
            result.outcome,
            completed
                ? HabitOccurrenceOutcome.completed
                : HabitOccurrenceOutcome.skipped,
          );
          expect(container.read(profileProvider).xp, initialXp);
          await waitRead(
            () async =>
                button.evaluate().isNotEmpty &&
                $.tester.widget<ButtonStyleButton>(button).onPressed == null,
            'Same-period terminal action must become disabled after the recorded outcome.',
          );
          final pending = await registration(cadence, title, true);
          await pauseOwned(id, title);
          await waitRead(
            () async => (await scheduler.pendingForAccount(
              account,
            )).where((item) => item.id == 'habit_reminder_daily').isEmpty,
            'Pausing the only active owned rhythm must cancel its alarm.',
          );
          return {
            'habit_id': id,
            'outcome': result.toJson(),
            ...pending,
            'owned_rhythm_paused': true,
            'pause_cancelled_alarm': true,
            'no_task_xp_awarded': true,
            'pause_native_snapshot': await nativeSnapshot(
              '${cadence.name}-paused',
            ),
          };
        });
      }
    } finally {
      await caseRun('restore-owned-qa-reminder-state', () async {
        await manageRhythms();
        for (final entry in owned.entries) {
          await pauseOwned(entry.key, entry.value);
        }
        await settingsPlanning();
        await toggleHabitReminder(initialPrefs.habitRemindersEnabled);
        final restored = reminder.loadPrefs();
        expect(
          restored.habitRemindersEnabled,
          initialPrefs.habitRemindersEnabled,
        );
        expect(
          restored.goalRemindersEnabled,
          initialPrefs.goalRemindersEnabled,
        );
        expect(
          restored.dailyPlanningEnabled,
          initialPrefs.dailyPlanningEnabled,
        );
        expect(restored.dailyPlanningHour, initialPrefs.dailyPlanningHour);
        expect(restored.dailyPlanningMinute, initialPrefs.dailyPlanningMinute);
        expect(
          (await scheduler.pendingForAccount(
            account,
          )).where((item) => item.id == 'habit_reminder_daily'),
          isEmpty,
        );
        expect({
          for (final task in await taskRepo.getAllTasks())
            task.id: task.toJson(),
        }, baselineTasks);
        expect((await habitRepo.getHabits()).map((habit) => habit.id).toSet(), {
          ...baselineHabits.keys,
          ...owned.keys,
        });
        for (final habit in await habitRepo.getHabits()) {
          if (baselineHabits.containsKey(habit.id)) {
            expect(
              habit.toJson(),
              baselineHabits[habit.id],
              reason: 'Every preexisting paused rhythm must remain unchanged.',
            );
          }
        }
        expect(
          (await habitRepo.getHabits()).any((habit) => habit.active),
          isFalse,
        );
        expect(container.read(profileProvider).xp, initialXp);
        final finalOutcomes = await container
            .read(habitOccurrenceRepositoryProvider)!
            .load();
        for (final entry in baselineOutcomes.entries) {
          final selected = finalOutcomes
              .where((item) => item.id == entry.key)
              .toList();
          expect(selected, hasLength(1));
          expect(
            selected.single.toJson(),
            entry.value,
            reason: 'Preexisting terminal history must remain unchanged.',
          );
        }
        for (final entry in terminalRecords.entries) {
          final selected = finalOutcomes
              .where((item) => item.habitId == entry.key)
              .toList();
          expect(selected, hasLength(1));
          expect(
            selected.single.toJson(),
            entry.value,
            reason:
                'Terminal outcome identity/time must remain unchanged after revisiting and pausing.',
          );
        }
        return {
          'initial_effective_preferences_restored': true,
          'temporary_habit_alarm_cancelled': true,
          'synthetic_habits_retained_paused': owned.length,
          'no_hidden_tasks': true,
          'baseline_paused_habits_unchanged': baselineHabits.length,
          'baseline_period_outcomes_unchanged': baselineOutcomes.length,
          ...await nativeSnapshot('finally-restored'),
        };
      });
    }
  });
}
