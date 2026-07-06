import 'package:fantastic_guacamole/state/services/session_recovery_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionRecoveryProvider = Provider<SessionRecoveryService>(
  (Ref ref) => SessionRecoveryService(),
);
