import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/person_context_repository.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final personContextClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

final personContextRepositoryProvider = Provider<PersonContextRepository?>((
  Ref ref,
) {
  final scope = ref.watch(accountStorageScopeProvider);
  if (!scope.isWritable) return null;
  return PersonContextRepository(
    ref.read(sensitivePrefsStoreProvider),
    scope,
    clock: ref.watch(personContextClockProvider),
  );
});

final personContextSpineProvider = FutureProvider<PersonContextSpine?>((
  Ref ref,
) async {
  return ref.watch(personContextRepositoryProvider)?.load();
});

final personContextForSurfaceProvider =
    Provider.family<PersonContextView?, PersonContextSurface>((
      Ref ref,
      PersonContextSurface surface,
    ) {
      final scope = ref.watch(accountStorageScopeProvider);
      final PersonContextSpine? spine = ref
          .watch(personContextSpineProvider)
          .value;
      if (!scope.isWritable ||
          spine == null ||
          spine.accountScopeId != scope.v2Namespace) {
        return null;
      }
      return spine.forSurface(surface, ref.watch(personContextClockProvider)());
    });

final personContextActionsProvider = Provider<PersonContextActions>(
  PersonContextActions.new,
);

final class PersonContextActions {
  PersonContextActions(this._ref);

  final Ref _ref;

  Future<void> upsert(PersonContextSignal signal) async {
    final PersonContextRepository repository = _repository();
    await repository.upsert(signal);
    _ref.invalidate(personContextSpineProvider);
  }

  Future<void> remove(String signalId) async {
    final PersonContextRepository repository = _repository();
    await repository.remove(signalId);
    _ref.invalidate(personContextSpineProvider);
  }

  Future<Map<String, dynamic>> export() => _repository().export();

  Future<void> clear() async {
    await _repository().clear();
    _ref.invalidate(personContextSpineProvider);
  }

  PersonContextRepository _repository() {
    final PersonContextRepository? repository = _ref.read(
      personContextRepositoryProvider,
    );
    if (repository == null) {
      throw StateError('Person context is unavailable for this account.');
    }
    return repository;
  }
}
