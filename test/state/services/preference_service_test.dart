import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_shared_prefs_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/services/preference_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps onboarding device-wide and account preferences isolated',
    () async {
      final _MemoryStore root = _MemoryStore();
      final PreferenceService accountA = PreferenceService(
        deviceStore: root,
        accountStore: AccountScopedSharedPrefsStore(
          delegate: root,
          scope: AccountStorageScope.authenticated('account-a'),
        ),
      );
      final PreferenceService accountB = PreferenceService(
        deviceStore: root,
        accountStore: AccountScopedSharedPrefsStore(
          delegate: root,
          scope: AccountStorageScope.authenticated('account-b'),
        ),
      );

      await accountA.setOnboardingComplete(true);
      await accountA.setLastOpenedTab(2);
      await accountA.setUserPreference('density', 'compact');

      expect(accountB.getOnboardingComplete(), isTrue);
      expect(accountB.getLastOpenedTab(), isNull);
      expect(accountB.getUserPreferences(), isEmpty);
      expect(accountA.getLastOpenedTab(), 2);
      expect(accountA.getUserPreferences(), <String, Object>{
        'density': 'compact',
      });
    },
  );

  test('account preference access fails closed without a scoped store', () {
    final PreferenceService service = PreferenceService(
      deviceStore: _MemoryStore(),
    );

    expect(service.getLastOpenedTab, throwsStateError);
    expect(service.getUserPreferences, throwsStateError);
  });
}

final class _MemoryStore
    implements SharedPrefsStore, EnumerableSharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> init() async {}

  @override
  Future<Set<String>> keys() async => values.keys.toSet();

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;
}
