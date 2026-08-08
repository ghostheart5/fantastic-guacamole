import 'package:fantastic_guacamole/domain/entities/session_entity.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Sessions/focus
///
/// Enforced by StartSession/EndSession, which await focus-session UI.
class SessionPolicy {
  static bool canStart(SessionEntity session) {
    return session.plannedDuration.inMinutes >= 5;
  }

  static bool canEnd(SessionEntity session) {
    return session.endedAt == null;
  }
}
