import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';

class SiPolicy {
  static bool shouldSuggestBreak(SiStateEntity state) {
    return state.fatigue > 0.7 || state.energy < 0.3;
  }

  static bool shouldPushFocus(SiStateEntity state) {
    return state.energy > 0.6 && state.focus > 0.5 && state.fatigue < 0.5;
  }
}
