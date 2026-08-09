import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/si_engine_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SI repository round-trips SiStateEntity', () async {
    final SiEngineRepository repository = SiEngineRepository(
      SecureStore(backend: InMemorySecureStoreBackend()),
    );
    final SiStateEntity original = SiStateEntity(
      energy: 0.8,
      focus: 0.7,
      fatigue: 0.2,
      mood: 'positive',
      confidence: 0.9,
      anticipatesConfusion: true,
      primaryInstinct: 'safety_first',
      avoidOverwhelm: true,
      frictionScore: 0.4,
      highFriction: false,
      lastUpdated: DateTime.utc(2026, 8, 4, 12),
    );

    await repository.saveState(original);
    final SiStateEntity restored = (await repository.getCurrentState())!;

    expect(restored.energy, original.energy);
    expect(restored.focus, original.focus);
    expect(restored.fatigue, original.fatigue);
    expect(restored.mood, original.mood);
    expect(restored.confidence, original.confidence);
    expect(restored.anticipatesConfusion, original.anticipatesConfusion);
    expect(restored.primaryInstinct, original.primaryInstinct);
    expect(restored.avoidOverwhelm, original.avoidOverwhelm);
    expect(restored.frictionScore, original.frictionScore);
    expect(restored.highFriction, original.highFriction);
    expect(restored.lastUpdated, original.lastUpdated);
  });

  test('SI DI provider resolves the domain repository interface', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(siEngineRepositoryProvider), isA<ISiRepository>());
  });
}
