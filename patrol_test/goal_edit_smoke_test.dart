import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fantastic_guacamole/app/startup/app_bootstrap.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest(
    'fresh local profile creates edits cancels and completes one goal through UI',
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
      final captureKey = GlobalKey();
      await $.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: const ProviderScope(child: StartupBootstrapGate()),
        ),
      );
      Future<void> waitFor(bool Function() ready, String reason) async {
        final end = DateTime.now().add(const Duration(seconds: 40));
        while (!ready() && DateTime.now().isBefore(end)) {
          await $.pump(const Duration(milliseconds: 200));
        }
        expect(ready(), isTrue, reason: reason);
      }

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
      if ($(const Key('local-profile-continue')).exists) {
        await $(const Key('local-profile-continue')).tap();
      }
      if (!$(find.byTooltip('Open navigation map')).exists) {
        await $(const Key('first-value-skip')).waitUntilVisible();
        await $(const Key('first-value-skip')).tap();
      }
      await $.pump(const Duration(seconds: 1));
      if ($('Pause guide').exists) await $('Pause guide').tap();
      final container = ProviderScope.containerOf(
        $.tester.element(find.byType(StartupBootstrapGate).first),
        listen: false,
      );
      expect(
        container.read(goalsProvider),
        isEmpty,
        reason: 'Cloud smoke requires a fresh QA profile.',
      );
      for (
        var swipe = 0;
        swipe < 20 && find.text('GOAL').hitTestable().evaluate().isEmpty;
        swipe++
      ) {
        await $.tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -450),
        );
        await $.pump(const Duration(milliseconds: 300));
      }
      await $('GOAL').tap();
      await $(find.byTooltip('Add goal')).waitUntilVisible();
      await $(find.byTooltip('Add goal')).tap();
      const title = 'QA Cloud fold one towel';
      const description = 'QA Cloud edited description with keyboard focused.';
      await $(TextField).at(0).enterText(title);
      await $('ADD GOAL').scrollTo();
      await $('ADD GOAL').tap();
      await waitFor(
        () => container.read(goalsProvider).any((goal) => goal.title == title),
        'The exact goal must be saved through its UI.',
      );
      await $(find.byTooltip('Manage goal')).tap();
      await $('Edit goal').tap();
      await $(const Key('edit-goal-description')).enterText(description);
      await $('Save').tap();
      await $.pump(const Duration(milliseconds: 16));
      await $.pump(const Duration(milliseconds: 400));
      expect($.tester.takeException(), isNull);
      await waitFor(
        () => container.read(goalsProvider).single.description == description,
        'The saved description must persist in its goal record.',
      );
      await $(find.byTooltip('Manage goal')).tap();
      await $('Edit goal').tap();
      expect(
        $.tester
            .widget<TextField>(find.byKey(const Key('edit-goal-description')))
            .controller!
            .text,
        description,
      );
      await $(
        const Key('edit-goal-description'),
      ).enterText('QA discarded edit');
      await $('Cancel').tap();
      await $.pump(const Duration(milliseconds: 16));
      await $.pump(const Duration(milliseconds: 400));
      expect($.tester.takeException(), isNull);
      expect(container.read(goalsProvider).single.description, description);
      final directory = await getExternalStorageDirectory();
      expect(directory, isNotNull);
      final receiptDirectory = Directory(
        '${directory!.path}/axiomara-goal-smoke',
      );
      await receiptDirectory.create(recursive: true);
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${receiptDirectory.path}/goal-edit-after.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
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
        () => container.read(goalsProvider).isEmpty,
        'Goal completes only after the normal swipe action.',
      );
      expect($.tester.takeException(), isNull);
      final receipt = {
        'operator': 'codex_ai',
        'scope': 'QA local goal UI smoke only',
        'title': title,
        'saved_description': description,
        'canceled_edit_preserved_saved_description': true,
        'completed_via_ui': true,
        'no_provider_mutation_or_xp_injection': true,
        'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
      };
      await File(
        '${receiptDirectory.path}/receipt.json',
      ).writeAsString(jsonEncode(receipt));
      debugPrint('AXIOMARA_GOAL_SMOKE_RECEIPT ${jsonEncode(receipt)}');
    },
    timeout: const Timeout(Duration(minutes: 8)),
    config: const PatrolTesterConfig(
      settlePolicy: SettlePolicy.noSettle,
      printLogs: true,
    ),
  );
}
