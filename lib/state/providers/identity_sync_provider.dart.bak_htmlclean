import 'package:fantastic_guacamole/state/providers/cognitive_twin_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_evolution_provider.dart';
import 'package:fantastic_guacamole/state/providers/life_os_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IdentitySyncState {
  const IdentitySyncState({
    required this.ready,
    required this.identityStage,
    required this.mission,
    required this.futureVersion,
  });

  final bool ready;
  final String identityStage;
  final String mission;
  final String futureVersion;
}

final identitySyncProvider = Provider<IdentitySyncState>((ref) {
  final identity = ref.watch(identityAccountProvider);
  final lifeOs = ref.watch(lifeOSProvider);
  final evolution = ref.watch(identityEvolutionProvider);
  final twin = ref.watch(cognitiveTwinProvider);

  if (identity == null) {
    return const IdentitySyncState(
      ready: false,
      identityStage: '',
      mission: '',
      futureVersion: '',
    );
  }

  return IdentitySyncState(
    ready: true,
    identityStage: evolution.stage,
    mission: lifeOs.mission,
    futureVersion: twin.identityStatement,
  );
});
