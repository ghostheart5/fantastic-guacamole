import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:fantastic_guacamole/app/startup/app_bootstrap.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fantastic_guacamole/domain/policies/progression_policy.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest(
    'real local UI earns level 20 without XP injection',
    ($) async {
      final package = await PackageInfo.fromPlatform();
      expect(package.packageName, 'com.ghostheart5.chronospark.qa');
      expect(Platform.isAndroid && kDebugMode && Env.isLocalMode, isTrue);
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
      final startupEnd = DateTime.now().add(const Duration(seconds: 40));
      var continuedWelcome = false;
      while (!$(const Key('local-profile-continue')).exists &&
          !$(find.byTooltip('Open navigation map')).exists &&
          DateTime.now().isBefore(startupEnd)) {
        if (!continuedWelcome && $('CONTINUE TO LOGIN').exists) {
          await $('CONTINUE TO LOGIN').scrollTo();
          await $('CONTINUE TO LOGIN').tap();
          continuedWelcome = true;
        }
        await $.pump(const Duration(milliseconds: 200));
      }
      debugPrint(
        'AXIOMARA_STARTUP_TEXTS ${$.tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).toList()}',
      );
      if ($(const Key('local-profile-continue')).exists) {
        await $(const Key('local-profile-continue')).tap();
      }
      if (!$(find.byTooltip('Open navigation map')).exists) {
        await $(const Key('first-value-skip')).waitUntilVisible();
        await $(const Key('first-value-skip')).tap();
      }
      await $.pump(const Duration(seconds: 1));
      if ($('Pause guide').exists) await $('Pause guide').tap();
      final context = $.tester.element(find.byType(StartupBootstrapGate).first);
      final container = ProviderScope.containerOf(context, listen: false);
      final folder = await getApplicationDocumentsDirectory();
      final receipts = File('${folder.path}/level20-ui-receipts.jsonl');
      void record(Map<String, Object?> event) {
        final line = jsonEncode({
          ...event,
          'operator': 'codex_ai',
          'lane': 'real_widgets_on_physical_android_local_backend',
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
            'capture_type': 'actual Flutter render on bound physical device',
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
