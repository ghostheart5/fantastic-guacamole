import 'package:fantastic_guacamole/features/tasks/ui/task_screen.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_progress_store.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renders trajectory shell and flowmap card navigates to flowmap view',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          trajectorySummaryProvider.overrideWithValue(_summary),
          tutorialProgressProvider.overrideWith(_StaticTutorialController.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TaskScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('TRAJECTORY ENGINE'), findsAtLeastNWidgets(1));
      expect(find.text('FLOWMAP ACCESS'), findsOneWidget);

      await tester.tap(find.text('FLOWMAP ACCESS'));
      await tester.pump();

      expect(container.read(appFlowProvider), AppView.flowmap);
    },
  );
}

const TrajectorySummaryView _summary = TrajectorySummaryView(
  pendingTasks: 2,
  completedTasks: 4,
  completedToday: 1,
  level: 3,
  streak: 5,
  energy: 0.72,
  momentum: 0.65,
  adaptability: 0.61,
  lastSessionXp: 48,
  lastSessionQuality: 0.84,
  pressureIndex: 36,
  behaviorDivergence: 12,
  alert: 'SI ALERT: trajectory is calm.',
  predictionTitle: null,
  predictionOutcome: null,
  predictionProbability: null,
  predictionExplanation: null,
);

class _StaticTutorialController extends TutorialProgressController {
  @override
  Future<TutorialProgress> build() async => const TutorialProgress();
}
