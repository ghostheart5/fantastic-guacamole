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

// Run only with the real local public-policy QA configuration. All mutations
// below originate in visible controls; repositories/providers are read oracles.
// Receipts claim only cases whose assertions completed, not all H01-H18.
void main() {
  patrolTest(
    'remaining local Creator task rhythm and note journeys preserve history',
    ($) async {
      final package = await PackageInfo.fromPlatform();
      expect(package.packageName, 'com.ghostheart5.chronospark.qa');
      expect(package.version, '4.2.4-qa');
      expect(package.buildNumber, '2026101201');
      expect(Platform.isAndroid && kDebugMode && Env.isLocalMode, isTrue);
      expect(
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
      final folder = await getApplicationDocumentsDirectory();
      final run = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
      final evidence = Directory('${folder.path}/remaining-journeys-$run');
      await evidence.create(recursive: true);
      final receipts = File('${evidence.path}/events.jsonl');
      void record(String caseId, String status, Map<String, Object?> details) {
        final line = jsonEncode({
          'case': caseId,
          'status': status,
          'run': run,
          'operator': 'codex_ai',
          'backend': 'real_local_public_policy',
          'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
          ...details,
        });
        receipts.writeAsStringSync(
          '$line\n',
          mode: FileMode.append,
          flush: true,
        );
        debugPrint('AXIOMARA_REMAINING_JOURNEY $line');
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
        Future<Map<String, Object?>> Function() body,
      ) async {
        record(id, 'started', {});
        try {
          final details = await body();
          expect($.tester.takeException(), isNull);
          record(id, 'passed', {...details, 'screenshot': await capture(id)});
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
        Future<bool> Function() condition,
        String reason,
      ) async {
        final deadline = DateTime.now().add(const Duration(seconds: 40));
        while (DateTime.now().isBefore(deadline)) {
          await $.pump(const Duration(milliseconds: 200));
          if (await condition()) return;
        }
        fail(reason);
      }

      Future<void> tap(
        Finder target, {
        AxisDirection direction = AxisDirection.down,
      }) async {
        if (target.hitTestable().evaluate().isEmpty) {
          await $(target).scrollTo(scrollDirection: direction);
        }
        await $(target.hitTestable()).waitUntilVisible();
        await $(target.hitTestable()).tap();
        await $.pump(const Duration(milliseconds: 300));
      }

      Future<void> textTap(String label) => tap(find.text(label));
      Future<void> dismissKeyboard() async {
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await $.pump(const Duration(milliseconds: 250));
      }

      Future<void> navigate(String destination) async {
        // Header Back is the public route back to Nexus; no router/provider writes.
        if (find
            .byTooltip('Open navigation map')
            .hitTestable()
            .evaluate()
            .isEmpty) {
          final back = find.byTooltip('Back to Nexus').evaluate().isNotEmpty
              ? find.byTooltip('Back to Nexus')
              : find.byTooltip('Back');
          await tap(back.first, direction: AxisDirection.up);
        }
        await tap(find.byTooltip('Open navigation map'));
        await tap(
          find.widgetWithText(
            ListTile,
            destination == 'Timeline' ? 'Truth Ledger' : destination,
          ),
        );
        await settleCurrentUserNavigation(
          $,
          destinationReady: () => find
              .text(
                destination == 'Reality Builder'
                    ? 'REALITY BUILDER'
                    : 'TRUTH LEDGER',
              )
              .hitTestable()
              .evaluate()
              .isNotEmpty,
        );
      }

      Future<void> form(String kind, String title, String body) async {
        await tap(find.byKey(const Key('creator-type-selector')));
        await tap(find.text(kind).hitTestable().last);
        final titleField = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Title *',
        );
        await $(titleField).enterText(title);
        final bodyField = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText ==
                  (kind == 'Note'
                      ? 'Body (optional)'
                      : 'Description (optional)'),
        );
        await $(bodyField).enterText(body);
        await dismissKeyboard();
      }

      Future<void> reviewConfirm(Future<bool> Function() notSaved) async {
        await textTap('REVIEW CHANGES');
        expect(find.text('CONFIRM CREATOR CHANGES'), findsOneWidget);
        expect(
          await notSaved(),
          isTrue,
          reason: 'Review must not persist the proposed entity.',
        );
        final selected = container
            .read(creatorHandshakeProvider)
            .preview!
            .selectedOperations;
        expect(
          selected,
          hasLength(1),
          reason: 'Each journey confirms one exact staged operation.',
        );
        final confirm = find.byKey(const Key('creator-confirm-selected'));
        final label = const CreatorCopy(
          false,
        ).createAction(selected.single.entityKind.name);
        expect(
          find.descendant(of: confirm, matching: find.text(label)),
          findsOneWidget,
        );
        await tap(confirm);
        await waitRead(
          () async => find.text('CREATION SAVED').evaluate().isNotEmpty,
          'The real Creator confirmation must finish.',
        );
      }

      var newItemTransition = 0;
      Future<void> newItem() async {
        final transition = ++newItemTransition;
        await caseRun('transition-new-item-$transition', () async {
          for (var pause = 0; pause < 8; pause++) {
            await $.pump(const Duration(milliseconds: 200));
            final pauseControl = find.text('Pause guide').hitTestable();
            if (pauseControl.evaluate().isEmpty) break;
            await $(pauseControl).tap();
            await $.pump(const Duration(milliseconds: 250));
            record(
              'transition-guide-pause-$transition-$pause',
              'visible-ui-action',
              {
                'acceptance_kind': 'navigation_transition',
                'h_criteria_acceptance': false,
                'scope':
                    'Pause the separate adaptive walkthrough to expose the saved Creator receipt.',
                'screenshot': await capture(
                  'transition-guide-pause-$transition-$pause',
                ),
              },
            );
          }
          final target = find.text('New item');
          var direction = AxisDirection.down;
          if (target.evaluate().isNotEmpty &&
              target.hitTestable().evaluate().isEmpty) {
            final viewport = find.byType(Scrollable).hitTestable().first;
            direction =
                $.tester.getRect(target).center.dy <
                    $.tester.getRect(viewport).center.dy
                ? AxisDirection.up
                : AxisDirection.down;
          }
          await tap(target, direction: direction);
          await waitRead(
            () async =>
                container.read(creatorHandshakeProvider).receipt == null &&
                find
                    .byKey(const Key('creator-type-selector'))
                    .evaluate()
                    .isNotEmpty,
            'Visible New item must clear the saved receipt and expose the normal Creator form.',
          );
          return {
            'acceptance_kind': 'navigation_transition',
            'h_criteria_acceptance': false,
            'transition_sequence': transition,
            'new_item_control_used': true,
          };
        });
      }

      Future<void> scheduleToday() async {
        await textTap('Schedule date and time...');
        await tap(find.widgetWithText(TextButton, 'OK'));
        await tap(find.widgetWithText(TextButton, 'OK'));
      }

      Future<void> library(String kind, String query) async {
        await textTap('Browse records');
        await $(const Key('record-library-search')).waitUntilVisible();
        await textTap(kind);
        await $(const Key('record-library-search')).enterText(query);
        await dismissKeyboard();
        await $.pump(const Duration(milliseconds: 500));
      }

      final taskRepo = container.read(domainTaskRepositoryProvider);
      final habitRepo = container.read(domainHabitRepositoryProvider);
      final noteRepo = container.read(domainNoteRepositoryProvider);
      final initialTasks = (await taskRepo.getAllTasks())
          .map((t) => t.id)
          .toSet();
      final initialHabits = (await habitRepo.getHabits())
          .map((h) => h.id)
          .toSet();
      final initialNotes = (await noteRepo.getNotes()).map((n) => n.id).toSet();
      record('scope', 'bounded', {
        'package': package.packageName,
        'version': package.version,
        'build_number': package.buildNumber,
        'existing_task_count': initialTasks.length,
        'existing_habit_count': initialHabits.length,
        'existing_note_count': initialNotes.length,
        'limits': [
          'No cloud/auth/billing requests',
          'No tutorial replay claim',
          'Navigation revisit and repository persistence only; no process restart claim',
          'No rapid completion or all-surface completion claim',
        ],
      });
      await navigate('Reality Builder');
      final goalTitle = 'QA-JOURNEY-GOAL-$run';
      late String goalId;
      await caseRun('creator-goal-confirm', () async {
        await form('Goal', goalTitle, 'Synthetic journey attachment target');
        await reviewConfirm(
          () async => !container
              .read(domainGoalRepositoryProvider)
              .getGoals()
              .any((g) => g.title == goalTitle),
        );
        final goals = container
            .read(domainGoalRepositoryProvider)
            .getGoals()
            .where((g) => g.title == goalTitle)
            .toList();
        expect(goals, hasLength(1));
        goalId = goals.single.id;
        return {
          'goal_id': goalId,
          'title': goalTitle,
          'review_saved_nothing': true,
        };
      });
      await newItem();
      final taskTitle = 'QA-JOURNEY-ONE-OFF-$run';
      late String taskId;
      await caseRun('H08-one-off-confirm', () async {
        await form('Task', taskTitle, 'Synthetic task description');
        await textTap('No linked goal');
        await tap(find.text(goalTitle).hitTestable().last);
        await scheduleToday();
        await reviewConfirm(
          () async =>
              !(await taskRepo.getAllTasks()).any((t) => t.title == taskTitle),
        );
        await waitRead(
          () async =>
              (await taskRepo.getAllTasks()).any((t) => t.title == taskTitle),
          'Exact task was not persisted.',
        );
        final tasks = (await taskRepo.getAllTasks())
            .where((t) => t.title == taskTitle)
            .toList();
        expect(tasks, hasLength(1));
        final task = tasks.single;
        taskId = task.id;
        expect(task.recurrenceRule, RecurrenceRule.none);
        expect(task.goalId, goalId);
        expect(task.scheduledFor, isNotNull);
        expect(task.dueDate, isNull);
        expect(task.isCompleted, isFalse);
        return task.toJson();
      });
      await newItem();
      late String dailyTaskId;
      late String dailyTaskTitle;
      for (final rule in [RecurrenceRule.daily, RecurrenceRule.weekly]) {
        await caseRun('task-${rule.name}-repeat-field', () async {
          final title = 'QA-JOURNEY-${rule.name.toUpperCase()}-$run';
          await form('Task', title, 'Synthetic ${rule.name} recurrence');
          await tap(find.byKey(const Key('creator-task-repeat')));
          await tap(
            find
                .text(rule == RecurrenceRule.daily ? 'Daily' : 'Weekly')
                .hitTestable()
                .last,
          );
          await scheduleToday();
          await reviewConfirm(
            () async =>
                !(await taskRepo.getAllTasks()).any((t) => t.title == title),
          );
          await waitRead(
            () async =>
                (await taskRepo.getAllTasks()).any((t) => t.title == title),
            'Recurring task not persisted.',
          );
          final items = (await taskRepo.getAllTasks())
              .where((t) => t.title == title)
              .toList();
          expect(items, hasLength(1));
          expect(items.single.recurrenceRule, rule);
          expect(items.single.scheduledFor, isNotNull);
          if (rule == RecurrenceRule.daily) {
            dailyTaskId = items.single.id;
            dailyTaskTitle = title;
          }
          return {
            'task': items.single.toJson(),
            'limit':
                'Recurrence creation fields only, not H12/H13 successor completion.',
          };
        });
        await newItem();
      }
      await navigate('Timeline');
      final taskRow = find.byKey(
        ValueKey('timeline-event-semantics-timeline-projected-task-$taskId'),
      );
      Future<void> rowAction(String label) =>
          tap(find.descendant(of: taskRow, matching: find.text(label)));
      await caseRun('H14-partial-task-edit-save-cancel', () async {
        // Filter the real Timeline so existing level-20 history cannot select
        // an unrelated task or exhaust a lazy-list scroll budget.
        await textTap('Find & filter');
        final search = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Find an event, task, goal, or note',
        );
        await $(search).enterText(taskTitle);
        await dismissKeyboard();
        await rowAction('Edit');
        await $(
          const Key('timeline-task-description-field'),
        ).enterText('Saved journey edit $run');
        await dismissKeyboard();
        await textTap('Save');
        await waitRead(
          () async =>
              (await taskRepo.getTaskById(taskId))?.description ==
              'Saved journey edit $run',
          'Saved task edit must persist.',
        );
        await rowAction('Edit');
        await $(
          const Key('timeline-task-title-field'),
        ).enterText('Discarded task edit $run');
        await dismissKeyboard();
        await textTap('Cancel');
        final saved = (await taskRepo.getTaskById(taskId))!;
        expect(saved.title, taskTitle);
        expect(saved.description, 'Saved journey edit $run');
        expect(saved.goalId, goalId);
        return {
          'task_id': taskId,
          'cancel_preserved_title': saved.title,
          'description': saved.description,
        };
      });
      await caseRun('H09-H10-one-off-complete-revisit', () async {
        await rowAction('Complete');
        await waitRead(() async {
          final saved = await taskRepo.getTaskById(taskId);
          final records = await container
              .read(taskOccurrenceRepositoryProvider)
              .listOccurrencesForTask(taskId);
          return saved?.isCompleted == true &&
              records.length == 1 &&
              records.single.terminalOutcome ==
                  TaskOccurrenceOutcome.completed &&
              !(await container.read(
                allTasksProvider.future,
              )).any((t) => t.id == taskId);
        }, 'Single UI completion must become durable.');
        final completed = (await taskRepo.getTaskById(taskId))!;
        expect(completed.completedAt, isNotNull);
        final occurrences = await container
            .read(taskOccurrenceRepositoryProvider)
            .listOccurrencesForTask(taskId);
        expect(occurrences, hasLength(1));
        expect(
          occurrences.single.terminalOutcome,
          TaskOccurrenceOutcome.completed,
        );
        expect(
          (await taskRepo.getAllTasks()).where((t) => t.title == taskTitle),
          hasLength(1),
        );
        expect(
          (await container.read(
            allTasksProvider.future,
          )).any((t) => t.id == taskId),
          isFalse,
        );
        await navigate('Reality Builder');
        await library('Tasks', taskTitle);
        await $(
          find.byKey(ValueKey('library-task-$taskId')),
        ).waitUntilVisible();
        expect(
          find.descendant(
            of: find.byKey(ValueKey('library-task-$taskId')),
            matching: find.textContaining('Completed · '),
          ),
          findsOneWidget,
        );
        expect(
          (await taskRepo.getTaskById(taskId))!.completedAt,
          completed.completedAt,
        );
        expect(
          await container
              .read(taskOccurrenceRepositoryProvider)
              .listOccurrencesForTask(taskId),
          hasLength(1),
        );
        return {
          'task_id': taskId,
          'completed_at': completed.completedAt!.toIso8601String(),
          'one_occurrence_after_revisit': true,
          'limit':
              'H10 navigation revisit only; process close/reopen and reward persistence require separate evidence.',
        };
      });
      await tap(find.byTooltip('Back'), direction: AxisDirection.up);
      await caseRun('H12-H13-daily-completion-successor-revisit', () async {
        await navigate('Timeline');
        await textTap('Find & filter');
        final search = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Find an event, task, goal, or note',
        );
        await $(search).enterText(dailyTaskTitle);
        await dismissKeyboard();
        final original = (await taskRepo.getTaskById(dailyTaskId))!;
        final anchor = original.scheduledFor!.toLocal();
        final expectedNext = DateTime(
          anchor.year,
          anchor.month,
          anchor.day + 1,
          anchor.hour,
          anchor.minute,
          anchor.second,
          anchor.millisecond,
          anchor.microsecond,
        );
        expect(
          expectedNext.isAfter(DateTime.now()),
          isTrue,
          reason:
              'This run requires same-day completion, before the next cadence slot.',
        );
        final dailyRow = find.byKey(
          ValueKey(
            'timeline-event-semantics-timeline-projected-task-$dailyTaskId',
          ),
        );
        final complete = find.descendant(
          of: dailyRow,
          matching: find.widgetWithText(OutlinedButton, 'Complete'),
        );
        if (complete.hitTestable().evaluate().isEmpty) {
          await $(complete).scrollTo();
        }
        await $(complete.hitTestable()).waitUntilVisible();
        final xpBefore = container.read(profileProvider).xp;
        var taps = 1;
        await $.tester.tap(complete.hitTestable());
        await $.pump(const Duration(milliseconds: 1));
        // Re-query the visible original control. An enabled control receives a
        // second real tap; busy/removed controls are recorded as UI containment.
        final fresh = complete.hitTestable();
        var secondTapContained = fresh.evaluate().isEmpty;
        if (fresh.evaluate().isNotEmpty) {
          final button = $.tester.widget<OutlinedButton>(fresh);
          secondTapContained = button.onPressed == null;
          if (!secondTapContained) {
            await $.tester.tap(fresh);
            taps++;
          }
        }
        final occurrencesRepo = container.read(
          taskOccurrenceRepositoryProvider,
        );
        await waitRead(
          () async {
            final saved = await taskRepo.getTaskById(dailyTaskId);
            final records = await occurrencesRepo.listOccurrencesForTask(
              dailyTaskId,
            );
            return saved?.isCompleted == true &&
                records.length == 1 &&
                records.single.terminalOutcome ==
                    TaskOccurrenceOutcome.completed &&
                container.read(profileProvider).xp ==
                    xpBefore + ProgressionPolicy.completionXp &&
                !(await container.read(
                  allTasksProvider.future,
                )).any((t) => t.id == dailyTaskId);
          },
          'Daily original must complete once, leave active work, and award exactly one completion reward.',
        );
        final records = await occurrencesRepo.listOccurrencesForTask(
          dailyTaskId,
        );
        expect(
          records.single.transitions.where(
            (t) => t.outcome == TaskOccurrenceOutcome.completed,
          ),
          hasLength(1),
        );
        final related = (await taskRepo.getAllTasks())
            .where((t) => t.title == dailyTaskTitle)
            .toList();
        expect(
          related.where((t) => t.id == dailyTaskId && t.isCompleted),
          hasLength(1),
        );
        final successors = related.where((t) => t.id != dailyTaskId).toList();
        expect(successors, hasLength(1));
        final successor = successors.single;
        expect(
          successor.isCompleted || successor.isSkipped || successor.isCanceled,
          isFalse,
        );
        expect(successor.recurrenceRule, RecurrenceRule.daily);
        expect(successor.recurrenceSeriesId, records.single.seriesId);
        expect(successor.scheduledFor!.toLocal(), expectedNext);
        expect(successor.occurrenceKey, isNot(original.occurrenceKey));
        // Timeline listens to the async canonical list and schedules setState.
        // A completed provider future is not evidence that its next frame has
        // disposed the old keyed row. Do not treat it as a successor/series key:
        // projection and Semantics keys bind to each distinct entity ID.
        final disposalClock = Stopwatch()..start();
        var pumpedMilliseconds = 0;
        while (dailyRow.evaluate().isNotEmpty &&
            pumpedMilliseconds < 3000 &&
            disposalClock.elapsed < const Duration(seconds: 3)) {
          await $.pump(const Duration(milliseconds: 100));
          pumpedMilliseconds += 100;
        }
        disposalClock.stop();
        expect(
          dailyRow,
          findsNothing,
          reason:
              'The terminal original task key must be fully disposed after bounded render-frame settlement.',
        );
        final successorRow = find.byKey(
          ValueKey(
            'timeline-event-semantics-timeline-projected-task-${successor.id}',
          ),
        );
        expect(successorRow, findsOneWidget);
        expect(
          find.descendant(
            of: successorRow,
            matching: find.text(dailyTaskTitle),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: successorRow,
            matching: find.text(
              'SCHEDULED ${DateTimeFormats.dateShort(expectedNext)}',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: successorRow, matching: find.text('Complete')),
          findsOneWidget,
          reason:
              'The remaining completion control belongs only to the distinctly keyed next-day successor.',
        );
        record('daily-original-row-render-settlement', 'observed', {
          'original_task_id': dailyTaskId,
          'successor_task_id': successor.id,
          'original_key_fully_disposed': true,
          'successor_ui_date_matches': true,
          'pumped_milliseconds': pumpedMilliseconds,
          'elapsed_wall_milliseconds': disposalClock.elapsedMilliseconds,
          'performance_acceptance_claimed': false,
        });
        expect(
          find.descendant(of: dailyRow, matching: find.text('Complete')),
          findsNothing,
        );
        final xpAfter = container.read(profileProvider).xp;
        await navigate('Reality Builder');
        await library('Tasks', dailyTaskTitle);
        final completedTile = find.byKey(ValueKey('library-task-$dailyTaskId'));
        final successorTile = find.byKey(
          ValueKey('library-task-${successor.id}'),
        );
        await $(completedTile).waitUntilVisible();
        expect(
          find.descendant(
            of: completedTile,
            matching: find.textContaining('Completed'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: successorTile,
            matching: find.textContaining('Active'),
          ),
          findsOneWidget,
        );
        await tap(find.byTooltip('Back'), direction: AxisDirection.up);
        await navigate('Timeline');
        await $.pump(const Duration(seconds: 1));
        expect(container.read(profileProvider).xp, xpAfter);
        expect(
          (await taskRepo.getAllTasks()).where(
            (t) => t.title == dailyTaskTitle,
          ),
          hasLength(2),
        );
        expect((await taskRepo.getTaskById(dailyTaskId))!.isCompleted, isTrue);
        expect(
          await occurrencesRepo.listOccurrencesForTask(dailyTaskId),
          hasLength(1),
        );
        expect(
          find.byKey(
            ValueKey(
              'timeline-event-semantics-timeline-projected-task-$dailyTaskId',
            ),
          ),
          findsNothing,
        );
        await navigate('Reality Builder');
        return {
          'original_task_id': dailyTaskId,
          'successor_task': successor.toJson(),
          'terminal_occurrence': records.single.toJson(),
          'xp_before': xpBefore,
          'xp_after': xpAfter,
          'expected_reward': ProgressionPolicy.completionXp,
          'actual_completion_taps': taps,
          'second_tap_contained_by_busy_or_removed_control': secondTapContained,
          'limit':
              'Same-day daily recurrence and navigation revisit. No process restart or weekly completion claim.',
        };
      });
      final rhythmTitle = 'QA-JOURNEY-RHYTHM-$run';
      late String habitId;
      await caseRun('rhythm-create-weekly-target', () async {
        await form('Daily Rhythm', rhythmTitle, 'Synthetic weekly rhythm');
        await textTap('Weekly');
        await tap(find.byTooltip('Increase target count'));
        await reviewConfirm(
          () async =>
              !(await habitRepo.getHabits()).any((h) => h.title == rhythmTitle),
        );
        await waitRead(
          () async =>
              (await habitRepo.getHabits()).any((h) => h.title == rhythmTitle),
          'Rhythm must persist.',
        );
        final items = (await habitRepo.getHabits())
            .where((h) => h.title == rhythmTitle)
            .toList();
        expect(items, hasLength(1));
        final habit = items.single;
        habitId = habit.id;
        expect(habit.cadence, HabitCadence.weekly);
        expect(habit.targetCount, 2);
        expect(habit.active, isTrue);
        return {
          'habit_id': habitId,
          'cadence': habit.cadence.name,
          'target': habit.targetCount,
        };
      });
      await newItem();
      await textTap('Manage Daily Rhythms');
      final habitCard = find.ancestor(
        of: find.text(rhythmTitle),
        matching: find.byType(TemporalGlassSurface),
      );
      Future<void> habitAction(String label) =>
          tap(find.descendant(of: habitCard, matching: find.text(label)));
      await caseRun('rhythm-outcome-pause-resume', () async {
        await waitRead(
          () async => container.read(habitOccurrencesProvider).hasValue,
          'Rhythm outcomes must load before recording.',
        );
        await habitAction('Mark target completed');
        final occurrenceRepo = container.read(
          habitOccurrenceRepositoryProvider,
        )!;
        await waitRead(
          () async =>
              (await occurrenceRepo.load()).any((o) => o.habitId == habitId),
          'Outcome must persist.',
        );
        final outcomes = (await occurrenceRepo.load())
            .where((o) => o.habitId == habitId)
            .toList();
        expect(outcomes, hasLength(1));
        expect(outcomes.single.outcome, HabitOccurrenceOutcome.completed);
        await habitAction('Pause');
        await waitRead(
          () async => !(await habitRepo.getHabits())
              .singleWhere((h) => h.id == habitId)
              .active,
          'Pause must persist.',
        );
        await habitAction('Resume');
        await waitRead(
          () async => (await habitRepo.getHabits())
              .singleWhere((h) => h.id == habitId)
              .active,
          'Resume must persist.',
        );
        final after = (await occurrenceRepo.load())
            .where((o) => o.habitId == habitId)
            .toList();
        expect(after, hasLength(1));
        expect(after.single.operationId, outcomes.single.operationId);
        return {
          'habit_id': habitId,
          'outcome': after.single.toJson(),
          'pause_resume_preserved_outcome': true,
        };
      });
      await caseRun('rhythm-frequency-save-cancel', () async {
        await habitAction('Edit frequency');
        await tap(find.byType(DropdownButton<HabitCadence>));
        await tap(find.text('Monthly').hitTestable().last);
        await textTap('Cancel');
        expect(
          (await habitRepo.getHabits())
              .singleWhere((h) => h.id == habitId)
              .cadence,
          HabitCadence.weekly,
        );
        await habitAction('Edit frequency');
        await tap(find.byType(DropdownButton<HabitCadence>));
        await tap(find.text('Daily').hitTestable().last);
        await textTap('Save');
        await waitRead(
          () async =>
              (await habitRepo.getHabits())
                  .singleWhere((h) => h.id == habitId)
                  .cadence ==
              HabitCadence.daily,
          'Saved cadence must persist.',
        );
        expect(
          (await habitRepo.getHabits())
              .singleWhere((h) => h.id == habitId)
              .targetCount,
          2,
        );
        expect(
          (await container.read(habitOccurrenceRepositoryProvider)!.load())
              .where((o) => o.habitId == habitId),
          hasLength(1),
        );
        return {
          'habit_id': habitId,
          'saved_cadence': 'daily',
          'canceled_monthly_preserved_weekly': true,
          'prior_outcome_retained': true,
        };
      });
      await tap(find.byTooltip('Back'), direction: AxisDirection.up);
      final noteTitle = 'QA-JOURNEY-NOTE-$run';
      final noteBody =
          'Synthetic note body retained through archive and restore $run';
      late String noteId;
      await caseRun('note-create-confirm', () async {
        await form('Note', noteTitle, noteBody);
        await reviewConfirm(
          () async =>
              !(await noteRepo.getNotes()).any((n) => n.title == noteTitle),
        );
        await waitRead(
          () async =>
              (await noteRepo.getNotes()).any((n) => n.title == noteTitle),
          'Exact note must persist.',
        );
        final items = (await noteRepo.getNotes())
            .where((n) => n.title == noteTitle)
            .toList();
        expect(items, hasLength(1));
        noteId = items.single.id;
        expect(items.single.body, noteBody);
        expect(items.single.isArchived, isFalse);
        return {'note_id': noteId, 'title': noteTitle, 'body': noteBody};
      });
      await newItem();
      await caseRun('note-archive-restore-revisit', () async {
        await library('Notes', noteTitle);
        await tap(find.byKey(ValueKey('library-note-$noteId')));
        expect(find.text(noteBody), findsOneWidget);
        await textTap('Archive');
        await tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Archive'),
          ),
        );
        await waitRead(
          () async => (await noteRepo.getNotes())
              .singleWhere((n) => n.id == noteId)
              .isArchived,
          'Archived note must remain stored.',
        );
        await tap(find.byTooltip('Back'), direction: AxisDirection.up);
        final tile = find.byKey(ValueKey('library-note-$noteId'));
        await tap(find.descendant(of: tile, matching: find.text('Restore')));
        await waitRead(
          () async => !(await noteRepo.getNotes())
              .singleWhere((n) => n.id == noteId)
              .isArchived,
          'Restore must retain the same note ID.',
        );
        await tap(tile);
        expect(find.text(noteBody), findsOneWidget);
        final items = (await noteRepo.getNotes())
            .where((n) => n.title == noteTitle)
            .toList();
        expect(items, hasLength(1));
        expect(items.single.id, noteId);
        expect(items.single.body, noteBody);
        return {'note_id': noteId, 'same_id_and_body_restored': true};
      });
      expect(
        (await taskRepo.getAllTasks())
            .map((t) => t.id)
            .toSet()
            .containsAll(initialTasks),
        isTrue,
      );
      expect(
        (await habitRepo.getHabits())
            .map((h) => h.id)
            .toSet()
            .containsAll(initialHabits),
        isTrue,
      );
      expect(
        (await noteRepo.getNotes())
            .map((n) => n.id)
            .toSet()
            .containsAll(initialNotes),
        isTrue,
      );
      record('preservation', 'passed', {
        'all_preexisting_task_habit_note_ids_retained': true,
      });
    },
    timeout: const Timeout(Duration(minutes: 18)),
    config: const PatrolTesterConfig(
      settlePolicy: SettlePolicy.noSettle,
      printLogs: true,
    ),
  );
}
