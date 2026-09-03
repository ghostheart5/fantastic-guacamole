import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_shared_prefs_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/state/services/extended_domain_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fails closed on malformed local records and persists used records',
    () async {
      final _MemoryPreferences preferences = _MemoryPreferences();
      await preferences.save('extended_domain.planner_messages', '[{"id": 7}]');

      final ExtendedDomainService service = ExtendedDomainService(preferences);
      await Future.wait<void>(<Future<void>>[
        service.initialize(),
        service.initialize(),
      ]);

      expect(service.getPlannerMessages(), isEmpty);

      await service.savePlannerMessage(
        const PlannerMessage(id: 'planner-message-1', label: 'Ready'),
      );

      final ExtendedDomainService restored = ExtendedDomainService(preferences);
      await restored.initialize();

      expect(restored.getPlannerMessages().single.id, 'planner-message-1');
    },
  );

  test('account-scoped services isolate SI and planner records', () async {
    final _MemoryPreferences root = _MemoryPreferences();
    final ExtendedDomainService accountA = ExtendedDomainService(
      AccountScopedSharedPrefsStore(
        delegate: root,
        scope: AccountStorageScope.authenticated('account-a'),
      ),
    );
    final ExtendedDomainService accountB = ExtendedDomainService(
      AccountScopedSharedPrefsStore(
        delegate: root,
        scope: AccountStorageScope.authenticated('account-b'),
      ),
    );
    await Future.wait<void>(<Future<void>>[
      accountA.initialize(),
      accountB.initialize(),
    ]);

    await accountA.savePlannerMessage(
      const PlannerMessage(id: 'planner-a', label: 'Account A'),
    );
    await accountA.saveSiQuery(
      const SiQuery(id: 'si-a', label: 'Private query'),
    );

    expect(accountA.getPlannerMessages().single.id, 'planner-a');
    expect(accountA.getSiQueries().single.id, 'si-a');
    expect(accountB.getPlannerMessages(), isEmpty);
    expect(accountB.getSiQueries(), isEmpty);
  });
}

final class _MemoryPreferences
    implements SharedPrefsStore, EnumerableSharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  Future<void> save(String key, String value) async => values[key] = value;

  @override
  String? load(String key) => values[key];

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<Set<String>> keys() async => values.keys.toSet();
}
