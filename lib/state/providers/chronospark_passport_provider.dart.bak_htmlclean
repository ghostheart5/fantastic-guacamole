import 'package:fantastic_guacamole/state/providers/account_security_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_evolution_provider.dart';
import 'package:fantastic_guacamole/state/providers/life_os_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChronoSparkPassport {
  const ChronoSparkPassport({
    required this.operatorName,
    required this.identityStage,
    required this.mission,
    required this.accountTier,
    required this.securityLevel,
    required this.passportId,
  });

  final String operatorName;
  final String identityStage;
  final String mission;
  final String accountTier;
  final String securityLevel;
  final String passportId;
}

final chronoSparkPassportProvider = Provider<ChronoSparkPassport>((ref) {
  final identity = ref.watch(identityAccountProvider);
  final evolution = ref.watch(identityEvolutionProvider);
  final lifeOs = ref.watch(lifeOSProvider);
  final security = ref.watch(accountSecurityProvider);

  final passportSeed =
      '${identity?.id ?? "guest"}-${evolution.stage.hashCode.abs()}';

  return ChronoSparkPassport(
    operatorName: identity?.displayLabel ?? 'Operator',
    identityStage: evolution.stage,
    mission: lifeOs.mission,
    accountTier: identity?.accountTier.name.toUpperCase() ?? 'LOCAL',
    securityLevel: security.level.name.toUpperCase(),
    passportId: passportSeed,
  );
});
