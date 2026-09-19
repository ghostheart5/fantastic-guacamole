import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
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
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/state/providers/voice_input_consent_provider.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}) => ProviderContainer(
  overrides: [
    accountStorageScopeProvider.overrideWith(
      (ref) => readScope?.call() ?? scope,
    ),
    authSessionBoundaryProvider.overrideWith(_Boundary.new),
    assistantConversationAvailableProvider.overrideWithValue(true),
    personalizationProfileProvider.overrideWith(_Consent.new),
    conversationTransportProvider.overrideWithValue(transport),
    siV2ReadGatewayProvider.overrideWithValue(readGateway ?? gateway),
    siV2EvidenceSnapshotProvider.overrideWith(
      (ref) => (readGateway ?? gateway).read(observedAt: DateTime.now()),
    ),
    domainTaskRepositoryProvider.overrideWithValue(taskRepository ?? _Tasks()),
    if (humanContext != null)
      consentedHumanContextProvider.overrideWithValue(humanContext),
    selectedPlanningNoteProvider.overrideWith(
      (ref) async => NoteEntity(
        id: 'list-note',
        title: 'Dinner shopping',
        body: 'Check the pantry before buying rice.',
        createdAt: DateTime(2026, 9, 16),
        taskId: 'grocery',
      ),
    ),
    if (voiceController != null)
      voiceInputEnabledProvider.overrideWithValue(true),
    if (voiceController != null)
      voiceControllerProvider.overrideWith(() => voiceController),
    if (voiceController != null)
      voiceInputConsentStoreProvider.overrideWithValue(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
        await tester.tap(
          find.text(planner ? 'Energy for this request' : 'Advanced analysis'),
        );
        await tester.pumpAndSettle();
        final label = tester.renderObject<RenderBox>(
          find.text(planner ? 'Energy (optional)' : 'Analysis mode'),
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
    expect(context['unavailableSources'], contains('tasks'));
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
    expect(context['goals'], isEmpty);
  });

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
        await tester.enterText(
          find.byKey(const Key('conversation-input')),
          'Groceries',
        );
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
        await tester.enterText(
          find.byKey(const Key('conversation-input')),
          'What time should I go to the store?',
        );
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
        await tester.enterText(
          find.byKey(const Key('conversation-input')),
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
    await tester.enterText(
      find.byKey(const Key('conversation-input')),
      'Compare the grocery timing.',
    );
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
    await tester.tap(find.text('Advanced analysis'));
    await tester.pumpAndSettle();
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
      await tester.tap(find.text('Energy for this request'));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Not set'), findsWidgets);
      await tester.enterText(
        find.byKey(const Key('conversation-input')),
        'Private grocery question',
      );
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
    await tester.enterText(
      find.byKey(const Key('conversation-input')),
      'Private review question',
    );
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

class _Boundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: 'synthetic-review',
    isTransitioning: false,
    isStorageReady: true,
  );
}

final class _ConversationVoiceController extends VoiceController {
  int starts = 0;
  int stops = 0;
  int revision = 0;

  @override
  int get lifecycleRevision => revision;

  @override
  VoiceState build() {
    revision++;
    ref.onDispose(() => revision++);
    return const VoiceState();
  }

  @override
  Future<void> startListening() async {
    starts++;
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
