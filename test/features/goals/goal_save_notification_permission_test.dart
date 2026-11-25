import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/features/goals/ui/goals_screen.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../permissions/notification_permission_test_support.dart';

void main() {
  Future<_Goals> saveGoal(
    WidgetTester tester,
    PermissionFixture fixture, {
    required bool withDate,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      fixture.app(
        Builder(
          // The animated backdrop only settles with animations off.
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const GoalsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add goal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Goal title',
      ),
      'Run a 10K',
    );
    if (withDate) {
      await tester.tap(find.text('Set target date (optional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('ADD GOAL'));
    await tester.tap(find.text('ADD GOAL'));
    await tester.pumpAndSettle();
    return fixture.container.read(goalsProvider.notifier) as _Goals;
  }

  PermissionFixture fixture() => PermissionFixture(
    overrides: [
      goalsProvider.overrideWith(_Goals.new),
      goalsReadProvider.overrideWithValue(const AsyncData(<GoalEntity>[])),
    ],
  );

  testWidgets('saving a goal with a date asks, after the goal is saved', (
    tester,
  ) async {
    final f = fixture();
    final goals = await saveGoal(tester, f, withDate: true);

    expect(goals.saved.single.targetDate, isNotNull);
    expect(find.text('WHEN IT IS USED'), findsOneWidget);
    expect(f.actions.requests, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Allow Notifications'));
    await tester.pumpAndSettle();
    expect(f.actions.requests, 1);
  });

  testWidgets('saving a goal without a date does not ask', (tester) async {
    final f = fixture();
    final goals = await saveGoal(tester, f, withDate: false);

    expect(goals.saved.single.targetDate, isNull);
    expect(find.text('WHEN IT IS USED'), findsNothing);
    expect(f.scheduler.queries, 0);
  });

  testWidgets('with goal reminders off a dated goal does not ask', (
    tester,
  ) async {
    final f = fixture();
    f.actions.reminderPrefs = const ReminderOrchestratorPrefs(
      goalRemindersEnabled: false,
      habitRemindersEnabled: true,
      dailyPlanningEnabled: true,
      dailyPlanningHour: 7,
      dailyPlanningMinute: 30,
    );
    final goals = await saveGoal(tester, f, withDate: true);

    expect(goals.saved, hasLength(1));
    expect(find.text('WHEN IT IS USED'), findsNothing);
    expect(f.scheduler.queries, 0);
  });
}

class _Goals extends GoalsNotifier {
  final List<({String title, DateTime? targetDate})> saved = [];

  @override
  List<GoalEntity> build() => const <GoalEntity>[];

  @override
  Future<GoalMutationResult> add({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    saved.add((title: title, targetDate: targetDate));
    return const GoalMutationResult();
  }
}
