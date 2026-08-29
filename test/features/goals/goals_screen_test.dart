import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/features/goals/ui/goals_screen.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the active goal list', (WidgetTester tester) async {
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
