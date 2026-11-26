import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_chat_mode_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'assistant_conversation_screen_test.dart'
    show MemoryPrefs, enterChatText, setup, waitForChatReady;

// One two-way switch at the top of Chat: free on this device, or AI chat with
// its price. The choice is remembered while the app runs, typed text goes with
// the person, and choosing AI chat before it is allowed opens the consent step.

const _switch = Key('assistant-mode-switch');
const _onDevice = Key('assistant-mode-on-device');
const _ai = Key('assistant-mode-ai');
const _aiInput = Key('conversation-input');
const _localInput = Key('si-query-input');

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container, {
  String language = 'en',
  Size? size,
  double textScale = 1,
}) async {
  if (size != null) {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ProviderScope(
        // The free console needs its own availability check to be open.
        overrides: [siV2AvailabilityProvider.overrideWith((ref) async => true)],
        child: MaterialApp(
          locale: Locale(language),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: const [
            ChronoSparkLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const SIConsoleScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language on-device choice is announced once and keeps its tooltip',
      (tester) async {
        final container = setup((_) async => throw StateError('no AI'));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        final semantics = tester.ensureSemantics();
        await _pump(tester, container, language: language);
        await waitForChatReady(tester);
        final label = language == 'es'
            ? 'En este dispositivo · gratis'
            : 'On this device · free';

        // The tooltip still exists for pointer users...
        expect(find.byTooltip(label), findsOneWidget);
        final tooltip = tester.widget<Tooltip>(find.byTooltip(label));
        expect(tooltip.excludeFromSemantics, isTrue);
        // ...and the label is still announced, by the button itself.
        expect(find.bySemanticsLabel(label), findsWidgets);
        semantics.dispose();
      },
    );

    testWidgets('$language switches both ways and carries the typed text', (
      tester,
    ) async {
      var calls = 0;
      final container = setup((_) async {
        calls++;
        throw StateError('Switching must not request AI');
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container, language: language);
      await waitForChatReady(tester);

      // AI chat is the starting choice and the switch states both prices.
      expect(find.byKey(_switch), findsOneWidget);
      expect(
        find.text(
          language == 'es'
              ? 'En este dispositivo · gratis'
              : 'On this device · free',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          language == 'es'
              ? 'Chat con IA · $conversationMessageCredits créditos por mensaje'
              : 'AI chat · $conversationMessageCredits credits per message',
        ),
        findsOneWidget,
      );
      expect(find.byKey(_localInput), findsNothing);

      // To the free assistant: the draft goes with the person.
      await enterChatText(tester, 'A quiet next step');
      await _tap(tester, _onDevice);
      expect(find.byKey(_localInput), findsOneWidget);
      expect(find.byKey(_aiInput), findsNothing);
      expect(find.byKey(_switch), findsOneWidget);
      expect(_text(tester, _localInput), 'A quiet next step');

      // And back to AI chat, with the text changed on the way.
      await tester.enterText(find.byKey(_localInput), 'A longer walk');
      await _tap(tester, _ai);
      await waitForChatReady(tester);
      expect(find.byKey(_localInput), findsNothing);
      expect(_text(tester, _aiInput), 'A longer walk');

      // Once more each way: it never gets stuck.
      await _tap(tester, _onDevice);
      expect(find.byKey(_localInput), findsOneWidget);
      await _tap(tester, _ai);
      expect(find.byKey(_aiInput), findsOneWidget);
      expect(calls, 0, reason: 'Switching must send nothing');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the choice is kept when the screen is left and opened again', (
    tester,
  ) async {
    final container = setup((_) async => throw StateError('No AI here'));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await _pump(tester, container);
    await waitForChatReady(tester);
    await _tap(tester, _onDevice);
    expect(find.byKey(_localInput), findsOneWidget);

    // Leaving Chat for another screen unmounts it; coming back keeps the choice.
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, container);
    expect(find.byKey(_localInput), findsOneWidget);
    expect(find.byKey(_aiInput), findsNothing);
    expect(
      container.read(assistantOnDeviceModeProvider(ConversationSurface.si)),
      isTrue,
    );

    await _tap(tester, _ai);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, container);
    await waitForChatReady(tester);
    expect(find.byKey(_aiInput), findsOneWidget);
    expect(
      container.read(assistantOnDeviceModeProvider(ConversationSurface.si)),
      isFalse,
    );
  });

  test('another account starts again on AI chat', () async {
    var account = AccountStorageScope.authenticated('first-mode-account');
    final container = setup(
      (_) async => throw StateError('No AI here'),
      readScope: () => account,
    );
    addTearDown(container.dispose);
    final modes = container.listen(assistantChatModeProvider, (_, _) {});
    addTearDown(modes.close);
    container
        .read(assistantChatModeProvider.notifier)
        .choose(ConversationSurface.si, onDevice: true);
    expect(modes.read(), contains(ConversationSurface.si));
    account = AccountStorageScope.authenticated('second-mode-account');
    container.invalidate(accountStorageScopeProvider);
    await container.pump();
    expect(modes.read(), isEmpty);
  });

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language choosing AI chat without consent opens the consent step first',
      (tester) async {
        var calls = 0;
        final prefs = MemoryPrefs();
        final container = setup((_) async {
          calls++;
          throw StateError('Choosing must not request AI');
        }, preferences: prefs);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(tester, container, language: language);
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          container.read(personalizationProfileProvider).externalAiAllowed,
          isFalse,
        );
        await _tap(tester, _onDevice);
        expect(find.byKey(_localInput), findsOneWidget);

        final title = language == 'es'
            ? '¿Activar el chat con IA?'
            : 'Turn on AI chat?';
        // Not now: stays on the free assistant, nothing saved, nothing sent.
        await tester.tap(find.byKey(_ai));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        await tester.tap(find.byKey(const Key('ai-chat-consent-decline')));
        await tester.pumpAndSettle();
        expect(find.text(title), findsNothing);
        expect(find.byKey(_localInput), findsOneWidget);
        expect(
          container.read(personalizationProfileProvider).externalAiAllowed,
          isFalse,
        );
        expect(prefs.values, isEmpty);

        // Allow: saved for this account, and the person lands on AI chat.
        await tester.enterText(find.byKey(_localInput), 'Plan my evening');
        await tester.tap(find.byKey(_ai));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        await tester.tap(find.byKey(const Key('ai-chat-consent-allow')));
        await tester.pumpAndSettle();
        await waitForChatReady(tester);
        expect(find.byKey(_localInput), findsNothing);
        expect(
          container.read(personalizationProfileProvider).externalAiAllowed,
          isTrue,
        );
        expect(_text(tester, _aiInput), 'Plan my evening');
        expect(calls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language the switch fits 320 wide at 200 percent text with 48dp targets',
      (tester) async {
        final container = setup((_) async => throw StateError('No AI here'));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _pump(
          tester,
          container,
          language: language,
          size: const Size(320, 640),
          textScale: 2,
        );
        await waitForChatReady(tester);
        for (final key in [_onDevice, _ai]) {
          final finder = find.byKey(key);
          await tester.ensureVisible(finder);
          await tester.pump();
          final bounds = tester.getRect(finder);
          expect(bounds.height, greaterThanOrEqualTo(48));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(320));
        }
        // The same at the free assistant.
        await _tap(tester, _onDevice);
        for (final key in [_onDevice, _ai]) {
          final finder = find.byKey(key);
          await tester.ensureVisible(finder);
          await tester.pump();
          final bounds = tester.getRect(finder);
          expect(bounds.height, greaterThanOrEqualTo(48));
          expect(bounds.right, lessThanOrEqualTo(320));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a running request is not touched by the switch and its reply stays visible',
    (tester) async {
      final gate = Completer<void>();
      var paid = 0;
      final container = setup((body) async {
        if (body['quoteOnly'] == true) {
          return (
            status: 200,
            data: <String, dynamic>{
              'requestId': body['requestId'],
              'quote': <String, dynamic>{
                'credits': conversationMessageCredits,
                'digest': 'fixture',
                'proof': 'fixture',
                'policy': 'fixture',
                'expiresAt': DateTime.now()
                    .add(const Duration(minutes: 5))
                    .millisecondsSinceEpoch,
              },
            },
          );
        }
        paid++;
        await gate.future;
        return (
          status: 200,
          data: <String, dynamic>{
            'requestId': body['requestId'],
            'message': 'Take a short walk first.',
            'creditsCharged': conversationMessageCredits,
            'remainingCredits': 20,
            'model': 'transport-fixture',
          },
        );
      });
      addTearDown(() async {
        if (!gate.isCompleted) gate.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _pump(tester, container, size: const Size(412, 915));
      await enterChatText(tester, 'What should I do first?');
      await tester.tap(find.byKey(const Key('conversation-send')));
      for (var i = 0; i < 40 && find.text('Send').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.text('Send'));
      for (var i = 0; i < 40 && paid == 0; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(paid, 1);

      // While the paid request runs the switch cannot be used.
      for (final key in [_onDevice, _ai]) {
        final button = tester.widget<OutlinedButton>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(button.onPressed, isNull);
      }
      await tester.tap(find.byKey(_onDevice), warnIfMissed: false);
      await tester.pump();
      expect(find.byKey(_localInput), findsNothing);

      // The reply arrives once, and it is still there after switching away
      // and back.
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Take a short walk first.'), findsOneWidget);
      expect(paid, 1);
      await _tap(tester, _onDevice);
      expect(find.byKey(_localInput), findsOneWidget);
      await _tap(tester, _ai);
      expect(find.text('Take a short walk first.'), findsOneWidget);
      expect(paid, 1, reason: 'Switching must never resend or recharge');
      expect(tester.takeException(), isNull);
    },
  );
}
