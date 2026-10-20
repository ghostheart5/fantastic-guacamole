import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fantastic_guacamole/app/startup/app_bootstrap.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';
import 'current_navigation_support.dart';

void main() {
  patrolTest(
    'real local UI earns level 20 without XP injection',
    ($) async {
      final package = await PackageInfo.fromPlatform();
      expect(package.packageName, 'com.ghostheart5.chronospark.qa');
      expect(package.version, '4.2.4-qa');
      expect(package.buildNumber, '2026101201');
      expect(Platform.isAndroid && kDebugMode && Env.isLocalMode, isTrue);
      final device = await DeviceInfoPlugin().androidInfo;
      expect(
        device.isPhysicalDevice,
        isFalse,
        reason: 'This actor is bound to the separate full Android emulator.',
      );
      expect(
        Env.isMockMode ||
            Env.isMockLoginEnabled ||
            Env.isPaywallDisabled ||
            Env.hasTesterFullAccess,
        isFalse,
      );
      final screenshotKey = GlobalKey();
      await $.pumpWidget(
        RepaintBoundary(
          key: screenshotKey,
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
      final context = $.tester.element(find.byType(StartupBootstrapGate).first);
      final container = ProviderScope.containerOf(context, listen: false);
      final folder = await getApplicationDocumentsDirectory();
      final receipts = File('${folder.path}/level20-ui-receipts.jsonl');
      final baselineFile = File(
        '${folder.path}/level20-preservation-baseline.json',
      );
      void record(Map<String, Object?> event) {
        final line = jsonEncode({
          ...event,
          'operator': 'codex_ai',
          'lane': 'real_widgets_on_android_emulator_local_backend',
          'device': {
            'is_physical_device': device.isPhysicalDevice,
            'model': device.model,
            'fingerprint': device.fingerprint,
            'sdk_int': device.version.sdkInt,
          },
          'package': package.packageName,
          'version': package.version,
          'build_number': package.buildNumber,
          'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
        });
        receipts.writeAsStringSync(
          '$line\n',
          mode: FileMode.append,
          flush: true,
        );
        debugPrint('AXIOMARA_UI_RECEIPT $line');
      }

      Future<void> captureLevel(int level) async {
        await $.pump(const Duration(milliseconds: 100));
        final boundary =
            screenshotKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final path = '${folder.path}/level-$level-visible-profile.png';
          File(path).writeAsBytesSync(bytes!.buffer.asUint8List(), flush: true);
          record({
            'action': 'visible_profile_capture',
            'level': level,
            'file': path,
            'capture_type': 'actual Flutter render on bound Android emulator',
          });
        } finally {
          image.dispose();
        }
      }

      Future<void> waitFor(bool Function() condition, String reason) async {
        final end = DateTime.now().add(const Duration(seconds: 30));
        while (!condition() && DateTime.now().isBefore(end)) {
          await $.pump(const Duration(milliseconds: 100));
        }
        expect(condition(), isTrue, reason: reason);
      }

      Future<void> navigate(String label) async {
        final destination = label == 'Goals' ? 'Nexus Core' : label;
        if (!$(find.byTooltip('Open navigation map')).exists &&
            $(find.byTooltip('Back')).exists) {
          await $(find.byTooltip('Back')).tap();
        }
        await $(find.byTooltip('Open navigation map')).tap();
        final item = find.widgetWithText(ListTile, destination);
        await $(item).scrollTo();
        await $(item).tap();
        await $.pump(const Duration(milliseconds: 400));
        if (label == 'Goals') {
          for (
            var swipe = 0;
            swipe < 30 && find.text('GOAL').hitTestable().evaluate().isEmpty;
            swipe++
          ) {
            await $.tester.drag(
              find.byType(CustomScrollView).first,
              const Offset(0, -450),
            );
            await $.pump(const Duration(milliseconds: 300));
          }
          debugPrint(
            'AXIOMARA_GOALS_ROUTE_TEXTS ${$.tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).toList()}',
          );
          await $('GOAL').tap();
          await settleCurrentUserNavigation(
            $,
            destinationReady: () =>
                find.byTooltip('Add goal').hitTestable().evaluate().isNotEmpty,
          );
          await $(find.byTooltip('Add goal')).waitUntilVisible();
        }
      }

      final initial = container.read(profileProvider);
      final previous = receipts.existsSync()
          ? receipts
                .readAsLinesSync()
                .where((line) => line.trim().isNotEmpty)
                .map((line) => jsonDecode(line) as Map<String, dynamic>)
                .toList()
          : <Map<String, dynamic>>[];
      var completedSequence = 0;
      var createdSequence = 0;
      for (final event in previous) {
        if (event['action'] == 'complete_goal') {
          completedSequence = event['sequence'] as int;
        }
        if (event['action'] == 'create_goal') {
          createdSequence = event['sequence'] as int;
        }
      }
      expect(
        createdSequence == completedSequence ||
            createdSequence == completedSequence + 1,
        isTrue,
      );
      final pendingCreation = createdSequence == completedSequence + 1;
      expect(
        initial.xp,
        completedSequence * 52 + (pendingCreation ? 12 : 0),
        reason: 'Existing XP must match only the recorded ordinary UI actions.',
      );
      expect(initial.level, ProgressionPolicy.levelFromXp(initial.xp));

      // Repositories are read-only oracles. Retain the original baseline on
      // resume so restarting the actor cannot conceal prior collateral edits.
      Future<Map<String, Object?>> canonicalSnapshot() async {
        final habitOccurrences = container.read(
          habitOccurrenceRepositoryProvider,
        );
        expect(habitOccurrences, isNotNull);
        return {
          'tasks': (await container.read(taskRepositoryProvider).getAllTasks())
              .map((item) => item.toJson())
              .toList(),
          'habits': (await container.read(habitRepositoryProvider).getHabits())
              .map((item) => item.toJson())
              .toList(),
          'notes': (await container.read(noteRepositoryProvider).getNotes())
              .map((item) => item.toJson())
              .toList(),
          'goals': container
              .read(goalRepositoryProvider)
              .getGoals()
              .map((item) => item.toJson())
              .toList(),
          'task_occurrences':
              (await container
                      .read(taskOccurrenceRepositoryProvider)
                      .listOccurrences())
                  .map(
                    (item) => <String, dynamic>{
                      'id': item.id,
                      'canonical_json': item.toJson(),
                    },
                  )
                  .toList(),
          'habit_occurrences': (await habitOccurrences!.load())
              .map(
                (item) => <String, dynamic>{
                  'id': item.id,
                  'canonical_json': item.toJson(),
                },
              )
              .toList(),
        };
      }

      if (previous.isEmpty) {
        expect(
          initial.xp,
          0,
          reason: 'Fresh acceptance must start at zero XP.',
        );
        expect(
          baselineFile.existsSync(),
          isFalse,
          reason:
              'An orphan baseline requires external inspection, not overwrite.',
        );
        await baselineFile.writeAsString(
          jsonEncode(await canonicalSnapshot()),
          flush: true,
        );
      } else {
        expect(
          baselineFile.existsSync(),
          isTrue,
          reason: 'Resume requires the original preservation baseline.',
        );
      }
      final baseline =
          jsonDecode(await baselineFile.readAsString()) as Map<String, dynamic>;
      expect(
        baseline.keys,
        unorderedEquals(const <String>[
          'tasks',
          'habits',
          'notes',
          'goals',
          'task_occurrences',
          'habit_occurrences',
        ]),
      );
      Future<void> verifyPreservation(int completed) async {
        final current = await canonicalSnapshot();
        for (final entry in baseline.entries) {
          final expectedRows = entry.value as List<dynamic>;
          final actualRows = current[entry.key]! as List<dynamic>;
          final byId = <String, dynamic>{
            for (final dynamic row in actualRows)
              (row as Map<String, dynamic>)['id'] as String: row,
          };
          expect(
            byId.length,
            actualRows.length,
            reason: '${entry.key} must have unique canonical record IDs.',
          );
          for (final dynamic row in expectedRows) {
            expect(
              byId[(row as Map<String, dynamic>)['id']],
              equals(row),
              reason: 'Preexisting ${entry.key} must remain exactly unchanged.',
            );
          }
          if (entry.key != 'goals') {
            expect(
              actualRows.length,
              expectedRows.length,
              reason: 'Goal UI actions must not add unrelated ${entry.key}.',
            );
          } else {
            expect(
              actualRows.length,
              expectedRows.length + completed,
              reason:
                  'Every UI-completed QA goal must remain in canonical history.',
            );
            for (var sequence = 1; sequence <= completed; sequence++) {
              final title =
                  'QA Level20 goal ${sequence.toString().padLeft(4, '0')}';
              final goals = actualRows
                  .where(
                    (dynamic row) =>
                        (row as Map<String, dynamic>)['title'] == title,
                  )
                  .toList();
              expect(goals, hasLength(1));
              expect(
                (goals.single as Map<String, dynamic>)['completedAt'],
                isNotNull,
              );
            }
          }
        }
        record({
          'action': 'canonical_preservation_passed',
          'completed_sequence': completed,
          'baseline_file': baselineFile.path,
          'counts': {
            for (final entry in current.entries)
              entry.key: (entry.value! as List<dynamic>).length,
          },
        });
      }

      // A pending creation is verified after its ordinary UI completion below.
      if (!pendingCreation) await verifyPreservation(completedSequence);
      record({
        'action': previous.isEmpty ? 'baseline' : 'resume_checkpoint',
        'xp': initial.xp,
        'level': initial.level,
        'completed_sequence': completedSequence,
      });
      if (!previous.any(
        (event) =>
            event['action'] == 'level_ui_readback' &&
            event['level'] == initial.level,
      )) {
        await navigate('Human Profile');
        expect(
          find.textContaining('AXIOMARA LEVEL ${initial.level}'),
          findsWidgets,
        );
        record({
          'action': 'level_ui_readback',
          'level': initial.level,
          'xp': initial.xp,
        });
        await captureLevel(initial.level);
      }
      await navigate('Goals');
      var lastLevel = initial.level;
      for (var sequence = completedSequence + 1; sequence <= 695; sequence++) {
        final resumingCreation = pendingCreation && sequence == createdSequence;
        final before =
            container.read(profileProvider).xp - (resumingCreation ? 12 : 0);
        final title = 'QA Level20 goal ${sequence.toString().padLeft(4, '0')}';
        if (!resumingCreation) {
          await $(find.byTooltip('Add goal')).tap();
          await $(TextField).at(0).enterText(title);
          await $('ADD GOAL').scrollTo();
          await $('ADD GOAL').tap();
          await waitFor(
            () =>
                container
                    .read(goalsProvider)
                    .any((goal) => goal.title == title) &&
                container.read(profileProvider).xp == before + 12,
            'Named goal and its creation XP must be visible before completion.',
          );
          final created = container.read(profileProvider).xp;
          expect(created - before, 12);
          record({
            'action': 'create_goal',
            'sequence': sequence,
            'title': title,
            'before_xp': before,
            'after_xp': created,
            'expected_delta': 12,
          });
        }
        final created = container.read(profileProvider).xp;
        final goalCard = find.ancestor(
          of: find.text(title),
          matching: find.byType(Dismissible),
        );
        await $(goalCard).waitUntilVisible();
        final bounds = $.tester.getRect(goalCard);
        await $.tester.dragFrom(
          Offset(bounds.right - 20, bounds.center.dy),
          Offset(-(bounds.width - 40), 0),
        );
        await waitFor(
          () =>
              !container
                  .read(goalsProvider)
                  .any((goal) => goal.title == title) &&
              container.read(profileProvider).xp == created + 40,
          'Named goal completion and its XP must finish before the next action.',
        );
        final profile = container.read(profileProvider);
        expect(profile.xp - created, 40);
        expect(profile.level, ProgressionPolicy.levelFromXp(profile.xp));
        record({
          'action': 'complete_goal',
          'sequence': sequence,
          'title': title,
          'before_xp': created,
          'after_xp': profile.xp,
          'expected_delta': 40,
          'level': profile.level,
        });
        if (profile.level != lastLevel) {
          await verifyPreservation(sequence);
          await navigate('Human Profile');
          expect(
            find.textContaining('AXIOMARA LEVEL ${profile.level}'),
            findsWidgets,
          );
          record({
            'action': 'level_ui_readback',
            'level': profile.level,
            'xp': profile.xp,
          });
          await captureLevel(profile.level);
          lastLevel = profile.level;
          await navigate('Goals');
        }
      }
      final finalProfile = container.read(profileProvider);
      expect(finalProfile.xp, 36140);
      expect(finalProfile.level, 20);
      await verifyPreservation(695);
      await navigate('Human Profile');
      await captureLevel(20);
      record({
        'action': 'level20_ui_readback',
        'xp': finalProfile.xp,
        'level': finalProfile.level,
        'restart_acceptance': 'pending_external_restart',
      });
    },
    timeout: const Timeout(Duration(hours: 2)),
    config: const PatrolTesterConfig(
      settlePolicy: SettlePolicy.noSettle,
      printLogs: true,
    ),
  );
}
