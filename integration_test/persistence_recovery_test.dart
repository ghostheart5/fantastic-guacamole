import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/features/plan/ui/plan_screen.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('task survives restart and malformed storage degrades safely', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();

    final ProviderContainer firstRun = _containerFor(backend);
    await firstRun.read(taskActionsProvider).createQuickTask('Persisted integration task');
    expect(
      (await firstRun.read(tasksProvider.future)).map((t) => t.title),
      contains('Persisted integration task'),
    );
    firstRun.dispose();

    final ProviderContainer secondRun = _containerFor(backend);
    addTearDown(secondRun.dispose);
    final recovered = await secondRun.read(tasksProvider.future);
    expect(recovered.map((t) => t.title), contains('Persisted integration task'));

    await backend.write(key: 'task_entries_v2', value: '{ malformed-json');

    final ProviderContainer corruptedRun = _containerFor(backend);
    addTearDown(corruptedRun.dispose);

    try {
      await corruptedRun.read(tasksProvider.future).timeout(const Duration(seconds: 2));
    } on Object {
      // Corrupted payload may surface as a handled read failure.
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: corruptedRun,
        child: const MaterialApp(home: PlanScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(PlanScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ProviderContainer _containerFor(InMemorySecureStoreBackend backend) {
  return ProviderContainer(
    overrides: [
      secureStoreProvider.overrideWithValue(SecureStore(backend: backend)),
      siStateProvider.overrideWith(_FixedSiStateController.new),
      learningProvider.overrideWith(_FixedLearningController.new),
    ],
  );
}

class _FixedSiStateController extends SIStateController {
  @override
  SIState build() => const SIState(energy: 0.7, fatigue: 0.2, completedToday: 0);
}

class _FixedLearningController extends LearningController {
  @override
  LearningState build() => const LearningState();
}
