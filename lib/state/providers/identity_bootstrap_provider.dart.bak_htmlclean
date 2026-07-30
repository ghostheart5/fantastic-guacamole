import 'package:fantastic_guacamole/features/auth/data/repositories/local_identity_repository.dart';
import 'package:fantastic_guacamole/features/auth/domain/models/chronospark_identity.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum IdentityBootstrapState { idle, loading, restored, missing, failed }

class IdentityBootstrapResult {
  const IdentityBootstrapResult({
    required this.state,
    this.identity,
    this.message,
  });

  final IdentityBootstrapState state;
  final ChronoSparkIdentity? identity;
  final String? message;
}

final identityRepositoryProvider = Provider<LocalIdentityRepository>(
  (ref) => LocalIdentityRepository(),
);

final identityBootstrapProvider = FutureProvider<IdentityBootstrapResult>((
  ref,
) async {
  try {
    final repository = ref.read(identityRepositoryProvider);

    final identity = await repository.loadIdentity();

    if (identity == null) {
      return const IdentityBootstrapResult(
        state: IdentityBootstrapState.missing,
        message: 'No saved identity found.',
      );
    }

    ref.read(identityAccountProvider.notifier).setIdentity(identity);

    return IdentityBootstrapResult(
      state: IdentityBootstrapState.restored,
      identity: identity,
      message: 'Identity restored.',
    );
  } catch (e) {
    return IdentityBootstrapResult(
      state: IdentityBootstrapState.failed,
      message: e.toString(),
    );
  }
});
