import 'package:fantastic_guacamole/domain/entities/emotional_state.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/policies/memory_governance_policy.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('personalization consent defaults fail closed', () {
    const PersonalizationProfile profile = PersonalizationProfile();

    expect(profile.useEmotionSignals, isFalse);
    expect(profile.useMemoryContext, isFalse);
    expect(profile.allowsEmotionSignals, isFalse);
    expect(profile.allowsMemoryContext, isFalse);
  });

  test('legacy consent booleans without grant receipts fail closed', () {
    final PersonalizationProfile profile = PersonalizationProfile.fromJson(
      <String, dynamic>{
        'version': 1,
        'useEmotionSignals': true,
        'useMemoryContext': true,
      },
    );

    expect(profile.version, PersonalizationProfile.currentVersion);
    expect(profile.allowsEmotionSignals, isFalse);
    expect(profile.allowsMemoryContext, isFalse);
    expect(profile.emotionConsentGrantedAt, isNull);
    expect(profile.memoryConsentGrantedAt, isNull);
  });

  test('versioned grants require matching timestamps', () {
    final PersonalizationProfile profile =
        PersonalizationProfile.fromJson(<String, dynamic>{
          'version': PersonalizationProfile.currentVersion,
          'useEmotionSignals': true,
          'useMemoryContext': true,
          'emotionConsentGrantedAt': '2026-08-29T12:00:00Z',
          'memoryConsentGrantedAt': '2026-08-29T12:01:00Z',
        });

    expect(profile.allowsEmotionSignals, isTrue);
    expect(profile.allowsMemoryContext, isTrue);
    expect(profile.toJson()['version'], PersonalizationProfile.currentVersion);
  });

  test('shared boundary removes unconsented and estimated human state', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        personalizationProfileProvider.overrideWith(
          _FixedPersonalizationController.new,
        ),
        siStateProvider.overrideWith(_EstimatedSiStateController.new),
        emotionCheckInProvider.overrideWith(_FreshEmotionController.new),
      ],
    );
    addTearDown(container.dispose);

    final ConsentedHumanContext context = container.read(
      consentedHumanContextProvider,
    );

    expect(context.emotionAllowed, isFalse);
    expect(context.memoryAllowed, isFalse);
    expect(context.emotion, isNull);
    expect(context.siState.energy, 0.5);
    expect(context.siState.fatigue, 0.5);
    expect(context.siState.energyOrigin, PredictiveEvidenceOrigin.unavailable);
    expect(context.siState.fatigueOrigin, PredictiveEvidenceOrigin.unavailable);
    expect(context.authorizeReportedEmotion(EmotionalState.anxious), isNull);
  });

  test('shared boundary admits fresh consented reports and observed state', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        personalizationProfileProvider.overrideWith(
          _ConsentedPersonalizationController.new,
        ),
        siStateProvider.overrideWith(_ObservedSiStateController.new),
        emotionCheckInProvider.overrideWith(_FreshEmotionController.new),
      ],
    );
    addTearDown(container.dispose);

    final ConsentedHumanContext context = container.read(
      consentedHumanContextProvider,
    );

    expect(context.emotion, EmotionalState.calm);
    expect(context.memoryAllowed, isTrue);
    expect(context.siState.energy, 0.8);
    expect(context.siState.fatigue, 0.2);
    expect(context.siState.hasObservedEnergy, isTrue);
    expect(context.siState.hasObservedFatigue, isTrue);
  });

  test('stale emotion check-ins are unknown', () {
    const EmotionCheckIn checkIn = EmotionCheckIn(
      value: EmotionalState.energized,
      reportedAt: null,
    );

    expect(checkIn.isFreshAt(DateTime.utc(2026, 8, 29)), isFalse);
  });

  test('revoked global memory consent blocks recall and new writes', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        personalizationProfileProvider.overrideWith(
          _FixedPersonalizationController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(memoryRecallProvider(MemorySurface.smartPlanner)),
      isEmpty,
    );
    await expectLater(
      () => container
          .read(memoryGovernanceControllerProvider)
          .rememberPreference(
            text: 'Prefer one small first step.',
            sourceSurface: MemorySurface.smartPlanner,
            expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
            consentConfirmed: true,
            whyStored: 'Adapt future planning guidance.',
            provenance: 'Test user entry.',
          ),
      throwsA(
        isA<MemoryGovernanceException>().having(
          (MemoryGovernanceException error) => error.code,
          'code',
          'global_memory_consent_required',
        ),
      ),
    );
  });
}

class _FixedPersonalizationController extends PersonalizationProfileController {
  @override
  PersonalizationProfile build() => const PersonalizationProfile();
}

class _ConsentedPersonalizationController
    extends PersonalizationProfileController {
  @override
  PersonalizationProfile build() => PersonalizationProfile(
    useEmotionSignals: true,
    useMemoryContext: true,
    emotionConsentGrantedAt: DateTime.utc(2026, 8, 29),
    memoryConsentGrantedAt: DateTime.utc(2026, 8, 29),
  );
}

class _EstimatedSiStateController extends SIStateController {
  @override
  SIState build() => const SIState(energy: 0.9, fatigue: 0.1);
}

class _ObservedSiStateController extends SIStateController {
  @override
  SIState build() => const SIState(
    energy: 0.8,
    fatigue: 0.2,
    energyOrigin: PredictiveEvidenceOrigin.observed,
    fatigueOrigin: PredictiveEvidenceOrigin.observed,
  );
}

class _FreshEmotionController extends EmotionNotifier {
  @override
  EmotionCheckIn build() => EmotionCheckIn(
    value: EmotionalState.calm,
    reportedAt: DateTime.now().toUtc(),
  );
}
