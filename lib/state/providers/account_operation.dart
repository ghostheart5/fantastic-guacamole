import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A lease for one asynchronous operation, including A -> B -> A transitions.
final class AccountOperation {
  AccountOperation.capture(this._ref)
    : namespace = _ref.read(accountStorageScopeProvider).v2Namespace,
      generation = _ref.read(authSessionBoundaryProvider).generation;

  final Ref _ref;
  final String? namespace;
  final int generation;

  bool get isCurrent {
    if (!_ref.mounted) return false;
    try {
      final scope = _ref.read(accountStorageScopeProvider);
      return scope.isWritable &&
          scope.v2Namespace == namespace &&
          _ref.read(authSessionBoundaryProvider).generation == generation;
    } on Object {
      return false;
    }
  }

  void check() {
    if (!isCurrent) throw const StaleAccountOperation();
  }

  Future<T> wait<T>(Future<T> pending) async {
    final result = await pending;
    check();
    return result;
  }
}

final class StaleAccountOperation implements Exception {
  const StaleAccountOperation();
}
