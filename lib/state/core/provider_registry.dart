import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/learning_history_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_memory_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final providerRegistryProvider = Provider<List<Object>>((ref) {
  return <Object>[
    tasksProvider,
    siStateProvider,
    learningProvider,
    aiTriggerProvider,
    aiDecisionProvider,
    aiResponseProvider,
    notificationProvider,
    learningHistoryProvider,
    siMemoryProvider,
  ];
});
