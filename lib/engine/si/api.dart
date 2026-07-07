// Public SI surface for code outside lib/engine/si/.
// New external imports should go through this file rather than directly
// importing additional engine internals.
export 'package:fantastic_guacamole/engine/si/ai_personality.dart';
export 'package:fantastic_guacamole/engine/si/ai_response.dart';
export 'package:fantastic_guacamole/engine/si/core/si_core.dart';
export 'package:fantastic_guacamole/engine/si/models/si_state.dart';
export 'package:fantastic_guacamole/engine/si/offline/behavior_shaping_engine.dart';
export 'package:fantastic_guacamole/engine/si/offline/identity_engine.dart';
export 'package:fantastic_guacamole/engine/si/offline/narrative_engine.dart';
export 'package:fantastic_guacamole/engine/si/offline/user_growth_engine.dart';
export 'package:fantastic_guacamole/engine/si/prediction.dart';
export 'package:fantastic_guacamole/engine/si/si_ai_service.dart';
export 'package:fantastic_guacamole/engine/si/si_decision.dart';
export 'package:fantastic_guacamole/engine/si/si_engine_service.dart';
export 'package:fantastic_guacamole/engine/si/si_response_policy.dart'
    hide SIIntent;
export 'package:fantastic_guacamole/engine/si/si_synthetic_soul_layer.dart';
export 'package:fantastic_guacamole/engine/si/si_task_core.dart' hide SICore;
export 'package:fantastic_guacamole/engine/si/synthetic_intelligence_engine.dart';
