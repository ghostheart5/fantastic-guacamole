import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firstUseContextOfferSeenProvider = FutureProvider<bool>((Ref ref) async {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  final String? namespace = scope.v2Namespace;
  if (!scope.isWritable || namespace == null) return true;
  final SharedPrefsStore store = ref.read(sharedPrefsStoreProvider);
  await store.init();
  return store.load(_key(namespace)) == 'true';
});

final firstUseContextOfferActionsProvider =
    Provider<FirstUseContextOfferActions>(FirstUseContextOfferActions.new);

/// Account-scoped one-shot gate for the optional prompt shown only after the
/// first useful Planner decision. Claiming records that the offer was shown;
/// it never records context or implies consent.
final class FirstUseContextOfferActions {
  FirstUseContextOfferActions(this._ref);

  final Ref _ref;
  Future<void> _tail = Future<void>.value();

  Future<bool> claim() {
    bool claimed = false;
    final Future<void> operation = _tail.then((_) async {
      final AccountStorageScope before = _ref.read(accountStorageScopeProvider);
      final String? namespace = before.v2Namespace;
      if (!before.isWritable || namespace == null) return;
      final SharedPrefsStore store = _ref.read(sharedPrefsStoreProvider);
      await store.init();
      if (store.load(_key(namespace)) == 'true') return;
      final AccountStorageScope after = _ref.read(accountStorageScopeProvider);
      if (!after.isWritable || after.v2Namespace != namespace) return;
      await store.save(_key(namespace), 'true');
      claimed = true;
      _ref.invalidate(firstUseContextOfferSeenProvider);
    });
    _tail = operation.catchError((Object _) {});
    return operation.then((_) => claimed);
  }
}

String _key(String namespace) =>
    'chronospark.first_use_context_offer.v1.$namespace';
