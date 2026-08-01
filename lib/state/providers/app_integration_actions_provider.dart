import 'package:fantastic_guacamole/state/services/app_integration_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appIntegrationActionsProvider = Provider<AppIntegrationActions>((Ref ref) {
  return AppIntegrationActions(ref);
});
