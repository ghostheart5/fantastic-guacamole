import 'dart:async';

import 'package:fantastic_guacamole/data/services/local_profile_auth_service.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared by auth state and the factory without depending on intelligence
/// state, which itself is derived from the active profile.
final localProfileAuthServiceProvider = Provider<LocalProfileAuthService>((
  ref,
) {
  final service = LocalProfileAuthService(
    store: ref.read(secureStoreProvider),
    onBeforeClosed: (id) => ref
        .read(localUserDataCleanupServiceProvider)
        .cancelScheduledNotificationsForAccount(id),
    onProfileDeleted: ref
        .read(localProfileLifecycleActionsProvider)
        .deleteProfileData,
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// An action binding avoids a dependency cycle from identity to the lifecycle
/// coordinator, which itself listens to identity. Missing binding fails closed.
final localProfileLifecycleActionsProvider =
    Provider<LocalProfileLifecycleActions>(
      (ref) => LocalProfileLifecycleActions(),
    );

class LocalProfileLifecycleActions {
  Object? _owner;
  Future<void> Function(String)? _delete;

  void attach(Object owner, Future<void> Function(String) delete) {
    _owner = owner;
    _delete = delete;
  }

  void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _delete = null;
  }

  Future<void> deleteProfileData(String accountId) {
    final action = _delete;
    if (action == null) {
      throw StateError(
        'Local profile lifecycle is unavailable. Retry opening the app.',
      );
    }
    return action(accountId);
  }
}
