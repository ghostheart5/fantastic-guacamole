<style>
a {
    text-decoration: none;
    color: #464feb;
}
tr th, tr td {
    border: 1px solid #e6e6e6;
}
tr th {
    background-color: #f5f5f5;
}
</style>

## Concrete import examples

### features/si_console/ui/si_console_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers/intelligence_provider.dart';
import '../../../state/providers/si_memory_provider.dart';
import '../../../ui/widgets/error_view.dart';
import '../../../ui/widgets/loading_overlay.dart';
```

### state/controllers/ai_controller.dart

```dart
import '../../core/errors/result.dart';
import '../../data/services/ai/models/agent_request.dart';
import '../../data/services/ai/models/agent_result.dart';
import '../../data/services/ai/orchestration/agent_orchestrator.dart';
import '../state/intelligence_state.dart';
```

### data/services/ai/orchestration/agent_orchestrator.dart

```dart
import '../agents/chat_agent.dart';
import '../agents/planner_agent.dart';
import '../agents/recommendation_agent.dart';
import '../models/agent_request.dart';
import '../models/agent_result.dart';
import '../tools/intent_classification_tool.dart';
import '../../../repositories/si_engine_repository.dart';
```

### data/repositories/si_engine_repository.dart

```dart
import '../../domain/interfaces/i_si_repository.dart';
import '../../domain/entities/si_decision_entity.dart';
import '../../engine/si/si_engine_service.dart';
import '../../engine/si/si_output_bundle.dart';
import '../../engine/si/models/si_state.dart';
```

### engine/si/si_engine_service.dart

```dart
import 'si_engine.dart';
import 'si_input_fusion.dart';
import 'si_intent_engine.dart';
import 'si_memory.dart';
import 'si_output_bundle.dart';
import 'si_policy.dart';
import 'si_reasoning.dart';
import 'si_self_consistency_engine.dart';
import 'si_snapshot.dart';
import 'si_user_state_tracker.dart';
```

Important rule: no package:flutter/* and no flutter_riverpod inside engine/si/*. Engine files stay pure Dart.
