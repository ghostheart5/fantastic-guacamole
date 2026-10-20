import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fantastic_guacamole/app/startup/app_bootstrap.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_onboarding_preferences_repository.dart';
import 'package:fantastic_guacamole/features/onboarding/domain/onboarding_content_contract.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_draft_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/smart_planner_first_value_provider.dart';
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

// All state changes are ordinary visible actions. Repository/provider/prefs
// access below is read-only. Settings replay resets only first-setup markers
// through the production control; it never resets the profile or task data.
void main() {
  patrolTest(
    'public first setup replay gives one local shirt choice and supports skip',
    ($) async {
      final package = await PackageInfo.fromPlatform();
      expect(package.packageName, 'com.ghostheart5.chronospark.qa');
      expect(package.version, '4.2.4-qa');
      expect(package.buildNumber, '2026101201');
      expect(Platform.isAndroid && kDebugMode && Env.isLocalMode, isTrue);
      expect(Env.cloudServicesEnabled, isFalse);
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
      // The shared helper is used ONLY to enter the existing profile initially.
      // Once replay starts, every setup decision below is an explicit test act.
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
      final evidence = Directory('${folder.path}/tutorial-planner-$run');
      await evidence.create(recursive: true);
      final receipt = File('${evidence.path}/events.jsonl');
      void record(String id, String status, Map<String, Object?> fields) {
        final line = jsonEncode({
          'case': id,
          'status': status,
          'operator': 'codex_ai',
          'run': run,
          'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
          ...fields,
        });
        receipt.writeAsStringSync(
          '$line\n',
          mode: FileMode.append,
          flush: true,
        );
        debugPrint('AXIOMARA_TUTORIAL_PLANNER $line');
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

      Future<void> waitFor(
        bool Function() ready,
        String reason, {
        bool allowContextualDismiss = false,
      }) async {
        final deadline = DateTime.now().add(const Duration(seconds: 50));
        var dismissals = 0;
        while (DateTime.now().isBefore(deadline)) {
          if (allowContextualDismiss &&
              find
                  .text('CONTEXTUAL GUIDANCE')
                  .hitTestable()
                  .evaluate()
                  .isNotEmpty &&
              find.text('Not now').hitTestable().evaluate().isNotEmpty) {
            expect(
              dismissals++,
              lessThan(5),
              reason: 'Contextual prompts must stay bounded.',
            );
            await $(find.text('Not now').hitTestable()).tap();
            record('contextual-prompt', 'dismissed-through-ui', {});
          } else if (ready()) {
            return;
          }
          await $.pump(const Duration(milliseconds: 200));
        }
        debugPrint(
          'AXIOMARA_TUTORIAL_BLOCKED ${$.tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).toList()}',
        );
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

      Future<void> keyTap(String key) => tap(find.byKey(Key(key)));
      Future<void> revealPlanner(
        String key, {
        AxisDirection initialDirection = AxisDirection.down,
      }) async {
        final target = find.byKey(Key(key));
        final viewport = find.byKey(const Key('planner-content-scroll'));
        var direction = initialDirection;
        var missingFrames = 0;
        // Result generation and full-response expansion can move a target
        // above the viewport during a downward search. Re-query its actual
        // bounds before every ordinary drag instead of persisting a direction.
        for (var attempt = 0; attempt < 36; attempt++) {
          await $.pump(const Duration(milliseconds: 200));
          if (target.hitTestable().evaluate().isNotEmpty) return;
          expect(
            viewport.hitTestable(),
            findsOneWidget,
            reason:
                'Planner scrolling must stay in the real visible planner list.',
          );
          if (target.evaluate().isNotEmpty) {
            missingFrames = 0;
            final bounds = $.tester.getRect(target);
            final visible = $.tester.getRect(viewport);
            direction = bounds.center.dy < visible.center.dy
                ? AxisDirection.up
                : AxisDirection.down;
          } else if (++missingFrames % 6 == 0) {
            // Bounded reverse search also handles a lazily unmounted target.
            direction = direction == AxisDirection.down
                ? AxisDirection.up
                : AxisDirection.down;
          }
          await $.tester.drag(
            viewport,
            Offset(0, direction == AxisDirection.up ? 220 : -220),
          );
        }
        fail(
          'Planner target $key remained unreachable after 36 bounded visible drags.',
        );
      }

      Future<void> plannerTap(String key) async {
        await revealPlanner(key);
        await tap(find.byKey(Key(key)));
      }

      Future<void> back() =>
          tap(find.byTooltip('Back').first, direction: AxisDirection.up);
      Future<void> openSettings() async {
        await tap(find.byTooltip('Open navigation map'));
        await tap(find.widgetWithText(ListTile, 'Control Center'));
        await waitFor(
          () => find.text('SETTINGS').evaluate().isNotEmpty,
          'Control Center must show real Settings.',
          allowContextualDismiss: true,
        );
        if (find.text('Restart first setup').evaluate().isEmpty) {
          await tap(find.text('Planning & guidance'));
        }
        await waitFor(
          () => find.text('Restart first setup').evaluate().isNotEmpty,
          'Settings must load the production first-setup replay control.',
        );
        await $(find.text('Restart first setup')).scrollTo();
        await $(
          find.text('Restart first setup').hitTestable(),
        ).waitUntilVisible();
      }

      String welcomeAction() =>
          container.read(intelligenceStateProvider).auth.isAuthenticated
          ? 'CONTINUE TO SETUP'
          : 'CONTINUE TO LOGIN';
      late String observedWelcomeAction;
      Future<void> restartSetup() async {
        await tap(find.text('Restart first setup'));
        await waitFor(
          () =>
              find
                  .byKey(const Key('onboarding-brand-title'))
                  .evaluate()
                  .isNotEmpty &&
              find.text(welcomeAction()).hitTestable().evaluate().isNotEmpty,
          'Visible first-setup replay must reopen Welcome.',
        );
        expect(
          container.read(accountOnboardingCompleteProvider).asData?.value,
          isFalse,
        );
        observedWelcomeAction = welcomeAction();
        expect(find.text(observedWelcomeAction).hitTestable(), findsOneWidget);
      }

      Future<String> continueWelcome() async {
        final authenticated = container
            .read(intelligenceStateProvider)
            .auth
            .isAuthenticated;
        await tap(find.text(observedWelcomeAction));
        await waitFor(
          () =>
              find
                  .byKey(const Key('first-value-question'))
                  .evaluate()
                  .isNotEmpty ||
              find
                  .byKey(const Key('local-profile-continue'))
                  .hitTestable()
                  .evaluate()
                  .isNotEmpty,
          'Welcome action must advance to local profile or current step 3.',
        );
        var path = 'existing authenticated profile advances directly to step 3';
        if (find
            .byKey(const Key('local-profile-continue'))
            .hitTestable()
            .evaluate()
            .isNotEmpty) {
          path = 'welcome then visible local-profile-continue then step 3';
          await keyTap('local-profile-continue');
        }
        await waitFor(
          () => find
              .text('FIRST SETUP 3 OF 3')
              .hitTestable()
              .evaluate()
              .isNotEmpty,
          'The real optional question page must be usable.',
        );
        expect(
          find.byKey(const Key('first-value-show-choice')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('first-value-skip')), findsOneWidget);
        if (authenticated) {
          expect(observedWelcomeAction, 'CONTINUE TO SETUP');
          expect(
            path,
            'existing authenticated profile advances directly to step 3',
          );
        } else {
          expect(observedWelcomeAction, 'CONTINUE TO LOGIN');
        }
        return path;
      }

      final taskRepo = container.read(domainTaskRepositoryProvider);
      Future<Map<String, Object?>> taskSnapshot() async => {
        for (final task in await taskRepo.getAllTasks()) task.id: task.toJson(),
      };
      final initialTasks = await taskSnapshot();
      final noteRepo = container.read(domainNoteRepositoryProvider);
      Future<Map<String, Object?>> noteSnapshot() async => {
        for (final note in await noteRepo.getNotes()) note.id: note.toJson(),
      };
      final initialNotes = await noteSnapshot();
      final xpBefore = container.read(profileProvider).xp;
      final prefs = await SharedPreferences.getInstance();
      Future<void> assertCompletionStored() async {
        await prefs.reload();
        expect(prefs.getBool(onboardingWelcomeCompleteStorageKey), isTrue);
        expect(prefs.getBool(onboardingCompleteStorageKey), isTrue);
        expect(
          prefs.getInt(onboardingContentVersionStorageKey),
          OnboardingContentContract.currentVersion,
        );
        final account = container.read(accountStorageScopeProvider).v2Namespace;
        expect(account, isNotNull);
        expect(
          prefs.getBool('onboarding_profile_complete_v1.$account'),
          isTrue,
        );
        expect(
          container.read(accountOnboardingCompleteProvider).asData?.value,
          isTrue,
        );
      }

      record('scope', 'bounded', {
        'package': package.packageName,
        'version': package.version,
        'build_number': package.buildNumber,
        'backend': 'local',
        'baseline_tasks': initialTasks.length,
        'baseline_notes': initialNotes.length,
        'limits': [
          'Authenticated replay can omit separate login step',
          'Navigation revisit and persisted preferences, not Android process restart',
          'No cloud/auth/billing/provider request or task confirmation',
        ],
      });
      await openSettings();
      await caseRun('H01-partial-welcome-replay-main-action', () async {
        await restartSetup();
        final welcomeScreenshot = await capture('H01-welcome-before-action');
        final path = await continueWelcome();
        expect(await taskSnapshot(), equals(initialTasks));
        if (path.startsWith('existing authenticated')) {
          record(
            'H01-copy-destination',
            'baseline-finding-resolved-in-current-run',
            {
              'historical_baseline_cta': 'CONTINUE TO LOGIN',
              'visible_cta': observedWelcomeAction,
              'actual_destination': 'FIRST SETUP 3 OF 3',
              'finding':
                  'Current signed-in replay CTA names setup and advances to its optional question. Archived baseline mismatch remains preserved.',
            },
          );
        }
        return {
          'observed_path': path,
          'welcome_screenshot': welcomeScreenshot,
          'source_page_count': OnboardingContentContract.pageCount,
          'no_task_changes': true,
          'visible_cta': observedWelcomeAction,
          'cta_matches_actual_destination': true,
          'full_H01_copy_acceptance': 'not_claimed',
        };
      });
      const prompt = 'I have five minutes and want to fold one shirt';
      await caseRun('H02-capacity-question-helpful-choice', () async {
        for (final selected in ['low', 'steady', 'high']) {
          await keyTap('first-value-capacity-$selected');
          for (final value in ['low', 'steady', 'high']) {
            expect(
              $.tester
                  .widget<ChoiceChip>(
                    find.byKey(Key('first-value-capacity-$value')),
                  )
                  .selected,
              value == selected,
              reason: 'Exactly the latest capacity choice must be selected.',
            );
          }
          record('H02-capacity-$selected', 'passed', {
            'screenshot': await capture('H02-capacity-$selected'),
          });
        }
        await $(const Key('first-value-question')).enterText(prompt);
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await $.pump(const Duration(milliseconds: 200));
        expect(
          $.tester
              .widget<TextField>(find.byKey(const Key('first-value-question')))
              .controller!
              .text,
          prompt,
        );
        await keyTap('first-value-show-choice');
        await waitFor(
          () => find
              .byKey(const Key('planner-response-panel'))
              .evaluate()
              .isNotEmpty,
          'SHOW ONE HELPFUL CHOICE must produce a real local planner result.',
          allowContextualDismiss: true,
        );
        expect(
          find.byKey(const Key('planner-guidance-unavailable')),
          findsNothing,
        );
        await revealPlanner(
          'planner-context-field',
          initialDirection: AxisDirection.up,
        );
        final input = $.tester.widget<TextField>(
          find.byKey(const Key('planner-context-field')),
        );
        expect(input.controller!.text, prompt);
        expect(
          container.read(smartPlannerFirstValueProvider),
          isNull,
          reason: 'First-value request must be consumed once.',
        );
        await revealPlanner('planner-next-step');
        final next = $.tester
            .widget<Text>(find.byKey(const Key('planner-next-step')))
            .data!;
        expect(next.toLowerCase(), contains('shirt'));
        expect(next.toLowerCase(), contains('fold'));
        expect(find.text('Local planning from your context'), findsOneWidget);
        await plannerTap('planner-why-this');
        final panelTexts = $.tester
            .widgetList<Text>(
              find.descendant(
                of: find.byKey(const Key('planner-response-panel')),
                matching: find.byType(Text),
              ),
            )
            .map((w) => w.data ?? '')
            .where((value) => value.isNotEmpty)
            .toList();
        expect(
          panelTexts.any((text) => text.toLowerCase().contains('tradeoff')),
          isTrue,
          reason: 'Why this must expose a concrete tradeoff explanation.',
        );
        await plannerTap('planner-full-response');
        final full = $.tester
            .widgetList<SelectableText>(
              find.descendant(
                of: find.byKey(const Key('planner-full-response')),
                matching: find.byType(SelectableText),
              ),
            )
            .map((w) => w.data ?? '')
            .join('\n');
        expect(full.toLowerCase(), contains('shirt'));
        expect(full.trim().length, greaterThan(next.trim().length));
        await assertCompletionStored();
        expect(await taskSnapshot(), equals(initialTasks));
        expect(await noteSnapshot(), equals(initialNotes));
        expect(container.read(profileProvider).xp, xpBefore);
        return {
          'prompt': prompt,
          'last_capacity': 'High',
          'next_step': next,
          'full_visible_response': full,
          'local_source_label': true,
          'completion_preferences_persisted': true,
          'no_hidden_task_note_or_xp_change': true,
        };
      });
      await caseRun('H03-visible-plan-handoff-back-revisit', () async {
        await plannerTap('planner-use-this-plan');
        await waitFor(
          () => find
              .byKey(const Key('creator-planner-draft-preview'))
              .evaluate()
              .isNotEmpty,
          'Use this plan must open the real Creator draft.',
          allowContextualDismiss: true,
        );
        final draft = container.read(creatorDraftPreviewProvider);
        expect(draft, isNotNull);
        expect(draft!.title.toLowerCase(), contains('shirt'));
        expect(
          draft.estimatedMinutes,
          inInclusiveRange(1, 5),
          reason:
              'The offered draft must fit the user-stated five-minute constraint.',
        );
        final title = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Title *',
        );
        expect($.tester.widget<TextField>(title).controller!.text, draft.title);
        expect(await taskSnapshot(), equals(initialTasks));
        expect(await noteSnapshot(), equals(initialNotes));
        final handoffScreenshot = await capture('H03-creator-editable-draft');
        for (var pause = 0; pause < 5; pause++) {
          await $.pump(const Duration(milliseconds: 200));
          final pauseControl = find.text('Pause guide').hitTestable();
          if (pauseControl.evaluate().isEmpty) break;
          await $(pauseControl).tap();
          await $.pump(const Duration(milliseconds: 250));
          record('H03-guide-pause-$pause', 'visible-ui-action', {
            'scope':
                'Pause the separate adaptive walkthrough before Creator Back; walkthrough completion not claimed',
            'screenshot': await capture('H03-guide-pause-$pause'),
          });
        }
        await back();
        await waitFor(
          () => find
              .byTooltip('Open navigation map')
              .hitTestable()
              .evaluate()
              .isNotEmpty,
          'Creator Back must return to usable app navigation.',
          allowContextualDismiss: true,
        );
        expect(find.text('FIRST SETUP 3 OF 3'), findsNothing);
        await openSettings();
        await assertCompletionStored();
        expect(find.byKey(const Key('first-value-question')), findsNothing);
        expect(await taskSnapshot(), equals(initialTasks));
        return {
          'draft_title': draft.title,
          'draft_minutes': draft.estimatedMinutes,
          'handoff_screenshot': handoffScreenshot,
          'no_hidden_task_save': true,
          'settings_revisit_did_not_repeat_setup': true,
        };
      });
      await caseRun('H04-visible-replay-skip-persistence', () async {
        await restartSetup();
        final path = await continueWelcome();
        await keyTap('first-value-skip');
        await waitFor(
          () => find
              .byTooltip('Open navigation map')
              .hitTestable()
              .evaluate()
              .isNotEmpty,
          'Explicit SKIP FOR NOW must reach usable navigation.',
          allowContextualDismiss: true,
        );
        expect(find.byKey(const Key('first-value-question')), findsNothing);
        expect(container.read(smartPlannerFirstValueProvider), isNull);
        await assertCompletionStored();
        await openSettings();
        await back();
        await waitFor(
          () => find
              .byTooltip('Open navigation map')
              .hitTestable()
              .evaluate()
              .isNotEmpty,
          'Settings Back after skip must remain usable.',
          allowContextualDismiss: true,
        );
        expect(find.byKey(const Key('first-value-question')), findsNothing);
        expect(await taskSnapshot(), equals(initialTasks));
        expect(container.read(profileProvider).xp, xpBefore);
        expect(await noteSnapshot(), equals(initialNotes));
        return {
          'observed_replay_path': path,
          'explicit_skip': true,
          'completion_preferences_persisted': true,
          'no_repeat_on_settings_revisit': true,
          'exact_task_snapshot_unchanged': true,
          'exact_note_snapshot_unchanged': true,
          'xp_unchanged': true,
        };
      });
    },
    timeout: const Timeout(Duration(minutes: 12)),
    config: const PatrolTesterConfig(
      settlePolicy: SettlePolicy.noSettle,
      printLogs: true,
    ),
  );
}
