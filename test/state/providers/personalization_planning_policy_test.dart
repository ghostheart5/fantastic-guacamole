import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/models/personalization_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('priority strategies map to distinct deterministic weights', () {
    expect(
      adaptivePlanPolicyFor(
        const PersonalizationProfile(
          priorityStrategy: PriorityStrategy.deadlineFirst,
        ),
      ).deadlineWeight,
      greaterThan(1),
    );
    expect(
      adaptivePlanPolicyFor(
        const PersonalizationProfile(
          priorityStrategy: PriorityStrategy.energyFirst,
        ),
      ).energyWeight,
      greaterThan(1),
    );
    expect(
      adaptivePlanPolicyFor(
        const PersonalizationProfile(
          priorityStrategy: PriorityStrategy.goalFirst,
        ),
      ).goalBonus,
      greaterThan(0),
    );
    expect(
      adaptivePlanPolicyFor(
        const PersonalizationProfile(
          priorityStrategy: PriorityStrategy.quickWins,
        ),
      ).quickWinBonus,
      greaterThan(0),
    );
  });

  test('planning styles change duration, break, and energy behavior', () {
    final flexible = adaptivePlanPolicyFor(const PersonalizationProfile());
    final timeBlocked = adaptivePlanPolicyFor(
      const PersonalizationProfile(planningStyle: PlanningStyle.timeBlocked),
    );
    final energyMatched = adaptivePlanPolicyFor(
      const PersonalizationProfile(planningStyle: PlanningStyle.energyMatched),
    );
    final singleTask = adaptivePlanPolicyFor(
      const PersonalizationProfile(planningStyle: PlanningStyle.singleTask),
    );

    expect(flexible.adaptDurationToEnergy, isTrue);
    expect(timeBlocked.adaptDurationToEnergy, isFalse);
    expect(timeBlocked.fixedBreakMinutes, 10);
    expect(energyMatched.energyWeight, greaterThan(flexible.energyWeight));
    expect(singleTask.priorityWeight, greaterThan(flexible.priorityWeight));
    expect(singleTask.fixedBreakMinutes, 15);
  });

  test('failed persistence never publishes a consent change', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPrefsStoreProvider.overrideWithValue(_ThrowingPrefs()),
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('account-a'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final before = container.read(personalizationProfileProvider);
    await expectLater(
      container
          .read(personalizationProfileProvider.notifier)
          .update(before.copyWith(useEmotionSignals: true)),
      throwsStateError,
    );
    expect(container.read(personalizationProfileProvider), before);
  });
}

class _ThrowingPrefs implements SharedPrefsStore {
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => null;
  @override
  Future<void> save(String key, String value) async =>
      throw StateError('write failed');
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> clear() async {}
}
