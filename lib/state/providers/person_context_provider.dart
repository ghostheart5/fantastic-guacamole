import 'dart:async';

import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/person_context_repository.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final personContextClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

final personContextTimerFactoryProvider =
    Provider<Timer Function(Duration duration, void Function() callback)>(
      (_) => Timer.new,
    );

final personContextRepositoryProvider = Provider<PersonContextRepository?>((
  Ref ref,
) {
  final scope = ref.watch(accountStorageScopeProvider);
  if (!scope.isWritable) return null;
  final AuthSessionBoundary boundary = ref.watch(authSessionBoundaryProvider);
  final int generation = boundary.generation;
  final String namespace = scope.v2Namespace!;
  return PersonContextRepository(
    ref.read(sensitivePrefsStoreProvider),
    scope,
    clock: ref.watch(personContextClockProvider),
    isScopeCurrent: () {
      try {
        final currentScope = ref.read(accountStorageScopeProvider);
        final AuthSessionBoundary currentBoundary = ref.read(
          authSessionBoundaryProvider,
        );
        return currentScope.isWritable &&
            currentScope.v2Namespace == namespace &&
            currentBoundary.generation == generation;
      } on Object {
        return false;
      }
    },
  );
});

final personContextSpineProvider = FutureProvider<PersonContextSpine?>((
  Ref ref,
) async {
  return ref.watch(personContextRepositoryProvider)?.load();
});

final personContextForSurfaceProvider =
    Provider.family<PersonContextView?, PersonContextAccessRequest>((
      Ref ref,
      PersonContextAccessRequest request,
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
      final DateTime now = ref.watch(personContextClockProvider)().toUtc();
      final List<DateTime> transitions = <DateTime>[];
      for (final PersonContextSignal signal in spine.signals) {
        if (!signal.surfaceScopes.contains(request.surface) ||
            !request.purposes.contains(signal.purpose)) {
          continue;
        }
        final DateTime? consented = signal.consentedAt?.toUtc();
        if (consented != null && consented.isAfter(now)) {
          transitions.add(consented);
        }
        final DateTime freshUntil = signal.freshUntil.toUtc();
        if (freshUntil.isAfter(now)) transitions.add(freshUntil);
        final DateTime expiresAt = signal.expiresAt.toUtc();
        if (expiresAt.isAfter(now)) transitions.add(expiresAt);
      }
      if (transitions.isNotEmpty) {
        transitions.sort();
        void refreshAtBoundary() {
          ref.invalidate(personContextSpineProvider);
          ref.invalidateSelf();
        }

        final Timer timer = ref.read(personContextTimerFactoryProvider)(
          transitions.first.difference(now),
          refreshAtBoundary,
        );
        ref.onDispose(timer.cancel);
      }
      return spine.forAccess(request, now);
    });

final personContextActionsProvider = Provider<PersonContextActions>(
  PersonContextActions.new,
);

final personContextSettingsEntryProvider =
    NotifierProvider<PersonContextSettingsEntry, bool>(
      PersonContextSettingsEntry.new,
    );

class PersonContextSettingsEntry extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  void clear() => state = false;
}

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

  Future<void> correct({
    required String signalId,
    required String value,
    required DateTime correctedAt,
    required String reason,
    required DateTime freshUntil,
    required DateTime expiresAt,
  }) async {
    final PersonContextRepository repository = _repository();
    await repository.updateSignal(
      signalId,
      (PersonContextSignal current) => current.corrected(
        value: value,
        correctedAt: correctedAt,
        reason: reason,
        freshUntil: freshUntil,
        expiresAt: expiresAt,
      ),
    );
    _ref.invalidate(personContextSpineProvider);
  }

  Future<void> withdrawConsent({
    required String signalId,
    required DateTime withdrawnAt,
  }) async {
    final PersonContextRepository repository = _repository();
    await repository.updateSignal(
      signalId,
      (PersonContextSignal current) => current.withdrawConsent(withdrawnAt),
    );
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
