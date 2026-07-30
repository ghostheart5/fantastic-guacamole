import 'package:fantastic_guacamole/domain/policies/crisis_detection_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final siConsoleQueryControllerProvider = Provider<SIConsoleQueryController>((
  _,
) {
  return const SIConsoleQueryController();
});

class SIConsoleQueryController {
  const SIConsoleQueryController();

  bool detectsCrisis(String text) => CrisisDetectionPolicy.detects(text);
}
