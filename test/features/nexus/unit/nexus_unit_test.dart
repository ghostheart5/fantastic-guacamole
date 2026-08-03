import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NexusStartupSummary', () {
    test('retains startup signal fields for UI composition', () {
      final ProfileState profile = ProfileState(
        name: 'Operator',
        level: 4,
        streak: 6,
        profileReady: true,
      );

      final NexusStartupSummary summary = NexusStartupSummary(
        profile: profile,
        energy: 0.72,
        fatigue: 0.28,
        completedToday: 3,
        emotionLabel: 'focused',
        startupDirective: 'Prime objective locked. Execute one decisive action now.',
      );

      expect(summary.profile.name, 'Operator');
      expect(summary.profile.level, 4);
      expect(summary.energy, 0.72);
      expect(summary.fatigue, 0.28);
      expect(summary.completedToday, 3);
      expect(summary.emotionLabel, 'focused');
      expect(summary.startupDirective, isNotEmpty);
    });
  });
}

