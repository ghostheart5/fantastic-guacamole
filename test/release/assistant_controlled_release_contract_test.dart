import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 11 release controls guard all assistant capabilities', () {
    final String repository = File(
      'lib/data/repositories/feature_flag_repository.dart',
    ).readAsStringSync();
    final String planner = File(
      'lib/state/controllers/smart_planner_query_controller.dart',
    ).readAsStringSync();
    final String si = File(
      'lib/state/providers/si_v2_provider.dart',
    ).readAsStringSync();
    final String memory = File(
      'lib/state/providers/memories_provider.dart',
    ).readAsStringSync();

    expect(repository, contains('loadAssistantReleaseConfig'));
    expect(repository, contains('kill_assistant_smart_planner_v2'));
    expect(repository, contains('kill_assistant_si_console_v2'));
    expect(repository, contains('kill_assistant_governed_memory'));
    expect(repository, contains('kill_assistant_safety_critic'));
    expect(planner, contains('AssistantReleaseCapability.smartPlannerV2'));
    expect(planner, contains('AssistantReleaseCapability.safetyCritic'));
    expect(si, contains('AssistantReleaseCapability.siConsoleV2'));
    expect(si, contains('AssistantReleaseCapability.safetyCritic'));
    expect(memory, contains('AssistantReleaseCapability.governedMemory'));
  });

  test('shadow mode has no publication or write authority', () {
    final String source = File(
      'lib/domain/release/assistant_release_control.dart',
    ).readAsStringSync();

    expect(source, contains('bool get mayPublish => false'));
    expect(source, contains('bool get mayWrite => false'));
    expect(source, isNot(contains('rawPrompt')));
    expect(source, isNot(contains('rawResponse')));
  });

  test('beta preference is account-scoped and visible in Settings', () {
    final String provider = File(
      'lib/state/providers/assistant_release_provider.dart',
    ).readAsStringSync();
    final String settings = File(
      'lib/features/settings/ui/settings_screen.sections.dart',
    ).readAsStringSync();

    expect(provider, contains('assistant_beta_opt_in_v1.\$digest'));
    expect(provider, contains('if (!scope.isAuthenticated'));
    expect(settings, contains('Join opt-in assistant beta'));
    expect(settings, contains('Independent rollback ready'));
  });
}
