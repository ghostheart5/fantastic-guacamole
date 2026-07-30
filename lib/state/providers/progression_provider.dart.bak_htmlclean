import 'package:fantastic_guacamole/state/services/progression_service.dart';
import 'package:fantastic_guacamole/state/models/progression_state.dart';
import 'package:fantastic_guacamole/state/controllers/controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final progressionServiceProvider = Provider<ProgressionService>(
  (Ref ref) => const ProgressionService(),
);

final progressionProvider = Provider<ProgressionState>((Ref ref) {
  final profile = ref.watch(profileProvider);
  final service = ref.watch(progressionServiceProvider);
  return service.fromProfile(profile);
});
