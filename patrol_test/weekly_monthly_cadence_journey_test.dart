import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fantastic_guacamole/app/startup/app_bootstrap.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/utils/date_time_formats.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/l10n/creator_copy.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/creator_handshake_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
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

// Fills the accepted records lane's missing WEEKLY task completion and MONTHLY
// rhythm outcome. Task recurrence has no monthly option in this production UI.
// Provider/repository access is read-only; all changes use visible controls.
void main() {
  patrolTest(
    'weekly task successor and monthly rhythm terminal history through real UI',
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
      final taskRepo = container.read(domainTaskRepositoryProvider);
      final habitRepo = container.read(domainHabitRepositoryProvider);
      final occurrenceRepo = container.read(taskOccurrenceRepositoryProvider);
      final baselineTasks = {
        for (final task in await taskRepo.getAllTasks()) task.id: task.toJson(),
      };
      final baselineHabits = {
        for (final habit in await habitRepo.getHabits())
          habit.id: habit.toJson(),
      };
      final run = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      final folder = await getApplicationDocumentsDirectory();
      final evidence = Directory('${folder.path}/weekly-monthly-cadence-$run');
      await evidence.create(recursive: true);
      final events = File('${evidence.path}/events.jsonl');
      void record(String id, String status, Map<String, Object?> fields) {
        final line = jsonEncode({
          'case': id,
          'status': status,
          'run': run,
          'operator': 'codex_ai',
          'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
          ...fields,
        });
        events.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
        debugPrint('AXIOMARA_WEEKLY_MONTHLY $line');
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
        final deadline = DateTime.now().add(const Duration(seconds: 40));
        while (DateTime.now().isBefore(deadline)) {
          await $.pump(const Duration(milliseconds: 200));
          if (await ready()) return;
        }
        fail(reason);
      }

      Future<void> reveal(Finder target) async {
        var direction = AxisDirection.down;
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
            expect(
              guides++,
              lessThan(8),
              reason: 'Separate guidance interruptions must stay bounded.',
            );
            final paused = pause.evaluate().isNotEmpty;
            await $(paused ? pause : notNow).tap();
            record('guide-navigation-action', 'visible-ui-action', {
              'action': paused ? 'Pause guide' : 'Not now',
              'scope':
                  'Expose ordinary recurrence controls; tutorial completion not claimed',
            });
            continue;
          }
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
          'Target $target remained unreachable after bounded normal scrolling.',
        );
      }

      Future<void> tap(Finder target) async {
        await reveal(target);
        await $(target.hitTestable()).tap();
        await $.pump(const Duration(milliseconds: 250));
      }

      Future<void> textTap(String label) => tap(find.text(label));
      Future<void> dismissKeyboard() async {
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await $.pump(const Duration(milliseconds: 200));
      }

      Future<void> back() => tap(find.byTooltip('Back').first);
      Future<void> navigate(String destination) async {
        if (find
            .byTooltip('Open navigation map')
            .hitTestable()
            .evaluate()
            .isEmpty) {
          final header = find.byTooltip('Back to Nexus').evaluate().isNotEmpty
              ? find.byTooltip('Back to Nexus')
              : find.byTooltip('Back');
          await tap(header.first);
        }
        await tap(find.byTooltip('Open navigation map'));
        await tap(find.widgetWithText(ListTile, destination));
        await $.pump(const Duration(milliseconds: 300));
      }

      Future<void> form(String kind, String title) async {
        await tap(find.byKey(const Key('creator-type-selector')));
        await tap(find.text(kind).hitTestable().last);
        final titleField = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Title *',
        );
        await reveal(titleField);
        await $(titleField).enterText(title);
        await dismissKeyboard();
      }

      Future<void> confirm(Future<bool> Function() notSaved) async {
        await textTap('REVIEW CHANGES');
        expect(find.text('CONFIRM CREATOR CHANGES'), findsOneWidget);
        expect(
          await notSaved(),
          isTrue,
          reason: 'Review alone must not save the proposed record.',
        );
        final selected = container
            .read(creatorHandshakeProvider)
            .preview!
            .selectedOperations;
        expect(selected, hasLength(1));
        final button = find.byKey(const Key('creator-confirm-selected'));
        expect(
          find.descendant(
            of: button,
            matching: find.text(
              const CreatorCopy(
                false,
              ).createAction(selected.single.entityKind.name),
            ),
          ),
          findsOneWidget,
        );
        await tap(button);
        await waitRead(
          () async => find.text('CREATION SAVED').evaluate().isNotEmpty,
          'Ordinary Creator confirmation must finish.',
        );
      }

      Future<void> timelineFilter(String title) async {
        // Default Week excludes exactly +7 days. Use the real All time-range
        // control so a valid weekly successor cannot be mistaken for disappearance.
        await tap(
          find.byWidgetPredicate(
            (w) =>
                w is SmartPressable && w.semanticLabel == 'Show All timeline',
          ),
        );
        await textTap('Find & filter');
        final search = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Find an event, task, goal, or note',
        );
        await reveal(search);
        await $(search).enterText(title);
        await dismissKeyboard();
      }

      record('scope', 'bounded', {
        'package': package.packageName,
        'version': package.version,
        'build_number': package.buildNumber,
        'baseline_tasks': baselineTasks.length,
        'baseline_habits': baselineHabits.length,
        'limits': [
          'Tasks support none/daily/weekly; monthly cadence belongs to rhythms',
          'Navigation revisit only; no process restart, future-week/month rollover, or clock manipulation',
          'No cloud/provider calls or provider/repository writes; real UI writes only',
        ],
      });
      await navigate('Reality Builder');
      final weeklyTitle = 'QA-WEEKLY-COMPLETION-$run';
      late String taskId;
      await caseRun('weekly-task-review-confirm', () async {
        await form('Task', weeklyTitle);
        await reveal(find.byKey(const Key('creator-task-repeat')));
        final repeats = $.tester.widget<DropdownButton<RecurrenceRule>>(
          find.byKey(const Key('creator-task-repeat')),
        );
        expect(
          repeats.items!.map((item) => item.value).toSet(),
          RecurrenceRule.values.toSet(),
        );
        expect(
          repeats.items!.map((item) => (item.child as Text).data),
          isNot(contains('Monthly')),
        );
        await tap(find.byKey(const Key('creator-task-repeat')));
        await tap(find.text('Weekly').hitTestable().last);
        await textTap('Schedule date and time...');
        await tap(find.widgetWithText(TextButton, 'OK'));
        await tap(find.widgetWithText(TextButton, 'OK'));
        await confirm(
          () async => !(await taskRepo.getAllTasks()).any(
            (task) => task.title == weeklyTitle,
          ),
        );
        final records = (await taskRepo.getAllTasks())
            .where((task) => task.title == weeklyTitle)
            .toList();
        expect(records, hasLength(1));
        final original = records.single;
        taskId = original.id;
        expect(original.recurrenceRule, RecurrenceRule.weekly);
        expect(original.scheduledFor, isNotNull);
        expect(original.isCompleted, isFalse);
        expect(original.dueDate, isNull);
        return {
          'task': original.toJson(),
          'monthly_task_option_offered': false,
        };
      });
      await navigate('Truth Ledger');
      await timelineFilter(weeklyTitle);
      late String successorId;
      late int weeklyXpAfter;
      late DateTime originalCompletedAt;
      await caseRun('weekly-terminal-successor-reward-once', () async {
        final original = (await taskRepo.getTaskById(taskId))!;
        final anchor = original.scheduledFor!.toLocal();
        final next = DateTime(
          anchor.year,
          anchor.month,
          anchor.day + 7,
          anchor.hour,
          anchor.minute,
          anchor.second,
          anchor.millisecond,
          anchor.microsecond,
        );
        expect(next.isAfter(DateTime.now()), isTrue);
        final row = find.byKey(
          ValueKey('timeline-event-semantics-timeline-projected-task-$taskId'),
        );
        final button = find.descendant(
          of: row,
          matching: find.widgetWithText(OutlinedButton, 'Complete'),
        );
        await reveal(button);
        final xpBefore = container.read(profileProvider).xp;
        var taps = 1;
        await $.tester.tap(button.hitTestable());
        await $.pump(const Duration(milliseconds: 1));
        final second = button.hitTestable();
        var contained = second.evaluate().isEmpty;
        if (second.evaluate().isNotEmpty) {
          contained = $.tester.widget<OutlinedButton>(second).onPressed == null;
          if (!contained) {
            await $.tester.tap(second);
            taps++;
          }
        }
        await waitRead(
          () async {
            final terminal = await taskRepo.getTaskById(taskId);
            final occurrences = await occurrenceRepo.listOccurrencesForTask(
              taskId,
            );
            return terminal?.isCompleted == true &&
                occurrences.length == 1 &&
                occurrences.single.terminalOutcome ==
                    TaskOccurrenceOutcome.completed &&
                container.read(profileProvider).xp ==
                    xpBefore + ProgressionPolicy.completionXp &&
                !(await container.read(
                  allTasksProvider.future,
                )).any((task) => task.id == taskId);
          },
          'Weekly original must complete once, leave active work, and grant exactly one completion reward.',
        );
        final terminal = (await taskRepo.getTaskById(taskId))!;
        expect(terminal.completedAt, isNotNull);
        originalCompletedAt = terminal.completedAt!;
        final occurrences = await occurrenceRepo.listOccurrencesForTask(taskId);
        expect(
          occurrences.single.transitions.where(
            (transition) =>
                transition.outcome == TaskOccurrenceOutcome.completed,
          ),
          hasLength(1),
        );
        final related = (await taskRepo.getAllTasks())
            .where((task) => task.title == weeklyTitle)
            .toList();
        expect(related, hasLength(2));
        final successor = related.singleWhere((task) => task.id != taskId);
        successorId = successor.id;
        expect(
          successor.isCompleted || successor.isSkipped || successor.isCanceled,
          isFalse,
        );
        expect(successor.recurrenceRule, RecurrenceRule.weekly);
        expect(successor.recurrenceSeriesId, occurrences.single.seriesId);
        expect(successor.occurrenceKey, isNot(original.occurrenceKey));
        expect(successor.scheduledFor!.toLocal(), next);
        final settle = Stopwatch()..start();
        var pumped = 0;
        while (row.evaluate().isNotEmpty &&
            pumped < 3000 &&
            settle.elapsed < const Duration(seconds: 3)) {
          await $.pump(const Duration(milliseconds: 100));
          pumped += 100;
        }
        settle.stop();
        expect(
          row,
          findsNothing,
          reason: 'The terminal original keyed UI row must be fully disposed.',
        );
        final nextRow = find.byKey(
          ValueKey(
            'timeline-event-semantics-timeline-projected-task-$successorId',
          ),
        );
        await reveal(nextRow);
        expect(
          find.descendant(of: nextRow, matching: find.text(weeklyTitle)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: nextRow,
            matching: find.text('SCHEDULED ${DateTimeFormats.dateShort(next)}'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: nextRow, matching: find.text('Complete')),
          findsOneWidget,
        );
        weeklyXpAfter = container.read(profileProvider).xp;
        return {
          'original_task_id': taskId,
          'terminal_occurrence': occurrences.single.toJson(),
          'successor': successor.toJson(),
          'xp_before': xpBefore,
          'xp_after': weeklyXpAfter,
          'expected_reward': ProgressionPolicy.completionXp,
          'actual_completion_taps': taps,
          'second_tap_contained': contained,
          'original_key_disposal_pumped_ms': pumped,
          'render_settlement_performance_acceptance_claimed': false,
          'timeline_time_range': 'All',
        };
      });
      await caseRun('weekly-history-revisit-no-duplicate', () async {
        await navigate('Reality Builder');
        await textTap('Browse records');
        await $(const Key('record-library-search')).waitUntilVisible();
        await $(const Key('record-library-search')).enterText(weeklyTitle);
        await dismissKeyboard();
        final completed = find.byKey(ValueKey('library-task-$taskId'));
        final successor = find.byKey(ValueKey('library-task-$successorId'));
        await reveal(completed);
        expect(
          find.descendant(
            of: completed,
            matching: find.textContaining('Completed · '),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: successor,
            matching: find.textContaining('Active · '),
          ),
          findsOneWidget,
        );
        await back();
        await navigate('Truth Ledger');
        await timelineFilter(weeklyTitle);
        await $.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(
            ValueKey(
              'timeline-event-semantics-timeline-projected-task-$taskId',
            ),
          ),
          findsNothing,
        );
        expect(
          (await taskRepo.getTaskById(taskId))!.completedAt,
          originalCompletedAt,
        );
        expect(
          (await taskRepo.getAllTasks()).where(
            (task) => task.title == weeklyTitle,
          ),
          hasLength(2),
        );
        expect(
          await occurrenceRepo.listOccurrencesForTask(taskId),
          hasLength(1),
        );
        expect(container.read(profileProvider).xp, weeklyXpAfter);
        return {
          'original_task_id': taskId,
          'successor_id': successorId,
          'terminal_time_unchanged': true,
          'one_completion_one_successor_one_reward_retained': true,
        };
      });
      await navigate('Reality Builder');
      await textTap('New item');
      final taskSnapshotBeforeRhythm = {
        for (final task in await taskRepo.getAllTasks()) task.id: task.toJson(),
      };
      final monthlyTitle = 'QA-MONTHLY-RHYTHM-$run';
      late String habitId;
      await caseRun('monthly-rhythm-review-confirm', () async {
        await form('Daily Rhythm', monthlyTitle);
        await tap(
          find.descendant(
            of: find.byKey(const Key('creator-rhythm-cadence')),
            matching: find.text('Monthly'),
          ),
        );
        await confirm(
          () async => !(await habitRepo.getHabits()).any(
            (habit) => habit.title == monthlyTitle,
          ),
        );
        final related = (await habitRepo.getHabits())
            .where((habit) => habit.title == monthlyTitle)
            .toList();
        expect(related, hasLength(1));
        final habit = related.single;
        habitId = habit.id;
        expect(habit.cadence, HabitCadence.monthly);
        expect(habit.targetCount, 1);
        expect(habit.frequencyRevision, 0);
        expect(habit.active, isTrue);
        expect(
          {
            for (final task in await taskRepo.getAllTasks())
              task.id: task.toJson(),
          },
          equals(taskSnapshotBeforeRhythm),
          reason: 'Monthly rhythm creation must not create hidden tasks.',
        );
        return {
          'habit': habit.toJson(),
          'scope': 'Monthly rhythm, not unsupported monthly task recurrence',
        };
      });
      await textTap('New item');
      await textTap('Manage Daily Rhythms');
      final card = find.ancestor(
        of: find.text(monthlyTitle),
        matching: find.byType(TemporalGlassSurface),
      );
      final monthButton = find.descendant(
        of: card,
        matching: find.widgetWithText(FilledButton, 'Mark target completed'),
      );
      late String monthlyOperation;
      late String monthlyOccurrence;
      late DateTime monthlyRecordedAt;
      late int monthlyXp;
      await caseRun('monthly-one-period-terminal-outcome', () async {
        await reveal(card);
        await waitRead(
          () async => container.read(habitOccurrencesProvider).hasValue,
          'Monthly period outcomes must load before recording.',
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text('1 time per month · Active'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text('Not recorded this month'),
          ),
          findsOneWidget,
        );
        final before = DateTime.now();
        monthlyOccurrence =
            '${before.year}-${before.month.toString().padLeft(2, '0')}';
        monthlyXp = container.read(profileProvider).xp;
        await tap(monthButton);
        final repo = container.read(habitOccurrenceRepositoryProvider)!;
        await waitRead(
          () async {
            final items = (await repo.load())
                .where((outcome) => outcome.habitId == habitId)
                .toList();
            return items.length == 1 &&
                items.single.outcome == HabitOccurrenceOutcome.completed &&
                monthButton.evaluate().isNotEmpty &&
                find
                    .descendant(
                      of: card,
                      matching: find.text('Completed this month'),
                    )
                    .evaluate()
                    .isNotEmpty &&
                $.tester.widget<FilledButton>(monthButton).onPressed == null;
          },
          'Monthly target must have one durable outcome and disable same-period completion.',
        );
        final outcome = (await repo.load()).singleWhere(
          (outcome) => outcome.habitId == habitId,
        );
        expect(outcome.occurrenceKey, monthlyOccurrence);
        monthlyOperation = outcome.operationId;
        monthlyRecordedAt = outcome.recordedAt;
        expect(
          find.descendant(
            of: card,
            matching: find.text('Completed this month'),
          ),
          findsOneWidget,
        );
        expect($.tester.widget<FilledButton>(monthButton).onPressed, isNull);
        expect(
          container.read(profileProvider).xp,
          monthlyXp,
          reason: 'Monthly rhythm outcome does not award task completion XP.',
        );
        expect(
          (await habitRepo.getHabits()).where(
            (habit) => habit.title == monthlyTitle,
          ),
          hasLength(1),
        );
        expect(
          {
            for (final task in await taskRepo.getAllTasks())
              task.id: task.toJson(),
          },
          equals(taskSnapshotBeforeRhythm),
          reason:
              'Monthly rhythm recording must not create or modify task successors.',
        );
        return {
          'habit_id': habitId,
          'monthly_outcome': outcome.toJson(),
          'same_period_complete_control_disabled': true,
          'xp_before_and_after': monthlyXp,
          'no_task_successor_or_habit_clone': true,
        };
      });
      await caseRun('monthly-period-history-revisit-no-duplicate', () async {
        await back();
        await textTap('Manage Daily Rhythms');
        await reveal(card);
        await waitRead(
          () async =>
              monthButton.evaluate().isNotEmpty &&
              find
                  .descendant(
                    of: card,
                    matching: find.text('Completed this month'),
                  )
                  .evaluate()
                  .isNotEmpty &&
              $.tester.widget<FilledButton>(monthButton).onPressed == null,
          'Completed monthly period must remain disabled after normal navigation revisit.',
        );
        final items =
            (await container.read(habitOccurrenceRepositoryProvider)!.load())
                .where((outcome) => outcome.habitId == habitId)
                .toList();
        expect(items, hasLength(1));
        expect(items.single.occurrenceKey, monthlyOccurrence);
        expect(items.single.operationId, monthlyOperation);
        expect(items.single.recordedAt, monthlyRecordedAt);
        expect(items.single.outcome, HabitOccurrenceOutcome.completed);
        expect(
          (await habitRepo.getHabits())
              .singleWhere((habit) => habit.id == habitId)
              .cadence,
          HabitCadence.monthly,
        );
        expect(container.read(profileProvider).xp, monthlyXp);
        expect({
          for (final task in await taskRepo.getAllTasks())
            task.id: task.toJson(),
        }, equals(taskSnapshotBeforeRhythm));
        return {
          'habit_id': habitId,
          'same_occurrence_operation_time_retained': true,
          'repeat_completion_contained_by_disabled_ui': true,
          'xp_unchanged_after_revisit': true,
        };
      });
      final finalTasks = {
        for (final task in await taskRepo.getAllTasks()) task.id: task.toJson(),
      };
      final finalHabits = {
        for (final habit in await habitRepo.getHabits())
          habit.id: habit.toJson(),
      };
      for (final id in baselineTasks.keys) {
        expect(finalTasks[id], equals(baselineTasks[id]));
      }
      for (final id in baselineHabits.keys) {
        expect(finalHabits[id], equals(baselineHabits[id]));
      }
      record('preservation', 'passed', {
        'all_preexisting_task_habit_records_unchanged': true,
      });
    },
    timeout: const Timeout(Duration(minutes: 15)),
    config: const PatrolTesterConfig(
      settlePolicy: SettlePolicy.noSettle,
      printLogs: true,
    ),
  );
}
