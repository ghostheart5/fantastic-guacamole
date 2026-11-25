import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/features/goals/ui/goals_screen.dart';
import 'package:fantastic_guacamole/state/models/goal_progress_view.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../permissions/notification_permission_test_support.dart';

void main() {
  PermissionFixture fixture(_Goals goals) => PermissionFixture(
    overrides: [
      goalsProvider.overrideWith(() => goals),
      goalsReadProvider.overrideWithValue(const AsyncData(<GoalEntity>[])),
      goalProgressProvider(
        'g',
      ).overrideWith((ref) async => const GoalProgressView.empty()),
    ],
  );

  Future<void> openEdit(
    WidgetTester tester,
    PermissionFixture f, {
    bool spanish = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      f.app(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const GoalsScreen(),
          ),
        ),
        spanish: spanish,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip(spanish ? 'Administrar meta' : 'Manage goal'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(spanish ? 'Editar meta' : 'Edit goal'));
    await tester.pumpAndSettle();
  }

  testWidgets('a goal without a date can be given one, then it asks', (
    tester,
  ) async {
    final goals = _Goals(null);
    final f = fixture(goals);
    await openEdit(tester, f);

    expect(find.text('No target date'), findsOneWidget);
    expect(find.byTooltip('Clear target date'), findsNothing);
    await tester.tap(find.text('No target date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Target:'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(goals.updated.single.targetDate, isNotNull);
    expect(find.text('WHEN IT IS USED'), findsOneWidget);
  });

  testWidgets('the date can be changed, then it asks', (tester) async {
    final goals = _Goals(DateTime(2026, 9, 1));
    final f = fixture(goals);
    await openEdit(tester, f);

    expect(find.text('Target: 1/9/2026'), findsOneWidget);
    await tester.tap(find.text('Target: 1/9/2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Target: 15/9/2026'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(goals.updated.single.targetDate, DateTime(2026, 9, 15));
    expect(find.text('WHEN IT IS USED'), findsOneWidget);
  });

  testWidgets('the date can be cleared, and clearing does not ask', (
    tester,
  ) async {
    final goals = _Goals(DateTime(2026, 9, 1));
    final f = fixture(goals);
    await openEdit(tester, f);

    await tester.tap(find.byTooltip('Clear target date'));
    await tester.pumpAndSettle();
    expect(find.text('No target date'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(goals.updated.single.targetDate, isNull);
    expect(find.text('WHEN IT IS USED'), findsNothing);
    expect(f.scheduler.queries, 0);
  });

  testWidgets('saving without touching the date keeps it and does not ask', (
    tester,
  ) async {
    final goals = _Goals(DateTime(2026, 9, 1));
    final f = fixture(goals);
    await openEdit(tester, f);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(goals.updated.single.targetDate, DateTime(2026, 9, 1));
    expect(find.text('WHEN IT IS USED'), findsNothing);
  });

  testWidgets('cancelling leaves the date alone', (tester) async {
    final goals = _Goals(DateTime(2026, 9, 1));
    final f = fixture(goals);
    await openEdit(tester, f);

    await tester.tap(find.byTooltip('Clear target date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(goals.updated, isEmpty);
  });

  testWidgets('with goal reminders off a new date does not ask', (
    tester,
  ) async {
    final goals = _Goals(null);
    final f = fixture(goals);
    f.actions.reminderPrefs = const ReminderOrchestratorPrefs(
      goalRemindersEnabled: false,
      habitRemindersEnabled: true,
      dailyPlanningEnabled: true,
      dailyPlanningHour: 7,
      dailyPlanningMinute: 30,
    );
    await openEdit(tester, f);

    await tester.tap(find.text('No target date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(goals.updated.single.targetDate, isNotNull);
    expect(find.text('WHEN IT IS USED'), findsNothing);
  });

  testWidgets('the date row is in Spanish with accessible labels', (
    tester,
  ) async {
    final goals = _Goals(DateTime(2026, 9, 1));
    final f = fixture(goals);
    final semantics = tester.ensureSemantics();
    await openEdit(tester, f, spanish: true);

    expect(find.text('Objetivo: 1/9/2026'), findsOneWidget);
    expect(find.byTooltip('Quitar fecha objetivo'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Fecha objetivo')),
      findsAtLeastNWidgets(1),
    );
    await tester.tap(find.byTooltip('Quitar fecha objetivo'));
    await tester.pumpAndSettle();
    expect(find.text('Sin fecha objetivo'), findsOneWidget);
    semantics.dispose();
  });
}

class _Goals extends GoalsNotifier {
  _Goals(this._date);

  final DateTime? _date;
  final List<GoalEntity> updated = <GoalEntity>[];

  @override
  List<GoalEntity> build() => <GoalEntity>[
    GoalEntity(
      id: 'g',
      title: 'Ship it',
      createdAt: DateTime.utc(2026, 8, 1),
      targetDate: _date,
    ),
  ];

  @override
  Future<GoalMutationResult> update(GoalEntity goal) async {
    updated.add(goal);
    state = <GoalEntity>[goal];
    return const GoalMutationResult();
  }
}
