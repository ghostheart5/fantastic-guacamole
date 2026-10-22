import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/features/goals/ui/goals_screen.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fantastic_guacamole/state/models/goal_progress_view.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

void main() {
  for (final light in [false, true]) {
    testWidgets(
      'new goal fields and date picker use ${light ? 'Light' : 'Dark'} forms',
      (tester) async {
        final previousFatal = WidgetController.hitTestWarningShouldBeFatal;
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(
          () => WidgetController.hitTestWarningShouldBeFatal = previousFatal,
        );
        await tester.binding.setSurfaceSize(const Size(1000, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final goals = _SavedWithWarning();
        final container = ProviderContainer(
          overrides: [goalsProvider.overrideWith(() => goals)],
        );
        addTearDown(container.dispose);
        final selectedTheme = light ? appLightTheme : appTheme;
        await tester.pumpWidget(
          _testApp(container, false, theme: selectedTheme),
        );
        await tester.pump();
        final stored = container.read(goalsProvider).single;
        await _revealGoalControl(tester, find.byTooltip('Add goal'));
        await tester.tap(find.byTooltip('Add goal').hitTestable());
        await tester.pumpAndSettle();
        for (final hint in ['Goal title', 'Description (optional)']) {
          final field = find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.hintText == hint,
          );
          await _revealGoalControl(tester, field);
          final inputFinder = find.descendant(
            of: field,
            matching: find.byType(InputDecorator),
          );
          final input = tester.widget<InputDecorator>(inputFinder);
          final fill = input.decoration.fillColor!;
          expect(
            Theme.of(tester.element(field)).brightness,
            selectedTheme.brightness,
          );
          expect(fill, selectedTheme.inputDecorationTheme.fillColor);
          final hintParagraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: field, matching: find.byType(RichText)).first,
          );
          expect(
            _contrast(hintParagraph.text.style!.color!, fill),
            greaterThanOrEqualTo(4.5),
          );
          await tester.enterText(
            field,
            hint == 'Goal title'
                ? 'Unsaved contrast title'
                : 'Unsaved contrast description',
          );
          await tester.pump();
          final editable = tester.widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          );
          expect(
            _contrast(editable.style.color!, fill),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            tester.widget<InputDecorator>(inputFinder).decoration.focusedBorder,
            selectedTheme.inputDecorationTheme.focusedBorder,
          );
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.testTextInput.hide();
        await tester.pumpAndSettle();
        final date = find.text('Set target date (optional)');
        await _revealGoalControl(tester, date);
        await tester.tap(date.hitTestable());
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        final pickerContext = tester.element(find.byType(DatePickerDialog));
        final pickerTheme = Theme.of(pickerContext);
        expect(pickerTheme.brightness, selectedTheme.brightness);
        expect(
          pickerTheme.colorScheme.primary,
          selectedTheme.colorScheme.primary,
        );
        expect(
          _contrast(
            pickerTheme.colorScheme.onPrimary,
            pickerTheme.colorScheme.primary,
          ),
          greaterThanOrEqualTo(4.5),
        );
        final pickerCancel = find.text('Cancel');
        await _revealGoalControl(tester, pickerCancel);
        await tester.tap(pickerCancel.hitTestable());
        await tester.pumpAndSettle();
        final cancel = find.text('CANCEL');
        await _revealGoalControl(tester, cancel);
        final material = tester
            .element(cancel)
            .findAncestorWidgetOfExactType<Material>()!;
        final text = tester.renderObject<RenderParagraph>(
          find.descendant(of: cancel, matching: find.byType(RichText)).first,
        );
        // Light form buttons use their white fill with a dark theme foreground.
        // Dark buttons have transparent fill over the retained dark sheet.
        final background = material.color == null || material.color!.a == 0
            ? const Color(0xFF081426)
            : material.color!;
        expect(
          _contrast(text.text.style!.color!, background),
          greaterThanOrEqualTo(4.5),
        );
        await tester.tap(cancel.hitTestable());
        await tester.pumpAndSettle();
        expect(goals.saves, 0);
        expect(container.read(goalsProvider).single, same(stored));
        expect(find.text('Unsaved contrast title'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final save in [false, true]) {
    testWidgets('focused goal edit closes safely; save=$save', (tester) async {
      final notifier = _EditedGoals();
      final container = ProviderContainer(
        overrides: [
          goalsProvider.overrideWith(() => notifier),
          goalsReadProvider.overrideWithValue(const AsyncData(<GoalEntity>[])),
          goalProgressProvider(
            'release',
          ).overrideWith((ref) async => const GoalProgressView.empty()),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        _testApp(container, false, disableAnimations: false),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('Manage goal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Edit goal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(
        find.byKey(const Key('edit-goal-description')),
        'QA revised description',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 120);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(save ? 'Save' : 'Cancel'));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(notifier.updates, save ? 1 : 0);
      expect(container.read(goalsProvider).single.id, 'release');
      expect(
        container.read(goalsProvider).single.description,
        save ? 'QA revised description' : null,
      );
      expect(find.byKey(const Key('edit-goal-description')), findsNothing);
    });
  }
  testWidgets(
    'durable save warning closes the form instead of inviting a duplicate retry',
    (tester) async {
      final notifier = _SavedWithWarning()..saveGate = Completer<void>();
      final container = ProviderContainer(
        overrides: [goalsProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_testApp(container, false));
      await tester.tap(find.byTooltip('Add goal'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Goal title',
        ),
        'Saved once',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('ADD GOAL'));
      await tester.pump(const Duration(milliseconds: 300));
      // Two pointer activations can reach the same callback before its disabled
      // state is rendered. They must still result in only one canonical save.
      await tester.tap(find.text('ADD GOAL'));
      await tester.tap(find.text('ADD GOAL'));
      expect(notifier.saves, 1);
      notifier.saveGate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(notifier.saves, 1);
      expect(find.text('ADD GOAL'), findsNothing);
      expect(
        find.text('Goal could not be saved. Please try again.'),
        findsNothing,
      );
      expect(
        find.text(
          'Goal saved. Some reminders or activity updates could not finish.',
        ),
        findsOneWidget,
      );
      expect(notifier.saves, 1);
      expect(tester.takeException(), isNull);
    },
  );
  for (final es in [false, true]) {
    testWidgets(
      '${es ? 'Spanish' : 'English'} goal controls preserve the stored title',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            goalsProvider.overrideWith(_GoalsNotifier.new),
            goalsReadProvider.overrideWithValue(
              const AsyncData(<GoalEntity>[]),
            ),
            goalProgressProvider(
              'release',
            ).overrideWith((ref) async => const GoalProgressView.empty()),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(_testApp(container, es));
        await tester.pumpAndSettle();
        expect(find.text(es ? 'Metas' : 'Goals'), findsOneWidget);
        expect(find.text('Ship the first release'), findsOneWidget);
        expect(
          find.byTooltip(
            es
                ? 'Compartir meta: Ship the first release'
                : 'Share goal: Ship the first release',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip(es ? 'Añadir meta' : 'Add goal'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.widgetWithText(
            TextField,
            es ? 'Título de la meta' : 'Goal title',
          ),
          findsOneWidget,
        );
        expect(find.text(es ? 'AÑADIR META' : 'ADD GOAL'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

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
                      widget is IconButton &&
                      widget.tooltip == (es ? 'Añadir meta' : 'Add goal'),
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

    expect(find.text('Goals'), findsOneWidget);
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

Widget _testApp(
  ProviderContainer container,
  bool es, {
  bool disableAnimations = true,
  ThemeData? theme,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: theme,
    locale: Locale(es ? 'es' : 'en'),
    supportedLocales: const [Locale('en'), Locale('es')],
    localizationsDelegates: const [
      ChronoSparkLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
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

class _SavedWithWarning extends _GoalsNotifier {
  int saves = 0;
  Completer<void>? saveGate;
  @override
  Future<GoalMutationResult> add({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    saves += 1;
    await saveGate?.future;
    return const GoalMutationResult(warnings: <String>['reminders']);
  }
}

class _EditedGoals extends _GoalsNotifier {
  int updates = 0;
  @override
  Future<GoalMutationResult> update(GoalEntity updated) async {
    updates++;
    state = [updated];
    return const GoalMutationResult();
  }
}

double _contrast(Color foreground, Color background) {
  final painted = Color.alphaBlend(foreground, background).computeLuminance();
  final base = background.computeLuminance();
  return painted >= base
      ? (painted + .05) / (base + .05)
      : (base + .05) / (painted + .05);
}

/// Revealing a nested sheet control can schedule another layout when a field
/// loses focus. Settle, reveal to the viewport center, settle again and require
/// an actual hit target before the single gesture. No callback bypass/missed tap.
Future<void> _revealGoalControl(WidgetTester tester, Finder control) async {
  for (var observation = 0; observation < 4; observation++) {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    expect(control, findsOneWidget);
    await Scrollable.ensureVisible(
      tester.element(control),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    if (control.hitTestable().evaluate().length == 1) return;
  }
  expect(
    control.hitTestable(),
    findsOneWidget,
    reason:
        'The real goal control must be reachable after bounded sheet layout settling.',
  );
}
