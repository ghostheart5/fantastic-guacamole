import 'package:fantastic_guacamole/state/providers/identity_bootstrap_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppStartupStatus { initializing, ready, failed }

class AppStartupState {
  const AppStartupState({required this.status, required this.message});

  final AppStartupStatus status;
  final String message;
}

final appStartupProvider = FutureProvider<AppStartupState>((ref) async {
  try {
    final bootstrap = await ref.read(identityBootstrapProvider.future);

    switch (bootstrap.state) {
      case IdentityBootstrapState.restored:
        return const AppStartupState(
          status: AppStartupStatus.ready,
          message: 'Identity restored.',
        );

      case IdentityBootstrapState.missing:
        return const AppStartupState(
          status: AppStartupStatus.ready,
          message: 'Running without identity.',
        );

      case IdentityBootstrapState.failed:
        return AppStartupState(
          status: AppStartupStatus.failed,
          message: bootstrap.message ?? 'Bootstrap failed.',
        );

      default:
        return const AppStartupState(
          status: AppStartupStatus.ready,
          message: 'Startup complete.',
        );
    }
  } catch (e) {
    return AppStartupState(
      status: AppStartupStatus.failed,
      message: e.toString(),
    );
  }
});
