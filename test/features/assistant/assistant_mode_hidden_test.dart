import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_history_provider.dart';
import 'package:fantastic_guacamole/features/assistant/ui/assistant_mode_switch.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_chat_mode_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/domain/entities/si_one_tap_question.dart';
import 'package:fantastic_guacamole/state/providers/si_one_tap_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'assistant_conversation_screen_test.dart'
    show MemoryPrefs, enterChatText, setup, waitForChatReady;

// The AI screen is kept (hidden) behind the free assistant, so a paid request
// that is running, stopped-waiting or stored is collected out of sight: one
// paid call, its reply is there when the person switches back, and another
// account never sees it. When AI chat cannot be used, tapping it says why.

const _onDevice = Key('assistant-mode-on-device');
const _ai = Key('assistant-mode-ai');
const _aiInput = Key('conversation-input');
const _localInput = Key('si-query-input');
const _ready = Key('assistant-mode-reply-ready');
const _reply = 'Take a short walk first.';

typedef _Response = ({int status, Map<String, dynamic> data});

Future<void> _host(
  WidgetTester tester,
  ProviderContainer container, {
  String language = 'en',
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ProviderScope(
        overrides: [siV2AvailabilityProvider.overrideWith((ref) async => true)],
        child: MaterialApp(
          locale: Locale(language),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: const [
            ChronoSparkLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
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

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  for (
    var t = Duration.zero;
    t < total;
    t += const Duration(milliseconds: 50)
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A server that quotes 4 credits and holds the paid answer at [gate].
class _Server {
  _Server(this.gate);
  final Completer<void> gate;
  final paid = <Map<String, dynamic>>[];

  Future<_Response> call(Map<String, dynamic> body) async {
    if (body['quoteOnly'] == true) {
      return (
        status: 200,
        data: <String, dynamic>{
          'requestId': body['requestId'],
          'quote': <String, dynamic>{
            'credits': 4,
            'digest': 'fixture',
            'proof': 'fixture',
            'policy': 'fixture',
            'expiresAt': 4102444800000, // Far away: not real time.
          },
        },
      );
    }
    paid.add(body);
    await gate.future;
    return (
      status: 200,
      data: <String, dynamic>{
        'requestId': body['requestId'],
        'message': _reply,
        'creditsCharged': 4,
        'remainingCredits': 20,
        'model': 'transport-fixture',
      },
    );
  }
}

Future<void> _sendPaid(WidgetTester tester, _Server server) async {
  await enterChatText(tester, 'What should I do first?');
  await tester.tap(find.byKey(const Key('conversation-send')));
  for (var i = 0; i < 40 && find.text('Send').evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.tap(find.text('Send'));
  for (
    var i = 0;
    i < 40 && find.text('Use 4 credits').evaluate().isEmpty;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.tap(find.text('Use 4 credits'));
  for (var i = 0; i < 40 && server.paid.isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(server.paid, hasLength(1));
}

Future<void> _showReply(WidgetTester tester) async {
  final reply = find.text(_reply);
  if (reply.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      reply,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  expect(reply, findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a request that stopped waiting is collected while the free assistant is shown',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final server = _Server(Completer<void>());
      final container = setup(
        server.call,
        paidWaitTimeout: const Duration(milliseconds: 300),
      );
      addTearDown(() async {
        if (!server.gate.isCompleted) server.gate.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _host(tester, container);
      await _sendPaid(tester, server);

      // While the request runs the control is dimmed and says why.
      expect(
        find.byKey(const Key('assistant-mode-disabled-reason')),
        findsOneWidget,
      );

      // Waiting stops; the request keeps running. Go to the free assistant.
      await _pumpFor(tester, const Duration(milliseconds: 600));
      await _tap(tester, _onDevice);
      expect(find.byKey(_localInput), findsOneWidget);

      // The answer arrives while the AI screen is out of sight.
      server.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text(_reply), findsNothing);
      expect(find.byKey(_ready), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await _tap(tester, _ai);
      await waitForChatReady(tester);
      await _showReply(tester);
      expect(find.byKey(_ready), findsNothing);
      expect(server.paid, hasLength(1), reason: 'One paid call only');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'another account sees nothing of a reply that arrived while hidden',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var account = AccountStorageScope.authenticated('synthetic-review');
      final server = _Server(Completer<void>());
      final container = setup(
        server.call,
        paidWaitTimeout: const Duration(milliseconds: 300),
        readScope: () => account,
      );
      addTearDown(() async {
        if (!server.gate.isCompleted) server.gate.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _host(tester, container);
      await _sendPaid(tester, server);
      await _pumpFor(tester, const Duration(milliseconds: 600));
      await _tap(tester, _onDevice);
      await tester.enterText(find.byKey(_localInput), 'Typed for account one');

      // Another account signs in while the AI screen is hidden.
      account = AccountStorageScope.authenticated('another-account');
      container.invalidate(accountStorageScopeProvider);
      await tester.pumpAndSettle();
      server.gate.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(_ready), findsNothing);
      expect(find.text(_reply), findsNothing);
      // The other account starts on AI chat with nothing carried over.
      await waitForChatReady(tester);
      expect(find.text(_reply), findsNothing);
      expect(
        tester.widget<TextField>(find.byKey(_aiInput)).controller!.text,
        isEmpty,
      );
      await _tap(tester, _onDevice);
      await _tap(tester, _ai);
      await waitForChatReady(tester);
      expect(find.text(_reply), findsNothing);
      expect(
        tester.widget<TextField>(find.byKey(_aiInput)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'coming back with the free choice remembered still collects a stored request',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      final server = _Server(Completer<void>());
      final container = setup(server.call, historyBackend: backend);
      addTearDown(() async {
        if (!server.gate.isCompleted) server.gate.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _host(tester, container);
      await _sendPaid(tester, server);

      // Leave Chat for another screen (the request is stored) and come back
      // with the free assistant remembered. Nothing is switched on the way.
      container
          .read(assistantChatModeProvider.notifier)
          .choose(ConversationSurface.si, onDevice: true);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _host(tester, container);
      expect(find.byKey(_localInput), findsOneWidget);

      server.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(_ready), findsOneWidget);
      await _tap(tester, _ai);
      await waitForChatReady(tester);
      await _showReply(tester);
      expect(server.paid, hasLength(1), reason: 'One paid call only');
      expect(tester.takeException(), isNull);
    },
  );

  // A dialog the hidden AI screen raises (here the crisis support dialog on a
  // recovered request) waits until AI chat is chosen, and is never shown to
  // another account.
  for (final changeAccount in [false, true]) {
    testWidgets(
      changeAccount
          ? 'a deferred dialog is dropped when another account signs in'
          : 'a deferred dialog is shown once when AI chat is chosen',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var account = AccountStorageScope.authenticated('synthetic-review');
        final server = _Server(Completer<void>());
        final container = setup(
          server.call,
          historyBackend: InMemorySecureStoreBackend(),
          readScope: () => account,
        );
        addTearDown(() async {
          if (!server.gate.isCompleted) server.gate.complete();
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await _host(tester, container);
        await _sendPaid(tester, server);
        container
            .read(assistantChatModeProvider.notifier)
            .choose(ConversationSurface.si, onDevice: true);
        await tester.pumpWidget(const SizedBox.shrink());
        // Chat already holds an earlier message that calls for support.
        final repository = container.read(
          assistantConversationHistoryRepositoryProvider,
        )!;
        await tester.runAsync(() async {
          final saved = await repository.load(keep: (_) => true);
          await repository.save(
            expectedRevision: saved.revision,
            messages: [
              {'role': 'user', 'content': 'I want to kill myself'},
              {'role': 'assistant', 'content': 'Please reach out for help.'},
            ],
            sources: <SIV2Source>{},
          );
        });
        await _host(tester, container);
        await _pumpFor(tester, const Duration(seconds: 2));
        expect(find.byKey(_localInput), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);

        if (changeAccount) {
          account = AccountStorageScope.authenticated('another-account');
          container.invalidate(accountStorageScopeProvider);
          await _pumpFor(tester, const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
        } else {
          await _tap(tester, _ai);
          await _pumpFor(tester, const Duration(milliseconds: 500));
          expect(find.byType(Dialog), findsOneWidget);
        }
        expect(server.paid, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  // When AI chat cannot be used, the AI choice stays visible and tapping it
  // says why; nothing switches.
  final reasons = <String, ({String en, String es})>{
    'checking': (
      en: 'Checking whether AI chat is available',
      es: 'Estamos comprobando si el chat con IA está disponible',
    ),
    'release off': (
      en: 'AI chat is not available for this account right now',
      es: 'El chat con IA no está disponible para esta cuenta en este momento',
    ),
    'unavailable': (
      en: 'AI chat is not available in this version of the app',
      es: 'El chat con IA no está disponible en esta versión de la app',
    ),
    'account not ready': (
      en: 'your account is not ready yet',
      es: 'tu cuenta aún no está lista',
    ),
  };
  for (final entry in reasons.entries) {
    for (final language in ['en', 'es']) {
      testWidgets('${entry.key}: tapping AI chat says why ($language)', (
        tester,
      ) async {
        var account = AccountStorageScope.authenticated('synthetic-review');
        final gate = Completer<void>();
        final container = setup(
          (_) async => throw StateError('Choosing must not request AI'),
          readScope: () => account,
          releaseGate: entry.key == 'checking' ? gate : null,
          releaseEnabled: entry.key != 'release off',
          conversationAvailable: entry.key != 'unavailable',
          externalAiBuild: true,
        );
        addTearDown(() async {
          if (!gate.isCompleted) gate.complete();
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        if (entry.key == 'account not ready') {
          // An account that cannot be written to: the switch alone.
          account = const AccountStorageScope.unsafe();
          container.invalidate(accountStorageScopeProvider);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: Locale(language),
                supportedLocales: ChronoSparkLocalizations.supportedLocales,
                localizationsDelegates: const [
                  ChronoSparkLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                home: Scaffold(
                  body: AssistantModeSwitch(
                    surface: ConversationSurface.si,
                    aiSelected: false,
                    enabled: true,
                    onChooseOnDevice: () {},
                    onChooseAi: () => fail('Must not switch'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        } else {
          await _host(tester, container, language: language);
          // The switch is there from the start and does not come and go.
          expect(
            find.byKey(const Key('assistant-mode-switch')),
            findsOneWidget,
          );
          expect(find.byKey(_aiInput), findsNothing);
        }
        await tester.tap(find.byKey(_ai));
        await tester.pump();
        final text = language == 'es' ? entry.value.es : entry.value.en;
        expect(find.textContaining(text), findsOneWidget);
        expect(find.byKey(_aiInput), findsNothing);
        expect(find.byKey(const Key('ai-chat-consent-allow')), findsNothing);
        if (entry.key == 'checking') {
          gate.complete();
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('assistant-mode-switch')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a person who never allowed AI chat sees it as off, not active', (
    tester,
  ) async {
    final container = setup(
      (_) async => throw StateError('No AI here'),
      preferences: MemoryPrefs(),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await _host(tester, container);
    await tester.pump(const Duration(milliseconds: 200));
    final notice = tester.getTopLeft(
      find.byKey(const Key('conversation-ai-off-notice')),
    );
    final switchTop = tester.getTopLeft(
      find.byKey(const Key('assistant-mode-switch')),
    );
    expect(notice.dy, lessThan(switchTop.dy));
    expect(find.textContaining('AI chat · off'), findsOneWidget);
    // Neither choice is shown as chosen and active.
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets(
    'a free question is answered while a paid reply is recovered out of sight',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      final server = _Server(Completer<void>());
      final container = setup(server.call, historyBackend: backend);
      addTearDown(() async {
        if (!server.gate.isCompleted) server.gate.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _host(tester, container);
      await _sendPaid(tester, server);
      // Leave Chat with the request stored and come back on the free
      // assistant; a question from Today is waiting.
      container
          .read(assistantChatModeProvider.notifier)
          .choose(ConversationSurface.si, onDevice: true);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container
          .read(siOneTapRequestProvider.notifier)
          .ask(SIOneTapQuestion.planMyDay);
      await _host(tester, container);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Chat is already on the free assistant, so nothing switches away from
      // the recovered request and the question is answered whether or not
      // that request has started by then...
      expect(find.byKey(const Key('one-tap-free-line')), findsOneWidget);
      // ...and the recovered reply still arrives once, with its notice.
      server.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(_ready), findsOneWidget);
      await _tap(tester, _ai);
      await waitForChatReady(tester);
      await _showReply(tester);
      expect(server.paid, hasLength(1), reason: 'One paid call only');
    },
  );

  testWidgets(
    'an idle stored request does not block a free question or say a message is being sent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final quotes = _Server(Completer<void>());
      var executes = 0;
      final container = setup((body) async {
        if (body['quoteOnly'] == true) return quotes.call(body);
        executes++;
        throw StateError('synthetic_network_failure');
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await _host(tester, container);
      await enterChatText(tester, 'What should I do first?');
      await tester.tap(find.byKey(const Key('conversation-send')));
      for (var i = 0; i < 40 && find.text('Send').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.text('Send'));
      for (
        var i = 0;
        i < 40 && find.text('Use 4 credits').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.text('Use 4 credits'));
      for (var i = 0; i < 40 && executes == 0; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      // The request failed and sits idle, waiting for Retry same request.
      expect(find.text('Retry same request'), findsOneWidget);
      container
          .read(siOneTapRequestProvider.notifier)
          .ask(SIOneTapQuestion.planMyDay);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.text(
          'A message is being sent. Ask the question when it finishes.',
        ),
        findsNothing,
      );
      expect(find.byKey(_localInput), findsOneWidget);
      expect(find.byKey(const Key('one-tap-free-line')), findsOneWidget);
      expect(executes, 1, reason: 'No second paid call');
    },
  );
}
