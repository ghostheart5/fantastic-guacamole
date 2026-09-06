import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _scopeProvider = NotifierProvider<_Scope, AccountStorageScope>(
  _Scope.new,
);

void main() {
  for (final scope in [
    const AccountStorageScope.signedOut(),
    const AccountStorageScope.unsafe(),
  ]) {
    test('extended bootstrap does no I/O while ${scope.state.name}', () async {
      final prefs = _ControlledPreferences();
      final errors = _Errors();
      final container = _container(prefs, errors);
      addTearDown(container.dispose);
      container.read(_scopeProvider.notifier).set(scope);

      await expectLater(
        container.read(extendedDomainBootstrapProvider.future),
        completes,
      );

      expect(prefs.initCalls, 0);
      expect(prefs.reads, isEmpty);
      expect(prefs.writes, isEmpty);
      expect(errors.values, isEmpty);
    });
  }

  test(
    'logout during preference initialization cancels old hydration',
    () async {
      final prefs = _ControlledPreferences(blockFirstInit: true);
      final errors = _Errors();
      final container = _container(prefs, errors);
      addTearDown(container.dispose);
      container.listen(extendedDomainBootstrapProvider, (_, _) {});
      await prefs.initStarted.future;

      container
          .read(_scopeProvider.notifier)
          .set(const AccountStorageScope.signedOut());
      // Match the immediate account fence's invalidation while Settings remains
      // subscribed long enough for a new bootstrap evaluation.
      container.invalidate(extendedDomainRepositoryProvider);
      container.invalidate(extendedDomainBootstrapProvider);
      await container.pump();
      prefs.releaseInit.complete();
      await expectLater(
        container.read(extendedDomainBootstrapProvider.future),
        completes,
      );
      await container.pump();

      expect(prefs.reads, isEmpty);
      expect(prefs.writes, isEmpty);
      expect(errors.values, isEmpty);
    },
  );

  test('delayed A initialization cannot overwrite B records', () async {
    final prefs = _ControlledPreferences(blockFirstInit: true)
      ..seed('account-b');
    final errors = _Errors();
    final container = _container(prefs, errors);
    addTearDown(container.dispose);
    container.listen(extendedDomainBootstrapProvider, (_, _) {});
    await prefs.initStarted.future;

    container
        .read(_scopeProvider.notifier)
        .set(AccountStorageScope.authenticated('account-b'));
    await container.pump();
    prefs.releaseInit.complete();
    await container.read(extendedDomainBootstrapProvider.future);
    await container.pump();

    expect(
      prefs.reads.where((key) => key.endsWith(_suffix('account-a'))),
      isEmpty,
    );
    expect(prefs.writes, isEmpty);
    _expectAccountRecords(container, 'account-b');
    expect(errors.values, isEmpty);
  });

  test(
    'account switch during first seed write stops remaining old writes',
    () async {
      final prefs = _ControlledPreferences(blockFirstSave: true)
        ..seed('account-b');
      final errors = _Errors();
      final container = _container(prefs, errors);
      addTearDown(container.dispose);
      container.listen(extendedDomainBootstrapProvider, (_, _) {});
      await prefs.saveStarted.future;

      container
          .read(_scopeProvider.notifier)
          .set(AccountStorageScope.authenticated('account-b'));
      await container.pump();
      prefs.releaseSave.complete();
      await container.read(extendedDomainBootstrapProvider.future);
      await container.pump();

      // An already issued write may finish only in its captured A namespace.
      expect(prefs.writes, [_key('planner_messages', 'account-a')]);
      _expectAccountRecords(container, 'account-b');
      expect(errors.values, isEmpty);
    },
  );

  test('ready A B A bootstrap rehydrates each account exactly once', () async {
    final prefs = _ControlledPreferences();
    final errors = _Errors();
    final container = _container(prefs, errors);
    addTearDown(container.dispose);
    container.listen(extendedDomainBootstrapProvider, (_, _) {});
    await container.read(extendedDomainBootstrapProvider.future);
    expect(prefs.writes, hasLength(5));

    container
        .read(_scopeProvider.notifier)
        .set(AccountStorageScope.authenticated('account-b'));
    await container.read(extendedDomainBootstrapProvider.future);
    expect(
      prefs.writes.where((key) => key.endsWith(_suffix('account-b'))),
      hasLength(5),
    );

    container
        .read(_scopeProvider.notifier)
        .set(AccountStorageScope.authenticated('account-a'));
    await container.read(extendedDomainBootstrapProvider.future);
    expect(prefs.writes, hasLength(10));
    expect(
      container.read(extendedDomainRepositoryProvider).getSettings(),
      hasLength(1),
    );
    expect(errors.values, isEmpty);
  });

  test('real storage initialization failure remains observable', () async {
    final failure = StateError('storage unavailable');
    final prefs = _ControlledPreferences(initError: failure);
    final errors = _Errors();
    final container = _container(prefs, errors);
    addTearDown(container.dispose);

    await expectLater(
      container.read(extendedDomainBootstrapProvider.future),
      throwsA(same(failure)),
    );
    expect(errors.values, contains(same(failure)));
  });
}

ProviderContainer _container(_ControlledPreferences prefs, _Errors errors) {
  return ProviderContainer(
    observers: [errors],
    overrides: [
      accountStorageScopeProvider.overrideWith(
        (ref) => ref.watch(_scopeProvider),
      ),
      accountLegacyOwnershipProvider.overrideWithValue(
        LegacyScopeOwnership.ambiguous,
      ),
      sharedPrefsStoreProvider.overrideWithValue(prefs),
    ],
  );
}

void _expectAccountRecords(ProviderContainer container, String account) {
  final repository = container.read(extendedDomainRepositoryProvider);
  expect(
    repository.getPlannerMessages().single.id,
    '$account-planner_messages',
  );
  expect(repository.getSiQueries().single.id, '$account-si_queries');
  expect(
    repository.getReflectionEntries().single.id,
    '$account-reflection_entries',
  );
  expect(
    repository.getAnalyticsMetrics().single.id,
    '$account-analytics_metrics',
  );
  expect(repository.getSettings().single.id, '$account-settings');
}

String _suffix(String account) =>
    '.${AccountStorageScope.authenticated(account).v2Namespace}';
String _key(String category, String account) =>
    'extended_domain.$category${_suffix(account)}';

final class _Scope extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => AccountStorageScope.authenticated('account-a');

  void set(AccountStorageScope value) => state = value;
}

final class _Errors extends ProviderObserver {
  final values = <Object>[];

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    values.add(error);
  }
}

final class _ControlledPreferences implements SharedPrefsStore {
  _ControlledPreferences({
    this.blockFirstInit = false,
    this.blockFirstSave = false,
    this.initError,
  });

  final bool blockFirstInit;
  final bool blockFirstSave;
  final Error? initError;
  final initStarted = Completer<void>();
  final releaseInit = Completer<void>();
  final saveStarted = Completer<void>();
  final releaseSave = Completer<void>();
  final values = <String, String>{};
  final reads = <String>[];
  final writes = <String>[];
  int initCalls = 0;

  void seed(String account) {
    for (final category in [
      'planner_messages',
      'si_queries',
      'reflection_entries',
      'analytics_metrics',
      'settings',
    ]) {
      values[_key(category, account)] = jsonEncode([
        {'id': '$account-$category', 'label': 'Preserved'},
      ]);
    }
  }

  @override
  Future<void> init() async {
    initCalls++;
    if (!initStarted.isCompleted) initStarted.complete();
    if (initError case final error?) throw error;
    if (blockFirstInit && initCalls == 1) await releaseInit.future;
  }

  @override
  String? load(String key) {
    reads.add(key);
    return values[key];
  }

  @override
  Future<void> save(String key, String value) async {
    writes.add(key);
    if (!saveStarted.isCompleted) saveStarted.complete();
    if (blockFirstSave && writes.length == 1) await releaseSave.future;
    values[key] = value;
  }

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);
}
