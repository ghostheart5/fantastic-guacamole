import 'dart:async';
import 'dart:math';

import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/models/si_memory_models.dart';
import 'package:fantastic_guacamole/state/providers/si_memory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('surface-local transient providers cannot overwrite each other', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(aiInputProvider.notifier).set('console input');
    container
        .read(aiExecutionStatusProvider.notifier)
        .set(
          const AIExecutionStatus(phase: 'running', requestId: 'si-request'),
        );

    expect(container.read(smartPlannerAiInputProvider), isNull);
    expect(container.read(smartPlannerAiExecutionStatusProvider).phase, 'idle');

    container.read(smartPlannerAiInputProvider.notifier).set('planner input');
    container
        .read(smartPlannerAiExecutionStatusProvider.notifier)
        .set(
          const AIExecutionStatus(
            phase: 'completed',
            requestId: 'planner-request',
          ),
        );

    expect(container.read(aiInputProvider), 'console input');
    expect(container.read(aiExecutionStatusProvider).requestId, 'si-request');
    expect(container.read(smartPlannerAiInputProvider), 'planner input');
  });

  test('surface-local snapshot stores cannot see each other', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(siMemoryProvider.notifier).capture(_snapshot('si-hash'));
    container
        .read(smartPlannerMemoryProvider.notifier)
        .capture(_snapshot('planner-hash'));

    expect(
      container.read(siMemoryProvider).entries.single.responseHash,
      'si-hash',
    );
    expect(
      container.read(smartPlannerMemoryProvider).entries.single.responseHash,
      'planner-hash',
    );
  });

  test('surface-local throttles and dedup limiters do not share capacity', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final consoleThrottle = container.read(aiMessageThrottleProvider);
    final plannerThrottle = container.read(
      smartPlannerAiMessageThrottleProvider,
    );
    addTearDown(consoleThrottle.dispose);
    addTearDown(plannerThrottle.dispose);

    consoleThrottle.run(() {});
    expect(consoleThrottle.isReady, isFalse);
    expect(plannerThrottle.isReady, isTrue);

    final consoleLimiter = container.read(aiSuggestionRateLimiterProvider);
    final plannerLimiter = container.read(
      smartPlannerAiSuggestionRateLimiterProvider,
    );
    expect(consoleLimiter.tryAcquire(), isTrue);
    expect(consoleLimiter.tryAcquire(), isTrue);
    expect(consoleLimiter.tryAcquire(), isTrue);
    expect(consoleLimiter.tryAcquire(), isFalse);
    expect(plannerLimiter.remaining, 3);
  });

  test('10,000 randomized interleavings preserve surface isolation', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final Random random = Random(20260820);
    String? expectedConsoleInput;
    String? expectedPlannerInput;
    String? expectedConsoleRequest;
    String? expectedPlannerRequest;
    String? expectedConsoleHash;
    String? expectedPlannerHash;

    for (int index = 0; index < 10000; index += 1) {
      final bool planner = random.nextBool();
      final int operation = random.nextInt(3);
      final String value = '${planner ? 'planner' : 'console'}-$index';
      switch (operation) {
        case 0:
          if (planner) {
            container.read(smartPlannerAiInputProvider.notifier).set(value);
            expectedPlannerInput = value;
          } else {
            container.read(aiInputProvider.notifier).set(value);
            expectedConsoleInput = value;
          }
        case 1:
          final AIExecutionStatus status = AIExecutionStatus(
            phase: index.isEven ? 'running' : 'completed',
            requestId: value,
          );
          if (planner) {
            container
                .read(smartPlannerAiExecutionStatusProvider.notifier)
                .set(status);
            expectedPlannerRequest = value;
          } else {
            container.read(aiExecutionStatusProvider.notifier).set(status);
            expectedConsoleRequest = value;
          }
        case 2:
          if (planner) {
            container
                .read(smartPlannerMemoryProvider.notifier)
                .capture(_snapshot(value));
            expectedPlannerHash = value;
          } else {
            container.read(siMemoryProvider.notifier).capture(_snapshot(value));
            expectedConsoleHash = value;
          }
      }

      if (index % 97 == 0) {
        expect(container.read(aiInputProvider), expectedConsoleInput);
        expect(
          container.read(smartPlannerAiInputProvider),
          expectedPlannerInput,
        );
        expect(
          container.read(aiExecutionStatusProvider).requestId,
          expectedConsoleRequest,
        );
        expect(
          container.read(smartPlannerAiExecutionStatusProvider).requestId,
          expectedPlannerRequest,
        );
        expect(
          container.read(siMemoryProvider).latest?.responseHash,
          expectedConsoleHash,
        );
        expect(
          container.read(smartPlannerMemoryProvider).latest?.responseHash,
          expectedPlannerHash,
        );
      }
    }
  });

  test('a runtime rejects requests for the other surface', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container
          .read(aiResponseProvider.notifier)
          .executeSmartPlannerQuery(input: 'wrong surface'),
      throwsA(isA<StateError>()),
    );
    expect(
      () => container
          .read(smartPlannerAiResponseProvider.notifier)
          .executeConsoleQuery(input: 'wrong surface'),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'simultaneous response providers keep loading and results isolated',
    () async {
      final Completer<AIRecommendation?> plannerResult =
          Completer<AIRecommendation?>();
      final Completer<AIRecommendation?> consoleResult =
          Completer<AIRecommendation?>();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          smartPlannerAiResponseProvider.overrideWith(
            () => _ControlledAIResponseController(plannerResult),
          ),
          aiResponseProvider.overrideWith(
            () => _ControlledAIResponseController(consoleResult),
          ),
        ],
      );
      addTearDown(container.dispose);

      await Future.wait(<Future<AIRecommendation?>>[
        container.read(smartPlannerAiResponseProvider.future),
        container.read(aiResponseProvider.future),
      ]);

      final Future<AIRecommendation?> pendingPlanner = container
          .read(smartPlannerAiResponseProvider.notifier)
          .executeSmartPlannerQuery(input: 'planner');
      final Future<AIRecommendation?> pendingConsole = container
          .read(aiResponseProvider.notifier)
          .executeConsoleQuery(input: 'console');

      expect(container.read(smartPlannerAiResponseProvider).isLoading, isTrue);
      expect(container.read(aiResponseProvider).isLoading, isTrue);

      plannerResult.complete(const AIRecommendation(message: 'planner result'));
      expect((await pendingPlanner)?.message, 'planner result');
      expect(
        container.read(smartPlannerAiResponseProvider).value?.message,
        'planner result',
      );
      expect(container.read(aiResponseProvider).isLoading, isTrue);

      consoleResult.complete(const AIRecommendation(message: 'console result'));
      expect((await pendingConsole)?.message, 'console result');
      expect(
        container.read(aiResponseProvider).value?.message,
        'console result',
      );
    },
  );
}

SISnapshot _snapshot(String hash) => SISnapshot(
  timestamp: DateTime(2026, 8, 20),
  energy: 0.5,
  fatigue: 0.5,
  completed: 0,
  skipped: 0,
  responseHash: hash,
);

class _ControlledAIResponseController extends AIResponseController {
  _ControlledAIResponseController(this._result);

  final Completer<AIRecommendation?> _result;

  @override
  Future<AIRecommendation?> build() async => null;

  @override
  Future<AIRecommendation?> executeSmartPlannerQuery({
    required String input,
    List<Map<String, String>> history = const <Map<String, String>>[],
    Map<String, dynamic> context = const <String, dynamic>{},
  }) => _complete();

  @override
  Future<AIRecommendation?> executeConsoleQuery({
    required String input,
    List<Map<String, String>> history = const <Map<String, String>>[],
    Map<String, dynamic> context = const <String, dynamic>{},
  }) => _complete();

  Future<AIRecommendation?> _complete() async {
    state = const AsyncLoading<AIRecommendation?>();
    final AIRecommendation? value = await _result.future;
    state = AsyncData<AIRecommendation?>(value);
    return value;
  }
}
