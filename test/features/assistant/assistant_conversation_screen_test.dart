import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/assistant_conversation_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/emotional_state.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/engine/si/api.dart';
import 'package:fantastic_guacamole/features/assistant/ui/assistant_conversation_screen.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_history_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/internal_credit_test_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/state/providers/voice_input_consent_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/system/voice/speech_recognition_service.dart';
import 'package:fantastic_guacamole/system/voice/voice_service.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final scope = AccountStorageScope.authenticated('synthetic-review');
final records = [
  TaskEntity(
    id: 'grocery',
    title: 'Grocery list',
    description: 'Milk, rice and vegetables for dinner.',
    estimatedDuration: const Duration(minutes: 45),
  ),
  TaskEntity(
    id: 'work',
    title: 'Finish work',
    scheduledFor: DateTime(2026, 9, 16, 9),
    estimatedDuration: const Duration(hours: 8),
  ),
];
final gateway = SIV2ReadGateway(
  accountScopeId: scope.v2Namespace!,
  readTasks: () async => records,
  readGoals: () async => [],
  readMilestones: () async => [],
  readTimeline: () async => [],
);

ProviderContainer setup(
  ConversationTransport transport, {
  AccountStorageScope Function()? readScope,
  SIV2ReadGateway? readGateway,
  ITaskRepository? taskRepository,
  ConsentedHumanContext? humanContext,
  VoiceController? voiceController,
  SpeechRecognitionService? speechService,
  VoicePermissionService? voicePermission,
  VoiceInputConsentStore? voiceConsent,
  bool conversationAvailable = true,
  Duration? requestTimeout,
  Duration? paidWaitTimeout,
  NoteEntity? selectedNote,
  SecureStoreBackend? historyBackend,
}) => ProviderContainer(
  overrides: [
    secureStoreProvider.overrideWithValue(
      SecureStore(backend: historyBackend ?? InMemorySecureStoreBackend()),
    ),
    accountStorageScopeProvider.overrideWith(
      (ref) => readScope?.call() ?? scope,
    ),
    authSessionBoundaryProvider.overrideWith(_Boundary.new),
    assistantConversationAvailableProvider.overrideWithValue(
      conversationAvailable,
    ),
    if (!conversationAvailable)
      siV2AvailabilityProvider.overrideWith((ref) async => true),
    personalizationProfileProvider.overrideWith(_Consent.new),
    conversationTransportProvider.overrideWithValue(transport),
    if (requestTimeout != null)
      conversationRequestTimeoutProvider.overrideWithValue(requestTimeout),
    if (paidWaitTimeout != null)
      conversationPaidWaitTimeoutProvider.overrideWithValue(paidWaitTimeout),
    siV2ReadGatewayProvider.overrideWithValue(readGateway ?? gateway),
    // Retained local-SI voice tests exercise capture lifecycle, not the real
    // Person Context secure-preference loader and its account mutation queue.
    siV2PersonContextRevisionProvider.overrideWithValue(
      'fixture-context-revision',
    ),
    siV2EvidenceSnapshotProvider.overrideWith(
      (ref) => (readGateway ?? gateway).read(observedAt: DateTime.now()),
    ),
    domainTaskRepositoryProvider.overrideWithValue(taskRepository ?? _Tasks()),
    if (humanContext != null)
      consentedHumanContextProvider.overrideWithValue(humanContext),
    selectedPlanningNoteProvider.overrideWith(
      (ref) async =>
          selectedNote ??
          NoteEntity(
            id: 'list-note',
            title: 'Dinner shopping',
            body: 'Check the pantry before buying rice.',
            createdAt: DateTime(2026, 9, 16),
            taskId: 'grocery',
          ),
    ),
    if (voiceController != null || speechService != null)
      voiceInputEnabledProvider.overrideWithValue(true),
    if (speechService != null)
      speechRecognitionServiceProvider.overrideWithValue(speechService),
    if (speechService != null)
      voiceServiceProvider.overrideWithValue(_SilentVoiceService()),
    if (voicePermission != null)
      voicePermissionServiceProvider.overrideWithValue(voicePermission),
    if (voiceController != null)
      voiceControllerProvider.overrideWith(() => voiceController),
    if (voiceController != null || speechService != null)
      voiceInputConsentStoreProvider.overrideWithValue(
        voiceConsent ??
            VoiceInputConsentStore(const AccountStorageScope.unsafe()),
      ),
    for (final capability in [
      AssistantReleaseCapability.smartPlannerV2,
      AssistantReleaseCapability.siConsoleV2,
      AssistantReleaseCapability.safetyCritic,
    ])
      assistantReleaseDecisionProvider(capability).overrideWith(
        (ref) async => AssistantReleaseDecision(
          enabled: true,
          shadowEvaluationEnabled: false,
          cohort: AssistantReleaseCohort.internal,
          reasonCode: 'synthetic-test',
          accountDigest: 'test',
          capability: capability,
          configDigest: 'test',
        ),
      ),
  ],
);

/// Hydration is asynchronous, especially when SI resolves its Chat route on a
/// later frame. A settled animation is not evidence that the form is usable.
Future<void> waitForChatReady(WidgetTester tester) async {
  final input = find.byKey(const Key('conversation-input'));
  for (var i = 0; i < 40; i++) {
    if (input.evaluate().length == 1 &&
        tester.widget<TextField>(input).enabled == true) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(input, findsOneWidget);
  expect(
    tester.widget<TextField>(input).enabled,
    isTrue,
    reason: 'Chat must finish loading before typing or dictating.',
  );
}

Future<void> enterChatText(WidgetTester tester, String text) async {
  await waitForChatReady(tester);
  await tester.enterText(find.byKey(const Key('conversation-input')), text);
  expect(
    tester
        .widget<TextField>(find.byKey(const Key('conversation-input')))
        .controller!
        .text,
    text,
  );
}

Future<void> pumpConversationScreen(
  WidgetTester tester,
  ProviderContainer container, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme,
        home: AssistantConversationScreen(
          surface: ConversationSurface.si,
          onLocalTools: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await waitForChatReady(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'blocked history hydration disables real input send and voice until restored',
    (tester) async {
      final backend = _GatedChatReadBackend();
      final voice = _ConversationVoiceController();
      var calls = 0;
      final container = setup(
        (_) async {
          calls++;
          throw StateError('Hydration must never request AI');
        },
        historyBackend: backend,
        voiceController: voice,
      );
      addTearDown(() async {
        if (!backend.release.isCompleted) backend.release.complete();
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: AssistantConversationScreen(
              surface: ConversationSurface.si,
              onLocalTools: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(backend.entered, isTrue);
      final input = find.byKey(const Key('conversation-input'));
      expect(tester.widget<TextField>(input).enabled, isFalse);
      IconButton button(String tooltip) => tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == tooltip,
        ),
      );
      expect(button('Send to AI').onPressed, isNull);
      expect(button('Start voice input').onPressed, isNull);
      expect(find.text('Loading saved chat…'), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Send to AI',
        ),
      );
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == 'Start voice input',
        ),
      );
      expect(calls, 0);
      expect(voice.starts, 0);
      backend.release.complete();
      await waitForChatReady(tester);
      expect(button('Send to AI').onPressed, isNotNull);
      expect(button('Start voice input').onPressed, isNotNull);
      await enterChatText(
        tester,
        'This draft is entered only after restoration.',
      );
      expect(
        tester.widget<TextField>(input).controller!.text,
        'This draft is entered only after restoration.',
      );
      expect(find.text('Loading saved chat…'), findsNothing);
      expect(calls, 0);
      expect(voice.starts, 0);
    },
  );

  for (final selectedTheme in [appLightTheme, appTheme]) {
    testWidgets(
      '${selectedTheme.brightness.name} Chat keeps body and bubbles readable without changing form mode',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var requests = 0;
        final container = setup((_) async {
          requests++;
          throw StateError('Rendering must not send AI');
        });
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await container
            .read(assistantConversationHistoryRepositoryProvider)!
            .save(
              expectedRevision: 0,
              messages: [
                {'role': 'user', 'content': 'A calm break, please.'},
                {
                  'role': 'assistant',
                  'content': 'A short pause can help you regroup.',
                },
              ],
              sources: {},
            );
        await pumpConversationScreen(tester, container, theme: selectedTheme);
        Color paintedText(Finder finder) {
          final rich = find
              .descendant(of: finder, matching: find.byType(RichText))
              .first;
          final paragraph = tester.renderObject<RenderParagraph>(rich);
          final color = paragraph.text.style?.color;
          expect(
            color,
            isNotNull,
            reason: 'Check the rendered text style, not only its theme.',
          );
          return color!;
        }

        double contrast(Color foreground, Color background) {
          final first = Color.alphaBlend(
            foreground,
            background,
          ).computeLuminance();
          final second = background.computeLuminance();
          return first > second
              ? (first + .05) / (second + .05)
              : (second + .05) / (first + .05);
        }

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, const Color(0xFF07111C));
        for (final text in [
          find.textContaining('Say what is on your mind'),
          find.text(
            'Saved on this device for this account. Up to 6 recent messages go with your next AI request.',
          ),
          find.text('Saved planning sources: off.'),
          find.text('Chat history & privacy'),
        ]) {
          expect(
            contrast(paintedText(text), scaffold.backgroundColor!),
            greaterThanOrEqualTo(4.5),
          );
        }
        expect(
          find.byKey(const Key('conversation-copy-history')),
          findsNothing,
        );
        final answer = find.text('A short pause can help you regroup.');
        final bubble = tester.widget<Card>(
          find.ancestor(of: answer, matching: find.byType(Card)).first,
        );
        expect(
          contrast(paintedText(answer), bubble.color!),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          bubble.color,
          selectedTheme.brightness == Brightness.light
              ? selectedTheme.colorScheme.surface
              : const Color(0xFF101E2C),
        );
        final userMessage = find.widgetWithText(
          SelectableText,
          'A calm break, please.',
        );
        final userBubble = tester.widget<Card>(
          find.ancestor(of: userMessage, matching: find.byType(Card)).first,
        );
        final userText = tester.widget<EditableText>(
          find.descendant(of: userMessage, matching: find.byType(EditableText)),
        );
        expect(
          contrast(userText.style.color!, userBubble.color!),
          greaterThanOrEqualTo(4.5),
        );
        final input = find.byKey(const Key('conversation-input'));
        final formTheme = Theme.of(tester.element(input));
        expect(formTheme.brightness, selectedTheme.brightness);
        expect(
          formTheme.inputDecorationTheme.fillColor,
          selectedTheme.inputDecorationTheme.fillColor,
        );
        final editable = tester.widget<EditableText>(
          find.descendant(of: input, matching: find.byType(EditableText)),
        );
        expect(
          contrast(
            editable.style.color!,
            formTheme.inputDecorationTheme.fillColor!,
          ),
          greaterThanOrEqualTo(4.5),
        );
        final options = find.byKey(const Key('conversation-advanced'));
        await tester.ensureVisible(options);
        await tester.tap(options);
        await tester.pump(const Duration(milliseconds: 300));
        final dropdown = find.byType(DropdownButtonFormField<SIV2Intent>);
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pump(const Duration(milliseconds: 300));
        final explain = find.text('Explain').last;
        final popupTheme = Theme.of(tester.element(explain));
        expect(popupTheme.brightness, selectedTheme.brightness);
        final popup = tester.widget<Material>(
          find.ancestor(of: explain, matching: find.byType(Material)).first,
        );
        expect(
          contrast(paintedText(explain), popup.color ?? popupTheme.canvasColor),
          greaterThanOrEqualTo(4.5),
        );
        await tester.tap(explain);
        await tester.pump(const Duration(milliseconds: 300));
        expect(requests, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'saved Chat survives route and container restart without auto sending, and explicitly clears',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = InMemorySecureStoreBackend();
      var transportCalls = 0;
      final first = setup((_) async {
        transportCalls++;
        throw StateError('No automatic AI request');
      }, historyBackend: backend);
      await first
          .read(assistantConversationHistoryRepositoryProvider)!
          .save(
            expectedRevision: 0,
            messages: [
              {'role': 'user', 'content': 'A quiet break after work'},
              {
                'role': 'assistant',
                'content': 'Try a short pause wherever you are comfortable.',
              },
            ],
            sources: {},
          );
      Future<void> show(ProviderContainer container) async {
        await pumpConversationScreen(tester, container);
      }

      await show(first);
      expect(find.textContaining('Try a short pause'), findsOneWidget);
      expect(
        find.text(
          'Saved on this device for this account. Up to 6 recent messages go with your next AI request.',
        ),
        findsOneWidget,
      );
      final privacy = find.byKey(const Key('conversation-history-privacy'));
      expect(tester.widget<ExpansionTile>(privacy).initiallyExpanded, isFalse);
      expect(find.text('Chat history & privacy'), findsOneWidget);
      expect(find.text('Up to 40 messages · copy or clear'), findsOneWidget);
      expect(find.text('Saved planning sources: off.'), findsOneWidget);
      expect(find.byKey(const Key('conversation-copy-history')), findsNothing);
      expect(find.byKey(const Key('conversation-clear-history')), findsNothing);
      expect(
        find.textContaining('Signing out keeps this account'),
        findsNothing,
      );
      expect(transportCalls, 0);
      // A new route state, then a new provider container, model route reentry and
      // process recreation over the same durable backend without a provider call.
      await tester.pumpWidget(const SizedBox.shrink());
      await show(first);
      expect(find.textContaining('Try a short pause'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();
      final restarted = setup((_) async {
        transportCalls++;
        throw StateError('No automatic AI request');
      }, historyBackend: backend);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        restarted.dispose();
      });
      await show(restarted);
      expect(find.textContaining('Try a short pause'), findsOneWidget);
      await tester.tap(find.byKey(const Key('conversation-advanced')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester
            .widgetList<FilterChip>(find.byType(FilterChip))
            .every((chip) => !chip.selected),
        isTrue,
      );
      expect(
        find.text(
          'Saved planning records are off. Earlier messages in this chat still apply.',
        ),
        findsOneWidget,
      );
      final restored = await restarted
          .read(assistantConversationHistoryRepositoryProvider)!
          .load();
      final packet = await restarted
          .read(conversationPacketFactoryProvider)
          .build(
            surface: ConversationSurface.si,
            prompt: '/tasks explain a fictional example',
            history: restored.messages,
            languageCode: 'en',
            sources: restored.sources,
          );
      expect(packet.toJson()['history'], restored.messages);
      final restoredContext = packet.toJson()['context'] as Map;
      expect(restoredContext['selectedSources'], isEmpty);
      expect(restoredContext['tasks'], isEmpty);
      expect(restoredContext.containsKey('explicitlyAttachedNote'), isFalse);
      final copied = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') copied.add(call.arguments);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      expect(copied, isEmpty);
      await tester.ensureVisible(privacy);
      await tester.tap(privacy);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.textContaining('Signing out keeps this account'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const Key('conversation-copy-history')),
      );
      await tester.tap(find.byKey(const Key('conversation-copy-history')));
      await tester.pump();
      expect(copied.single, {
        'text':
            'user: A quiet break after work\n\nassistant: Try a short pause wherever you are comfortable.',
      });
      await tester.tap(find.byKey(const Key('conversation-clear-history')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Clear conversation'),
        ),
      );
      await tester.pumpAndSettle();
      final cleared = await restarted
          .read(assistantConversationHistoryRepositoryProvider)!
          .load();
      expect(cleared.messages, isEmpty);
      expect(cleared.sources, isEmpty);
      expect(find.textContaining('Try a short pause'), findsNothing);
      expect(transportCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final conflictingClear in [false, true]) {
    testWidgets(
      conflictingClear
          ? 'concurrent clear preserves a paid mock answer and offers explicit reload without resurrecting history'
          : 'failed local save keeps a paid mock answer and save retry never executes AI again',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 1500));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final backend = _FailingChatBackend();
        var quoteCalls = 0;
        var paidCalls = 0;
        late final ProviderContainer container;
        container = setup((body) async {
          if (body['quoteOnly'] == true) {
            quoteCalls++;
            return (
              status: 200,
              data: <String, dynamic>{
                'requestId': body['requestId'],
                'quote': {
                  'credits': 4,
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
          paidCalls++;
          if (conflictingClear) {
            await container
                .read(assistantConversationHistoryRepositoryProvider)!
                .clear();
          }
          return (
            status: 200,
            data: <String, dynamic>{
              'requestId': body['requestId'],
              'message':
                  'Try a brief quiet pause before choosing your next activity.',
              'creditsCharged': 4,
              'remainingCredits': 20,
              'model': 'transport-fixture',
            },
          );
        }, historyBackend: backend);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: AssistantConversationScreen(
                surface: ConversationSurface.si,
                onLocalTools: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        backend.failWrites = !conflictingClear;
        await enterChatText(tester, 'Suggest a quiet break after work.');
        await tester.tap(find.byTooltip('Send to AI'));
        for (
          var i = 0;
          i < 20 && find.text('Get credit price').evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
          if (find.text('Review AI price').evaluate().isNotEmpty) {
            await tester.tap(find.text('Review AI price'));
          }
        }
        expect(find.text('Get credit price'), findsOneWidget);
        await tester.tap(find.text('Get credit price'));
        for (
          var i = 0;
          i < 20 && find.text('Use 4 credits').evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.text('Use 4 credits'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.textContaining('Try a brief quiet pause'), findsOneWidget);
        expect(quoteCalls, 1);
        expect(paidCalls, 1);
        expect(
          find.byKey(const Key('conversation-copy-history')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('conversation-clear-history')),
          findsNothing,
        );
        if (conflictingClear) {
          expect(find.text('Retry saving chat'), findsNothing);
          expect(
            (await container
                    .read(assistantConversationHistoryRepositoryProvider)!
                    .load())
                .messages,
            isEmpty,
          );
          final reload = find.text('Reload saved chat');
          await tester.scrollUntilVisible(
            reload,
            -300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(reload);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text('Reload saved chat'),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.textContaining('Try a brief quiet pause'), findsNothing);
          expect(quoteCalls, 1);
          expect(paidCalls, 1);
          expect(tester.takeException(), isNull);
          return;
        }
        backend.failWrites = false;
        final retry = find.text('Retry saving chat');
        await tester.scrollUntilVisible(
          retry,
          -300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(retry);
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          (await container
                  .read(assistantConversationHistoryRepositoryProvider)!
                  .load())
              .messages,
          hasLength(2),
        );
        expect(quoteCalls, 1);
        expect(paidCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'chat-only packets exclude saved records even when account has tasks and a selected note',
    () async {
      final container = setup(
        (_) async => throw StateError('No network expected'),
      );
      addTearDown(container.dispose);
      for (final surface in ConversationSurface.values) {
        for (final prompt in [
          'Compare two fictional quiet breaks',
          '/tasks explain a fictional example',
          '/goals explain a fictional example',
          '/milestones explain a fictional example',
          '/timeline explain a fictional example',
        ]) {
          final packet = await container
              .read(conversationPacketFactoryProvider)
              .build(
                surface: surface,
                prompt: prompt,
                history: [],
                languageCode: 'en',
                sources: {},
              );
          final context = packet.toJson()['context'] as Map;
          expect(context['selectedSources'], isEmpty);
          for (final key in [
            'tasks',
            'goals',
            'milestones',
            'timeline',
            'unavailableSources',
          ]) {
            expect(context[key], isEmpty);
          }
          expect(context['contextScope'], 'chatOnly');
          expect(context['evidenceRevision'], 'chat-only');
          expect(context.containsKey('explicitlyAttachedNote'), isFalse);
          expect(packet.preview, isNot(contains('Grocery list')));
          expect(packet.preview, isNot(contains('Dinner shopping')));
        }
      }
    },
  );

  test('conversation deadline precedes the production transport deadline', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(conversationRequestTimeoutProvider),
      lessThan(internalCreditTestQuoteTransportTimeout),
    );
  });

  test('SI refuses a UTC fallback when the native zone is London', () async {
    tzdata.initializeTimeZones();
    final previousZone = tz.local;
    tz.setLocalLocation(tz.UTC);
    addTearDown(() => tz.setLocalLocation(previousZone));
    const channel = MethodChannel('flutter_timezone');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => 'Europe/London');
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final container = setup(
      (_) async => throw StateError('No transport should run'),
    );
    addTearDown(container.dispose);
    final packet = await container
        .read(conversationPacketFactoryProvider)
        .build(
          surface: ConversationSurface.si,
          prompt: 'Does Grocery list conflict with an 8 PM store closing?',
          history: [],
          languageCode: 'en',
          intent: SIV2Intent.findConflict,
          sources: {SIV2Source.tasks},
        );
    expect((packet.toJson()['context'] as Map)['taskTimeZoneId'], isNull);
  });
  for (final surface in ConversationSurface.values) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('expanded $surface floating label is not clipped at $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = setup((_) async => throw StateError('No AI request'));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        final planner = surface == ConversationSurface.planner;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData.dark().copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  border: OutlineInputBorder(),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: AssistantConversationScreen(
                surface: surface,
                onLocalTools: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (!planner) {
          await waitForChatReady(tester);
        }
        final advanced = find.text(
          planner
              ? 'How much energy do you have? (optional)'
              : 'Choose information to use (optional)',
        );
        await tester.scrollUntilVisible(
          advanced,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(advanced);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text(planner ? 'Energy (optional)' : 'What kind of help?'),
        );
        final label = tester.renderObject<RenderBox>(
          find.text(planner ? 'Energy (optional)' : 'What kind of help?'),
        );
        var checkedClips = 0;
        RenderObject? ancestor = label.parent;
        while (ancestor != null) {
          if (ancestor is RenderClipRect &&
              ancestor.clipBehavior != Clip.none) {
            final top = label.localToGlobal(Offset.zero, ancestor: ancestor).dy;
            expect(
              top,
              greaterThanOrEqualTo(0),
              reason: 'Floating label must stay inside every clipping ancestor',
            );
            checkedClips++;
          }
          ancestor = ancestor.parent;
        }
        expect(checkedClips, greaterThan(0));
        expect(tester.takeException(), isNull);
      });
    }
  }
  test(
    'attached-task-only packet excludes unrelated goals, notes and emotion',
    () async {
      final container = setup(
        (_) async => throw StateError('No transport should run'),
        readGateway: SIV2ReadGateway(
          accountScopeId: scope.v2Namespace!,
          readTasks: () async => records,
          readGoals: () async => [
            GoalEntity(
              id: 'private',
              title: 'Private personal goal',
              createdAt: DateTime(2026, 9, 17),
            ),
          ],
          readMilestones: () async => [],
          readTimeline: () async => [],
        ),
        humanContext: const ConsentedHumanContext(
          emotionAllowed: true,
          memoryAllowed: false,
          emotion: EmotionalState.fatigued,
          siState: SIState(),
        ),
      );
      addTearDown(container.dispose);
      for (final restricted in [true, false]) {
        final packet = await container
            .read(conversationPacketFactoryProvider)
            .build(
              surface: ConversationSurface.planner,
              prompt: 'What time should I go to the store?',
              history: [],
              languageCode: 'en',
              selectedTaskId: 'grocery',
              attachedTaskOnly: restricted,
            );
        final context = packet.toJson()['context'] as Map;
        if (restricted) {
          expect((context['tasks'] as List).map((e) => (e as Map)['id']), [
            'grocery',
          ]);
          for (final source in ['goals', 'milestones', 'timeline']) {
            expect(context[source], isEmpty);
          }
          expect(context.containsKey('explicitlyAttachedNote'), isFalse);
          expect(context.containsKey('reportedEmotion'), isFalse);
          expect(context['contextScope'], 'attachedTaskOnly');
          expect(context['selectedSources'], ['tasks']);
        } else {
          expect(context['goals'], isNotEmpty);
          expect(context['explicitlyAttachedNote'], isNotNull);
          expect(context['reportedEmotion'], 'fatigued');
        }
      }
    },
  );
  test('SI goals remain usable when deselected task storage fails', () async {
    final repository = _UnavailableTasks(
      StateError('Task storage unavailable'),
    );
    final container = setup(
      (_) async => throw StateError('No transport should run'),
      taskRepository: repository,
      readGateway: SIV2ReadGateway(
        accountScopeId: scope.v2Namespace!,
        readTasks: () async => throw StateError('Task storage unavailable'),
        readGoals: () async => [
          GoalEntity(
            id: 'budget',
            title: 'Build an emergency fund',
            createdAt: DateTime(2026, 9, 1),
          ),
        ],
        readMilestones: () async => [],
        readTimeline: () async => [],
      ),
    );
    addTearDown(container.dispose);
    final packet = await container
        .read(conversationPacketFactoryProvider)
        .build(
          surface: ConversationSurface.si,
          prompt: 'goals',
          history: [],
          languageCode: 'en',
          sources: {SIV2Source.goals},
        );
    final context = packet.toJson()['context'] as Map;
    expect(
      ((context['goals'] as List).single as Map)['title'],
      'Build an emergency fund',
    );
    expect(context['tasks'], isEmpty);
    expect(context['selectedSources'], ['goals']);
    expect(context['unavailableSources'], isEmpty);
    expect(repository.reads, 0);
  });

  test(
    'SI preserves a goals-only filter when the selected group is empty',
    () async {
      final container = setup(
        (_) async => throw StateError('No transport should run'),
      );
      addTearDown(container.dispose);
      final packet = await container
          .read(conversationPacketFactoryProvider)
          .build(
            surface: ConversationSurface.si,
            prompt: 'What saved evidence is available?',
            history: [],
            languageCode: 'en',
            sources: {SIV2Source.goals},
            entityFilter: 'No matching goal',
          );
      final context = packet.toJson()['context'] as Map;
      expect(context['selectedSources'], ['goals']);
      expect(context['goals'], isEmpty);
      expect(context['tasks'], isEmpty);
      expect(context['milestones'], isEmpty);
      expect(context['timeline'], isEmpty);
    },
  );

  test('SI shortcut serializes the source actually used', () async {
    final container = setup(
      (_) async => throw StateError('No transport should run'),
      readGateway: SIV2ReadGateway(
        accountScopeId: scope.v2Namespace!,
        readTasks: () async => records,
        readGoals: () async => [
          GoalEntity(
            id: 'private',
            title: 'Private personal goal',
            createdAt: DateTime(2026, 9, 17),
          ),
        ],
        readMilestones: () async => [],
        readTimeline: () async => [],
      ),
    );
    addTearDown(container.dispose);

    final packet = await container
        .read(conversationPacketFactoryProvider)
        .build(
          surface: ConversationSurface.si,
          prompt: '/tasks What is scheduled?',
          history: [],
          languageCode: 'en',
          sources: {SIV2Source.goals},
        );
    final context = packet.toJson()['context'] as Map;

    expect(context['selectedSources'], ['tasks']);
    expect(context['tasks'], isNotEmpty);
    final work = (context['tasks'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((task) => task['id'] == 'work');
    expect(work['scheduledStart'], isNotNull);
    expect(context.containsKey('taskTimeZoneId'), isTrue);
    final zone = context['taskTimeZoneId'];
    if (zone != null) expect(zone, isA<String>());
    expect(context['goals'], isEmpty);
  });

  test(
    'SI carries its uniquely matched grocery task among multiple tasks',
    () async {
      final container = setup(
        (_) async => throw StateError('No transport should run'),
      );
      addTearDown(container.dispose);
      final packet = await container
          .read(conversationPacketFactoryProvider)
          .build(
            surface: ConversationSurface.si,
            prompt: 'Does Grocery list conflict with an 8 PM store closing?',
            history: [],
            languageCode: 'en',
            intent: SIV2Intent.findConflict,
            sources: {SIV2Source.tasks},
          );
      final context = packet.toJson()['context'] as Map;
      expect((context['tasks'] as List).length, greaterThan(1));
      expect(context['focusedTaskId'], 'grocery');

      final ambiguous = setup(
        (_) async => throw StateError('No transport should run'),
        readGateway: SIV2ReadGateway(
          accountScopeId: scope.v2Namespace!,
          readTasks: () async => [
            ...records,
            TaskEntity(id: 'grocery-copy', title: 'Grocery list'),
          ],
          readGoals: () async => [],
          readMilestones: () async => [],
          readTimeline: () async => [],
        ),
      );
      addTearDown(ambiguous.dispose);
      final ambiguousPacket = await ambiguous
          .read(conversationPacketFactoryProvider)
          .build(
            surface: ConversationSurface.si,
            prompt: 'Does Grocery list conflict with an 8 PM store closing?',
            history: [],
            languageCode: 'en',
            intent: SIV2Intent.findConflict,
            sources: {SIV2Source.tasks},
          );
      final ambiguousContext = ambiguousPacket.toJson()['context'] as Map;
      expect(ambiguousContext['focusedTaskId'], isNull);

      final incidental = setup(
        (_) async => throw StateError('No transport should run'),
        readGateway: SIV2ReadGateway(
          accountScopeId: scope.v2Namespace!,
          readTasks: () async => [
            ...records,
            TaskEntity(id: 'inventory', title: 'Store inventory'),
          ],
          readGoals: () async => [],
          readMilestones: () async => [],
          readTimeline: () async => [],
        ),
      );
      addTearDown(incidental.dispose);
      final incidentalPacket = await incidental
          .read(conversationPacketFactoryProvider)
          .build(
            surface: ConversationSurface.si,
            prompt: 'Does this task conflict with an 8 PM store closing?',
            history: [],
            languageCode: 'en',
            intent: SIV2Intent.findConflict,
            sources: {SIV2Source.tasks},
          );
      final incidentalContext = incidentalPacket.toJson()['context'] as Map;
      expect(incidentalContext['focusedTaskId'], isNull);
    },
  );

  for (final failure in [
    StateError('Task details unavailable'),
    TimeoutException('Task details timed out'),
  ]) {
    test(
      'selected task evidence survives detail failure: ${failure.runtimeType}',
      () async {
        final repository = _UnavailableTasks(failure);
        final container = setup(
          (_) async => throw StateError('No transport should run'),
          taskRepository: repository,
        );
        addTearDown(container.dispose);
        final packet = await container
            .read(conversationPacketFactoryProvider)
            .build(
              surface: ConversationSurface.planner,
              prompt: 'When can I get groceries?',
              history: [],
              languageCode: 'en',
              selectedTaskId: 'grocery',
            );
        final context = packet.toJson()['context'] as Map;
        final grocery = (context['tasks'] as List).first as Map;
        expect(grocery['title'], 'Grocery list');
        expect(grocery['description'], isEmpty);
        expect(grocery['estimatedDurationMinutes'], isNull);
        expect(context['taskDetailsUnavailable'], isTrue);
        expect(repository.reads, 1);
      },
    );
  }

  test(
    'emotion consent adds emotional state only to disclosed Planner context',
    () async {
      final container = setup(
        (_) async => throw StateError('No transport should run'),
        humanContext: const ConsentedHumanContext(
          emotionAllowed: true,
          memoryAllowed: false,
          emotion: EmotionalState.fatigued,
          siState: SIState(),
        ),
      );
      addTearDown(container.dispose);
      for (final surface in ConversationSurface.values) {
        final packet = await container
            .read(conversationPacketFactoryProvider)
            .build(
              surface: surface,
              prompt: 'What should I do next?',
              history: [],
              languageCode: 'en',
            );
        final context = packet.toJson()['context'] as Map;
        if (surface == ConversationSurface.planner) {
          expect(context['reportedEmotion'], 'fatigued');
        } else {
          expect(context.containsKey('reportedEmotion'), isFalse);
        }
      }
    },
  );

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 300));
        return;
      }
    }
    expect(finder, findsOneWidget);
  }

  testWidgets(
    'chat-only option keeps slash task prompts out of saved context review',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var transportCalls = 0;
      final container = setup((_) async {
        transportCalls++;
        throw StateError('Reviewing context must not request a credit quote');
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: AssistantConversationScreen(
              surface: ConversationSurface.si,
              onLocalTools: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await waitForChatReady(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('conversation-advanced')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('conversation-advanced')));
      await tester.pumpAndSettle();
      final chatOnly = find.text('Use just this chat');
      await tester.ensureVisible(chatOnly);
      await tester.tap(chatOnly);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Saved planning records are off. Earlier messages in this chat still apply.',
        ),
        findsOneWidget,
      );
      final sources = tester.widgetList<FilterChip>(find.byType(FilterChip));
      expect(sources, hasLength(SIV2Source.values.length));
      expect(sources.every((source) => !source.selected), isTrue);

      final input = find.byKey(const Key('conversation-input'));
      await tester.ensureVisible(input);
      await enterChatText(tester, '/tasks explain a fictional example');
      final send = find.byTooltip('Send to AI');
      await tester.ensureVisible(send);
      await tester.tap(send);
      // Routing may offer local help before the disclosure; neither choice
      // should override the explicit chat-only source selection.
      await waitFor(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == 'Free on-device option' ||
                  widget.data == 'Review what AI will receive'),
        ),
      );
      if (find.text('Review AI price').evaluate().isNotEmpty) {
        await tester.tap(find.text('Review AI price'));
      }
      await waitFor(tester, find.text('Get credit price'));
      final includedContext = find.text('Included app context');
      await tester.ensureVisible(includedContext);
      await tester.tap(includedContext);
      // The focused prompt can keep its cursor animation alive. Wait for
      // disclosure content rather than waiting for every animation to stop.
      await tester.pump(const Duration(milliseconds: 300));
      await waitFor(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              (widget.data ?? widget.textSpan!.toPlainText()).contains(
                'Sources: just this chat',
              ),
        ),
      );
      final review = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SelectableText),
      );
      final reviewText = tester
          .widgetList<SelectableText>(review)
          .map((widget) => widget.data ?? widget.textSpan!.toPlainText())
          .join('\n');
      expect(reviewText, contains('/tasks explain a fictional example'));
      expect(reviewText, contains('Sources: just this chat'));
      for (final excluded in [
        'Grocery list',
        'Finish work',
        'Dinner shopping',
        'Milk, rice and vegetables for dinner.',
        'Check the pantry before buying rice.',
        'Attached note',
      ]) {
        expect(reviewText, isNot(contains(excluded)));
      }
      expect(transportCalls, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Review what AI will receive'), findsNothing);
      expect(transportCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Spanish conversation dictation requests Spanish recognition', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final voice = _ConversationVoiceController();
    final container = setup(
      (_) async => throw StateError('Dictation must not send a request'),
      voiceController: voice,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('es'),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: const [
            ChronoSparkLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: AssistantConversationScreen(
            surface: ConversationSurface.si,
            onLocalTools: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await waitForChatReady(tester);
    await tester.tap(find.byTooltip('Iniciar entrada de voz'));
    await tester.pumpAndSettle();
    final agree = find.text('Aceptar y dictar');
    await tester.ensureVisible(agree);
    await tester.tap(agree);
    await tester.pumpAndSettle();

    expect(voice.lastLocaleId, 'es');
    expect(voice.starts, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local question offers free tools and preserves the draft', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var transportCalls = 0;
    String? handoffDraft;
    final container = setup((_) async {
      transportCalls++;
      throw StateError('A local handoff must not call the AI service');
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: AssistantConversationScreen(
            surface: ConversationSurface.si,
            onLocalTools: () {},
            onLocalToolsWithDraft: (draft) => handoffDraft = draft,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterChatText(tester, 'What are my tasks?');
    await tester.tap(find.byTooltip('Send to AI'));
    await waitFor(tester, find.text('Use free tools'));
    expect(transportCalls, 0);
    expect(find.text('Get credit price'), findsNothing);

    await tester.tap(find.text('Use free tools'));
    await tester.pumpAndSettle();
    expect(handoffDraft, 'What are my tasks?');
    expect(transportCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Spanish local question offers free tools without a quote', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? handoffDraft;
    var transportCalls = 0;
    final container = setup((_) async {
      transportCalls++;
      throw StateError('Spanish local handoff must not call the AI service');
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('es'),
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: const [
            ChronoSparkLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: ThemeData.dark(),
          home: AssistantConversationScreen(
            surface: ConversationSurface.si,
            onLocalTools: () {},
            onLocalToolsWithDraft: (draft) => handoffDraft = draft,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterChatText(tester, '¿Cuáles son mis tareas?');
    await tester.tap(find.byTooltip('Enviar a IA'));
    await waitFor(tester, find.text('Usar herramientas gratis'));
    expect(transportCalls, 0);
    await tester.tap(find.text('Usar herramientas gratis'));
    await tester.pumpAndSettle();
    expect(handoffDraft, '¿Cuáles son mis tareas?');
    expect(transportCalls, 0);
  });

  testWidgets('local suggestion can still enter the existing paid quote flow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var transportCalls = 0;
    final container = setup((_) async {
      transportCalls++;
      throw StateError('The user did not request a quote');
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: AssistantConversationScreen(
            surface: ConversationSurface.si,
            onLocalTools: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterChatText(tester, 'What are my tasks?');
    await tester.tap(find.byTooltip('Send to AI'));
    await waitFor(tester, find.text('Review AI price'));
    await tester.tap(find.text('Review AI price'));
    await waitFor(tester, find.text('Get credit price'));
    expect(transportCalls, 0);
    expect(tester.takeException(), isNull);
  });

  for (final failure in <String, String>{
    'daily_budget_exceeded': 'rolling daily AI safety limit',
    'timing_context_missing': 'one scheduled task and its local date',
    'insufficient_credits': 'not have enough AI credits',
    'credits_exhausted': 'not have enough AI credits',
    'request_denied': 'denied before processing',
    'provider_cost_budget_exceeded': 'service spending limit',
    'rate_limit_exceeded': 'Too many AI requests',
    'request_completed': 'already finished, but its reply is unavailable',
    'request_refunded': 'credits were refunded',
    'unsafe_upstream_response': 'credits were refunded',
    'inconsistent_upstream_response': 'credits were refunded',
    'upstream_ai_error': 'credits were refunded',
    'truncated_upstream_response': 'credits were refunded',
    'invalid_upstream_response': 'credits were refunded',
    'empty_upstream_response': 'credits were refunded',
  }.entries) {
    testWidgets(
      '${failure.key} is visible, explains no charge and gives the valid next action',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = setup(
          (body) async => (
            status: body['quoteOnly'] == true ? 200 : 429,
            data: body['quoteOnly'] == true
                ? <String, dynamic>{
                    'requestId': body['requestId'],
                    'quote': <String, dynamic>{
                      'credits': 4,
                      'digest': 'fixture',
                      'proof': 'fixture',
                      'policy': 'fixture',
                      'expiresAt': DateTime.now()
                          .add(const Duration(minutes: 5))
                          .millisecondsSinceEpoch,
                    },
                  }
                : <String, dynamic>{'error': failure.key},
          ),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: AssistantConversationScreen(
                surface: ConversationSurface.si,
                onLocalTools: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await enterChatText(tester, 'Keep this question for a safe retry.');
        await tester.tap(find.byTooltip('Send to AI'));
        await waitFor(tester, find.text('Get credit price'));
        await tester.tap(find.text('Get credit price'));
        await waitFor(tester, find.text('Use 4 credits'));
        await tester.tap(find.text('Use 4 credits'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('conversation-error')), findsOneWidget);
        expect(find.textContaining(failure.value), findsOneWidget);
        if (failure.key == 'request_completed') {
          expect(
            find.textContaining('did not charge you again'),
            findsOneWidget,
          );
        } else {
          expect(
            find.textContaining('No credits were charged'),
            findsOneWidget,
          );
        }
        if (<String>{
          'daily_budget_exceeded',
          'timing_context_missing',
          'insufficient_credits',
          'credits_exhausted',
          'request_completed',
          'request_refunded',
          'unsafe_upstream_response',
          'inconsistent_upstream_response',
          'upstream_ai_error',
          'truncated_upstream_response',
          'invalid_upstream_response',
          'empty_upstream_response',
        }.contains(failure.key)) {
          expect(find.text('Retry same request'), findsNothing);
          expect(find.textContaining('new request'), findsOneWidget);
          expect(find.textContaining('new quote'), findsOneWidget);
        } else {
          expect(find.text('Retry same request'), findsOneWidget);
        }
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('conversation-input')))
              .controller!
              .text,
          'Keep this question for a safe retry.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final failure in <String, String>{
    'quote_expired': 'price expired',
    'credit_quote_required': 'price expired',
    'response_withheld': 'did not pass the response check',
  }.entries) {
    testWidgets('${failure.key} unlocks a fresh request', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = setup(
        (body) async => (
          status: body['quoteOnly'] == true ? 200 : 409,
          data: body['quoteOnly'] == true
              ? <String, dynamic>{
                  'requestId': body['requestId'],
                  'quote': <String, dynamic>{
                    'credits': 4,
                    'digest': 'fixture',
                    'proof': 'fixture',
                    'policy': 'fixture',
                    'expiresAt': DateTime.now()
                        .add(const Duration(minutes: 5))
                        .millisecondsSinceEpoch,
                  },
                }
              : <String, dynamic>{'error': failure.key},
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: AssistantConversationScreen(
              surface: ConversationSurface.si,
              onLocalTools: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enterChatText(tester, 'Keep this question for a fresh request.');
      await tester.tap(find.byTooltip('Send to AI'));
      await waitFor(tester, find.text('Get credit price'));
      await tester.tap(find.text('Get credit price'));
      await waitFor(tester, find.text('Use 4 credits'));
      await tester.tap(find.text('Use 4 credits'));
      await tester.pumpAndSettle();

      expect(find.textContaining(failure.value), findsOneWidget);
      expect(find.text('Retry same request'), findsNothing);
      final input = tester.widget<TextField>(
        find.byKey(const Key('conversation-input')),
      );
      expect(input.enabled, isTrue);
      expect(input.controller!.text, 'Keep this question for a fresh request.');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Spanish daily AI limit is readable at 150 percent and requires a new request',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = setup(
        (body) async => (
          status: body['quoteOnly'] == true ? 200 : 429,
          data: body['quoteOnly'] == true
              ? <String, dynamic>{
                  'requestId': body['requestId'],
                  'quote': <String, dynamic>{
                    'credits': 4,
                    'digest': 'fixture',
                    'proof': 'fixture',
                    'policy': 'fixture',
                    'expiresAt': DateTime.now()
                        .add(const Duration(minutes: 5))
                        .millisecondsSinceEpoch,
                  },
                }
              : <String, dynamic>{'error': 'daily_budget_exceeded'},
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('es'),
            supportedLocales: ChronoSparkLocalizations.supportedLocales,
            localizationsDelegates: const [
              ChronoSparkLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            theme: ThemeData.dark(),
            home: AssistantConversationScreen(
              surface: ConversationSurface.si,
              onLocalTools: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'initial Spanish layout');
      await enterChatText(tester, 'Conserva esta pregunta para reintentar.');
      await tester.tap(find.byTooltip('Enviar a IA'));
      await waitFor(tester, find.text('Consultar precio'));
      expect(tester.takeException(), isNull, reason: 'disclosure dialog');
      await tester.tap(find.text('Consultar precio'));
      await waitFor(tester, find.text('Usar 4 créditos'));
      expect(tester.takeException(), isNull, reason: 'price dialog');
      await tester.tap(find.text('Usar 4 créditos'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('conversation-error')), findsOneWidget);
      expect(find.textContaining('límite diario móvil'), findsOneWidget);
      expect(find.textContaining('No se cobraron créditos'), findsOneWidget);
      expect(find.text('Reintentar la misma solicitud'), findsNothing);
      expect(find.textContaining('no se puede reutilizar'), findsOneWidget);
      expect(find.textContaining('Inicia una solicitud nueva'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'failure presentation');
    },
  );

  testWidgets(
    'Spanish insufficient credits preserves input and requires a new quote',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = setup(
        (body) async => (
          status: body['quoteOnly'] == true ? 200 : 402,
          data: body['quoteOnly'] == true
              ? <String, dynamic>{
                  'requestId': body['requestId'],
                  'quote': <String, dynamic>{
                    'credits': 4,
                    'digest': 'fixture',
                    'proof': 'fixture',
                    'policy': 'fixture',
                    'expiresAt': DateTime.now()
                        .add(const Duration(minutes: 5))
                        .millisecondsSinceEpoch,
                  },
                }
              : <String, dynamic>{'error': 'insufficient_credits'},
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('es'),
            supportedLocales: ChronoSparkLocalizations.supportedLocales,
            localizationsDelegates: const [
              ChronoSparkLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            home: AssistantConversationScreen(
              surface: ConversationSurface.si,
              onLocalTools: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enterChatText(tester, 'Conserva esta pregunta.');
      await tester.tap(find.byTooltip('Enviar a IA'));
      await waitFor(tester, find.text('Consultar precio'));
      await tester.tap(find.text('Consultar precio'));
      await waitFor(tester, find.text('Usar 4 créditos'));
      await tester.tap(find.text('Usar 4 créditos'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No tienes suficientes créditos'),
        findsOneWidget,
      );
      expect(find.textContaining('No se cobraron créditos'), findsOneWidget);
      expect(find.text('Reintentar la misma solicitud'), findsNothing);
      expect(find.textContaining('solicitud nueva'), findsOneWidget);
      expect(find.textContaining('cotización'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('conversation-input')))
            .controller!
            .text,
        'Conserva esta pregunta.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'packet preserves an attached grocery task, note and clock fields',
    () async {
      final container = setup(
        (_) async => throw StateError('No transport should run'),
      );
      addTearDown(container.dispose);
      final packet = await container
          .read(conversationPacketFactoryProvider)
          .build(
            surface: ConversationSurface.planner,
            prompt: 'What time should I go to the store?',
            selectedTaskId: 'grocery',
            history: [],
            languageCode: 'en',
          );
      final data = packet.toJson()['context'] as Map;
      final tasks = data['tasks'] as List;
      expect((tasks.first as Map)['title'], 'Grocery list');
      expect((tasks.first as Map)['description'], contains('vegetables'));
      expect((tasks.first as Map)['estimatedDurationMinutes'], 45);
      expect(
        (data['explicitlyAttachedNote'] as Map)['body'],
        contains('pantry'),
      );
      expect(
        data.containsKey('dataLimitations'),
        isFalse,
        reason:
            'The local parser cannot veto a question it does not understand.',
      );
    },
  );

  test('an attached crisis note blocks a quote before transport', () async {
    var transportCalls = 0;
    final container = setup(
      (_) async {
        transportCalls++;
        throw StateError('An attached crisis note must not reach transport');
      },
      selectedNote: NoteEntity(
        id: 'list-note',
        title: 'Please help',
        body: 'I want to kill myself tonight.',
        createdAt: DateTime(2026, 9, 16),
        taskId: 'grocery',
      ),
    );
    addTearDown(container.dispose);
    final packet = await container
        .read(conversationPacketFactoryProvider)
        .build(
          surface: ConversationSurface.planner,
          prompt: 'Can you summarize my note?',
          selectedTaskId: 'grocery',
          history: [],
          languageCode: 'en',
        );
    expect(packet.attachedNoteSafetyText, contains('kill myself'));
    await expectLater(
      container.read(conversationServiceProvider).quote(packet),
      throwsA(
        isA<ConversationFailure>().having(
          (failure) => failure.code,
          'code',
          'supportive_route_required',
        ),
      ),
    );
    expect(transportCalls, 0);
  });

  test(
    'Advanced mode, entity filter and scenario reach the model packet',
    () async {
      final container = setup(
        (_) async => throw StateError('No transport should run'),
      );
      addTearDown(container.dispose);
      final packet = await container
          .read(conversationPacketFactoryProvider)
          .build(
            surface: ConversationSurface.si,
            prompt: 'tasks',
            history: [],
            languageCode: 'en',
            intent: SIV2Intent.forecast,
            entityFilter: 'Grocery',
            scenario: 'Go tomorrow instead of tonight.',
          );
      final data = packet.toJson()['context'] as Map;
      expect(data['mode'], 'forecast');
      expect(data['scenarioAssumption'], 'Go tomorrow instead of tonight.');
      expect((data['tasks'] as List).map((task) => (task as Map)['title']), [
        'Grocery list',
      ]);
      expect(data.containsKey('explicitlyAttachedNote'), isFalse);
    },
  );

  for (final surface in ConversationSurface.values) {
    testWidgets(
      '${surface.name} dictation requires consent, fills the draft and never auto-sends',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        final voice = _ConversationVoiceController();
        final sent = <Map<String, dynamic>>[];
        final container = setup((body) async {
          sent.add(body);
          throw StateError('Dictation must not send an AI request');
        }, voiceController: voice);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          container.dispose();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: AssistantConversationScreen(
                surface: surface,
                onLocalTools: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await enterChatText(tester, 'Groceries');
        await tester.tap(find.byTooltip('Start voice input'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('may send audio to its servers'),
          findsOneWidget,
        );
        final Finder agree = find.text('Agree and dictate');
        await tester.ensureVisible(agree);
        await tester.tap(agree);
        await tester.pumpAndSettle();
        expect(voice.starts, 1);

        voice.emitTranscript('before 7 pm', listening: true);
        await tester.pump();
        final Finder input = find.byKey(const Key('conversation-input'));
        expect(
          tester.widget<TextField>(input).controller!.text,
          'Groceries before 7 pm',
        );
        expect(tester.widget<TextField>(input).readOnly, isTrue);
        expect(
          tester
              .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.send_rounded),
              )
              .onPressed,
          isNull,
        );
        expect(sent, isEmpty);

        voice.emitTranscript('before 7 pm', listening: false);
        await tester.pump();
        expect(tester.widget<TextField>(input).readOnly, isFalse);
        expect(
          tester.widget<TextField>(input).controller!.text,
          'Groceries before 7 pm',
        );
        expect(sent, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${surface.name} obtains consent and price then sends a real conversation payload',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final sent = <Map<String, dynamic>>[];
        final container = setup((body) async {
          sent.add(body);
          return (
            status: 200,
            data: body['quoteOnly'] == true
                ? {
                    'requestId': body['requestId'],
                    'quote': {
                      'credits': 4,
                      'digest': 'fixture',
                      'proof': 'fixture',
                      'policy': 'fixture',
                      'expiresAt': DateTime.now()
                          .add(const Duration(minutes: 5))
                          .millisecondsSinceEpoch,
                    },
                  }
                : {
                    'requestId': body['requestId'],
                    'message': 'What time window are you free to go shopping?',
                    'creditsCharged': 4,
                    'remainingCredits': 20,
                    'model': 'transport-fixture',
                  },
          );
        });
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: AssistantConversationScreen(
                surface: surface,
                onLocalTools: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (surface == ConversationSurface.planner) {
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Grocery list').last);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<SwitchListTile>(
                  find.byKey(const Key('conversation-task-only')),
                )
                .value,
            isTrue,
          );
        }
        await enterChatText(tester, 'What time should I go to the store?');
        await tester.tap(find.byTooltip('Send to AI'));
        await waitFor(tester, find.text('Get credit price'));
        expect(
          sent,
          isEmpty,
          reason: 'Even the backend quote waits for disclosure consent.',
        );
        await tester.tap(find.text('Get credit price'));
        await waitFor(tester, find.text('Use 4 credits'));
        expect(sent, hasLength(1));
        if (surface == ConversationSurface.planner) {
          final outgoing = sent.single['context'] as Map;
          expect(outgoing['contextScope'], 'attachedTaskOnly');
          expect(outgoing['tasks'], hasLength(1));
          expect(outgoing.containsKey('explicitlyAttachedNote'), isFalse);
        }
        await tester.tap(find.text('Use 4 credits'));
        await tester.pumpAndSettle();
        expect(sent, hasLength(2));
        expect(
          find.text('What time window are you free to go shopping?'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Report response'));
        await tester.tap(find.text('Report response'));
        await tester.pumpAndSettle();
        expect(find.text('Send report'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await enterChatText(
          tester,
          'Between 5 pm and 7 pm. The trip takes 45 minutes.',
        );
        await tester.tap(find.byTooltip('Send to AI'));
        await waitFor(tester, find.text('Get credit price'));
        await tester.tap(find.text('Get credit price'));
        await waitFor(tester, find.text('Use 4 credits'));
        expect(sent.last['history'], [
          {'role': 'user', 'content': 'What time should I go to the store?'},
          {
            'role': 'assistant',
            'content': 'What time window are you free to go shopping?',
          },
        ]);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(
          sent,
          hasLength(3),
          reason: 'Canceling a price must not execute a paid request.',
        );
        if (surface == ConversationSurface.planner) {
          final contextSwitch = find.byKey(const Key('conversation-task-only'));
          await tester.ensureVisible(contextSwitch);
          await tester.tap(contextSwitch);
          await tester.pumpAndSettle();
          expect(
            find.text('What time window are you free to go shopping?'),
            findsNothing,
            reason:
                'Changing context cannot carry old private conversation into a new scope.',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final retainedView in ['assistant', 'SI console', 'local SI console']) {
    for (final pendingStage in ['capture', 'permission', 'consent']) {
      testWidgets(
        'retained $retainedView stops $pendingStage on tab deactivation',
        (tester) async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          final active = ValueNotifier(true);
          final speech = _RetainedSpeechService();
          final permission = _RetainedVoicePermission(
            pending: pendingStage == 'permission',
          );
          final consent = _RetainedVoiceConsent(
            pending: pendingStage == 'consent',
          );
          final container = setup(
            (_) async => throw StateError('Dictation must not send'),
            speechService: speech,
            voicePermission: permission,
            voiceConsent: consent,
            conversationAvailable: retainedView != 'local SI console',
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            container.dispose();
            active.dispose();
          });
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: ValueListenableBuilder<bool>(
                  valueListenable: active,
                  builder: (context, isActive, _) => MediaQuery(
                    data: const MediaQueryData(disableAnimations: true),
                    child: IndexedStack(
                      index: isActive ? 0 : 1,
                      children: [
                        if (retainedView != 'assistant')
                          SIConsoleScreen(isActive: isActive)
                        else
                          AssistantConversationScreen(
                            surface: ConversationSurface.si,
                            isActive: isActive,
                            onLocalTools: () {},
                          ),
                        const Scaffold(body: Text('Other tab')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final input = find.byKey(
            Key(
              retainedView == 'local SI console'
                  ? 'si-query-input'
                  : 'conversation-input',
            ),
          );
          if (retainedView != 'local SI console') {
            await waitForChatReady(tester);
          }
          await tester.enterText(input, 'Keep my draft');
          final mic = retainedView == 'local SI console'
              ? find.bySemanticsLabel('Start voice input')
              : find.byTooltip('Start voice input');
          await tester.ensureVisible(mic);
          await tester.tap(mic);
          await tester.pumpAndSettle();
          if (pendingStage == 'capture') {
            expect(speech.starts, 1);
            expect(speech.isListening, isTrue);
          } else {
            expect(speech.starts, 0);
          }
          final revision = container
              .read(voiceControllerProvider.notifier)
              .lifecycleRevision;
          active.value = false;
          await tester.pumpAndSettle();
          expect(speech.isListening, isFalse);
          expect(speech.stops, greaterThan(0));
          expect(
            container.read(voiceControllerProvider.notifier).lifecycleRevision,
            greaterThan(revision),
          );
          // Returning must not revive consent or permission from the old visit.
          active.value = true;
          await tester.pumpAndSettle();
          consent.release();
          permission.release();
          speech.emitLateResult('stale private audio');
          await tester.pumpAndSettle();
          expect(speech.starts, pendingStage == 'capture' ? 1 : 0);
          expect(container.read(voiceControllerProvider).isListening, isFalse);
          expect(
            tester.widget<TextField>(input).controller!.text,
            'Keep my draft',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'dictation uses the replacement voice controller after provider invalidation',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final voice = _ConversationVoiceController();
      final container = setup(
        (_) async => throw StateError('Dictation must not send'),
        voiceController: voice,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: AssistantConversationScreen(
              surface: ConversationSurface.si,
              onLocalTools: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final revision = voice.lifecycleRevision;
      container.invalidate(voiceControllerProvider);
      await tester.pumpAndSettle();
      expect(voice.lifecycleRevision, isNot(revision));

      await waitForChatReady(tester);
      await tester.tap(find.byTooltip('Start voice input'));
      await tester.pumpAndSettle();
      final agree = find.text('Agree and dictate');
      await tester.ensureVisible(agree);
      await tester.tap(agree);
      await tester.pumpAndSettle();

      expect(voice.starts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('SI publishes the safe remainder of a repaired model reply', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = setup((body) async {
      return (
        status: 200,
        data: body['quoteOnly'] == true
            ? {
                'requestId': body['requestId'],
                'quote': {
                  'credits': 4,
                  'digest': 'fixture',
                  'proof': 'fixture',
                  'policy': 'fixture',
                  'expiresAt': DateTime.now()
                      .add(const Duration(minutes: 5))
                      .millisecondsSinceEpoch,
                },
              }
            : {
                'requestId': body['requestId'],
                'message':
                    'SI has completed the comparison. '
                    'With 35 minutes, finish at 7:15 PM. '
                    'With 20 minutes, finish at 7:00 PM with zero buffer.',
                'creditsCharged': 4,
                'remainingCredits': 20,
                'model': 'transport-fixture',
              },
      );
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AssistantConversationScreen(
            surface: ConversationSurface.si,
            onLocalTools: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterChatText(tester, 'Compare the grocery timing.');
    await tester.tap(find.byTooltip('Send to AI'));
    await waitFor(tester, find.text('Get credit price'));
    await tester.tap(find.text('Get credit price'));
    await waitFor(tester, find.text('Use 4 credits'));
    await tester.tap(find.text('Use 4 credits'));
    await tester.pumpAndSettle();

    expect(find.textContaining('SI has completed'), findsNothing);
    expect(find.textContaining('finish at 7:15 PM'), findsOneWidget);
    expect(find.textContaining('finish at 7:00 PM'), findsOneWidget);
    expect(
      find.textContaining('did not pass the response check'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'paid conversation continues beyond the quote deadline and publishes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final never = Completer<({int status, Map<String, dynamic> data})>();
      final sent = <Map<String, dynamic>>[];
      final container = setup((body) async {
        sent.add(body);
        if (body['quoteOnly'] != true) return never.future;
        return (
          status: 200,
          data: <String, dynamic>{
            'requestId': body['requestId'],
            'quote': <String, dynamic>{
              'credits': 4,
              'digest': 'fixture',
              'proof': 'fixture',
              'policy': 'fixture',
              'expiresAt': DateTime.now()
                  .add(const Duration(minutes: 5))
                  .millisecondsSinceEpoch,
            },
          },
        );
      }, requestTimeout: const Duration(milliseconds: 100));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: AssistantConversationScreen(
              surface: ConversationSurface.si,
              onLocalTools: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enterChatText(tester, 'Compare my two options.');
      await tester.tap(find.byTooltip('Send to AI'));
      await waitFor(tester, find.text('Get credit price'));
      await tester.tap(find.text('Get credit price'));
      await waitFor(tester, find.text('Use 4 credits'));
      await tester.tap(find.text('Use 4 credits'));
      await tester.pump();
      expect(find.text('Stop waiting'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 101));
      await tester.pump();

      expect(find.textContaining('took too long'), findsNothing);
      expect(find.text('Stop waiting'), findsOneWidget);
      expect(sent, hasLength(2));
      never.complete((
        status: 200,
        data: <String, dynamic>{
          'requestId': sent.last['requestId'],
          'message': 'The authoritative paid reply arrived safely.',
          'model': 'synthetic-model',
          'creditsCharged': 4,
          'remainingCredits': 16,
        },
      ));
      await tester.pumpAndSettle();

      expect(
        find.text('The authoritative paid reply arrived safely.'),
        findsOneWidget,
      );
      expect(find.text('Retry same request'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quote timeout preserves the question and requires a fresh quote',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final never = Completer<({int status, Map<String, dynamic> data})>();
      final container = setup(
        (_) => never.future,
        requestTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: AssistantConversationScreen(
              surface: ConversationSurface.si,
              onLocalTools: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enterChatText(
        tester,
        'Keep this question while the quote times out.',
      );
      await tester.tap(find.byTooltip('Send to AI'));
      await waitFor(tester, find.text('Get credit price'));
      await tester.tap(find.text('Get credit price'));
      await tester.pump(const Duration(milliseconds: 101));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const Key('conversation-error')),
          matching: find.textContaining('credit price'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('No paid request was confirmed'),
        findsOneWidget,
      );
      expect(find.textContaining('fresh quote'), findsOneWidget);
      expect(find.text('Retry same request'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('conversation-input')))
            .controller!
            .text,
        'Keep this question while the quote times out.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stop waiting preserves and publishes the paid late reply', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final never = Completer<({int status, Map<String, dynamic> data})>();
    String? executedRequestId;
    final container = setup((body) async {
      if (body['quoteOnly'] != true) {
        executedRequestId = body['requestId'] as String?;
        return never.future;
      }
      return (
        status: 200,
        data: <String, dynamic>{
          'requestId': body['requestId'],
          'quote': <String, dynamic>{
            'credits': 4,
            'digest': 'fixture',
            'proof': 'fixture',
            'policy': 'fixture',
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch,
          },
        },
      );
    }, requestTimeout: const Duration(minutes: 1));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: AssistantConversationScreen(
            surface: ConversationSurface.si,
            onLocalTools: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterChatText(tester, 'Compare my two options.');
    await tester.tap(find.byTooltip('Send to AI'));
    await waitFor(tester, find.text('Get credit price'));
    await tester.tap(find.text('Get credit price'));
    await waitFor(tester, find.text('Use 4 credits'));
    await tester.tap(find.text('Use 4 credits'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('conversation-stop-waiting')));
    await tester.pump();

    expect(
      find.textContaining('paid request is still finishing safely'),
      findsOneWidget,
    );
    expect(find.text('Retry same request'), findsNothing);
    expect(find.text('Preparing your response…'), findsNothing);
    expect(tester.takeException(), isNull);
    never.complete((
      status: 200,
      data: <String, dynamic>{
        'requestId': executedRequestId,
        'message': 'The late paid response is preserved.',
        'creditsCharged': 4,
        'remainingCredits': 20,
        'model': 'transport-fixture',
      },
    ));
    await tester.pumpAndSettle();
    expect(find.text('The late paid response is preserved.'), findsOneWidget);
    expect(find.textContaining('still finishing safely'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('conversation-input')))
          .readOnly,
      isFalse,
    );
  });

  testWidgets('paid execution releases a stuck screen and keeps a late reply', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final never = Completer<({int status, Map<String, dynamic> data})>();
    String? executedRequestId;
    final container = setup((body) async {
      if (body['quoteOnly'] != true) {
        executedRequestId = body['requestId'] as String?;
        return never.future;
      }
      return (
        status: 200,
        data: <String, dynamic>{
          'requestId': body['requestId'],
          'quote': <String, dynamic>{
            'credits': 4,
            'digest': 'fixture',
            'proof': 'fixture',
            'policy': 'fixture',
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch,
          },
        },
      );
    }, paidWaitTimeout: const Duration(milliseconds: 100));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AssistantConversationScreen(
            surface: ConversationSurface.si,
            onLocalTools: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterChatText(tester, 'Compare my two options.');
    await tester.tap(find.byTooltip('Send to AI'));
    await waitFor(tester, find.text('Get credit price'));
    await tester.tap(find.text('Get credit price'));
    await waitFor(tester, find.text('Use 4 credits'));
    await tester.tap(find.text('Use 4 credits'));
    await tester.pump();
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);

    await tester.pump(const Duration(milliseconds: 101));
    await tester.pump();
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
    expect(find.text('Retry same request'), findsOneWidget);
    expect(
      find.textContaining('took too long to confirm a reply'),
      findsOneWidget,
    );

    never.complete((
      status: 200,
      data: <String, dynamic>{
        'requestId': executedRequestId,
        'message': 'The late paid response arrived.',
        'creditsCharged': 4,
        'remainingCredits': 20,
        'model': 'transport-fixture',
      },
    ));
    await tester.pumpAndSettle();
    expect(find.text('The late paid response arrived.'), findsOneWidget);
    expect(find.text('Retry same request'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('real conversation Advanced fields survive a phone keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = setup(
      (_) async => throw StateError('Must not send while editing'),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AssistantConversationScreen(
            surface: ConversationSurface.si,
            onLocalTools: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await waitForChatReady(tester);
    final advanced = find.byKey(const Key('conversation-advanced'));
    await tester.scrollUntilVisible(
      advanced,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<SIV2Intent>),
    );
    await tester.tap(find.byType(DropdownButtonFormField<SIV2Intent>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forecast').last);
    await tester.pumpAndSettle();
    final filter = find.byKey(const Key('conversation-entity-filter'));
    await tester.ensureVisible(filter);
    await tester.enterText(filter, 'Grocery');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final scenario = find.byKey(const Key('conversation-scenario'));
    await tester.ensureVisible(scenario);
    await tester.enterText(scenario, 'Delay shopping until tomorrow');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(filter).controller!.text, 'Grocery');
    expect(
      tester.widget<TextField>(scenario).controller!.text,
      contains('tomorrow'),
    );
    expect(find.text('Forecast'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'account change withholds a paid reply from the previous account',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var currentScope = scope;
      final pending = Completer<({int status, Map<String, dynamic> data})>();
      String? executedRequestId;
      final container = setup((body) async {
        if (body['quoteOnly'] != true) {
          executedRequestId = body['requestId'] as String;
          return pending.future;
        }
        return (
          status: 200,
          data: <String, dynamic>{
            'requestId': body['requestId'],
            'quote': <String, dynamic>{
              'credits': 4,
              'digest': 'fixture',
              'proof': 'fixture',
              'policy': 'fixture',
              'expiresAt': DateTime.now()
                  .add(const Duration(minutes: 5))
                  .millisecondsSinceEpoch,
            },
          },
        );
      }, readScope: () => currentScope);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: AssistantConversationScreen(
              surface: ConversationSurface.si,
              onLocalTools: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enterChatText(tester, 'Private account A question.');
      await tester.tap(find.byTooltip('Send to AI'));
      await waitFor(tester, find.text('Get credit price'));
      await tester.tap(find.text('Get credit price'));
      await waitFor(tester, find.text('Use 4 credits'));
      await tester.tap(find.text('Use 4 credits'));
      await tester.pump();
      expect(executedRequestId, isNotNull);
      currentScope = AccountStorageScope.authenticated(
        'different-paid-account',
      );
      container.invalidate(accountStorageScopeProvider);
      await tester.pumpAndSettle();
      pending.complete((
        status: 200,
        data: <String, dynamic>{
          'requestId': executedRequestId,
          'message': 'Private late response for account A.',
          'creditsCharged': 4,
          'remainingCredits': 20,
          'model': 'transport-fixture',
        },
      ));
      await tester.pumpAndSettle();
      expect(find.text('Private account A question.'), findsNothing);
      expect(find.text('Private late response for account A.'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('conversation-input')))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account change dismisses private request review and clears input',
    (tester) async {
      var currentScope = scope;
      var sent = 0;
      final container = setup((_) async {
        sent++;
        throw StateError('No request was approved');
      }, readScope: () => currentScope);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: AssistantConversationScreen(
              surface: ConversationSurface.planner,
              onLocalTools: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('How much energy do you have? (optional)'));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Not set'), findsWidgets);
      await enterChatText(tester, 'Private grocery question');
      await tester.tap(find.byTooltip('Send to AI'));
      await waitFor(tester, find.text('Get credit price'));
      currentScope = AccountStorageScope.authenticated(
        'different-review-account',
      );
      container.invalidate(accountStorageScopeProvider);
      await tester.pumpAndSettle();
      expect(find.text('Get credit price'), findsNothing);
      expect(find.text('Private grocery question'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('conversation-input')))
            .controller!
            .text,
        isEmpty,
      );
      expect(sent, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('account change cancels a free-route handoff', (tester) async {
    var currentScope = scope;
    var transportCalls = 0;
    String? handoffDraft;
    final container = setup((_) async {
      transportCalls++;
      throw StateError('No AI request was approved');
    }, readScope: () => currentScope);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AssistantConversationScreen(
            surface: ConversationSurface.si,
            onLocalTools: () {},
            onLocalToolsWithDraft: (draft) => handoffDraft = draft,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterChatText(tester, 'What are my tasks?');
    await tester.tap(find.byTooltip('Send to AI'));
    await waitFor(tester, find.text('Use free tools'));

    currentScope = AccountStorageScope.authenticated('different-local-account');
    container.invalidate(accountStorageScopeProvider);
    await tester.pumpAndSettle();
    expect(find.text('Use free tools'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('conversation-input')))
          .controller!
          .text,
      isEmpty,
    );
    expect(handoffDraft, isNull);
    expect(transportCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing the conversation closes its private review dialog', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    final container = setup(
      (_) async => throw StateError('No request approved'),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      visible.dispose();
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (context, show, child) => show
                ? AssistantConversationScreen(
                    surface: ConversationSurface.si,
                    onLocalTools: () {},
                  )
                : const Scaffold(body: Text('Different account screen')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterChatText(tester, 'Private review question');
    await tester.tap(find.byTooltip('Send to AI'));
    await waitFor(tester, find.text('Get credit price'));
    visible.value = false;
    await tester.pumpAndSettle();
    expect(find.text('Private review question'), findsNothing);
    expect(find.text('Get credit price'), findsNothing);
    expect(find.text('Different account screen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Consent extends PersonalizationProfileController {
  @override
  PersonalizationProfile build() =>
      const PersonalizationProfile(externalAiAllowed: true);
}

class _GatedChatReadBackend extends InMemorySecureStoreBackend {
  final release = Completer<void>();
  bool entered = false;
  @override
  Future<String?> read({required String key}) async {
    if (key.startsWith(AssistantConversationRepository.storageKey)) {
      entered = true;
      await release.future;
    }
    return super.read(key: key);
  }
}

class _FailingChatBackend extends InMemorySecureStoreBackend {
  bool failWrites = false;
  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrites &&
        key.startsWith(AssistantConversationRepository.storageKey)) {
      throw StateError('synthetic_local_write_failure');
    }
    return super.write(key: key, value: value);
  }
}

class _Boundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: 'synthetic-review',
    isTransitioning: false,
    isStorageReady: true,
  );
}

class _SilentVoiceService extends VoiceService {
  @override
  Future<void> stop() async {}
}

class _RetainedVoiceConsent extends VoiceInputConsentStore {
  _RetainedVoiceConsent({required bool pending})
    : gate = pending ? Completer<bool>() : null,
      super(const AccountStorageScope.unsafe());
  final Completer<bool>? gate;
  @override
  Future<bool> isApproved() async => gate == null ? true : await gate!.future;
  void release() {
    if (gate != null && !gate!.isCompleted) gate!.complete(true);
  }
}

class _RetainedVoicePermission extends VoicePermissionService {
  _RetainedVoicePermission({required bool pending})
    : gate = pending ? Completer<bool>() : null;
  final Completer<bool>? gate;
  @override
  Future<bool> requestPermission() async =>
      gate == null ? true : await gate!.future;
  void release() {
    if (gate != null && !gate!.isCompleted) gate!.complete(true);
  }
}

class _RetainedSpeechService implements SpeechRecognitionService {
  int starts = 0;
  int stops = 0;
  bool _listening = false;
  void Function(String, bool)? _result;
  @override
  bool get isListening => _listening;
  @override
  Future<bool> initialize() async => true;
  @override
  Future<void> listen({
    required void Function(String, bool) onResult,
    required void Function() onDone,
    String? localeId,
  }) async {
    starts++;
    _listening = true;
    _result = onResult;
  }

  @override
  Future<void> stop() async {
    stops++;
    _listening = false;
  }

  @override
  Future<void> cancel() => stop();
  void emitLateResult(String text) => _result?.call(text, false);
}

final class _ConversationVoiceController extends VoiceController {
  int starts = 0;
  int stops = 0;
  int revision = 0;
  String? lastLocaleId;

  @override
  int get lifecycleRevision => revision;

  @override
  VoiceState build() {
    revision++;
    ref.onDispose(() => revision++);
    return const VoiceState();
  }

  @override
  Future<void> startListening({String? localeId}) async {
    starts++;
    lastLocaleId = localeId;
    state = state.copyWith(isAvailable: true, isListening: true);
  }

  @override
  Future<void> stopListening() async {
    stops++;
    state = state.copyWith(isListening: false);
  }

  void emitTranscript(String text, {required bool listening}) {
    state = state.copyWith(isListening: listening, recognizedText: text);
  }
}

class _Tasks implements ITaskRepository {
  @override
  Future<List<TaskEntity>> getAllTasks() async => records;
  @override
  Future<TaskEntity?> getTaskById(String id) async =>
      records.where((t) => t.id == id).firstOrNull;
  @override
  Future<void> saveTask(TaskEntity task) =>
      throw StateError('Conversation must not mutate tasks');
  @override
  Future<void> deleteTask(String id) =>
      throw StateError('Conversation must not mutate tasks');
}

class _UnavailableTasks extends _Tasks {
  _UnavailableTasks(this.failure);
  final Object failure;
  int reads = 0;
  @override
  Future<List<TaskEntity>> getAllTasks() async {
    reads++;
    final error = failure;
    if (error is Error) throw error;
    if (error is Exception) throw error;
    throw StateError('Unsupported test failure');
  }
}
