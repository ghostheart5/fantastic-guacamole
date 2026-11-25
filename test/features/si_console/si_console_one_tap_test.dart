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
import 'package:fantastic_guacamole/state/providers/assistant_chat_mode_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_one_tap_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../assistant/assistant_conversation_screen_test.dart'
    show scope, setup, waitForChatReady;

// The eight one-tap questions in Chat: answered on this device, free, from the
// records the app already has. Tapping one never reaches the paid path.

const _localInput = Key('si-query-input');
const _aiInput = Key('conversation-input');

SIV2ReadGateway _gateway(String kind) {
  final DateTime now = DateTime.now();
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
    readTasks: () async => empty
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
}) {
  final _Paid counter = paid ?? _Paid();
  final ProviderContainer container = setup(
    (_) async {
      counter.calls++;
      throw StateError('A one-tap question must never reach the paid path');
    },
    readGateway: _gateway(kind),
    conversationAvailable: ai,
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
    final container = _container(kind: 'late');
    addTearDown(() => _dispose(tester, container));
    container
        .read(siOneTapRequestProvider.notifier)
        .ask(SIOneTapQuestion.planMyDay);
    expect(container.read(siOneTapRequestProvider), isNotNull);
    // A request is account scoped state: it starts empty when rebuilt.
    container.invalidate(siOneTapRequestProvider);
    expect(container.read(siOneTapRequestProvider), isNull);
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
}
