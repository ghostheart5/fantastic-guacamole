import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fantastic_guacamole/app/startup/app_bootstrap.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_handshake_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

import 'current_navigation_support.dart';

// Normal app controls perform all mutations. Canonical providers and prefs are
// read-only corroboration; this is separate from first-helpful-choice onboarding.
void main() {
  patrolTest('adaptive guide replay saves and completes one exact real task', (
    $,
  ) async {
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
    final repo = container.read(domainTaskRepositoryProvider);
    final occurrences = container.read(taskOccurrenceRepositoryProvider);
    final beforeTasks = await repo.getAllTasks();
    final beforeIds = beforeTasks.map((task) => task.id).toSet();
    final beforeRecords = {
      for (final task in beforeTasks) task.id: task.toJson(),
    };
    final beforeGuidance = await container.read(
      adaptiveGuidanceProvider.future,
    );
    final scope = container.read(accountStorageScopeProvider);
    expect(scope.isWritable, isTrue);
    final prefix = 'adaptive_guidance_v3.${scope.v2Namespace}';
    final run = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    final title = 'QA-GUIDE-TASK-$run';
    final documents = await getApplicationDocumentsDirectory();
    final evidence = Directory('${documents.path}/adaptive-guide-$run');
    await evidence.create(recursive: true);
    final events = File('${evidence.path}/events.jsonl');
    void record(String id, String status, Map<String, Object?> details) {
      final line = jsonEncode({
        'case': id,
        'status': status,
        'run': run,
        'operator': 'codex_ai',
        'backend': 'real_local_public_policy',
        'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
        ...details,
      });
      events.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
      debugPrint('AXIOMARA_ADAPTIVE_GUIDE $line');
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
      Future<Map<String, Object?>> Function() body,
    ) async {
      record(id, 'started', {});
      try {
        final result = await body();
        expect($.tester.takeException(), isNull);
        record(id, 'passed', {...result, 'screenshot': await capture(id)});
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

    Future<void> dismissKeyboard() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await $.pump(const Duration(milliseconds: 250));
    }

    Future<void> navigate(String label) async {
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
      await tap(find.widgetWithText(ListTile, label));
      await settleCurrentUserNavigation(
        $,
        destinationReady: () =>
            find
                .byTooltip('Back to Nexus')
                .hitTestable()
                .evaluate()
                .isNotEmpty ||
            find.byTooltip('Back').hitTestable().evaluate().isNotEmpty,
      );
    }

    record('baseline', 'observed', {
      'existing_task_count': beforeTasks.length,
      'core_complete_before': beforeGuidance.coreComplete,
      'limits': [
        'No process restart or cloud/billing claim',
        'Finish guide is used only if the actual recovery CTA appears',
        'Synthetic task remains as completed audit evidence',
      ],
    });
    await caseRun('guide-restart-real-settings-control', () async {
      await navigate('Control Center');
      if (find.text('Restart Adaptive Guide').evaluate().isEmpty) {
        await tap(find.text('Planning & guidance'));
      }
      await tap(find.text('Restart Adaptive Guide'));
      await waitRead(
        () async =>
            container
                .read(adaptiveGuidanceProvider)
                .asData
                ?.value
                .activeCoreLesson ==
            GuidanceLessonId.createFirstItem,
        'Restart must activate the first replayed core lesson.',
      );
      final restarted = container.read(adaptiveGuidanceProvider).requireValue;
      for (final milestone in beforeGuidance.milestones.entries) {
        expect(restarted.milestones[milestone.key], milestone.value);
      }
      expect(
        restarted.replayLessons,
        containsAll([
          GuidanceLessonId.createFirstItem,
          GuidanceLessonId.scheduleFirstItem,
          GuidanceLessonId.reviewTimeline,
        ]),
      );
      expect(
        (await repo.getAllTasks()).map((task) => task.id).toSet(),
        beforeIds,
      );
      await tap(find.text('Open Creator'));
      await $(find.text('Name the real task')).waitUntilVisible();
      return {'existing_outcomes_preserved': true, 'replay_core_active': true};
    });
    await caseRun('guide-real-title-priority-and-due-schedule', () async {
      // The production spotlight key is on TextField itself, not a parent.
      // find.descendant excludes its root and therefore cannot locate it.
      final titleField = find.byKey(FirstRunTutorialTargets.creatorTitle);
      expect(titleField, findsOneWidget);
      expect($.tester.widget(titleField), isA<TextField>());
      await $(titleField).enterText(title);
      await dismissKeyboard();
      await tap(find.text('Title entered'));
      await tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is SmartPressable &&
              widget.semanticLabel == 'Set priority level 3',
        ),
      );
      await tap(find.text('Priority chosen'));
      await tap(find.text('Schedule date and time...'));
      await $(find.byType(DatePickerDialog)).waitUntilVisible();
      await tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.widgetWithText(TextButton, 'OK'),
        ),
      );
      await $(find.byType(TimePickerDialog)).waitUntilVisible();
      if (find.byTooltip('Switch to text input mode').evaluate().isNotEmpty) {
        await tap(find.byTooltip('Switch to text input mode'));
      }
      final dialog = find.byType(TimePickerDialog);
      final fields = find.descendant(
        of: dialog,
        matching: find.byType(TextField),
      );
      expect(fields, findsNWidgets(2));
      // Same day at midnight is actually due; no device clock or domain writes.
      final twelveHour = find
          .descendant(of: dialog, matching: find.text('AM'))
          .evaluate()
          .isNotEmpty;
      await $(fields.at(0)).enterText(twelveHour ? '12' : '0');
      await $(fields.at(1)).enterText('00');
      await dismissKeyboard();
      if (twelveHour) {
        await tap(find.descendant(of: dialog, matching: find.text('AM')));
      }
      await tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(TextButton, 'OK'),
        ),
      );
      await tap(find.text('Schedule chosen'));
      expect(
        (await repo.getAllTasks()).any((task) => task.title == title),
        isFalse,
      );
      return {
        'title': title,
        'priority_ui': 3,
        'schedule_ui': 'today 00:00',
        'unsaved_before_review': true,
      };
    });
    late String taskId;
    await caseRun('guide-review-confirm-exact-one-task', () async {
      await tap(find.text('Review changes'));
      await $(find.text('Confirm the exact task')).waitUntilVisible();
      expect(
        (await repo.getAllTasks()).any((task) => task.title == title),
        isFalse,
      );
      final preview = container.read(creatorHandshakeProvider).preview!;
      expect(preview.selectedOperations, hasLength(1));
      final operation = preview.selectedOperations.single;
      expect(operation.task.title, title);
      expect(operation.task.priority, 3);
      expect(operation.task.scheduledFor, isNotNull);
      expect(operation.task.scheduledFor!.isAfter(DateTime.now()), isFalse);
      await tap(find.text('Confirm and open Timeline'));
      await waitRead(
        () async =>
            (await repo.getAllTasks())
                .where((task) => task.title == title)
                .length ==
            1,
        'Final visible confirmation must save exactly one task.',
      );
      final task = (await repo.getAllTasks()).singleWhere(
        (task) => task.title == title,
      );
      taskId = task.id;
      expect(task.isCompleted, isFalse);
      expect(
        container
            .read(adaptiveGuidanceProvider)
            .requireValue
            .expectedFirstRunCreatorTaskIds,
        {taskId},
      );
      await $(find.text('I found my task')).waitUntilVisible();
      return {
        'task_id': taskId,
        'exact_one_task_saved': true,
        'review_saved_nothing': true,
        'timeline_receipt_matches': true,
      };
    });
    await caseRun('guide-find-complete-and-finish', () async {
      await tap(find.text('I found my task'));
      await $(find.text('Complete your task')).waitUntilVisible();
      await tap(find.byKey(FirstRunTutorialTargets.timelineCompletion));
      await waitRead(
        () async => (await repo.getTaskById(taskId))?.isCompleted == true,
        'Highlighted task completion must persist.',
      );
      await $.pump(const Duration(milliseconds: 700));
      final recovery = find.text('Finish guide').hitTestable();
      final usedRecovery = recovery.evaluate().isNotEmpty;
      if (usedRecovery) await tap(recovery);
      await waitRead(
        () async =>
            container
                .read(adaptiveGuidanceProvider)
                .asData
                ?.value
                .activeCoreLesson ==
            null,
        'Completion or the visible Finish guide recovery must finish core guidance.',
      );
      final guidance = container.read(adaptiveGuidanceProvider).requireValue;
      expect(guidance.coreComplete, isTrue);
      expect(
        guidance.count(GuidanceMilestone.firstTimelineReview),
        beforeGuidance.count(GuidanceMilestone.firstTimelineReview) + 1,
      );
      expect(guidance.replayLessons, isEmpty);
      expect(guidance.expectedFirstRunCreatorTaskIds, isEmpty);
      final outcomes = await occurrences.listOccurrencesForTask(taskId);
      expect(outcomes, hasLength(1));
      expect(outcomes.single.terminalOutcome, TaskOccurrenceOutcome.completed);
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      for (final lesson in [
        GuidanceLessonId.createFirstItem,
        GuidanceLessonId.scheduleFirstItem,
        GuidanceLessonId.reviewTimeline,
      ]) {
        expect(prefs.getBool('$prefix.replay.${lesson.name}'), isNot(true));
        expect(prefs.getBool('$prefix.complete.${lesson.name}'), isTrue);
      }
      expect(
        prefs.getStringList('$prefix.expected_first_run_creator_task_ids'),
        isNull,
      );
      return {
        'task_id': taskId,
        'one_terminal_completion': true,
        'finish_guide_recovery_tapped': usedRecovery,
        'persisted_core_flags': true,
      };
    });
    await caseRun('guide-revisit-no-repeat-or-duplicate', () async {
      await navigate('Control Center');
      await navigate('Truth Ledger');
      expect(find.text('I found my task'), findsNothing);
      expect(find.text('Finish guide'), findsNothing);
      final after = await repo.getAllTasks();
      expect(after.where((task) => task.title == title), hasLength(1));
      expect(
        after.map((task) => task.id).toSet().containsAll(beforeIds),
        isTrue,
      );
      expect(after.map((task) => task.id).toSet().difference(beforeIds), {
        taskId,
      });
      for (final task in after.where((task) => beforeIds.contains(task.id))) {
        expect(
          task.toJson(),
          beforeRecords[task.id],
          reason: 'Replaying the guide must preserve every preexisting task.',
        );
      }
      expect((await repo.getTaskById(taskId))!.isCompleted, isTrue);
      expect(await occurrences.listOccurrencesForTask(taskId), hasLength(1));
      expect(
        container.read(adaptiveGuidanceProvider).requireValue.activeCoreLesson,
        isNull,
      );
      return {
        'task_id': taskId,
        'all_preexisting_tasks_preserved': true,
        'one_added_task_only': true,
        'no_repeat_guide_after_navigation': true,
        'no_process_restart_claim': true,
      };
    });
  });
}
