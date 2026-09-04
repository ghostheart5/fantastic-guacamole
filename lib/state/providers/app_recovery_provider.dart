import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:fantastic_guacamole/state/services/app_recovery_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appRecoveryProvider = Provider<AppRecoveryService>(
  (Ref ref) =>
      AppRecoveryService(store: ref.watch(accountSharedPrefsStoreProvider)),
);
