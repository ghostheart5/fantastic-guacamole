import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_system_boot.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/entitlement_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_memory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final stateBootstrapProvider = FutureProvider<void>((ref) async {
  ref.read(eventBusBootstrapProvider);
  final SIState si = ref.read(siStateProvider);
  final LearningState learning = ref.read(learningProvider);
  final AssistantSystemBoot boot = const AssistantSystemBoot();

  // Riverpod forbids mutating other providers while this provider is building.
  // Deferring by one event-loop turn avoids the initialization-time mutation.
  await Future<void>.delayed(Duration.zero);
  if (!ref.mounted) return;
  // Start authority hydration without blocking local startup on the network.
  // Paid consumers continue to fail closed while this AsyncValue is loading
  // or errored. Its former ten-second wait exceeded startup's four-second
  // state deadline and incorrectly put otherwise usable profiles in limited mode.
  ref.read(entitlementProvider);
  ref
      .read(siMemoryProvider.notifier)
      .capture(boot.initialSnapshot(si: si, learning: learning));
});
