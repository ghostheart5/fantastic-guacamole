import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/prediction.dart';
import 'package:fantastic_guacamole/state/controllers/prediction_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';

void main() {
  for (final scope in [
    const AccountStorageScope.signedOut(),
    const AccountStorageScope.unsafe(),
  ]) {
    test(
      'prediction avoids protected history for ${scope.state.name}',
      () async {
        var opened = false;
        final container = ProviderContainer(
          overrides: [
            accountStorageScopeProvider.overrideWithValue(scope),
            accountSecureStoreProvider.overrideWith((ref) {
              opened = true;
              throw StateError('Storage must not be opened');
            }),
          ],
        );
        addTearDown(container.dispose);
        final result = await container.read(
          predictionProvider('Private task').future,
        );
        expect(opened, isFalse);
        expect(result.sampleSize, 0);
        expect(result.confidence, 0);
        expect(result.signals, contains('storage-unavailable'));
      },
    );
  }

  NeuralEntry outcome(String task, bool completed, int day) => NeuralEntry(
    task: task,
    reasoning: completed
        ? 'Observed completed task outcome.'
        : 'Observed skipped task outcome.',
    confidence: 1,
    duration: completed ? 300 : 0,
    quality: completed ? 1 : 0,
    timestamp: DateTime.utc(2026, 8, day),
    completed: completed,
  );

  test('uses completed and skipped outcomes with beta smoothing', () {
    final Prediction result = buildObservedFollowThroughPrediction(
      history: <NeuralEntry>[
        outcome('Write report', true, 1),
        outcome('Write report', true, 2),
        outcome('Write report', false, 3),
      ],
      taskTitle: 'Write report',
    );

    expect(result.probability, .6);
    expect(result.outcome, 'Mixed observed follow-through');
    expect(result.signals, containsAll(<String>['completed:2', 'skipped:1']));
    expect(result.explanation, isNot(contains('success')));
    expect(result.reliable, isFalse);
  });

  test('reads pre-outcome-schema completion records as completed', () {
    final NeuralEntry legacy = NeuralEntry.fromJson(<String, dynamic>{
      'task': 'Legacy task',
      'reasoning': 'Recorded from a completed task.',
      'confidence': .8,
      'duration': 300,
      'quality': .8,
      'timestamp': '2026-08-01T00:00:00.000Z',
    });

    expect(legacy.observedCompleted, isTrue);
    expect(legacy.toJson(), isNot(contains('completed')));
  });
}
