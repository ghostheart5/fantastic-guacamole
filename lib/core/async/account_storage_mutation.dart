import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';

const String accountStorageMutationKey =
    'chronospark-account-owned-local-storage';

Future<T> runAccountStorageMutation<T>(
  Future<T> Function() mutation, {
  KeyedMutationCoordinator? coordinator,
}) {
  return (coordinator ?? KeyedMutationCoordinator.shared).runExclusive(
    accountStorageMutationKey,
    mutation,
  );
}
