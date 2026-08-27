import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_output_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime fixedNow = DateTime.utc(2026, 8, 19, 12);
  const Task task = Task(
    id: 'task-1',
    title: 'Finish proposal',
    priority: 4,
    difficulty: 3,
    energyRequired: 3,
  );

  test('runs one core pass and emits stable provenance', () async {
    Future<SIFinalOutputBundle> runFixture() =>
        SIEngine(clock: () => fixedNow).process(
          input: const SIInputPacket(
            text: 'What should I do next?',
            context: <String, dynamic>{'surface': 'planner'},
          ),
          task: task,
          goals: const <String>['Ship the proposal'],
        );

    final SIFinalOutputBundle first = await runFixture();
    final SIFinalOutputBundle second = await runFixture();

    expect(
      first.debugTrace.events.where((e) => e == 'pipeline_start'),
      hasLength(1),
    );
    expect(first.provenance.decisionId, second.provenance.decisionId);
    expect(first.provenance.generatedAt, fixedNow);
    expect(first.provenance.modelVersion, 'si-core-v1');
    expect(first.provenance.evidenceSources, contains('task:task-1'));
    expect(first.provenance.evidenceSources, contains('context:surface'));
    expect(first.provenance.generationMode, 'deterministic_local');
  });

  test('terminal gate rejects unsupported meta responses', () {
    const SIOutputValidator validator = SIOutputValidator();

    expect(
      validator.accepts(
        message: 'As an AI language model I cannot help.',
        confidence: 0.9,
      ),
      isFalse,
    );
    expect(
      validator.accepts(
        message: 'Take one grounded next step.',
        confidence: 0.8,
      ),
      isTrue,
    );
  });
}
