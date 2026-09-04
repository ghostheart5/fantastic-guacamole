import 'package:fantastic_guacamole/engine/assistant/assistant_system_boot.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'captures the initial engine state without a system-layer dependency',
    () {
      final snapshot = const AssistantSystemBoot().initialSnapshot(
        si: const SIState(energy: 0.72, fatigue: 0.28),
        learning: const LearningState(completed: 4, skipped: 1),
      );

      expect(snapshot.energy, 0.72);
      expect(snapshot.fatigue, 0.28);
      expect(snapshot.completed, 4);
      expect(snapshot.skipped, 1);
      expect(snapshot.reasoning, 'System boot');
    },
  );
}
