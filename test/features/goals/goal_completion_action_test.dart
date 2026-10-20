import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/features/goals/ui/goals_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/models/goal_progress_view.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = 'goal-completion-qa';
const _button = ValueKey('complete-goal-release');

void main() {
  for (final es in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'visible goal completion with no linked tasks: es=$es scale=$scale',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            await tester.binding.setSurfaceSize(const Size(360, 640));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final notifier = _CompletingGoals();
            final container = _container(notifier);
            addTearDown(container.dispose);
            await tester.pumpWidget(_app(container, es: es, scale: scale));
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.byKey(_button),
              240,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(
              find.byKey(_button).hitTestable(),
              findsOneWidget,
              reason:
                  'button=${tester.getRect(find.byKey(_button))}; list=${tester.getRect(find.byType(CustomScrollView))}',
            );
            expect(
              find.bySemanticsLabel(
                es
                    ? 'Marcar meta como completada: Finish the goal'
                    : 'Mark goal complete: Finish the goal',
              ),
              findsOneWidget,
            );
            await tester.tap(find.byKey(_button));
            await tester.pumpAndSettle();
            expect(notifier.completedIds, ['release']);
            expect(container.read(goalsProvider), isEmpty);
            expect(find.text('Finish the goal'), findsNothing);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  testWidgets('pending button and swipe share one guarded completion', (
    tester,
  ) async {
    final notifier = _CompletingGoals()..gate = Completer<void>();
    final container = _container(notifier);
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    final callback = tester
        .widget<OutlinedButton>(find.byKey(_button))
        .onPressed!;
    final manage = tester
        .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>))
        .onSelected!;
    callback();
    callback();
    manage('edit');
    manage('delete');
    final swipe = tester
        .widget<Dismissible>(find.byType(Dismissible))
        .confirmDismiss!;
    expect(await swipe(DismissDirection.endToStart), isFalse);
    expect(notifier.completedIds, ['release']);
    await tester.pump();
    expect(
      tester.widget<OutlinedButton>(find.byKey(_button)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>))
          .enabled,
      isFalse,
    );
    expect(find.byType(AlertDialog), findsNothing);
    notifier.gate!.complete();
    await tester.pumpAndSettle();
    expect(container.read(goalsProvider), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed completion retains the goal and enables a deliberate retry',
    (tester) async {
      final notifier = _CompletingGoals()..fail = true;
      final container = _container(notifier);
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(container.read(goalsProvider).single.id, 'release');
      expect(
        find.text('Goal could not be completed. Please try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<OutlinedButton>(find.byKey(_button)).onPressed,
        isNotNull,
      );
      notifier.fail = false;
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(notifier.completedIds, ['release', 'release']);
      expect(container.read(goalsProvider), isEmpty);
    },
  );

  testWidgets(
    'durable completion warning survives card removal without a false retry',
    (tester) async {
      final notifier = _CompletingGoals()
        ..gate = Completer<void>()
        ..removeBeforeGate = true
        ..warn = true;
      final container = _container(notifier);
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(find.byKey(_button), findsNothing);
      notifier.gate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Goal completed. Some reminders or activity updates could not finish.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Goal could not be completed. Please try again.'),
        findsNothing,
      );
      expect(notifier.completedIds, ['release']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'account generation change suppresses stale completion feedback: failure=$fails',
      (tester) async {
        final notifier = _CompletingGoals()
          ..gate = Completer<void>()
          ..fail = fails
          ..warn = true;
        final container = _container(notifier);
        addTearDown(container.dispose);
        await tester.pumpWidget(_app(container));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_button));
        final boundary = container.read(authSessionBoundaryProvider.notifier);
        final generation = boundary.begin(userId: _user, isTransitioning: true);
        boundary.complete(generation);
        notifier.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(notifier.completedIds, ['release']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final blocked in [false, true]) {
    testWidgets(
      'unready or blocked account cannot activate goal completion: blocked=$blocked',
      (tester) async {
        final notifier = _CompletingGoals();
        final container = _container(notifier);
        addTearDown(container.dispose);
        final boundary = container.read(authSessionBoundaryProvider.notifier);
        final generation = boundary.begin(userId: _user, isTransitioning: true);
        if (blocked) boundary.block(generation, issue: 'Storage unavailable');
        await tester.pumpWidget(_app(container));
        await tester.pumpAndSettle();
        expect(
          tester.widget<OutlinedButton>(find.byKey(_button)).onPressed,
          isNull,
        );
        expect(
          tester.widget<Dismissible>(find.byType(Dismissible)).direction,
          DismissDirection.none,
        );
        expect(notifier.completedIds, isEmpty);
      },
    );
  }
}

ProviderContainer _container(_CompletingGoals notifier) => ProviderContainer(
  overrides: [
    goalsProvider.overrideWith(() => notifier),
    goalsReadProvider.overrideWithValue(const AsyncData(<GoalEntity>[])),
    goalProgressProvider(
      'release',
    ).overrideWith((ref) async => const GoalProgressView.empty()),
    accountStorageScopeProvider.overrideWithValue(
      AccountStorageScope.authenticated(_user),
    ),
    authSessionBoundaryProvider.overrideWith(_ReadyBoundary.new),
  ],
);

Widget _app(ProviderContainer container, {bool es = false, double scale = 1}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(es ? 'es' : 'en'),
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: const [
          ChronoSparkLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: const GoalsScreen(),
      ),
    );

class _ReadyBoundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: _user,
    isTransitioning: false,
    isStorageReady: true,
  );
}

class _CompletingGoals extends GoalsNotifier {
  final completedIds = <String>[];
  Completer<void>? gate;
  bool fail = false;
  bool warn = false;
  bool removeBeforeGate = false;
  @override
  List<GoalEntity> build() => [
    GoalEntity(
      id: 'release',
      title: 'Finish the goal',
      createdAt: DateTime.utc(2026, 10, 20),
      targetDate: DateTime.utc(2026, 12, 25),
    ),
  ];
  @override
  Future<GoalMutationResult> complete(String id) async {
    completedIds.add(id);
    if (removeBeforeGate) state = [];
    await gate?.future;
    if (fail) throw StateError('Completion failed before saving');
    state = [];
    return GoalMutationResult(warnings: warn ? ['reminders'] : []);
  }
}
