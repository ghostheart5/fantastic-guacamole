import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final NotifierProvider<_Scope, AccountStorageScope> _scope =
    NotifierProvider<_Scope, AccountStorageScope>(_Scope.new);

void main() {
  test('real memory provider chain isolates A to B to A', () async {
    final _Store store = _Store()..values['memories_v1'] = '[]';
    final ProviderContainer c = ProviderContainer(overrides: [
      sensitivePrefsStoreProvider.overrideWithValue(store),
      accountStorageScopeProvider.overrideWith((Ref ref) => ref.watch(_scope)),
    ]);
    addTearDown(c.dispose);
    await _set(c, AccountStorageScope.authenticated('A'));
    final Object repoA = c.read(memoryRepositoryProvider);
    final Object getA = c.read(getMemoriesUseCaseProvider);
    await c.read(saveMemoryUseCaseProvider).call(_memory('A_MEMORY_ONLY'));
    c.invalidate(memoriesProvider);
    expect(_texts(c), contains('A_MEMORY_ONLY'));
    expect(c.read(memoriesProvider).map((e) => e.text), contains('A_MEMORY_ONLY'));
    await _set(c, AccountStorageScope.authenticated('B'));
    expect(identical(repoA, c.read(memoryRepositoryProvider)), isFalse);
    expect(identical(getA, c.read(getMemoriesUseCaseProvider)), isFalse);
    expect(_texts(c), isNot(contains('A_MEMORY_ONLY')));
    expect(c.read(memoriesProvider).map((e) => e.text), isNot(contains('A_MEMORY_ONLY')));
    await c.read(saveMemoryUseCaseProvider).call(_memory('B_MEMORY_ONLY'));
    c.invalidate(memoriesProvider);
    expect(_texts(c), contains('B_MEMORY_ONLY'));
    await _set(c, AccountStorageScope.authenticated('A'));
    expect(_texts(c), contains('A_MEMORY_ONLY'));
    expect(_texts(c), isNot(contains('B_MEMORY_ONLY')));
    expect(store.values['memories_v1'], '[]');
  });

  test('same user, signed out to B, and final C expose no A memory', () async {
    final _Store store = _Store()..values['memories_v1'] = '[]';
    final ProviderContainer c = ProviderContainer(overrides: [
      sensitivePrefsStoreProvider.overrideWithValue(store),
      accountStorageScopeProvider.overrideWith((Ref ref) => ref.watch(_scope)),
    ]);
    addTearDown(c.dispose);
    await _set(c, AccountStorageScope.authenticated('A'));
    await c.read(saveMemoryUseCaseProvider).call(_memory('A_MEMORY_ONLY'));
    c.invalidate(memoriesProvider);
    await _set(c, AccountStorageScope.authenticated('A'));
    expect(_texts(c).where((String text) => text == 'A_MEMORY_ONLY'), hasLength(1));
    await _set(c, const AccountStorageScope.signedOut());
    expect(c.read(memoriesProvider), isEmpty);
    await _set(c, AccountStorageScope.authenticated('B'));
    expect(_texts(c), isNot(contains('A_MEMORY_ONLY')));
    await c.read(saveMemoryUseCaseProvider).call(_memory('B_MEMORY_ONLY'));
    await _set(c, const AccountStorageScope.unsafe());
    await _set(c, AccountStorageScope.authenticated('C'));
    expect(_texts(c), isEmpty);
    expect(store.values['memories_v1'], '[]');
  });
}

Future<void> _set(ProviderContainer c, AccountStorageScope scope) async {
  c.read(_scope.notifier).set(scope);
  c.invalidate(memoriesProvider);
  await Future<void>.delayed(Duration.zero);
}
List<String> _texts(ProviderContainer c) => c.read(getMemoriesUseCaseProvider).call().map((e) => e.text).toList();
MemoryEntity _memory(String text) => MemoryEntity(id: text, text: text, date: DateTime.utc(2026));
class _Scope extends Notifier<AccountStorageScope> { @override AccountStorageScope build() => const AccountStorageScope.unsafe(); void set(AccountStorageScope value) => state = value; }
class _Store implements SharedPrefsStore { final Map<String,String> values=<String,String>{}; @override Future<void> clear() async=>values.clear(); @override Future<void> delete(String k) async=>values.remove(k); @override Future<void> init() async{} @override String? load(String k)=>values[k]; @override Future<void> save(String k,String v) async=>values[k]=v; }
