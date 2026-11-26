import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/si_one_tap_question.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/state/providers/si_one_tap_provider.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/features/assistant/ui/one_tap_questions.dart';
import 'package:fantastic_guacamole/features/home/ui/today_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/l10n/insights_copy.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/creator_navigation_intent_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/golden_harness.dart';

void main() {
  const todayQuestions = todayOneTapQuestions;
  setUpAll(loadAppFontsForGolden);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final previewKey = GlobalKey();

  Future<ProviderContainer> pumpToday(
    WidgetTester tester, {
    double width = 390,
    double height = 1100,
    double scale = 1,
    Locale locale = const Locale('en'),
    Future<List<Task>> Function()? load,
    Future<void> Function(String)? complete,
    ThemeData? theme,
    List<Override> extraOverrides = const [],
    Widget? home,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        ...extraOverrides,
        domainTaskRepositoryProvider.overrideWithValue(_EmptyTaskRepository()),
        creatorHandshakeProvider.overrideWith(_PreviousSave.new),
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('today-test'),
        ),
        allTasksProvider.overrideWith(
          (ref) =>
              load?.call() ??
              Future.value([
                Task(
                  priority: 3,
                  difficulty: 3,
                  energyRequired: 3,
                  id: 'one',
                  title: 'Take a short walk',
                  estimatedDuration: const Duration(minutes: 10),
                ),
              ]),
        ),
        taskActionsProvider.overrideWith(
          (ref) => _Actions(ref, complete ?? (_) async {}),
        ),
      ],
    );
    addTearDown(container.dispose);
    final boundary = container.read(authSessionBoundaryProvider.notifier);
    final generation = boundary.begin(
      userId: 'today-test',
      isTransitioning: true,
    );
    boundary.complete(generation);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? appTheme,
          locale: locale,
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: const [
            ChronoSparkLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home:
              home ??
              RepaintBoundary(key: previewKey, child: const TodayScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  for (final dark in [true, false]) {
    testWidgets('Today artwork text stays readable with dark forms=$dark', (
      tester,
    ) async {
      final theme = dark ? appTheme : appLightTheme;
      var completions = 0;
      await pumpToday(
        tester,
        theme: theme,
        complete: (_) async {
          completions++;
        },
      );
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
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

      final background = tester
          .widget<Scaffold>(find.byType(Scaffold))
          .backgroundColor!;
      for (final label in [
        'Today',
        'One thing at a time.',
        'Add what matters. Take a step when you’re ready.',
        'A place to start',
      ]) {
        final text = tester.renderObject<RenderParagraph>(find.text(label));
        expect(
          contrast(text.text.style!.color!, background),
          greaterThanOrEqualTo(4.5),
        );
      }
      final task = find.text('Take a short walk');
      final taskText = tester.renderObject<RenderParagraph>(task);
      final card = tester.widget<Card>(
        find.ancestor(of: task, matching: find.byType(Card)).first,
      );
      final surface = Color.alphaBlend(
        card.color ?? theme.cardTheme.color!,
        background,
      );
      expect(
        contrast(taskText.text.style!.color!, surface),
        greaterThanOrEqualTo(4.5),
      );
      for (final icon in [
        Icons.notifications_outlined,
        Icons.settings_outlined,
      ]) {
        final target = find.byIcon(icon);
        final color =
            tester.widget<Icon>(target).color ??
            IconTheme.of(tester.element(target)).color!;
        expect(contrast(color, background), greaterThanOrEqualTo(3));
      }
      expect(
        Theme.of(tester.element(find.byType(TodayScreen))).brightness,
        theme.brightness,
      );
      expect(completions, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final kind in CreatorFormKind.values) {
    testWidgets('Add ${kind.name} opens the correct existing form', (
      tester,
    ) async {
      final container = await pumpToday(tester);
      await tester.tap(find.byKey(const Key('today-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('today-add-${kind.name}')));
      await tester.pumpAndSettle();
      expect(container.read(creatorNavigationIntentProvider), kind);
      expect(container.read(creatorHandshakeProvider).receipt, isNull);
      expect(
        container.read(creatorHandshakeProvider).phase,
        CreatorHandshakePhase.idle,
      );
      expect(container.read(appFlowProvider), AppView.creator);
      expect(
        container
            .read(adaptiveGuidanceProvider)
            .asData!
            .value
            .guidesCreatorTask,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Home keeps three current tasks and links to the full plan', (
    tester,
  ) async {
    final tomorrow = DateTime.now().add(const Duration(days: 2));
    await pumpToday(
      tester,
      load: () async => [
        for (int n = 0; n < 6; n++)
          Task(
            priority: 3,
            difficulty: 3,
            energyRequired: 3,
            id: '$n',
            title: 'Task $n',
          ),
        Task(
          priority: 3,
          difficulty: 3,
          energyRequired: 3,
          id: 'later',
          title: 'Future appointment',
          scheduledFor: tomorrow,
        ),
        Task(
          priority: 3,
          difficulty: 3,
          energyRequired: 3,
          id: 'done',
          title: 'Already done',
          isCompleted: true,
        ),
      ],
    );
    expect(find.byKey(const ValueKey('today-task-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-task-2')), findsOneWidget);
    expect(find.text('Task 3'), findsNothing);
    expect(find.text('Future appointment'), findsNothing);
    expect(find.text('Already done'), findsNothing);
    expect(find.text('See my full plan'), findsOneWidget);
    expect(find.text('PRESSURE'), findsNothing);
    expect(find.text('ENERGY'), findsNothing);
    expect(find.textContaining('streak'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Empty Today distinguishes completed work from future tasks', (
    tester,
  ) async {
    for (final locale in [const Locale('en'), const Locale('es')]) {
      await pumpToday(
        tester,
        locale: locale,
        load: () async => [
          Task(
            id: 'finished',
            title: 'Finished task',
            isCompleted: true,
            priority: 3,
            difficulty: 3,
            energyRequired: 3,
          ),
        ],
      );
      expect(
        find.textContaining(
          locale.languageCode == 'en'
              ? 'No tasks waiting right now.'
              : 'No hay tareas pendientes ahora.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Your scheduled tasks are ahead'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
    // The shipping active-task provider returns an empty list after completion.
    await pumpToday(tester, load: () async => []);
    expect(find.textContaining('No tasks waiting right now.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpToday(
      tester,
      load: () async => [
        Task(
          id: 'future',
          title: 'Later task',
          scheduledFor: DateTime.now().add(const Duration(days: 2)),
          priority: 3,
          difficulty: 3,
          energyRequired: 3,
        ),
      ],
    );
    expect(
      find.textContaining('Your scheduled tasks are ahead'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language: the Insights card reads its names from InsightsCopy',
      (tester) async {
        await pumpToday(tester, locale: Locale(language));
        final InsightsCopy copy = InsightsCopy(language == 'es');
        final card = find.byKey(const Key('today-insights'));
        await tester.ensureVisible(card);
        expect(
          find.descendant(of: card, matching: find.text(copy.todayCardTitle)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text(copy.todayCardSubtitle),
          ),
          findsOneWidget,
        );
        // The retired two-name title is gone.
        expect(find.text('Patterns & future outcomes'), findsNothing);
        expect(find.text('Patrones y resultados futuros'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('Chat and insights retain their canonical destinations', (
    tester,
  ) async {
    final container = await pumpToday(tester);
    for (final entry in [
      (const Key('today-chat'), AppView.console),
      (const Key('today-insights'), AppView.trajectoryEngine),
    ]) {
      await tester.ensureVisible(find.byKey(entry.$1));
      await tester.tap(find.byKey(entry.$1));
      await tester.pump();
      expect(container.read(appFlowProvider), entry.$2);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final language in ['en', 'es']) {
    testWidgets(
      '$language: quick questions on Today open Chat on the free assistant',
      (tester) async {
        final container = await pumpToday(tester, locale: Locale(language));
        for (final question in todayQuestions) {
          expect(
            find.text(question.label(isSpanish: language == 'es')),
            findsOneWidget,
          );
          expect(
            tester
                .getSize(find.byKey(ValueKey('one-tap-${question.name}')))
                .height,
            greaterThanOrEqualTo(48),
          );
        }
        expect(container.read(appFlowProvider), isNot(AppView.console));
        await tester.tap(find.byKey(const ValueKey('one-tap-planMyDay')));
        await tester.pump();
        // One tap: the question is waiting and Chat is open. Chat chooses the
        // free assistant when it takes the question.
        expect(
          container.read(siOneTapRequestProvider)?.question,
          SIOneTapQuestion.planMyDay,
        );
        expect(container.read(appFlowProvider), AppView.console);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final language in ['en', 'es']) {
    testWidgets('$language: the question row fits 320dp wide at 200% text', (
      tester,
    ) async {
      await pumpToday(
        tester,
        width: 320,
        height: 1400,
        scale: 2,
        locale: Locale(language),
      );
      for (final question in todayQuestions) {
        final button = find.byKey(ValueKey('one-tap-${question.name}'));
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        expect(tester.getRect(button).right, lessThanOrEqualTo(320));
      }
      final more = find.byKey(const Key('today-one-tap-more'));
      expect(tester.getRect(more).right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('More questions opens Chat without asking anything', (
    tester,
  ) async {
    final container = await pumpToday(tester);
    await tester.tap(find.byKey(const Key('today-one-tap-more')));
    await tester.pump();
    expect(container.read(appFlowProvider), AppView.console);
    expect(container.read(siOneTapRequestProvider), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('one tap on Today reaches an answer in Chat, free', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 20, 12);
    final snapshot = SIV2EvidenceSnapshot(
      accountScopeId: 'account:today-test',
      observedAt: now.toUtc(),
      tasks: [
        SIV2TaskEvidence(
          id: 'a',
          title: 'Take a short walk',
          createdAt: now.subtract(const Duration(days: 3)).toUtc(),
          priority: 3,
          dueDate: now.toUtc(),
        ),
      ],
      goals: const [],
      milestones: const [],
      timeline: const [],
    );
    var reads = 0;
    final container = await pumpToday(
      tester,
      extraOverrides: [
        siV2AvailabilityProvider.overrideWith((ref) async => true),
        siV2EvidenceSnapshotProvider.overrideWith((ref) async => snapshot),
        siV2PersonContextRevisionProvider.overrideWithValue('revision'),
        siOneTapServiceProvider.overrideWithValue(
          SIOneTapService(
            readEvidence: (_) async {
              reads++;
              return snapshot;
            },
            clock: () => now.toUtc(),
          ),
        ),
      ],
      home: Consumer(
        builder: (context, ref, _) =>
            ref.watch(appFlowProvider) == AppView.console
            ? const SIConsoleScreen()
            : const TodayScreen(),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('one-tap-planMyDay')));
    // The console animates its background, so settle by time, not by idle.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(container.read(appFlowProvider), AppView.console);
    expect(find.byKey(const Key('si-v2-response')), findsOneWidget);
    expect(
      find.textContaining('Take a short walk', findRichText: true),
      findsWidgets,
    );
    expect(find.byKey(const Key('one-tap-free-line')), findsOneWidget);
    expect(reads, 1);
    expect(container.read(siOneTapRequestProvider), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Loading and failed reads are never presented as an empty plan', (
    tester,
  ) async {
    final pending = Completer<List<Task>>();
    await pumpToday(tester, load: () => pending.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('No tasks waiting right now'), findsNothing);
    pending.completeError(StateError('fixture read failure'));
    await tester.pump();
    expect(find.textContaining('Your tasks could not load'), findsOneWidget);
    expect(find.textContaining('No tasks waiting right now'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Completion waits for success and ignores repeat taps', (
    tester,
  ) async {
    final pending = Completer<void>();
    int calls = 0;
    await pumpToday(
      tester,
      complete: (_) {
        calls++;
        return pending.future;
      },
    );
    final complete = find.byKey(const ValueKey('today-complete-one'));
    await tester.tap(complete);
    await tester.pump();
    await tester.tap(complete);
    expect(calls, 1);
    expect(find.text('Completed. Your progress is recorded.'), findsNothing);
    pending.complete();
    await tester.pump();
    expect(find.text('Completed. Your progress is recorded.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final action in ['complete', 'open']) {
    testWidgets('Using the suggested step ($action) finishes the Today lesson; '
        'opening Today does not', (tester) async {
      final container = await pumpToday(tester);
      await container.read(adaptiveGuidanceProvider.future);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        container
            .read(adaptiveGuidanceProvider)
            .requireValue
            .has(GuidanceMilestone.firstNexusReview),
        isFalse,
      );
      await tester.tap(
        action == 'complete'
            ? find.byKey(const ValueKey('today-complete-one'))
            : find.byKey(const ValueKey('today-task-one')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final guidance = container.read(adaptiveGuidanceProvider).requireValue;
      expect(guidance.has(GuidanceMilestone.firstNexusReview), isTrue);
      expect(guidance.completedLessons, contains(GuidanceLessonId.nexus));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Failed completion keeps the task and offers a retry', (
    tester,
  ) async {
    await pumpToday(
      tester,
      complete: (_) async => throw StateError('fixture write failure'),
    );
    await tester.tap(find.byKey(const ValueKey('today-complete-one')));
    await tester.pump();
    expect(
      find.text('Could not complete this task. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Take a short walk'), findsOneWidget);
    expect(find.text('Completed. Your progress is recorded.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Account change suppresses the previous account completion result',
    (tester) async {
      final pending = Completer<void>();
      final container = await pumpToday(
        tester,
        complete: (_) => pending.future,
      );
      await tester.tap(find.byKey(const ValueKey('today-complete-one')));
      await tester.pump();
      container
          .read(authSessionBoundaryProvider.notifier)
          .begin(userId: 'another', isTransitioning: true);
      pending.complete();
      await tester.pump();
      expect(find.text('Completed. Your progress is recorded.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final locale in [const Locale('en'), const Locale('es')]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Today fits 320dp ${locale.languageCode} at $scale text', (
        tester,
      ) async {
        await pumpToday(
          tester,
          width: 320,
          height: 640,
          scale: scale,
          locale: locale,
        );
        final insights = find.byKey(const Key('today-insights'));
        await tester.scrollUntilVisible(insights, 180);
        expect(insights, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'Today renders a reviewable image without changing source files',
    (tester) async {
      await pumpToday(tester, height: 1050);
      await tester.pumpAndSettle();
      final boundary =
          previewKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        expect(bytes, isNotNull);
        expect(bytes!.buffer.asUint8List().take(8), [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ]);
        expect(image.width, greaterThan(0));
        expect(image.height, greaterThan(0));
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Actions extends TaskActions {
  _Actions(super.ref, this.onComplete);
  final Future<void> Function(String) onComplete;
  @override
  Future<void> completeTask(String id, {bool notify = true}) => onComplete(id);
}

class _EmptyTaskRepository implements ITaskRepository {
  @override
  Future<List<TaskEntity>> getAllTasks() async => [];
  @override
  Future<TaskEntity?> getTaskById(String id) async => null;
  @override
  Future<void> saveTask(TaskEntity task) async =>
      throw UnsupportedError('read-only fixture');
  @override
  Future<void> deleteTask(String id) async =>
      throw UnsupportedError('read-only fixture');
}

class _PreviousSave extends CreatorHandshakeNotifier {
  @override
  CreatorHandshakeState build() => CreatorHandshakeState(
    phase: CreatorHandshakePhase.applied,
    receipt: CreatorHandshakeReceipt(
      proposalId: 'previous-save',
      accountScopeId: AccountStorageScope.authenticated(
        'today-test',
      ).v2Namespace!,
      confirmationTokenId: 'previous-token',
      appliedOperationIds: const ['previous-operation'],
      taskIds: const ['previous-task'],
      appliedAt: DateTime.utc(2026, 10, 20),
      undoExpiresAt: DateTime.utc(2026, 10, 20, 0, 10),
      resultingDomainRevision: 'previous-revision',
    ),
  );
}
