import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nextActionTextProvider falls back when there are no tasks', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        tasksProvider.overrideWith((Ref ref) async => const <Task>[]),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(nextActionTextProvider),
      'Create your first task to get started.',
    );
  });

  test('nextActionTextProvider uses first ranked task title', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        tasksProvider.overrideWith((Ref ref) async {
          return const <Task>[
            Task(
              id: 't1',
              title: 'Lock release scope',
              priority: 5,
              difficulty: 3,
              energyRequired: 3,
            ),
          ];
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(tasksProvider.future);
    expect(
      container.read(nextActionTextProvider),
      'Focus on: Lock release scope',
    );
  });

  test('AI notifier providers update state deterministically', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(aiTriggerProvider.notifier).set(7);
    container
        .read(aiPersonalityProvider.notifier)
        .set(AIPersonality.strategist);
    container.read(aiInputProvider.notifier).set('What is next?');
    container
        .read(aiExecutionStatusProvider.notifier)
        .set(
          const AIExecutionStatus(
            phase: 'running',
            requestId: 'req-1',
            durationMs: 55,
          ),
        );

    expect(container.read(aiTriggerProvider), 7);
    expect(container.read(aiPersonalityProvider), AIPersonality.strategist);
    expect(container.read(aiInputProvider), 'What is next?');
    expect(container.read(aiExecutionStatusProvider).phase, 'running');
  });

  test('sendMessage returns null for empty input', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final AIController controller = container.read(aiControllerProvider);
    final result = await controller.sendMessage('   ');

    expect(result, isNull);
  });

  test('safeInputLength handles null safely', () {
    expect(safeInputLength(null), 0);
    expect(safeInputLength('abc'), 3);
  });
}
