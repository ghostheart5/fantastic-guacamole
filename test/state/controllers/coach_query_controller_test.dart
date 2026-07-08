import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/services/workspace_store_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/coach_query_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requestCoaching falls back to local coaching message when AI result is null', () async {
    final ProviderContainer container = _buildContainer(aiOverride: _NullAIResponseController.new);
    addTearDown(container.dispose);

    final CoachQueryController controller = container.read(coachQueryControllerProvider);

    final CoachCoachingResult result = await controller.requestCoaching(
      energy: 0.35,
      emotion: EmotionalState.anxious,
      notes: '',
      history: const <Map<String, String>>[],
      previousSavedNotes: null,
    );

    expect(result.prompt, contains('practical coaching check-in'));
    expect(result.message, isNotEmpty);
    expect(
      result.message.toLowerCase(),
      contains('progress slows because effort gets spread too thin'),
    );
    expect(result.message, contains('•'));
    expect(result.message.toLowerCase(), contains('next step:'));
    expect(result.message, isNot(contains('🎯 Goal Detected')));
  });

  test('requestFollowUp falls back to deterministic reply when AI result is null', () async {
    final ProviderContainer container = _buildContainer(aiOverride: _NullAIResponseController.new);
    addTearDown(container.dispose);

    final CoachQueryController controller = container.read(coachQueryControllerProvider);

    final String reply = await controller.requestFollowUp(
      input: 'How do I stay motivated?',
      energy: 0.5,
      emotion: EmotionalState.neutral,
      reflection: '',
      history: const <Map<String, String>>[],
    );

    expect(reply, isNotEmpty);
    expect(reply.toLowerCase(), contains('try this next:'));
    expect(reply.toLowerCase(), contains('coach question:'));
  });

  test('requestFollowUp reflects answered fatigue details', () async {
    final ProviderContainer container = _buildContainer(aiOverride: _NullAIResponseController.new);
    addTearDown(container.dispose);

    final CoachQueryController controller = container.read(coachQueryControllerProvider);

    final String reply = await controller.requestFollowUp(
      input: '5 hours and I haven\'t eaten yet',
      energy: 0.38,
      emotion: EmotionalState.fatigued,
      reflection: '',
      history: const <Map<String, String>>[],
    );

    expect(reply.toLowerCase(), contains('you got 5 hours of sleep'));
    expect(reply.toLowerCase(), contains('you haven\'t eaten yet'));
    expect(reply.toLowerCase(), contains('try this next:'));
  });

  test('requestFollowUp reflects answered weight loss details', () async {
    final ProviderContainer container = _buildContainer(aiOverride: _NullAIResponseController.new);
    addTearDown(container.dispose);

    final CoachQueryController controller = container.read(coachQueryControllerProvider);

    final String reply = await controller.requestFollowUp(
      input: 'I weigh 190 lbs and want to get to 170 lbs',
      energy: 0.62,
      emotion: EmotionalState.neutral,
      reflection: '',
      history: const <Map<String, String>>[],
    );

    expect(reply.toLowerCase(), contains('you said 190 and want to get to 170'));
    expect(reply.toLowerCase(), contains('try this next:'));
  });

  test('requestFollowUp reflects answered stress details', () async {
    final ProviderContainer container = _buildContainer(aiOverride: _NullAIResponseController.new);
    addTearDown(container.dispose);

    final CoachQueryController controller = container.read(coachQueryControllerProvider);

    final String reply = await controller.requestFollowUp(
      input: 'My work deadline is tomorrow and I feel overloaded',
      energy: 0.42,
      emotion: EmotionalState.anxious,
      reflection: '',
      history: const <Map<String, String>>[],
    );

    expect(reply.toLowerCase(), contains('stress is tied to work pressure or deadlines'));
    expect(reply.toLowerCase(), contains('try this next:'));
  });

  test('requestFollowUp handles weight gain usecase', () async {
    final ProviderContainer container = _buildContainer(aiOverride: _NullAIResponseController.new);
    addTearDown(container.dispose);

    final CoachQueryController controller = container.read(coachQueryControllerProvider);

    final String reply = await controller.requestFollowUp(
      input: 'I want to gain weight and build muscle',
      energy: 0.58,
      emotion: EmotionalState.neutral,
      reflection: '',
      history: const <Map<String, String>>[],
    );

    expect(reply.toLowerCase(), contains('calorie-dense meal'));
  });

  test('requestFollowUp handles hydration usecase', () async {
    final ProviderContainer container = _buildContainer(aiOverride: _NullAIResponseController.new);
    addTearDown(container.dispose);

    final CoachQueryController controller = container.read(coachQueryControllerProvider);

    final String reply = await controller.requestFollowUp(
      input: 'I have been dehydrated and need more water today',
      energy: 0.66,
      emotion: EmotionalState.neutral,
      reflection: '',
      history: const <Map<String, String>>[],
    );

    expect(reply.toLowerCase(), contains('hydration has been low'));
    expect(reply.toLowerCase(), contains('full glass of water'));
  });

  test('requestFollowUp handles burnout usecase', () async {
    final ProviderContainer container = _buildContainer(aiOverride: _NullAIResponseController.new);
    addTearDown(container.dispose);

    final CoachQueryController controller = container.read(coachQueryControllerProvider);

    final String reply = await controller.requestFollowUp(
      input: 'I feel burned out and overloaded',
      energy: 0.31,
      emotion: EmotionalState.negative,
      reflection: '',
      history: const <Map<String, String>>[],
    );

    expect(reply.toLowerCase(), contains('step back from the overload'));
    expect(reply.toLowerCase(), contains('real recovery block'));
  });

  test('requestFollowUp handles career usecase', () async {
    final ProviderContainer container = _buildContainer(aiOverride: _NullAIResponseController.new);
    addTearDown(container.dispose);

    final CoachQueryController controller = container.read(coachQueryControllerProvider);

    final String reply = await controller.requestFollowUp(
      input: 'I need to think about my next career move',
      energy: 0.57,
      emotion: EmotionalState.neutral,
      reflection: '',
      history: const <Map<String, String>>[],
    );

    expect(reply.toLowerCase(), contains('what outcome matters most right now'));
    expect(reply.toLowerCase(), contains('try this next:'));
  });

  test('requestFollowUp reflects answered nutrition details', () async {
    final ProviderContainer container = _buildContainer(aiOverride: _NullAIResponseController.new);
    addTearDown(container.dispose);

    final CoachQueryController controller = container.read(coachQueryControllerProvider);

    final String reply = await controller.requestFollowUp(
      input: 'I have not eaten yet today',
      energy: 0.55,
      emotion: EmotionalState.neutral,
      reflection: '',
      history: const <Map<String, String>>[],
    );

    expect(reply.toLowerCase(), contains('and you haven\'t eaten yet'));
    expect(reply.toLowerCase(), contains('try this next:'));
  });

  test('detectsCrisis flags high-risk phrasing', () {
    final ProviderContainer container = _buildContainer(aiOverride: _NullAIResponseController.new);
    addTearDown(container.dispose);

    final CoachQueryController controller = container.read(coachQueryControllerProvider);

    expect(controller.detectsCrisis('I want to kill myself tonight'), isTrue);
    expect(controller.detectsCrisis('I had a rough day but will rest'), isFalse);
  });

  test('requestCoaching falls back when AI execution throws', () async {
    final ProviderContainer container = _buildContainer(
      aiOverride: _ThrowingAIResponseController.new,
    );
    addTearDown(container.dispose);

    final CoachQueryController controller = container.read(coachQueryControllerProvider);

    final CoachCoachingResult result = await Logger.withMutedErrors(
      () => controller.requestCoaching(
        energy: 0.52,
        emotion: EmotionalState.focused,
        notes: '',
        history: const <Map<String, String>>[],
        previousSavedNotes: null,
      ),
    );

    expect(result.message, isNotEmpty);
    expect(result.message.toLowerCase(), contains('when priorities are unclear'));
    expect(result.message, contains('•'));
  });

  test('requestCoaching ignores non-actionable AI dedup fallback text', () async {
    final ProviderContainer container = _buildContainer(
      aiOverride: _EvidenceFallbackAIResponseController.new,
    );
    addTearDown(container.dispose);

    final CoachQueryController controller = container.read(coachQueryControllerProvider);

    final CoachCoachingResult result = await controller.requestCoaching(
      energy: 0.33,
      emotion: EmotionalState.fatigued,
      notes: '',
      history: const <Map<String, String>>[],
      previousSavedNotes: null,
    );

    expect(result.message.toLowerCase(), isNot(contains('available app evidence has not changed')));
    expect(result.message.toLowerCase(), contains('tiredness'));
    expect(result.message.toLowerCase(), contains('sleep debt'));
  });

  test('requestFollowUp falls back when AI execution times out', () async {
    final ProviderContainer container = _buildContainer(
      aiOverride: _ThrowingAIResponseController.new,
    );
    addTearDown(container.dispose);

    final CoachQueryController controller = container.read(coachQueryControllerProvider);

    final String reply = await Logger.withMutedErrors(
      () => controller.requestFollowUp(
        input: 'How do I begin when overwhelmed?',
        energy: 0.38,
        emotion: EmotionalState.fatigued,
        reflection: 'Too much context switching today',
        history: const <Map<String, String>>[],
      ),
    );

    expect(reply, isNotEmpty);
    expect(reply.toLowerCase(), contains('try this next:'));
    expect(reply.toLowerCase(), contains('coach question:'));
  });
}

ProviderContainer _buildContainer({required AIResponseController Function() aiOverride}) {
  return ProviderContainer(
    overrides: [
      secureStoreProvider.overrideWithValue(SecureStore(backend: InMemorySecureStoreBackend())),
      profileProvider.overrideWith(_TestProfileController.new),
      workspaceStoreServiceProvider.overrideWithValue(
        WorkspaceStoreService(store: SecureStore(backend: InMemorySecureStoreBackend())),
      ),
      aiResponseProvider.overrideWith(aiOverride),
    ],
  );
}

class _NullAIResponseController extends AIResponseController {
  @override
  Future<AIRecommendation?> build() async {
    return null;
  }

  @override
  Future<AIRecommendation?> executeCoachQuery({
    required String input,
    List<Map<String, String>> history = const <Map<String, String>>[],
    Map<String, dynamic> context = const <String, dynamic>{},
  }) async {
    return null;
  }
}

class _ThrowingAIResponseController extends AIResponseController {
  @override
  Future<AIRecommendation?> build() async {
    return null;
  }

  @override
  Future<AIRecommendation?> executeCoachQuery({
    required String input,
    List<Map<String, String>> history = const <Map<String, String>>[],
    Map<String, dynamic> context = const <String, dynamic>{},
  }) async {
    throw TimeoutException('simulated ai timeout');
  }
}

class _EvidenceFallbackAIResponseController extends AIResponseController {
  @override
  Future<AIRecommendation?> build() async {
    return null;
  }

  @override
  Future<AIRecommendation?> executeCoachQuery({
    required String input,
    List<Map<String, String>> history = const <Map<String, String>>[],
    Map<String, dynamic> context = const <String, dynamic>{},
  }) async {
    return const AIRecommendation(
      message:
          'The available app evidence has not changed enough for a different answer. Ask from another angle.',
      reasoning: 'final_dedup_fallback',
    );
  }
}

class _TestProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState();
}
