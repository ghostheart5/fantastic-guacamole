import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/features/home/ui/today_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/creator_navigation_intent_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/golden_harness.dart';

void main() {
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
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
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
          theme: appTheme,
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
          home: RepaintBoundary(key: previewKey, child: const TodayScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
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

  testWidgets('Capture the actual Today widget for visual review', (
    tester,
  ) async {
    await pumpToday(tester, height: 1050);
    await tester.pumpAndSettle();
    final boundary =
        previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final target = File('artifacts/calm-core/today-preview.png');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });
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
