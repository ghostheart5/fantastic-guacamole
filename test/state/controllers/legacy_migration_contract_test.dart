import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/progression/progression_calculator.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/services/extended_domain_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Root-03 legacy migration contracts', () {
    test('Profile V2 keys are deterministic and collision-free', () {
      expect(
        ProfileController.canonicalStorageKeyForUser('user A'),
        'profile_state_v3.v2.dXNlciBB',
      );
      expect(
        ProfileController.canonicalStorageKeyForUser('a/b'),
        isNot(ProfileController.canonicalStorageKeyForUser('a?b')),
      );
    });

    test(
      'ExtendedDomain copies once, retains an existing destination, and is idempotent',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'extended_domain.settings': 'legacy',
          'extended_domain.settings.user_A': 'current',
        });
        final SharedPreferences prefs = await SharedPreferences.getInstance();

        await ExtendedDomainService.migrateLegacyStorage(
          prefs: prefs,
          storageScope: 'user A',
        );
        expect(prefs.getString('extended_domain.settings.user_A'), 'current');
        expect(prefs.getString('extended_domain.settings'), 'legacy');

        await prefs.remove('extended_domain.settings.user_A');
        await ExtendedDomainService.migrateLegacyStorage(
          prefs: prefs,
          storageScope: 'user A',
        );
        expect(prefs.getString('extended_domain.settings.user_A'), 'legacy');
        expect(prefs.containsKey('extended_domain.settings'), isFalse);

        await ExtendedDomainService.migrateLegacyStorage(
          prefs: prefs,
          storageScope: 'user A',
        );
        expect(prefs.getString('extended_domain.settings.user_A'), 'legacy');
      },
    );

    test(
      'Profile preserves ambiguous global legacy data without migration',
      () async {
        final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
        final SecureStore store = SecureStore(backend: backend);
        await store.writeString('profile_state_v2', 'legacy-profile');

        final ProfileLegacyMigrationResult result =
            await ProfileController.migrateLegacyStorage(
              secureStore: store,
              hiveStore: const HiveStoreAdapter(),
              userId: 'user A',
            );
        expect(result, ProfileLegacyMigrationResult.preservedAmbiguous);
        expect(await store.readString('profile_state_v2'), 'legacy-profile');
        expect(
          await store.readString(
            ProfileController.canonicalStorageKeyForUser('user A'),
          ),
          isNull,
        );
      },
    );

    test(
      'Learning migration is scoped, non-overwriting, and retry-safe',
      () async {
        final _FailingWriteBackend backend = _FailingWriteBackend();
        final SecureStore store = SecureStore(backend: backend);
        await backend.seed('ai_learning', 'legacy-learning');

        await expectLater(
          LearningController.migrateLegacyStorage(
            store: store,
            userId: 'user A',
          ),
          throwsStateError,
        );
        expect(await store.readString('ai_learning'), 'legacy-learning');

        backend.failWrites = false;
        await LearningController.migrateLegacyStorage(
          store: store,
          userId: 'user A',
        );
        expect(await store.readString('ai_learning.user_A'), 'legacy-learning');
        expect(await store.readString('ai_learning'), isNull);

        await backend.seed('ai_learning', 'new-legacy');
        await LearningController.migrateLegacyStorage(
          store: store,
          userId: 'user A',
        );
        expect(await store.readString('ai_learning.user_A'), 'legacy-learning');
        expect(await store.readString('ai_learning'), 'new-legacy');
      },
    );

    test('HLM-05 progression calculation remains canonical', () {
      final result = const ProgressionCalculator().calculate(
        xp: 250,
        legacyLevelFloor: 2,
      );
      expect(result.xp, 250);
      expect(result.effectiveLevel, greaterThanOrEqualTo(2));
    });
  });
}

class _FailingWriteBackend implements SecureStoreBackend {
  final Map<String, String> _values = <String, String>{};
  bool failWrites = true;

  Future<void> seed(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete({required String key}) async => _values.remove(key);

  @override
  Future<void> deleteAll() async => _values.clear();

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrites) throw StateError('write failed');
    _values[key] = value;
  }
}
