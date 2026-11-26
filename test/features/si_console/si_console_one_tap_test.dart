import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_one_tap_question.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_chat_mode_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_one_tap_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../assistant/assistant_conversation_screen_test.dart'
    show enterChatText, scope, setup, waitForChatReady;

// The eight one-tap questions in Chat: answered on this device, free, from the
// records the app already has. Tapping one never reaches the paid path.

const _localInput = Key('si-query-input');
const _aiInput = Key('conversation-input');

/// The moment every test runs at; the free assistant reads this clock.
final DateTime _now = DateTime(2026, 8, 20, 12);

SIV2ReadGateway _gateway(
  String kind, {
  Future<List<TaskEntity>> Function()? slowTasks,
}) {
  final DateTime now = _now;
  final HabitEntity walk = HabitEntity(
    id: 'walk',
    title: 'Walk',
    createdAt: now.subtract(const Duration(days: 60)),
  );
  HabitOccurrenceEntity checkIn(int daysAgo) => HabitOccurrenceEntity(
    habitId: walk.id,
    occurrenceKey: RhythmPlanningContext.occurrenceKey(
      walk,
      now.subtract(Duration(days: daysAgo)),
    ),
    operationId: 'op-$daysAgo',
    outcome: HabitOccurrenceOutcome.completed,
    recordedAt: now.subtract(Duration(days: daysAgo)),
  );
  final bool empty = kind == 'empty';
  final bool late = kind == 'late';
  final bool twoGoals = kind == 'two-goals';
  return SIV2ReadGateway(
    accountScopeId: scope.v2Namespace!,
    readTasks:
        slowTasks ??
        () async => empty
            ? <TaskEntity>[]
            : <TaskEntity>[
                if (late) ...<TaskEntity>[
                  TaskEntity(
                    id: 'late1',
                    title: 'File taxes',
                    createdAt: now.subtract(const Duration(days: 30)),
                    dueDate: now.subtract(const Duration(days: 9)),
                    priority: 5,
                  ),
                  TaskEntity(
                    id: 'late2',
                    title: 'Renew passport',
                    createdAt: now.subtract(const Duration(days: 30)),
                    dueDate: now.subtract(const Duration(days: 2)),
                  ),
                ] else ...<TaskEntity>[
                  TaskEntity(
                    id: 'today',
                    title: 'Write report',
                    createdAt: now.subtract(const Duration(days: 5)),
                    dueDate: now,
                    priority: 4,
                  ),
                  TaskEntity(
                    id: 'soon',
                    title: 'Call the bank',
                    createdAt: now.subtract(const Duration(days: 5)),
                    dueDate: now.add(const Duration(days: 3)),
                  ),
                  TaskEntity(
                    id: 'linked',
                    title: 'Draft the plan',
                    goalId: 'g1',
                    createdAt: now.subtract(const Duration(days: 5)),
                  ),
                  for (int i = 0; i < 5; i++)
                    TaskEntity(
                      id: 'done$i',
                      title: 'Finished $i',
                      createdAt: now.subtract(const Duration(days: 20)),
                      isCompleted: true,
                      completedAt: now.subtract(Duration(days: i + 1)),
                      goalId: i == 0 ? 'g1' : null,
                    ),
                ],
              ],
    readGoals: () async => empty
        ? <GoalEntity>[]
        : <GoalEntity>[
            GoalEntity(
              id: 'g1',
              title: 'Launch the app',
              createdAt: now.subtract(const Duration(days: 40)),
              targetDate: now.add(const Duration(days: 20)),
            ),
            if (twoGoals)
              GoalEntity(
                id: 'g2',
                title: 'Learn Spanish',
                createdAt: now.subtract(const Duration(days: 40)),
              ),
          ],
    readMilestones: () async => [],
    readTimeline: () async => [],
    readHabits: () async => empty ? <HabitEntity>[] : <HabitEntity>[walk],
    readHabitOccurrences: () async => empty
        ? <HabitOccurrenceEntity>[]
        : <HabitOccurrenceEntity>[
            for (final int d in <int>[0, 1, 2, 4, 5, 8]) checkIn(d),
          ],
  );
}

class _Paid {
  int calls = 0;
}

ProviderContainer _container({
  String kind = 'typical',
  bool ai = false,
  bool onDevice = true,
  _Paid? paid,
  Future<List<TaskEntity>> Function()? slowTasks,
  AccountStorageScope Function()? readScope,
  Completer<void>? paidGate,
}) {
  final _Paid counter = paid ?? _Paid();
  final ProviderContainer container = setup(
    (body) async {
      if (paidGate == null) {
        counter.calls++;
        throw StateError('A one-tap question must never reach the paid path');
      }
      // A paid AI message that is deliberately running (a quote, then a held
      // reply), so a one-tap question can arrive while it is in flight.
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
              'expiresAt': 4102444800000,
            },
          },
        );
      }
      counter.calls++;
      await paidGate.future;
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
    },
    readGateway: _gateway(kind, slowTasks: slowTasks),
    conversationAvailable: ai,
    clock: () => _now.toUtc(),
    readScope: readScope,
  );
  container
      .read(assistantChatModeProvider.notifier)
      .choose(ConversationSurface.si, onDevice: onDevice);
  return container;
}

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

Future<void> _dispose(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox.shrink());
  container.dispose();
}

/// Taps a question: in the row, or in the list that opens at large text.
Future<void> _ask(WidgetTester tester, SIOneTapQuestion question) async {
  final Finder chip = find.byKey(ValueKey<String>('one-tap-${question.name}'));
  final Finder sheetButton = find.byKey(const Key('one-tap-more-sheet'));
  if (sheetButton.evaluate().isNotEmpty) {
    await tester.tap(sheetButton);
    await tester.pumpAndSettle();
    final Finder item = find.byKey(
      ValueKey<String>('one-tap-sheet-${question.name}'),
    );
    final double height =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    for (var i = 0; i < 30 && tester.getCenter(item).dy > height - 60; i++) {
      await tester.drag(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(SingleChildScrollView),
        ),
        const Offset(0, -120),
      );
      await tester.pump();
    }
    await tester.tap(item);
    await tester.pumpAndSettle();
    return;
  }
  final Finder row = find.byKey(const Key('one-tap-row-scroll'));
  if (row.evaluate().isEmpty) {
    await tester.ensureVisible(chip);
    await tester.pump();
  } else {
    await tester.ensureVisible(row);
    await tester.pump();
    // The row scrolls sideways: drag it until the question is on screen.
    final double width =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (var i = 0; i < 30 && tester.getCenter(chip).dx > width - 24; i++) {
      await tester.drag(row, const Offset(-120, 0));
      await tester.pump();
    }
  }
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// Scrolls the conversation in small steps until [target] is built and on the
/// upper half of the screen, clear of the composer over the bottom of the list.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  final double height =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final Finder keyed = find.byKey(const ValueKey<String>('si-on-device'));
  final Finder list = keyed.evaluate().isEmpty
      ? find.byType(ListView)
      : find.descendant(of: keyed, matching: find.byType(ListView));
  final ScrollableState scrollable = tester.state<ScrollableState>(
    find.descendant(of: list.first, matching: find.byType(Scrollable)).first,
  );
  final ScrollPosition position = scrollable.position;
  for (var i = 0; i < 200; i++) {
    if (target.evaluate().isNotEmpty &&
        tester.getCenter(target).dy < height * .5) {
      return;
    }
    final double next = position.pixels + 80;
    if (next > position.maxScrollExtent + 80) break;
    position.jumpTo(next.clamp(0, position.maxScrollExtent));
    await tester.pump();
  }
}

String _label(SIOneTapQuestion q, String language) =>
    q.label(isSpanish: language == 'es');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final String language in <String>['en', 'es']) {
    testWidgets(
      '$language: all eight questions are one tap away on the free assistant',
      (tester) async {
        final container = _container();
        addTearDown(() => _dispose(tester, container));
        await _pump(tester, container, language: language);
        for (final SIOneTapQuestion q in SIOneTapQuestion.values) {
          final Finder chip = find.byKey(ValueKey<String>('one-tap-${q.name}'));
          expect(chip, findsOneWidget, reason: q.name);
          expect(
            find.descendant(of: chip, matching: find.text(_label(q, language))),
            findsOneWidget,
          );
          expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
        }
      },
    );

    testWidgets(
      '$language: Plan my day is answered on the device, free, with no paid call',
      (tester) async {
        final _Paid paid = _Paid();
        final container = _container(paid: paid);
        addTearDown(() => _dispose(tester, container));
        await _pump(tester, container, language: language);
        await _ask(tester, SIOneTapQuestion.planMyDay);

        expect(find.byKey(const Key('si-v2-response')), findsOneWidget);
        expect(
          find.text(_label(SIOneTapQuestion.planMyDay, language)),
          findsWidgets,
        );
        expect(
          find.textContaining(
            language == 'es' ? 'necesita' : 'needs you today',
            findRichText: true,
          ),
          findsWidgets,
        );
        // It says plainly where and at what price it was answered.
        expect(
          tester.widget<Text>(find.byKey(const Key('one-tap-free-line'))).data,
          language == 'es'
              ? 'Respondido en este dispositivo · gratis. No se envió nada y no se usaron créditos.'
              : 'Answered on this device · free. Nothing was sent and no credits were used.',
        );
        // Plan my day is exact on the device: no paid second step.
        expect(find.byKey(const Key('one-tap-ask-ai')), findsNothing);
        expect(paid.calls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a new account still gets a useful, honest answer to every question',
    (tester) async {
      final container = _container(kind: 'empty');
      addTearDown(() => _dispose(tester, container));
      await _pump(tester, container);
      for (final SIOneTapQuestion q in SIOneTapQuestion.values) {
        await _ask(tester, q);
        expect(find.byKey(const Key('si-v2-response')).last, findsOneWidget);
        expect(
          find.textContaining('Nothing was changed', findRichText: true).last,
          findsOneWidget,
          reason: q.name,
        );
      }
      // Adding is handed to the existing review step; paid AI is not offered on
      // an empty account.
      expect(find.byKey(const Key('one-tap-add')), findsWidgets);
      expect(find.byKey(const Key('one-tap-ask-ai')), findsNothing);
    },
  );

  testWidgets('Open Add something goes to the existing review step', (
    tester,
  ) async {
    final container = _container(kind: 'empty');
    addTearDown(() => _dispose(tester, container));
    await _pump(tester, container);
    await _ask(tester, SIOneTapQuestion.planMyDay);
    await _reveal(tester, find.byKey(const Key('one-tap-add')));
    await tester.tap(find.byKey(const Key('one-tap-add')));
    await tester.pump();
    expect(container.read(appFlowProvider), AppView.creator);
  });

  testWidgets(
    'Help me reach this goal asks which goal when there are several',
    (tester) async {
      final _Paid paid = _Paid();
      final container = _container(kind: 'two-goals', paid: paid);
      addTearDown(() => _dispose(tester, container));
      await _pump(tester, container);
      await _ask(tester, SIOneTapQuestion.reachGoal);
      expect(find.text('Which goal?'), findsOneWidget);
      expect(find.byKey(const Key('si-v2-response')), findsNothing);
      await tester.tap(find.byKey(const ValueKey<String>('one-tap-goal-g1')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Goal "Launch the app"', findRichText: true),
        findsWidgets,
      );
      expect(paid.calls, 0);
    },
  );

  testWidgets(
    'Help me reach this goal answers at once with one goal and offers AI as a second step',
    (tester) async {
      final _Paid paid = _Paid();
      final container = _container(ai: true, paid: paid);
      addTearDown(() => _dispose(tester, container));
      await _pump(tester, container);
      await _ask(tester, SIOneTapQuestion.reachGoal);
      expect(find.text('Which goal?'), findsNothing);
      expect(
        find.textContaining('Goal "Launch the app"', findRichText: true),
        findsWidgets,
      );
      final Finder askAi = find.byKey(const Key('one-tap-ask-ai'));
      expect(
        find.descendant(
          of: askAi,
          matching: find.text('Ask AI · $conversationMessageCredits credits'),
        ),
        findsOneWidget,
      );
      expect(paid.calls, 0);

      // The second step only opens AI chat with the question as a draft.
      await _reveal(tester, askAi);
      await tester.tap(askAi);
      await tester.pumpAndSettle();
      await waitForChatReady(tester);
      expect(find.byKey(_localInput), findsNothing);
      expect(
        tester.widget<TextField>(find.byKey(_aiInput)).controller!.text,
        'Help me reach this goal',
      );
      expect(
        paid.calls,
        0,
        reason: 'Nothing is sent until the price is confirmed',
      );
    },
  );

  testWidgets('AI is not offered when AI chat is not available', (
    tester,
  ) async {
    final container = _container(ai: false);
    addTearDown(() => _dispose(tester, container));
    await _pump(tester, container);
    await _ask(tester, SIOneTapQuestion.improveRoutine);
    expect(find.byKey(const Key('si-v2-response')), findsOneWidget);
    expect(find.byKey(const Key('one-tap-ask-ai')), findsNothing);
  });

  testWidgets(
    'AI chat shows the same questions as suggestions, answered for free',
    (tester) async {
      final _Paid paid = _Paid();
      final container = _container(ai: true, onDevice: false, paid: paid);
      addTearDown(() => _dispose(tester, container));
      await _pump(tester, container);
      await waitForChatReady(tester);
      // The suggestions sit with the options, a little way down the page.
      await tester.scrollUntilVisible(
        find.text('Quick questions · free, answered on this device'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Quick questions · free, answered on this device'),
        findsOneWidget,
      );
      await _ask(tester, SIOneTapQuestion.fallingBehind);
      // The free assistant is shown with the answer, still no paid call.
      expect(find.byKey(_localInput), findsOneWidget);
      expect(find.byKey(const Key('si-v2-response')), findsOneWidget);
      expect(paid.calls, 0);
    },
  );

  testWidgets('a question left by Today is answered when Chat opens', (
    tester,
  ) async {
    final _Paid paid = _Paid();
    final container = _container(kind: 'late', paid: paid);
    addTearDown(() => _dispose(tester, container));
    container
        .read(siOneTapRequestProvider.notifier)
        .ask(SIOneTapQuestion.fallingBehind);
    await _pump(tester, container);
    expect(find.byKey(const Key('si-v2-response')), findsOneWidget);
    expect(
      find.textContaining('"File taxes"', findRichText: true),
      findsWidgets,
    );
    // Asked once only.
    expect(container.read(siOneTapRequestProvider), isNull);
    expect(paid.calls, 0);
  });

  testWidgets('a question waiting for another account is dropped', (
    tester,
  ) async {
    AccountStorageScope current = scope;
    final container = _container(kind: 'late', readScope: () => current);
    addTearDown(() => _dispose(tester, container));
    container
        .read(siOneTapRequestProvider.notifier)
        .ask(SIOneTapQuestion.planMyDay);
    expect(container.read(siOneTapRequestProvider), isNotNull);
    // The account changes before Chat takes the question.
    current = AccountStorageScope.authenticated('another-account');
    container.invalidate(accountStorageScopeProvider);
    expect(container.read(siOneTapRequestProvider), isNull);
    await _pump(tester, container);
    expect(find.byKey(const Key('si-v2-response')), findsNothing);
  });

  for (final String language in <String>['en', 'es']) {
    testWidgets(
      '$language: fits 320dp wide at 200% text with an answer shown',
      (tester) async {
        final container = _container(kind: 'late', ai: true);
        addTearDown(() => _dispose(tester, container));
        await _pump(
          tester,
          container,
          language: language,
          size: const Size(320, 640),
          textScale: 2,
        );
        // At large text the questions open as a list that fits the screen.
        final Finder more = find.byKey(const Key('one-tap-more-sheet'));
        expect(more, findsOneWidget);
        expect(find.byKey(const Key('one-tap-row-scroll')), findsNothing);
        expect(tester.getSize(more).height, greaterThanOrEqualTo(48));
        expect(tester.getRect(more).right, lessThanOrEqualTo(320));
        await _ask(tester, SIOneTapQuestion.getBackOnTrack);
        expect(find.byKey(const Key('si-v2-response')), findsOneWidget);
        final Finder footer = find.byKey(const Key('one-tap-footer'));
        await _reveal(tester, footer);
        expect(tester.getRect(footer).right, lessThanOrEqualTo(320.5));
        for (final Key key in const <Key>[
          Key('one-tap-ask-ai'),
          Key('one-tap-add'),
        ]) {
          final Finder button = find.byKey(key);
          if (button.evaluate().isEmpty) continue;
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(tester.getRect(button).right, lessThanOrEqualTo(320.5));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  // ---- a question that arrives, waits, or is cut short ---------------------
  Future<void> tapQuestion(WidgetTester tester, SIOneTapQuestion q) async {
    final Finder chip = find.byKey(ValueKey<String>('one-tap-${q.name}'));
    await tester.tap(chip);
    // The typing indicator animates, so step by time instead of settling.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('an account change while an answer loads gives Chat back', (
    tester,
  ) async {
    final Completer<List<TaskEntity>> gate = Completer<List<TaskEntity>>();
    AccountStorageScope current = scope;
    final container = _container(
      slowTasks: () => gate.future,
      readScope: () => current,
    );
    addTearDown(() => _dispose(tester, container));
    await _pump(tester, container);
    await tapQuestion(tester, SIOneTapQuestion.planMyDay);
    // While loading, the questions are off.
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey<String>('one-tap-planMyDay')),
          )
          .onPressed,
      isNull,
    );
    current = AccountStorageScope.authenticated('another-account');
    container.invalidate(accountStorageScopeProvider);
    await tester.pump();
    gate.complete(<TaskEntity>[]);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // The other account's answer is not shown, and Chat works again.
    expect(find.byKey(const Key('si-v2-response')), findsNothing);
    final OutlinedButton chip = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey<String>('one-tap-planMyDay')),
    );
    expect(chip.onPressed, isNotNull);
    await tapQuestion(tester, SIOneTapQuestion.planMyDay);
    expect(find.byKey(const Key('si-v2-response')), findsOneWidget);
  });

  testWidgets('a question that arrives during an answer is asked after it', (
    tester,
  ) async {
    final Completer<List<TaskEntity>> gate = Completer<List<TaskEntity>>();
    final container = _container(slowTasks: () => gate.future);
    addTearDown(() => _dispose(tester, container));
    await _pump(tester, container);
    await tapQuestion(tester, SIOneTapQuestion.planMyDay);
    container
        .read(siOneTapRequestProvider.notifier)
        .ask(SIOneTapQuestion.whatsComingUp);
    await tester.pump();
    // Not lost: it waits.
    expect(container.read(siOneTapRequestProvider), isNotNull);
    gate.complete(<TaskEntity>[]);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(container.read(siOneTapRequestProvider), isNull);
    // The newest answer is the waiting question's.
    expect(
      find.textContaining(
        'Nothing with a date is coming up',
        findRichText: true,
      ),
      findsWidgets,
    );
  });

  testWidgets('a question from Today does not interrupt a message being sent', (
    tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    final _Paid paid = _Paid();
    final container = _container(
      ai: true,
      onDevice: false,
      paid: paid,
      paidGate: gate,
    );
    addTearDown(() async {
      if (!gate.isCompleted) gate.complete();
      await _dispose(tester, container);
    });
    await _pump(tester, container);
    await enterChatText(tester, 'What should I do first?');
    await tester.tap(find.byKey(const Key('conversation-send')));
    for (var i = 0; i < 40 && find.text('Send').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('Send'));
    for (var i = 0; i < 40 && paid.calls == 0; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(paid.calls, 1);
    container
        .read(siOneTapRequestProvider.notifier)
        .ask(SIOneTapQuestion.planMyDay);
    await tester.pump();
    await tester.pump();
    expect(
      find.text('A message is being sent. Ask the question when it finishes.'),
      findsOneWidget,
    );
    // Still on AI chat, nothing asked, nothing waiting.
    expect(find.byKey(_localInput), findsNothing);
    expect(container.read(siOneTapRequestProvider), isNull);
    expect(paid.calls, 1);
  });

  testWidgets('Ask AI keeps what the person already typed in AI chat', (
    tester,
  ) async {
    final _Paid paid = _Paid();
    final container = _container(ai: true, onDevice: false, paid: paid);
    addTearDown(() => _dispose(tester, container));
    await _pump(tester, container);
    await enterChatText(tester, 'my own words');
    await tester.scrollUntilVisible(
      find.byKey(const Key('one-tap-row-scroll')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await _ask(tester, SIOneTapQuestion.reachGoal);
    // The typed words went with the person to the free assistant.
    expect(
      tester.widget<TextField>(find.byKey(_localInput)).controller!.text,
      'my own words',
    );
    final Finder askAi = find.byKey(const Key('one-tap-ask-ai'));
    await _reveal(tester, askAi);
    await tester.tap(askAi);
    await tester.pumpAndSettle();
    await waitForChatReady(tester);
    expect(
      tester.widget<TextField>(find.byKey(_aiInput)).controller!.text,
      'my own words',
    );
    expect(paid.calls, 0);
  });

  testWidgets(
    'a Today question in AI chat that is not busy answers on the device',
    (tester) async {
      final _Paid paid = _Paid();
      final container = _container(ai: true, onDevice: false, paid: paid);
      addTearDown(() => _dispose(tester, container));
      await _pump(tester, container);
      await waitForChatReady(tester);
      container
          .read(siOneTapRequestProvider.notifier)
          .ask(SIOneTapQuestion.planMyDay);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(_localInput), findsOneWidget);
      expect(find.byKey(const Key('si-v2-response')), findsOneWidget);
      expect(container.read(siOneTapRequestProvider), isNull);
      expect(paid.calls, 0);
    },
  );

  testWidgets(
    'words typed in AI chat survive a Today question and the way back',
    (tester) async {
      final _Paid paid = _Paid();
      final container = _container(ai: true, onDevice: false, paid: paid);
      addTearDown(() => _dispose(tester, container));
      await _pump(tester, container);
      await enterChatText(tester, 'words typed in AI chat');
      // The person goes to Today and taps a question; Chat answers it for free.
      container
          .read(siOneTapRequestProvider.notifier)
          .ask(SIOneTapQuestion.planMyDay);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // The words went with the person to the free assistant...
      expect(
        tester.widget<TextField>(find.byKey(_localInput)).controller!.text,
        'words typed in AI chat',
      );
      // ...and back to AI chat they are not wiped by the plain switch.
      await tester.tap(find.byKey(const Key('assistant-mode-ai')));
      await tester.pumpAndSettle();
      await waitForChatReady(tester);
      expect(
        tester.widget<TextField>(find.byKey(_aiInput)).controller!.text,
        'words typed in AI chat',
      );
      expect(paid.calls, 0);
    },
  );

  testWidgets(
    'words typed in the free box go to AI chat and are not wiped on return',
    (tester) async {
      final container = _container(ai: true, onDevice: true);
      addTearDown(() => _dispose(tester, container));
      await _pump(tester, container);
      await tester.enterText(find.byKey(_localInput), 'free words');
      await tester.tap(find.byKey(const Key('assistant-mode-ai')));
      await tester.pumpAndSettle();
      await waitForChatReady(tester);
      expect(
        tester.widget<TextField>(find.byKey(_aiInput)).controller!.text,
        'free words',
      );
      // Back to the free assistant and to AI chat again with nothing new typed:
      // an empty draft never clears the box.
      await tester.tap(find.byKey(const Key('assistant-mode-on-device')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(_localInput)).controller!.text,
        'free words',
      );
      await tester.tap(find.byKey(const Key('assistant-mode-ai')));
      await tester.pumpAndSettle();
      await waitForChatReady(tester);
      expect(
        tester.widget<TextField>(find.byKey(_aiInput)).controller!.text,
        'free words',
      );
    },
  );

  testWidgets(
    'Ask AI says whose words are in the box and which question was left out',
    (tester) async {
      final _Paid paid = _Paid();
      final container = _container(ai: true, onDevice: false, paid: paid);
      addTearDown(() => _dispose(tester, container));
      await _pump(tester, container);
      await enterChatText(tester, 'words typed in AI chat');
      container
          .read(siOneTapRequestProvider.notifier)
          .ask(SIOneTapQuestion.reachGoal);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final Finder askAi = find.byKey(const Key('one-tap-ask-ai'));
      await _reveal(tester, askAi);
      await tester.tap(askAi);
      await tester.pumpAndSettle();
      await waitForChatReady(tester);
      expect(
        tester.widget<TextField>(find.byKey(_aiInput)).controller!.text,
        'words typed in AI chat',
      );
      expect(
        find.text(
          'Your own words are in AI chat. The question "Help me reach this goal" was not added.',
        ),
        findsOneWidget,
      );
      expect(paid.calls, 0);
    },
  );

  testWidgets('words typed in AI chat arrive in the free box once', (
    tester,
  ) async {
    final container = _container(ai: true, onDevice: true);
    addTearDown(() => _dispose(tester, container));
    await _pump(tester, container);
    await tester.enterText(find.byKey(_localInput), 'free draft');
    await tester.tap(find.byKey(const Key('assistant-mode-ai')));
    await tester.pumpAndSettle();
    await waitForChatReady(tester);
    await tester.enterText(find.byKey(_aiInput), 'different words');
    await tester.scrollUntilVisible(
      find.byKey(const Key('one-tap-row-scroll')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await _ask(tester, SIOneTapQuestion.whatsComingUp);
    final String free = tester
        .widget<TextField>(find.byKey(_localInput))
        .controller!
        .text;
    expect(free, 'different words');
  });

  testWidgets(
    'a Today question that arrives during a typed answer is asked after it',
    (tester) async {
      final Completer<List<TaskEntity>> gate = Completer<List<TaskEntity>>();
      final container = _container(slowTasks: () => gate.future);
      addTearDown(() => _dispose(tester, container));
      await _pump(tester, container);
      await tester.enterText(find.byKey(_localInput), 'What should I do next?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      container
          .read(siOneTapRequestProvider.notifier)
          .ask(SIOneTapQuestion.whatsComingUp);
      await tester.pump();
      expect(container.read(siOneTapRequestProvider), isNotNull);
      gate.complete(<TaskEntity>[]);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(container.read(siOneTapRequestProvider), isNull);
      expect(find.byKey(const Key('one-tap-free-line')), findsOneWidget);
    },
  );
}
