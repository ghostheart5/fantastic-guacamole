import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'fresh check-ins survive restart, remain account isolated and expire',
    (tester) async {
      final delegate = _MemoryPrefsStore();
      var now = DateTime.utc(2026, 9, 20, 2);
      ProviderContainer containerFor(String account) => ProviderContainer(
        overrides: [
          sharedPrefsStoreProvider.overrideWithValue(delegate),
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated(account),
          ),
          accountLegacyOwnershipProvider.overrideWithValue(
            LegacyScopeOwnership.provenNotOwned,
          ),
          siStateClockProvider.overrideWithValue(() => now),
        ],
      );

      var container = containerFor('owner-a');
      container
          .read(siStateProvider.notifier)
          .replaceState(
            energy: .7,
            fatigue: .25,
            energyOrigin: PredictiveEvidenceOrigin.observed,
            fatigueOrigin: PredictiveEvidenceOrigin.observed,
          );
      await tester.pump();
      await tester.pump();
      container.dispose();

      container = containerFor('owner-a');
      expect(container.read(siStateProvider).energy, .7);
      expect(container.read(siStateProvider).fatigue, .25);
      expect(container.read(siStateProvider).hasObservedEnergy, isTrue);
      expect(container.read(siStateProvider).hasObservedFatigue, isTrue);
      container.dispose();

      container = containerFor('owner-b');
      expect(container.read(siStateProvider), const SIState());
      container.dispose();

      now = now.add(const Duration(hours: 2, seconds: 1));
      container = containerFor('owner-a');
      final expired = container.read(siStateProvider);
      expect(expired.hasObservedEnergy, isFalse);
      expect(expired.hasObservedFatigue, isFalse);
      expect(expired.energy, .5);
      expect(expired.fatigue, .5);
      container.dispose();
    },
  );

  testWidgets(
    'check-ins expire independently and never become enduring state',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(siStateProvider.notifier);
      controller.adjustEnergy(.2);
      controller.adjustFatigue(-.1);
      await tester.pump(const Duration(hours: 1));
      controller.replaceState(
        energy: .8,
        fatigue: .4,
        energyOrigin: PredictiveEvidenceOrigin.observed,
      );
      await tester.pump(const Duration(hours: 1));
      expect(container.read(siStateProvider).hasObservedEnergy, isTrue);
      expect(container.read(siStateProvider).hasObservedFatigue, isFalse);
      await tester.pump(const Duration(hours: 1));
      expect(container.read(siStateProvider).hasObservedEnergy, isFalse);
      container.dispose();
    },
  );
  test('non-finite inputs cannot become personal observations', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(siStateProvider.notifier);
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      controller.adjustEnergy(value);
      controller.adjustFatigue(value);
      controller.replaceState(
        energy: value,
        fatigue: .5,
        energyOrigin: PredictiveEvidenceOrigin.observed,
      );
      expect(container.read(siStateProvider).hasObservedEnergy, isFalse);
      expect(container.read(siStateProvider).hasObservedFatigue, isFalse);
      expect(
        SIState(
          energy: value,
          energyOrigin: PredictiveEvidenceOrigin.observed,
        ).hasObservedEnergy,
        isFalse,
      );
      expect(
        SIState(
          fatigue: value,
          fatigueOrigin: PredictiveEvidenceOrigin.observed,
        ).hasObservedFatigue,
        isFalse,
      );
    }
  });
  test('build starts with default SI state', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(siStateProvider), const SIState());
  });

  test('recordCompletion does not invent energy or fatigue', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(siStateProvider.notifier).reset();
    container.read(siStateProvider.notifier).recordCompletion();

    final state = container.read(siStateProvider);
    expect(state.completedToday, 1);
    expect(state.energy, 0.5);
    expect(state.fatigue, 0.5);
    expect(state.hasObservedEnergy, isFalse);
    expect(state.hasObservedFatigue, isFalse);
  });

  test('explicit adjustments clamp and become observed reports', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(siStateProvider.notifier)
        .replaceState(energy: 0.9, fatigue: 0.1);
    container.read(siStateProvider.notifier).adjustEnergy(0.5);
    container.read(siStateProvider.notifier).adjustFatigue(-0.5);

    final state = container.read(siStateProvider);
    expect(state.energy, 1.0);
    expect(state.fatigue, 0.0);
    expect(state.energyOrigin, PredictiveEvidenceOrigin.observed);
    expect(state.fatigueOrigin, PredictiveEvidenceOrigin.observed);
  });

  test('replaceState and reset behave predictably', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(siStateProvider.notifier)
        .replaceState(energy: 0.2, fatigue: 0.9, completedToday: 4);
    expect(container.read(siStateProvider).completedToday, 4);

    container.read(siStateProvider.notifier).reset();
    expect(container.read(siStateProvider), const SIState());
  });

  test('task evidence never changes unavailable human state', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(siStateProvider.notifier).recordCompletion();
    container.read(siStateProvider.notifier).taskSkipped();

    final SIState state = container.read(siStateProvider);
    expect(state.energy, 0.5);
    expect(state.fatigue, 0.5);
    expect(state.completedToday, 1);
    expect(state.energyOrigin, PredictiveEvidenceOrigin.unavailable);
    expect(state.fatigueOrigin, PredictiveEvidenceOrigin.unavailable);
  });
}

final class _MemoryPrefsStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}
