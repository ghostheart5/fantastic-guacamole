import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_coach_screen.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/profile/ui/profile_screen.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/tutorial/widgets/show_me_again_button.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Core feature widget import coverage', () {
    test('core feature widgets are importable and constructible', () {
      final List<Widget> widgets = <Widget>[
        const NexusScreen(),
        const CreatorScreen(),
        const SmartCoachScreen(),
        const TimelineScreen(),
        const ProfileScreen(),
        const SettingsScreen(),
        const ProgressionScreen(),
        const TrajectoryEngineScreen(),
        const SIConsoleScreen(),
        const ShowMeAgainButton(stepId: 'nexus_overview'),
      ];

      expect(widgets.length, 10);
    });
  });
}
