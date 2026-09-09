import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/features/goals/ui/goals_screen.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fantastic_guacamole/state/models/goal_progress_view.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

void main() {
  for (final es in [false, true]) {
    testWidgets(
      '${es ? 'Spanish' : 'English'} unavailable goals show a recoverable error',
      (tester) async {
        var failed = true;
        final container = ProviderContainer(
          overrides: [
            goalsProvider.overrideWith(_GoalsNotifier.new),
            goalsReadProvider.overrideWith(
              (ref) => failed
                  ? AsyncError(StateError('unavailable'), StackTrace.current)
                  : const AsyncData(<GoalEntity>[]),
            ),
            goalProgressProvider(
              'release',
            ).overrideWith((ref) async => const GoalProgressView.empty()),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(_testApp(container, es));
        await tester.pump();
        expect(
          find.text(
            es
                ? 'No se pueden leer tus metas. Los datos existentes se conservaron.'
                : 'Your goals could not be read. Existing data was preserved.',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Add goal',
                ),
              )
              .onPressed,
          isNull,
        );
        expect(find.text('Ship the first release'), findsNothing);
        failed = false;
        await tester.tap(find.text(es ? 'Reintentar' : 'Retry'));
        await tester.pumpAndSettle();
        expect(find.text('Ship the first release'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${es ? 'Spanish' : 'English'} progress distinguishes loading, error and recovery',
      (tester) async {
        var read = Completer<GoalProgressView>();
        final container = ProviderContainer(
          overrides: [
            goalsProvider.overrideWith(_GoalsNotifier.new),
            goalsReadProvider.overrideWithValue(
              const AsyncData(<GoalEntity>[]),
            ),
            goalProgressProvider('release').overrideWith((ref) => read.future),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(_testApp(container, es));
        await tester.pump();
        expect(
          find.text(es ? 'Cargando progreso…' : 'Loading progress…'),
          findsOneWidget,
        );
        expect(
          find.textContaining(es ? 'acciones únicas' : 'one-time actions'),
          findsNothing,
        );
        read.completeError(StateError('task data unavailable'));
        await tester.pumpAndSettle();
        final retry = es
            ? 'Progreso no disponible. Reintentar'
            : 'Progress unavailable. Retry';
        expect(find.text(retry), findsOneWidget);
        read = Completer<GoalProgressView>();
        await tester.tap(find.text(retry));
        await tester.pump();
        final now = DateTime.utc(2026, 9, 8);
        read.complete(
          GoalProgressView.fromTasks([
            TaskEntity(
              id: 'done',
              title: 'Done',
              goalId: 'release',
              createdAt: now,
              isCompleted: true,
            ),
            TaskEntity(
              id: 'canceled',
              title: 'Canceled',
              goalId: 'release',
              createdAt: now,
              isCanceled: true,
            ),
          ]),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(es ? '1 de 1 acciones únicas' : '1 of 1 one-time actions'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'canceling a focused goal sheet during keyboard close preserves goals',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetViewInsets);
      final ProviderContainer container = ProviderContainer(
        overrides: [goalsProvider.overrideWith(_GoalsNotifier.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GoalsScreen()),
        ),
      );
      await tester.tap(find.byTooltip('Add goal'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Goal title',
        ),
        'Unsaved test goal',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.binding.handlePopRoute();
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('Unsaved test goal'), findsNothing);
      expect(container.read(goalsProvider).single.id, 'release');
    },
  );

  testWidgets('renders the active goal list', (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    final ProviderContainer container = ProviderContainer(
      overrides: [goalsProvider.overrideWith(_GoalsNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GoalsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('GOALS'), findsOneWidget);
    expect(find.text('Ship the first release'), findsOneWidget);
    expect(find.bySemanticsLabel('Ship the first release'), findsOneWidget);
    expect(
      find.byTooltip('Share goal: Ship the first release'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Expand goal details: Ship the first release'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}

Widget _testApp(ProviderContainer container, bool es) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(es ? 'es' : 'en'),
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const GoalsScreen(),
      ),
    );

class _GoalsNotifier extends GoalsNotifier {
  @override
  List<GoalEntity> build() => <GoalEntity>[
    GoalEntity(
      id: 'release',
      title: 'Ship the first release',
      createdAt: DateTime.utc(2026, 8, 1),
      targetDate: DateTime.utc(2026, 9, 1),
    ),
  ];
}
