import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/features/goals/ui/goals_screen.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
