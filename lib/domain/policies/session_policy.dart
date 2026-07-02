import 'package:fantastic_guacamole/domain/entities/session_entity.dart';

class SessionPolicy {
  static bool canStart(SessionEntity session) {
    return session.plannedDuration.inMinutes >= 5;
  }

  static bool canEnd(SessionEntity session) {
    return session.endedAt == null;
  }
}
