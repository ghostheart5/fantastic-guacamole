import 'package:fantastic_guacamole/data/repositories/assistant_conversation_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final assistantConversationHistoryRepositoryProvider =
    Provider<AssistantConversationRepository?>((ref) {
      final scope = ref.watch(accountStorageScopeProvider);
      final generation = ref.watch(authSessionBoundaryProvider).generation;
      if (!scope.isWritable) return null;
      // Capture the account-scoped store before any asynchronous work; never read a
      // legacy unowned transcript or obtain a different account's store after await.
      final store = ref.read(secureStoreProvider).forAccount(scope);
      return AssistantConversationRepository(
        store,
        isCurrent: () {
          try {
            final current = ref.read(accountStorageScopeProvider);
            return current.isWritable &&
                current.v2Namespace == scope.v2Namespace &&
                ref.read(authSessionBoundaryProvider).generation == generation;
          } on Object {
            return false;
          }
        },
      );
    });
