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
    expect(result.message.toLowerCase(), contains('anxiety'));
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
    expect(reply.toLowerCase(), contains('motivation follows action'));
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
    expect(result.message.toLowerCase(), contains('focus'));
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
    expect(reply.toLowerCase(), contains('start small, start now'));
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

class _TestProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState();
}
